package s3eventcertronhandler

import (
	"fmt"
	"log"
)

const LogInfoPattern = "I [S3Event=%s] %s\n"

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

func HandleRequest(evt S3Event) error {
	evt.logInfo(fmt.Sprintf("event=%s received", evt.Records[0].EventName))
	evt.logInfo("bucket=" + evt.Records[0].S3.Bucket.Name)
	evt.logInfo("key=" + evt.Records[0].S3.Object.Key)

	return nil
}

func (evt S3Event) logInfo(m string) {
	log.Printf(LogInfoPattern, evt.Records[0].ResponseElements.RequestID, m)
}
