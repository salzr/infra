# ECS Task Definition Certron
resource "aws_iam_role" "ecs_certron" {
  name = "ecs-certron"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecs_certron_task_role_policy" {
  name = "ecs-certron-task-role-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListHostedZonesByName",
        "route53:GetChange"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListResourceRecordSets",
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/Z091229319MH07R6MRZ6P"
    },
    {
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": "s3:*" ,
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.certron.id}",
        "arn:aws:s3:::${aws_s3_bucket.certron.id}/*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_certron_task_role_policy_attach" {
  role = aws_iam_role.ecs_certron.name
  policy_arn = aws_iam_policy.ecs_certron_task_role_policy.arn
}

# Lambda S3EventCertronHandler
resource "aws_iam_role" "lambda_s3_event_certron_handler_role" {
  name = "lambda-s3-event-certron-handler-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_certron_s3_access" {
  name = "lambda-certron-s3-access"
  path = "/"
  description = "IAM policy for giving lambda access to s3 resource"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": "s3:*" ,
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.certron.id}",
        "arn:aws:s3:::${aws_s3_bucket.certron.id}/*"
      ],
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_certron_acm_access" {
  name = "lambda-certron-acm-access"
  path = "/"
  description = "IAM policy for giving lambda access to acm resource"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "acm:ImportCertificate",
        "acm:ListCertificates",
        "acm:DescribeCertificate"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_certron_cloudwatch_events_policy" {
  name = "lambda-certron-cloudwatch-events-policy"
  path = "/"
  description = "IAM policy for giving the lambda ability to curate cloudwatch events"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "events:PutRule",
        "events:PutTargets"
      ],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "*"
      ],
      "Condition": {
        "StringLike": {
          "iam:PassedToService": "states.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "lambda_s3_event_certron_cloudwatch_events" {
  role = aws_iam_role.lambda_s3_event_certron_handler_role.name
  policy_arn = aws_iam_policy.lambda_certron_cloudwatch_events_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_event_certron_handler_logs" {
  role = aws_iam_role.lambda_s3_event_certron_handler_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_event_certron_handler_s3" {
  role = aws_iam_role.lambda_s3_event_certron_handler_role.name
  policy_arn = aws_iam_policy.lambda_certron_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "lambda_s3_event_certron_handler_acm" {
  role = aws_iam_role.lambda_s3_event_certron_handler_role.name
  policy_arn = aws_iam_policy.lambda_certron_acm_access.arn
}

# Step Certron
resource "aws_iam_role_policy_attachment" "stepfunc_certron_lambda_policy" {
  role = aws_iam_role.stepfunc_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
}

resource "aws_iam_role_policy_attachment" "stepfunc_certron_ecs_policy" {
  role = aws_iam_role.stepfunc_execution_role.name
  policy_arn = aws_iam_policy.stepfunc_execution_role_ecs_task_exec_policy.arn
}

# Lambda SpotFleetRequest
resource "aws_iam_role" "lambda_spotfleet_request_control_role" {
  name = "lambda-spotfleet-request-control-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_spotfleet_request_control_logs" {
  role = aws_iam_role.lambda_spotfleet_request_control_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_role_policy_attachment" "lambda_spotfleet_request_execution_policy" {
  role = aws_iam_role.lambda_spotfleet_request_control_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetAutoscaleRole"
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_readonly_policy" {
  role = aws_iam_role.lambda_spotfleet_request_control_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# SpotFleet Nodes Automata
resource "aws_iam_instance_profile" "spotfleet_automata_node" {
  name = "automata-spotfleet-profile"
  role = aws_iam_role.ec2_execution_role.name
}

resource "aws_iam_role_policy_attachment" "automata_attach_ecs_ec2" {
  role = aws_iam_role.ec2_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# General policies
resource "aws_iam_policy" "lambda_logging" {
  name = "lambda-logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# General execution roles
resource "aws_iam_role" "ecs_task_execution_certron_role" {
  name = "ecs-task-execution-certron-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  name = "ecs-task-execution-role-policy"
  path = "/"
  description = "IAM policy task interaction with AWS services"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_execution_attach_policy" {
  role = aws_iam_role.ecs_task_execution_certron_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
}

resource "aws_iam_role" "ec2_execution_role" {
  name = "ec2-execution-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role" "stepfunc_execution_role" {
  name = "stepfunc-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "stepfunc_execution_role_ecs_task_exec_policy" {
  name = "stepfunc-execution-role-ecs-task-exec-policy"
  path = "/"
  description = "IAM policy to be able to operate against and ECS task definition"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:RunTask"
      ],
      "Resource": "${aws_ecs_task_definition.certron.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:StopTasks",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "events:PutTargets",
        "events:PutRule",
        "events:DescribeRule"
      ],
      "Resource": "arn:aws:events:${var.aws_region}:${var.aws_account_number}:rule/StepFunctionsGetEventsForECSTaskRule"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "${aws_iam_role.ecs_task_execution_certron_role.arn}"
    }
  ]
}
EOF
}

# Github User
resource "aws_iam_user" "github_salzr" {
  name = "github-salzr"
  path = "/scm/"
}

resource "aws_iam_access_key" "github_salzr" {
  user = aws_iam_user.github_salzr.name
  pgp_key = "keybase:dnsalazar"
}

resource "aws_iam_user_policy" "github_salzr" {
  name = "github-salzr"
  user = aws_iam_user.github_salzr.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "ecr:GetAuthorizationToken"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

output "github_salzr_secret" {
  value = aws_iam_access_key.github_salzr.encrypted_secret
}
