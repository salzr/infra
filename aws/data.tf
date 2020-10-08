data "aws_s3_bucket" "www_iomediums_com" {
  bucket = "www.iomediums.com"
}

data "aws_acm_certificate" "iomediums" {
  domain = "*.iomediums.com"
  statuses = ["ISSUED"]
}