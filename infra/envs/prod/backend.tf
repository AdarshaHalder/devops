# Remote state for prod only, in its own bucket (and, in practice, its own
# AWS account) so nothing in dev can read or overwrite prod state.
#
# For review without AWS access, see "Terraform review" in the README.
terraform {
  backend "s3" {
    bucket         = "hotel-bookings-tfstate-prod"
    key            = "envs/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-bookings-tflock-prod"
    encrypt        = true
  }
}
