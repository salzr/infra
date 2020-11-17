package codepipeline

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/cloudfront"
	"github.com/aws/aws-sdk-go/service/codepipeline"
)

type InvalidationParameters struct {
	DistributionId    string    `json:"distributionId"`
	InvalidationPaths []*string `json:"invalidationPaths"`
}

type CFInvalidatorService struct {
	jobID  string
	cf     *cloudfront.CloudFront
	cp     *codepipeline.CodePipeline
	logger evtlogger
}

func (s CFInvalidatorService) getJobId() string {
	return s.jobID
}

func (s CFInvalidatorService) getCodePipelineClient() *codepipeline.CodePipeline {
	return s.cp
}

func NewCFInvalidatorService(evt events.CodePipelineEvent) (*CFInvalidatorService, error) {
	sess := session.Must(session.NewSession())
	return &CFInvalidatorService{
		jobID: evt.CodePipelineJob.ID,
		cf:    cloudfront.New(sess),
		cp:    codepipeline.New(sess),
		logger: evtlogger{
			pattern: fmt.Sprintf(logInfoPattern, "%s", evt.CodePipelineJob, "%v"),
		},
	}, nil
}

func CFInvalidatorEventHandler(evt events.CodePipelineEvent) error {
	svc, err := NewCFInvalidatorService(evt)
	if err != nil {
		return err
	}

	logger := svc.logger
	logger.Info(fmt.Sprintf(fmt.Sprintf("event=(%s) received", codePipelineEvent)))

	params := evt.CodePipelineJob.Data.ActionConfiguration.Configuration.UserParameters
	invParams := &InvalidationParameters{}
	if err := json.Unmarshal([]byte(params), invParams); err != nil {
		jobFailed(svc)
		return logger.Error(errOut(err))
	}

	t := time.Now()
	ts := t.Format(time.RFC3339)
	_, err = svc.cf.CreateInvalidation(&cloudfront.CreateInvalidationInput{
		DistributionId: aws.String(invParams.DistributionId),
		InvalidationBatch: &cloudfront.InvalidationBatch{
			CallerReference: aws.String(ts),
			Paths: &cloudfront.Paths{
				Items:    invParams.InvalidationPaths,
				Quantity: aws.Int64(int64(len(invParams.InvalidationPaths))),
			},
		},
	})
	if err != nil {
		jobFailed(svc)
		return logger.Error(errOut(err))
	}

	return jobSuccess(svc)
}
