package main

import (
	"github.com/aws/aws-lambda-go/lambda"

	"github.com/salzr/infra/aws/lambda/pkg/events/codepipeline"
)

func main() {
	lambda.Start(codepipeline.CFInvalidatorEventHandler)
}
