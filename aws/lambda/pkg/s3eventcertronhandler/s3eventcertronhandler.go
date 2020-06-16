package s3eventcertronhandler

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/acm"
	"github.com/aws/aws-sdk-go/service/cloudwatchevents"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/aws/aws-sdk-go/service/sts"
	"github.com/spf13/viper"
)

const (
	platformName = "certron"

	logInfoPattern = "I [S3Event=%s] %s\n"
	tmpDir         = "/tmp"
	defaultRegion  = "us-east-1"

	cronExp            = "cron(0 5 %d %d ? %d)"
	expiryLessDefault  = 1
	ruleNameFmt        = "cron-certron-%s-%s"
	stepFuncArnPattern = "arn:aws:states:%s:%s:stateMachine:%s" //arn:aws:states:us-east-1:728160576949:stateMachine:certron

	expiryLessKey         = "EXPIRY_LESS"
	certRefreshEnabledKey = "CERT_REFRESH_ENABLED"
	targetRoleArnKey      = "TARGET_ROLE_ARN"
)

type S3Event struct {
	Records []struct {
		EventName        string `json:"eventName"`
		ResponseElements struct {
			RequestID string `json:"x-amz-request-id"`
		}
		S3 struct {
			Bucket struct {
				Name string `json:"name"`
			} `json:"bucket"`
			Object struct {
				Key string `json:"key"`
			} `json:"object"`
		} `json:"s3"`
	} `json:"records"`
}

type Services struct {
	downloader *s3manager.Downloader
	acm        *acm.ACM
	cwe        *cloudwatchevents.CloudWatchEvents
	sts        *sts.STS
}

func HandleRequest(evt S3Event) error {
	viper.AutomaticEnv()
	viper.SetEnvPrefix("certron")

	bucket := evt.Records[0].S3.Bucket.Name
	key := evt.Records[0].S3.Object.Key
	keyParts := strings.Split(key, string(os.PathSeparator))
	domain := keyParts[0]

	evt.logInfo(fmt.Sprintf("event=%s received", evt.Records[0].EventName))
	evt.logInfo("bucket=" + bucket)
	evt.logInfo("key=" + key)

	sess := session.Must(session.NewSession())
	svcs := Services{
		downloader: s3manager.NewDownloader(sess),
		acm:        acm.New(sess),
		cwe:        cloudwatchevents.New(sess),
		sts:        sts.New(sess),
	}

	filename := filepath.Base(key)
	filep := filepath.Join(tmpDir, filename)

	f, err := os.Create(filep)
	if err != nil {
		return errOut(err)
	}

	n, err := svcs.downloader.Download(f, &s3.GetObjectInput{
		Bucket: aws.String(bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return errOut(fmt.Errorf("failed to download file, %v", err))
	}
	evt.logInfo(fmt.Sprintf("file downloaded, %d bytes\n", n))

	certFiles, err := unzip(filep, tmpDir)
	if err != nil {
		return errOut(fmt.Errorf("failed to unzip archive=%s, %v", filep, err))
	}

	certs := make(map[string][]byte)
	for _, fp := range certFiles {
		certName := filepath.Base(fp)
		b, err := ioutil.ReadFile(fp)
		if err != nil {
			return errOut(err)
		}
		certs[certName] = b
	}

	return svcs.importCertificate(domain, certs)
}

func (svcs Services) importCertificate(domain string, certs map[string][]byte) error {
	var (
		certARN   *string
		nextToken *string
	)

	for {
		req, err := svcs.acm.ListCertificates(&acm.ListCertificatesInput{NextToken: nextToken})
		if err != nil {
			return err
		}
		nextToken = req.NextToken

		for _, cs := range req.CertificateSummaryList {
			if domain == *cs.DomainName {
				certARN = cs.CertificateArn
				break
			}
		}

		if nextToken == nil {
			break
		}
	}

	ico, err := svcs.acm.ImportCertificate(&acm.ImportCertificateInput{
		Certificate:      certs["cert.pem"],
		CertificateChain: certs["chain.pem"],
		PrivateKey:       certs["privKey.pem"],
		CertificateArn:   certARN,
	})
	if err != nil {
		return errOut(err)
	}

	if viper.GetBool(certRefreshEnabledKey) {
		dco, err := svcs.acm.DescribeCertificate(&acm.DescribeCertificateInput{
			CertificateArn: ico.CertificateArn,
		})
		if err != nil {
			return errOut(err)
		}

		if err := svcs.setCertificateRefresh(dco.Certificate); err != nil {
			return errOut(err)
		}
	}

	return nil
}

func (svcs Services) setCertificateRefresh(cert *acm.CertificateDetail) error {
	expiryLess := viper.GetInt(expiryLessKey)
	if expiryLess == 0 {
		expiryLess = expiryLessDefault
	}
	expiry := *cert.NotAfter
	expiry = expiry.AddDate(0, 0, -expiryLess)
	cron := fmt.Sprintf(cronExp, expiry.Day(), expiry.Month(), expiry.Year())

	identity, err := svcs.sts.GetCallerIdentity(&sts.GetCallerIdentityInput{})
	if err != nil {
		return nil
	}

	ruleName := fmt.Sprintf(ruleNameFmt, *identity.Account, strings.Replace(*cert.DomainName, "*", "_", -1))
	cweInput := &cloudwatchevents.PutRuleInput{
		Name:               aws.String(ruleName),
		Description:        aws.String(fmt.Sprintf("Watch ensures that certificate=(%s) auto renews prior to them expiring", cert.DomainName)),
		ScheduleExpression: aws.String(cron),
		State:              aws.String(cloudwatchevents.RuleStateEnabled),
	}
	_, err = svcs.cwe.PutRule(cweInput)
	if err != nil {
		return err
	}

	cweTrgInput := &cloudwatchevents.PutTargetsInput{
		Rule: aws.String(ruleName),
		Targets: []*cloudwatchevents.Target{
			{
				Id:      aws.String(platformName),
				Arn:     aws.String(fmt.Sprintf(stepFuncArnPattern, defaultRegion, *identity.Account, platformName)),
				RoleArn: aws.String(viper.GetString(targetRoleArnKey)),
				Input: aws.String(`{
  "spot": {
    "requestId": "sfr-f0ac66b3-6c02-4c5f-bb10-cc2a92628e23",
    "wait": true
  },
  "certron": {
    "domain": "*.salzr.com",
    "email": "david@salzr.com",
    "acceptTerms": "true",
    "s3": "true",
    "s3Bucket": "certron-728160576949"
  }
}`),
			},
		},
	}

	_, err = svcs.cwe.PutTargets(cweTrgInput)
	if err != nil {
		return err
	}

	return nil
}

func (evt S3Event) logInfo(m string) {
	log.Printf(logInfoPattern, evt.Records[0].ResponseElements.RequestID, m)
}

func errOut(err error) error {
	if aerr, ok := err.(awserr.Error); ok {
		return aerr
	}
	return err
}
