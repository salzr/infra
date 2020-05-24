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
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

const (
	LogInfoPattern = "I [S3Event=%s] %s\n"
	TmpDir         = "/tmp"
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
}

func HandleRequest(evt S3Event) error {
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
	}

	filename := filepath.Base(key)
	filep := filepath.Join(TmpDir, filename)

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

	certFiles, err := unzip(filep, TmpDir)
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

func (evt S3Event) logInfo(m string) {
	log.Printf(LogInfoPattern, evt.Records[0].ResponseElements.RequestID, m)
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

	_, err := svcs.acm.ImportCertificate(&acm.ImportCertificateInput{
		Certificate:      certs["cert.pem"],
		CertificateChain: certs["chain.pem"],
		PrivateKey:       certs["privKey.pem"],
		CertificateArn:   certARN,
	})
	if err != nil {
		return errOut(err)
	}

	return nil
}

func errOut(err error) error {
	if aerr, ok := err.(awserr.Error); ok {
		return aerr
	}
	return err
}
