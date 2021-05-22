terraform {
  required_version = "~> 0.14"

  backend "s3" {
    bucket = "brutalismbot"
    key    = "terraform/mail.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.38"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags { tags = local.tags }
}

locals {
  domain = "brutalismbot.com"
  repo   = "https://github.com/brutalismbot/mail"

  tags = {
    App  = "mail"
    Name = local.domain
    Repo = local.repo
  }
}

data "aws_caller_identity" "current" {
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid       = "AllowSES"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::mail.${local.domain}/*"]

    condition {
      test     = "StringLike"
      variable = "aws:Referer"

      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "mail" {
  statement {
    sid     = "AllowS3"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::mail.${local.domain}",
      "arn:aws:s3:::mail.${local.domain}/*",
    ]
  }

  statement {
    sid       = "AllowSES"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "smtp" {
  statement {
    sid       = "AllowSES"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

data "aws_iam_role" "role" {
  name = "brutalismbot"
}

data "aws_route53_zone" "website" {
  name = "${local.domain}."
}

resource "aws_cloudwatch_log_group" "mail" {
  name              = "/aws/lambda/${aws_lambda_function.mail.function_name}"
  retention_in_days = 30
}

resource "aws_iam_user" "smtp" {
  name = "smtp"
}

resource "aws_iam_user_policy" "smtp" {
  name   = "AmazonSesSendingAccess"
  user   = aws_iam_user.smtp.name
  policy = data.aws_iam_policy_document.smtp.json
}

resource "aws_iam_role_policy" "mail" {
  name   = "mail"
  role   = data.aws_iam_role.role.id
  policy = data.aws_iam_policy_document.mail.json
}

resource "aws_lambda_function" "mail" {
  description      = "Forward incoming messages to @brutalismbot.com"
  filename         = "package.zip"
  function_name    = "brutalismbot-mail"
  handler          = "index.handler"
  role             = data.aws_iam_role.role.arn
  runtime          = "ruby2.7"
  source_code_hash = filebase64sha256("package.zip")
  timeout          = 15

  environment {
    variables = {
      DESTINATIONS = var.DESTINATIONS
    }
  }
}

resource "aws_lambda_permission" "mail" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mail.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mail.arn
}

resource "aws_route53_record" "mx" {
  zone_id = data.aws_route53_zone.website.id
  name    = "mail.${local.domain}"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

resource "aws_route53_record" "spf" {
  zone_id = data.aws_route53_zone.website.id
  name    = "mail.${local.domain}"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "txt" {
  zone_id = data.aws_route53_zone.website.id
  name    = "_amazonses.${local.domain}"
  type    = "TXT"
  ttl     = 1800
  records = [aws_ses_domain_identity.brutalismbot.verification_token]
}

resource "aws_route53_record" "cname" {
  count   = 3
  zone_id = data.aws_route53_zone.website.id
  name    = "${element(aws_ses_domain_dkim.dkim.dkim_tokens, count.index)}._domainkey.${local.domain}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${element(aws_ses_domain_dkim.dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource "aws_s3_bucket" "mail" {
  acl    = "private"
  bucket = "mail.${local.domain}"
  policy = data.aws_iam_policy_document.s3.json
}

resource "aws_s3_bucket_public_access_block" "mail" {
  bucket                  = aws_s3_bucket.mail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.brutalismbot.domain
}

resource "aws_ses_domain_identity" "brutalismbot" {
  domain = local.domain
}

resource "aws_ses_domain_mail_from" "mail_from" {
  behavior_on_mx_failure = "RejectMessage"
  domain                 = aws_ses_domain_identity.brutalismbot.domain
  mail_from_domain       = "mail.${aws_ses_domain_identity.brutalismbot.domain}"
}

resource "aws_ses_receipt_rule" "help" {
  name          = "help"
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
  recipients    = ["help@${local.domain}"]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.mail.bucket
    object_key_prefix = "help@${local.domain}/"
    position          = 1
    topic_arn         = aws_sns_topic.mail.arn
  }
}

resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = "default-rule-set"
}

resource "aws_sns_topic" "mail" {
  name = "brutalismbot-mail"
}

resource "aws_sns_topic_subscription" "mail" {
  endpoint  = aws_lambda_function.mail.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.mail.arn
}

variable "DESTINATIONS" {
  description = "Destination email list"
}
