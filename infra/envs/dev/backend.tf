# Remote state for dev only. Prod uses a separate bucket (and, in practice, a
# separate AWS account) so a dev mistake can never touch prod state.
#
# For review without AWS access, see "Terraform review" in the README.
terraform {
  backend "s3" {
    bucket         = "hotel-bookings-tfstate-dev"
    key            = "envs/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-bookings-tflock-dev"
    encrypt        = true
  }
}
