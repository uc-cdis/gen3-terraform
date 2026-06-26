# .env files now load automagically, use with care
set dotenv-load := true

default:
    @just --list

# Runs tflint recursively across all decoupled infrastructure modules
check:
    ln -s ./root.tf terragrunt.hcl || true
    terragrunt run -- validate-all
    @echo "==> Deep Linting Child Modules..."
    tflint --recursive --init
    tflint --recursive

init:
    terragrunt init -backend=false

# Format all decoupled terragrunt templates
fmt:
    terragrunt run -- hclfmt
    terraform fmt -recursive

# Run dynamic commands across your entire stack graph concurrently
tg-all *args:
    terragrunt run-all {{ args }}

# Standard targeted pipelines
plan-all:
    just tg-all plan

apply-all:
    just tg-all apply --terragrunt-non-interactive

