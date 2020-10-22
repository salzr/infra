resource "aws_lambda_function" "codepipeline_s3uploader" {
  function_name = "codepipeline-s3uploader"
  description = "CodePipeline job for uploading static site artifact"
  filename = pathexpand("../build/_output/artifacts/codepipeline-s3uploader.zip")
  source_code_hash = filebase64sha256(pathexpand("../build/_output/artifacts/codepipeline-s3uploader.zip"))
  handler = "main"
  role = data.aws_iam_role.codepipeline_lambda_exec_role.arn
  runtime = "go1.x"
  timeout = 300
}

resource "aws_lambda_function" "spotfleet_request_control" {
  function_name = "spotfleet-request-control"
  description = "Manages spotfleet request lifecycle"
  filename = pathexpand("../build/_output/artifacts/spotfleetrequestcontrol.zip")
  source_code_hash = filebase64sha256(pathexpand("../build/_output/artifacts/spotfleetrequestcontrol.zip"))
  handler = "main"
  role = aws_iam_role.lambda_spotfleet_request_control_role.arn
  runtime = "go1.x"
  timeout = 300

  depends_on = [
    aws_iam_role_policy_attachment.lambda_spotfleet_request_control_logs,
    aws_cloudwatch_log_group.spotfleet_request_control]
}

resource "aws_lambda_function" "s3_event_certron_handler" {
  function_name = "s3-event-certron-handler"
  description = "pull certificate from s3, extract contents, and put it into certificate manager"
  filename = pathexpand("../build/_output/artifacts/s3eventcertronhandler.zip")
  source_code_hash = filebase64sha256(pathexpand("../build/_output/artifacts/s3eventcertronhandler.zip"))
  handler = "main"
  role = aws_iam_role.lambda_s3_event_certron_handler_role.arn
  runtime = "go1.x"
  timeout = 300

  environment {
    variables = {
      CERTRON_CERT_REFRESH_ENABLED = true
      CERTRON_EXPIRY_LESS = 1
      CERTRON_TARGET_ROLE_ARN = aws_iam_role.certron_invoke_step_function_role.arn
      CERTRON_SPOTFLEET_REQUEST = aws_spot_fleet_request.automata.id
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_s3_event_certron_handler_logs,
    aws_cloudwatch_log_group.s3_event_certron_handler]
}

resource "aws_lambda_permission" "allow_certron_bucket" {
  statement_id = "AllowExecutionFromS3Bucket"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_event_certron_handler.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.certron.arn
}
