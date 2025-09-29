variable "project" {}
variable "config" {}

###############################################################################
# General S3 Bucket                                                    BEGIN  #
#                                                                             #
#    Creates a New s3 Bucket                                                  #
###############################################################################
resource "random_string" "suffix" {
  length  = 12
  special = false
  upper   = false
}

resource "aws_s3_bucket" "general" {
  bucket = "${var.project}-${random_string.suffix.result}"

  tags = {
    Name        = "${var.project}"
  }
}

resource "aws_s3_bucket_versioning" "general" {
  bucket = aws_s3_bucket.general.id

  versioning_configuration {
    status = var.config.versioning
  }
}

resource "aws_s3_bucket_public_access_block" "general" {
  bucket                  = aws_s3_bucket.general.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website_bucket_encryption" {
  bucket = aws_s3_bucket.general.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

###############################################################################
# General S3 bucket                                                      END  #
###############################################################################


###############################################################################
# CloudFront Bucket Access                                             BEGIN  #
#                                                                             #
#    Make bucket contents accessible via AWS CloudFront                       #
###############################################################################
resource "aws_cloudfront_origin_access_control" "general_bucket_oac" {
  count                             = var.config.cloudfront == true ? 1 : 0 
  name                              = "${var.project}-oac"
  description                       = "OAC for ${aws_s3_bucket.general.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "default" {
  name        = "${var.project}-general-bucket-cache-policy"
  default_ttl = 360
  max_ttl     = 3600
  min_ttl     = 60

  parameters_in_cache_key_and_forwarded_to_origin {

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_cache_policy" "static" {
  name        = "${var.project}-general-bucket-cache-policy"
  default_ttl = 360
  max_ttl     = 3600
  min_ttl     = 60

  parameters_in_cache_key_and_forwarded_to_origin {

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"

      headers { 
        items = ["Origin"]
      }
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "general_bucket" {
  count               = var.config.cloudfront == true ? 1 : 0 
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${aws_s3_bucket.general.bucket} s3 bucket"
  # Note: The below should cause a 404 when attempting to browse the root of the 
  # distribution/bucket. A proper index.html can be provided if desired, but this
  # should stop unwanted snooping of the bucket contents.
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.general.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.general_bucket_oac.0.id
    origin_id                = "S3-${aws_s3_bucket.general.bucket}"
  }

  default_cache_behavior {
    allowed_methods         = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods          = ["GET", "HEAD"]
    cache_policy_id         = aws_cloudfront_cache_policy.default.id
    target_origin_id        = "S3-${aws_s3_bucket.general.bucket}"
    viewer_protocol_policy  = "redirect-to-https"
    min_ttl                 = 0
    default_ttl             = 3600
    max_ttl                 = 86400
  }

  ordered_cache_behavior {
    path_pattern            = "/static/*"
    allowed_methods         = ["GET", "HEAD", "OPTIONS"]
    cached_methods          = ["GET", "HEAD", "OPTIONS"]
    cache_policy_id         = aws_cloudfront_cache_policy.static.id
    target_origin_id        = "S3-${aws_s3_bucket.general.bucket}"
    viewer_protocol_policy  = "redirect-to-https"
    min_ttl                 = 0
    default_ttl             = 86400
    max_ttl                 = 31536000
  }


  restrictions {
    geo_restriction {
      restriction_type  = "whitelist"
      locations         = ["US", "CA"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate  = true 
  }

  tags  = {
    Name  = "Project General S3 Bucket CloudFront Distribution"
  }
}

data "aws_iam_policy_document" "s3_bucket_base" {
  count       = var.config.cloudfront == true ? 1 : 0 
  statement {
    sid       = "S3GeneralBucketCloudFront"
    effect    = "allow"
    actions   = [ "s3:getObject" ]
    resources = [ "${aws_s3_bucket.general.arn}" ]

    principals {
      type        = "Service"
      identifiers = [ "cloudfront.amazonaws.com" ]
    }

    condition {
      test      = "StringEquals"
      variable  = "AWS:SourceArn"
      values    = [ "${aws_cloudfront_distribution.general_bucket.0.arn}" ]
    }
  }
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  count   = var.config.cloudfront == true ? 1 : 0 
  bucket  = aws_s3_bucket.general.id
  policy  = data.aws_iam_policy_document.s3_bucket_base.0.json
}
###############################################################################
# CloudFront Bucket Access                                               END  #
###############################################################################
