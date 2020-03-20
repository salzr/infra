resource "aws_lambda_function" "spotfleet_request_control" {
  function_name    = "spotfleet-request-control"
  description      = "Manages spotfleet request lifecycle"
  filename         = pathexpand("../build/_output/artifacts/spotfleetrequestcontrol.zip")
  source_code_hash = filebase64sha256(pathexpand("../build/_output/artifacts/spotfleetrequestcontrol.zip"))
  handler          = "main"
  role             = aws_iam_role.lambda_spotfleet_request_control_role.arn
  runtime          = "go1.x"
  timeout          = 300

  depends_on = [aws_iam_role_policy_attachment.lambda_spotfleet_request_control_logs, aws_cloudwatch_log_group.spotfleet_request_control]
}