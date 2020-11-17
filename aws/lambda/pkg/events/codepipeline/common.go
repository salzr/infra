package codepipeline

import (
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/codepipeline"
)

type CodePipelineEventInterface interface {
	getJobId() string
	getCodePipelineClient() *codepipeline.CodePipeline
}

func jobSuccess(cpei CodePipelineEventInterface) error {
	cp := cpei.getCodePipelineClient()
	id := cpei.getJobId()
	_, err := cp.PutJobSuccessResult(&codepipeline.PutJobSuccessResultInput{
		JobId: aws.String(id),
	})
	return err
}

func jobFailed(cpei CodePipelineEventInterface) error {
	cp := cpei.getCodePipelineClient()
	id := cpei.getJobId()
	_, err := cp.PutJobFailureResult(&codepipeline.PutJobFailureResultInput{
		JobId: aws.String(id),
	})
	return err
}
