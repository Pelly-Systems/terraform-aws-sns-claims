resource "aws_sns_topic" "default" {
  name_prefix = "claims-sns"
}

resource "aws_sns_topic_policy" "default" {
  arn    = "${aws_sns_topic.default.arn}"
  policy = "${data.aws_iam_policy_document.sns_topic_policy.json}"
}

locals {
  claims_mapper = {
    "alarms" = "default"
    "elasticache" = "default"
    "ebs" = "default"
    "asg" = "default"
    "rds" = "rds"
    "events" = "events"
    "ses" = "ses"
  }

  claims = "${distinct(matchkeys(values(local.claims_mapper), keys(local.claims_mapper), var.claims))}"

  all_claims = ["default", "rds", "events", "ses"]
  all_statements = [
    {
      sid = "__default_statement_ID"

      actions = [
	"sns:Subscribe",
	"sns:SetTopicAttributes",
	"sns:RemovePermission",
	"sns:Receive",
	"sns:Publish",
	"sns:ListSubscriptionsByTopic",
	"sns:GetTopicAttributes",
	"sns:DeleteTopic",
	"sns:AddPermission",
      ]

      effect    = "Allow"
      resources = ["${aws_sns_topic.default.arn}"]

      principals = [{
	type        = "AWS"
	identifiers = ["*"]
      }]

      condition = [{
	test     = "StringEquals"
	variable = "AWS:SourceOwner"

	values = [
	  "${data.aws_caller_identity.default.account_id}",
	]
      }]
    },
    {
      sid       = "rds"
      actions   = ["sns:Publish"]
      resources = ["${aws_sns_topic.default.arn}"]

      principals = [{
	type        = "Service"
	identifiers = ["rds.amazonaws.com"]
      }]
    },
    {
      sid       = "cwe"
      actions   = ["sns:Publish"]
      resources = ["${aws_sns_topic.default.arn}"]

      principals = [{
	type        = "Service"
	identifiers = ["events.amazonaws.com"]
      }]
    },
    {
      sid       = "ses"
      actions   = ["sns:Publish"]
      resources = ["${aws_sns_topic.default.arn}"]

      principals = [{
	type        = "Service"
	identifiers = ["ses.amazonaws.com"]
      }]

      condition = [{
	test     = "StringEquals"
	variable = "AWS:SourceOwner"

	values = [
	  "${data.aws_caller_identity.default.account_id}",
	]
      }]
    }
  ]

  statements = "${matchkeys(local.all_statements, local.all_claims, local.claims)}" 
}

data "aws_caller_identity" "default" {}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"
  statement = ["${local.statements}"]
}
