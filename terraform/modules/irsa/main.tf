# IAM role for application pods (IRSA)
data "aws_iam_policy_document" "app_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "app_role" {
  name               = "${var.cluster_name}-app-role"
  assume_role_policy = data.aws_iam_policy_document.app_assume_role_policy.json

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-app-role"
    }
  )
}

# Application policy for AWS service access
resource "aws_iam_policy" "app_policy" {
  name        = "${var.cluster_name}-app-policy"
  description = "Policy for application pods to access AWS services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:*:*:table/*"
        ]
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-app-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "app_policy_attachment" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}
