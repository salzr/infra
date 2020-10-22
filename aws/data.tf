data "aws_s3_bucket" "www_iomediums_com" {
  bucket = "www.iomediums.com"
}

data "aws_acm_certificate" "iomediums" {
  domain = "*.iomediums.com"
  statuses = ["ISSUED"]
}

data "aws_iam_role" "codepipeline_lambda_exec_role" {
  name = "CodePipleineLambdaExecRole"
}