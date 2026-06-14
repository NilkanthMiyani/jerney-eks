output "secret_arns" {
  description = "Map of secret name => ARN"
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}
