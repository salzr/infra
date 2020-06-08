resource "aws_sfn_state_machine" "certron" {
  name = "certron"
  role_arn = aws_iam_role.stepfunc_execution_role.arn

  definition = <<EOF
{
  "Comment": "This workflow manages SpotInstanceRequests target capacity, instance readiness, task state.",
  "StartAt": "ModifySpotFleetRequest",
  "States": {
    "ModifySpotFleetRequest": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.spotfleet_request_control.arn}",
      "InputPath": "$.spot",
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
      "ResultPath": null,
      "Next": "ExecuteTaskDefinition"
    },
    "ExecuteTaskDefinition": {
      "Type": "Task",
      "Resource": "arn:aws:states:::ecs:runTask.sync",
      "InputPath": "$.certron",
      "Parameters": {
        "Cluster": "${aws_ecs_cluster.automata.arn}",
        "TaskDefinition": "${aws_ecs_task_definition.certron.arn}",
        "Overrides": {
          "ContainerOverrides": [
            {
              "Name": "certron",
              "Environment": [
                {
                  "Name": "CERTRON_DOMAIN",
                  "Value.$": "$.domain"
                },
                {
                  "Name": "CERTRON_EMAIL",
                  "Value.$": "$.email"
                },
                {
                  "Name": "CERTRON_ACCEPT_TERMS",
                  "Value.$": "$.acceptTerms"
                },
                {
                  "Name": "CERTRON_S3",
                  "Value.$": "$.s3"
                },
                {
                  "Name": "CERTRON_S3_BUCKET",
                  "Value": "${aws_s3_bucket.certron.bucket}"
                },
                {
                  "Name": "AWS_REGION",
                  "Value": "${var.aws_region}"
                }
              ]
            }
          ]
        }
      },
      "End": true
    }
  }
}
EOF
}

