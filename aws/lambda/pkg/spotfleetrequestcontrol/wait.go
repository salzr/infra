package spotfleetrequestcontrol

import (
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
)

func (svcs Services) WaitTillRequestFulfilled(evt SpotFleetRequestEvent) error {
	descSpotInsIn := &ec2.DescribeSpotFleetInstancesInput{
		SpotFleetRequestId: aws.String(evt.RequestID),
	}

	insIds := make([]*string, 0) // Instance Ids
	for {
		descSpotInsOut, err := svcs.ec2.DescribeSpotFleetInstances(descSpotInsIn)
		if err != nil {
			return err
		}

		for _, i := range descSpotInsOut.ActiveInstances {
			insIds = append(insIds, i.InstanceId)
		}

		if len(insIds) >= int(evt.TargetCapacity) {
			break
		}

		time.Sleep(5 * time.Second)
	}

	descInsIn := &ec2.DescribeInstanceStatusInput{
		InstanceIds: insIds,
	}

	return svcs.ec2.WaitUntilInstanceStatusOk(descInsIn)
}
