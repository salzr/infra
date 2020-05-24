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
        "acm:ListCertificates"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
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
resource "aws_iam_policy_attachment" "spotfleet_certron_policy" {
  name = "spotfleet-modification-policy"
  roles = [
    aws_iam_role.stepfunc_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaRole"
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
