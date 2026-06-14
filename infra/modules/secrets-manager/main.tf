# ==============================================================
# Module: secrets-manager
#
# AWS Secrets Manager secrets, created from a single map so the set
# of secrets is data, not duplicated resource blocks. ESO reads
# these at runtime via the ClusterSecretStore.
# ==============================================================

# for_each cannot take a sensitive value, so iterate over the secret
# names (not secret) and look up each sensitive value by key.
resource "aws_secretsmanager_secret" "this" {
  for_each = nonsensitive(toset(keys(var.secrets)))

  name                    = each.value
  recovery_window_in_days = var.recovery_window_in_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = aws_secretsmanager_secret.this

  secret_id     = each.value.id
  secret_string = var.secrets[each.key]
}
