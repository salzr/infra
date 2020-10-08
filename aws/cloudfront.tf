resource "aws_cloudfront_distribution" "static_sites" {
  comment = "Cloudfront Distribution for static sites"
  enabled = "true"
  price_class = "PriceClass_100"
  aliases = [
    "www.iomediums.com"]
  default_root_object = "index.html"

  origin {
    domain_name = data.aws_s3_bucket.www_iomediums_com.bucket_regional_domain_name
    origin_id = "iomBucketOrigin"
  }

  default_cache_behavior {
    allowed_methods = [
      "GET",
      "HEAD"]
    cached_methods = [
      "GET",
      "HEAD"]
    compress = true
    target_origin_id = "iomBucketOrigin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      headers = [
        "Origin"]
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = data.aws_acm_certificate.iomediums.arn
    ssl_support_method = "sni-only"
  }
}