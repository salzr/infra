package main

import (
	"github.com/aws/aws-lambda-go/lambda"

	sfrctrl "github.com/salzr/infra/aws/lambda/pkg/spotfleetrequestcontrol"
)

func main() {
	lambda.Start(sfrctrl.HandleRequest)
}