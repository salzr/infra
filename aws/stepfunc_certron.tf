resource "aws_sfn_state_machine" "certron" {
  name     = "certron"
  role_arn = aws_iam_role.stepfunc_execution_role.arn

  definition = <<EOF
{
  "Comment": "This workflow manages SpotInstanceRequests target capacity, instance readiness, task state.",
  "StartAt": "ModifySpotFleetRequest",
  "States": {
    "ModifySpotFleetRequest": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.spotfleet_request_control.arn}",
      "Parameters": {
        "requestId.$": "$.requestId",
        "targetCapacity": 1,
        "wait.$": "$.wait"
      },
      "TimeoutSeconds": 300,
      "Retry" : [
          {
            "ErrorEquals": [ "States.Timeout" ],
            "IntervalSeconds": 3,
            "MaxAttempts": 4
          }
      ],
      "End": true
    }
  }
}
EOF
}

