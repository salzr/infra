package spotfleetrequestcontrol

import (
	"fmt"
	"log"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/awserr"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
)

const (
	LogInfoPattern = "I [SpotFleetRequestEvent=%s] %s\n"
)

type SpotFleetRequestEvent struct {
	RequestID      string `json:"requestID"`
	TargetCapacity int64  `json:"targetCapacity"`
	Wait           bool   `json:"wait"`
}

type Services struct {
	ec2 *ec2.EC2
}

func HandleRequest(evt SpotFleetRequestEvent) error {
	evt.logInfo("event received")
	evt.logInfo(fmt.Sprintf("targetCapacity=%d", evt.TargetCapacity))
	evt.logInfo(fmt.Sprintf("wait=%t", evt.Wait))

	svcs := Services{
		ec2: ec2.New(session.Must(session.NewSession())),
	}

	spotReqOut, err := svcs.DescribeSpotFleetRequest(evt.RequestID)
	if err != nil {
		return errOut(err)
	}

	for _, sfrc := range spotReqOut.SpotFleetRequestConfigs {
		if evt.requestFulfilled(sfrc) {
			evt.logInfo("SpotFleet already meets targetCapacity request")
			return nil
		}

		if err := svcs.ModifySpotFleetRequest(evt.RequestID, evt.TargetCapacity); err != nil {
			return errOut(err)
		}

		if evt.Wait {
			return svcs.WaitTillRequestFulfilled(evt)
		}
	}

	return nil
}

// DescribeSpotFleetRequest retrieves the current SpotFleetRequest configuration
func (svcs Services) DescribeSpotFleetRequest(uid string) (*ec2.DescribeSpotFleetRequestsOutput, error) {
	input := &ec2.DescribeSpotFleetRequestsInput{
		SpotFleetRequestIds: []*string{
			aws.String(uid),
		},
	}

	return svcs.ec2.DescribeSpotFleetRequests(input)
}

// ModifySpotFleetRequest modifies the spotfleet request configuration or returns an error
func (svcs Services) ModifySpotFleetRequest(uid string, capacity int64) error {
	input := &ec2.ModifySpotFleetRequestInput{
		ExcessCapacityTerminationPolicy: aws.String(ec2.ExcessCapacityTerminationPolicyDefault),
		SpotFleetRequestId:              aws.String(uid),
		TargetCapacity:                  aws.Int64(capacity),
	}
	modSpotReqIn, err := svcs.ec2.ModifySpotFleetRequest(input)
	if err != nil {
		return err
	}
	if !*modSpotReqIn.Return {
		return fmt.Errorf("there was an error processing the request sfid=%s targetCapacity=%d",
			uid, capacity)
	}

	return nil
}

func (evt SpotFleetRequestEvent) logInfo(m string) {
	log.Printf(LogInfoPattern, evt.RequestID, m)
}

func (evt SpotFleetRequestEvent) requestFulfilled(sfrc *ec2.SpotFleetRequestConfig) bool {
	return ec2.BatchStateActive == *sfrc.SpotFleetRequestState &&
		ec2.ActivityStatusFulfilled == *sfrc.ActivityStatus &&
		evt.TargetCapacity <= *sfrc.SpotFleetRequestConfig.TargetCapacity
}

func errOut(err error) error {
	if aerr, ok := err.(awserr.Error); ok {
		return aerr
	}
	return err
}
