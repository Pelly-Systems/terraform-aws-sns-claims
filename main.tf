resource "aws_sns_topic" "default" {
  name_prefix = "claims-sns"
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.default.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

locals {
  claims_mapper = {
    "default" = ["alarms", "elasticache", "ebs", "asg"]
    "rds" = ["rds"]
    "cwe" = ["events"]
    "ses" = ["ses"]
    "budgets" = ["budgets"]
    "s3" = ["s3"]
  }

  claims = distinct([for i, c in local.claims_mapper: i if length(setintersection(c, var.claims)) > 0])

  all_claims = ["default", "rds", "events", "ses", "budgets", "s3"]
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
      resources = [aws_sns_topic.default.arn]
      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        },
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "AWS:SourceOwner"
          values = [
            data.aws_caller_identity.default.account_id,
          ]
        },
      ]
    },
    {
      sid       = "rds"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.default.arn]
      principals = [
        {
          type        = "Service"
          identifiers = ["rds.amazonaws.com"]
        },
      ]
    },
    {
      sid       = "cwe"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.default.arn]
      principals = [
        {
          type        = "Service"
          identifiers = ["events.amazonaws.com"]
        },
      ]
    },
    {
      sid       = "ses"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.default.arn]
      principals = [
        {
          type        = "Service"
          identifiers = ["ses.amazonaws.com"]
        },
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "AWS:SourceOwner"
          values = [
            data.aws_caller_identity.default.account_id,
          ]
        },
      ]
    },
    {
      sid       = "budgets"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.default.arn]
      principals = [
        {
          type        = "Service"
          identifiers = ["budgets.amazonaws.com"]
        },
      ]
    },
    {
      sid       = "s3"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.default.arn]
      principals = [
        {
          type        = "Service"
          identifiers = ["s3.amazonaws.com"]
        },
      ]
    },
  ]

  statements = [for s in local.all_statements: s if contains(local.claims, s.sid) || s.sid == "__default_statement_ID"]
}

data "aws_caller_identity" "default" {
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"
  dynamic "statement" {
    for_each = local.statements
    content {
      # TF-UPGRADE-TODO: The automatic upgrade tool can't predict
      # which keys might be set in maps assigned here, so it has
      # produced a comprehensive set here. Consider simplifying
      # this after confirming which keys can be set in practice.

      actions       = lookup(statement.value, "actions", null)
      effect        = lookup(statement.value, "effect", null)
      not_actions   = lookup(statement.value, "not_actions", null)
      not_resources = lookup(statement.value, "not_resources", null)
      resources     = lookup(statement.value, "resources", null)
      sid           = lookup(statement.value, "sid", null)

      dynamic "condition" {
        for_each = lookup(statement.value, "condition", [])
        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }

      dynamic "not_principals" {
        for_each = lookup(statement.value, "not_principals", [])
        content {
          identifiers = not_principals.value.identifiers
          type        = not_principals.value.type
        }
      }

      dynamic "principals" {
        for_each = lookup(statement.value, "principals", [])
        content {
          identifiers = principals.value.identifiers
          type        = principals.value.type
        }
      }
    }
  }
}

