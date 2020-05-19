resource "aws_cloudwatch_log_group" "spotfleet_request_control" {
  name = "/aws/lambda/spotfleet-request-control"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "s3_event_certron_handler" {
  name = "/aws/lambda/s3-event-certron-handler"
  retention_in_days = 30
}
