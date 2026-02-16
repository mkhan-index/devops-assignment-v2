output "role_arn" {
  description = "ARN of the IAM role for IRSA"
  value       = aws_iam_role.app_role.arn
}

output "role_name" {
  description = "Name of the IAM role for IRSA"
  value       = aws_iam_role.app_role.name
}

output "policy_arn" {
  description = "ARN of the IAM policy attached to the role"
  value       = aws_iam_policy.app_policy.arn
}
