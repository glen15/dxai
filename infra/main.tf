terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

# 서울 리전 (S3, Route 53)
provider "aws" {
  region  = "ap-northeast-2"
  profile = "dxai"
}

# us-east-1 (ACM for CloudFront, CloudFront)
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "dxai"
}

locals {
  domain      = "dx-ai.cloud"
  subdomain   = "vanguard.dx-ai.cloud"
  bucket_name = "vanguard-dx-ai"
}

# ============================================================
# Route 53
# ============================================================

data "aws_route53_zone" "main" {
  name = local.domain
}

resource "aws_route53_record" "vanguard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.subdomain
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.vanguard.domain_name]
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.vanguard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

# ============================================================
# ACM (us-east-1 — CloudFront 필수)
# ============================================================

resource "aws_acm_certificate" "vanguard" {
  provider          = aws.us_east_1
  domain_name       = local.subdomain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "vanguard" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.vanguard.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ============================================================
# S3
# ============================================================

resource "aws_s3_bucket" "vanguard" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "vanguard" {
  bucket                  = aws_s3_bucket.vanguard.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "vanguard" {
  bucket = aws_s3_bucket.vanguard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.vanguard.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.vanguard.arn
        }
      }
    }]
  })
}

# ============================================================
# CloudFront
# ============================================================

resource "aws_cloudfront_origin_access_control" "vanguard" {
  name                              = "vanguard-s3-oac"
  description                       = "OAC for vanguard S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "vanguard-security-headers"
  comment = "Security headers for Vanguard"

  security_headers_config {
    xss_protection {
      override   = true
      protection = true
      mode_block = true
    }

    frame_options {
      override     = true
      frame_option = "DENY"
    }

    content_type_options {
      override = true
    }

    referrer_policy {
      override        = true
      referrer_policy = "strict-origin-when-cross-origin"
    }

    content_security_policy {
      override                = true
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' https://*.supabase.co wss://*.supabase.co; frame-ancestors 'none'"
    }
  }
}

resource "aws_cloudfront_distribution" "vanguard" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Vanguard Leaderboard"
  price_class         = "PriceClass_200"
  aliases             = [local.subdomain]

  origin {
    domain_name              = aws_s3_bucket.vanguard.bucket_regional_domain_name
    origin_id                = "vanguard-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.vanguard.id
  }

  default_cache_behavior {
    target_origin_id         = "vanguard-s3"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                 = true
  }

  # SPA fallback: 403/404 → index.html
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.vanguard.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# ============================================================
# Outputs
# ============================================================

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.vanguard.domain_name
}

output "cloudfront_id" {
  value = aws_cloudfront_distribution.vanguard.id
}

output "s3_bucket" {
  value = aws_s3_bucket.vanguard.bucket
}

output "site_url" {
  value = "https://${local.subdomain}"
}
