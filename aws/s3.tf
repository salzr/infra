resource "aws_s3_bucket" "certron" {
  bucket = "certron-${var.aws_account_number}"
  acl = "private"

  lifecycle_rule {
    id = "certificates"
    enabled = true
    expiration {
      days = 95
    }
  }
}

resource "aws_s3_bucket_notification" "certron" {
  bucket = aws_s3_bucket.certron.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_event_certron_handler.arn
    events = [
      "s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_certron_bucket]
}
