# Plan-only override for reviewers and CI without AWS access.
#
# Copied into an env directory (infra/envs/<env>/), Terraform merges it over
# the real config: the S3 backend is replaced by local state and the provider
# skips every AWS API call that `plan -refresh=false` would otherwise make.
# Never commit it inside infra/envs/ (.gitignore blocks *_override.tf there).
terraform {
  backend "local" {}
}

provider "aws" {
  access_key                  = "plan-only"
  secret_key                  = "plan-only"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
