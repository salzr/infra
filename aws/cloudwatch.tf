resource "aws_cloudwatch_log_group" "spotfleet_request_control" {
  name              = "/aws/lambda/spotfleet-request-control"
  retention_in_days = 30
}