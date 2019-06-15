terraform {
  backend s3 {
    bucket = "brutalismbot"
    key    = "terraform/mail.tfstate"
    region = "us-east-1"
  }

  required_version = ">= 0.12.0"

  required_providers {
    aws = ">= 2.7.0"
  }
}

provider aws {
  region  = "us-east-1"
  version = "~> 2.7"
}

locals {
  tags = {
    App     = "mail"
    Name    = var.domain_name
    Repo    = var.repo
    Release = var.release
  }
}

data aws_caller_identity current {
}

data aws_iam_policy_document s3 {
  statement {
    sid       = "AllowSES"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::mail.${var.domain_name}/*"]

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

data aws_iam_policy_document mail {
  statement {
    sid     = "AllowS3"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::mail.${var.domain_name}",
      "arn:aws:s3:::mail.${var.domain_name}/*",
    ]
  }

  statement {
    sid       = "AllowSES"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

data aws_iam_policy_document smtp {
  statement {
    sid       = "AllowSES"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

data aws_iam_role role {
  name = "brutalismbot"
}

data aws_route53_zone website {
  name = "${var.domain_name}."
}

resource aws_cloudwatch_log_group mail {
  name              = "/aws/lambda/${aws_lambda_function.mail.function_name}"
  retention_in_days = 30
  tags              = local.tags
}

resource aws_iam_user smtp {
  name = "smtp"
  tags = local.tags
}

resource aws_iam_user_policy smtp {
  name   = "AmazonSesSendingAccess"
  user   = aws_iam_user.smtp.name
  policy = data.aws_iam_policy_document.smtp.json
}

resource aws_iam_role_policy mail {
  name   = "mail"
  role   = data.aws_iam_role.role.id
  policy = data.aws_iam_policy_document.mail.json
}

resource aws_lambda_function mail {
  description      = "Forward incoming messages to @brutalismbot.com"
  filename         = "lambda.zip"
  function_name    = "brutalismbot-mail"
  handler          = "lambda.handler"
  role             = data.aws_iam_role.role.arn
  runtime          = "ruby2.5"
  source_code_hash = filebase64sha256("lambda.zip")
  tags             = local.tags

  environment {
    variables = {
      DESTINATIONS = "smallweirdnum@gmail.com"
    }
  }
}

resource aws_lambda_permission mail {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mail.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mail.arn
}

resource aws_route53_record mx {
  zone_id = data.aws_route53_zone.website.id
  name    = "mail.${var.domain_name}"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

resource aws_route53_record spf {
  zone_id = data.aws_route53_zone.website.id
  name    = "mail.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource aws_route53_record txt {
  zone_id = data.aws_route53_zone.website.id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 1800
  records = [aws_ses_domain_identity.brutalismbot.verification_token]
}

resource aws_route53_record cname {
  count   = 3
  zone_id = data.aws_route53_zone.website.id
  name    = "${element(aws_ses_domain_dkim.dkim.dkim_tokens, count.index)}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${element(aws_ses_domain_dkim.dkim.dkim_tokens, count.index)}.dkim.amazonses.com"]
}

resource aws_s3_bucket mail {
  acl    = "private"
  bucket = "mail.${var.domain_name}"
  policy = data.aws_iam_policy_document.s3.json
  tags   = local.tags
}

resource aws_s3_bucket_public_access_block mail {
  bucket                  = aws_s3_bucket.mail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource aws_ses_domain_dkim dkim {
  domain = aws_ses_domain_identity.brutalismbot.domain
}

resource aws_ses_domain_identity brutalismbot {
  domain = var.domain_name
}

resource aws_ses_domain_mail_from mail_from {
  behavior_on_mx_failure = "RejectMessage"
  domain                 = aws_ses_domain_identity.brutalismbot.domain
  mail_from_domain       = "mail.${aws_ses_domain_identity.brutalismbot.domain}"
}

resource aws_ses_receipt_rule help {
  name          = "help"
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
  recipients    = ["help@${var.domain_name}"]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name       = aws_s3_bucket.mail.bucket
    object_key_prefix = "help@${var.domain_name}/"
    position          = 1
    topic_arn         = aws_sns_topic.mail.arn
  }
}

resource aws_ses_receipt_rule_set default {
  rule_set_name = "default-rule-set"
}

resource aws_sns_topic mail {
  name = "brutalismbot_mail"
}

resource aws_sns_topic_subscription mail {
  endpoint  = aws_lambda_function.mail.arn
  protocol  = "lambda"
  topic_arn = aws_sns_topic.mail.arn
}

variable domain_name {
  description = "Website domain name."
  default     = "brutalismbot.com"
}

variable release {
  description = "Release tag."
}

variable repo {
  description = "Project repository."
  default     = "https://github.com/brutalismbot/mail"
}
