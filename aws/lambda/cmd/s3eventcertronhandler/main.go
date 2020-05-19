package main

import (
	"github.com/aws/aws-lambda-go/lambda"
	s3evt "github.com/salzr/infra/aws/lambda/pkg/s3eventcertronhandler"
)

func main() {
	lambda.Start(s3evt.HandleRequest)
}
