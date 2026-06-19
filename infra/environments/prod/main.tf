# ===== データソース: 既存の情報を「読む」だけ（作らない） =====
data "aws_caller_identity" "current" {}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# ===== S3: サイト原本を置く非公開バケット =====
resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-site-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===== OAC: CloudFront だけが S3 を読める通用口 =====
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project}-oac"
  description                       = "" # コンソールで空のまま作成したため実物に合わせる
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ===== CloudFront: HTTPS で配信する CDN =====
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  # 新ウィザードの料金プラン付き配信は WebACL 必須（外せない）。
  # WAF はプランに含まれ追加料金なしのため、コードに宣言して残す。
  web_acl_id = "arn:aws:wafv2:us-east-1:855071901694:global/webacl/CreatedByCloudFront-678c2291/c9c54a09-fd91-47d0-a670-6623f938e118"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ===== バケットポリシー: この CloudFront からの読み取りだけ許可 =====
data "aws_iam_policy_document" "s3_oac" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.s3_oac.json
}
