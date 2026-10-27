#!/usr/bin/env bash
# Runs fmt -> init -> validate -> plan -refresh=false for one environment
# without AWS credentials or the S3 state bucket, by temporarily dropping in
# infra/plan-only/plan_only_override.tf (local backend, offline provider).
#
# Usage: ./scripts/tf-plan.sh dev|prod
#
# With real AWS access, skip this script and run plain `terraform init/plan`.
set -euo pipefail

env=${1:?usage: $0 dev|prod}
root=$(cd "$(dirname "$0")/.." && pwd)
dir="$root/infra/envs/$env"
[[ -d "$dir" ]] || { echo "unknown environment: $env" >&2; exit 1; }

override="$dir/plan_only_override.tf"
cp "$root/infra/plan-only/plan_only_override.tf" "$override"
trap 'rm -f "$override"' EXIT

terraform fmt -check -recursive "$root/infra"
terraform -chdir="$dir" init -input=false -reconfigure
terraform -chdir="$dir" validate
terraform -chdir="$dir" plan -refresh=false -input=false -lock=false
