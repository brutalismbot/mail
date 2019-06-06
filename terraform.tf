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

data aws_iam_policy_document mail {
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

data aws_route53_zone website {
  name = "${var.domain_name}."
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
  policy = data.aws_iam_policy_document.mail.json
  tags   = local.tags
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
