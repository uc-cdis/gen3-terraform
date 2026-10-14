# .env files now load automagically, use with care
set dotenv-load := true

default:
    @just --list

# Run dynamic commands across your entire stack graph concurrently
tg-all *args:
    terragrunt run -- {{ args }} -recursive

# Runs tflint recursively across all decoupled infrastructure modules
check:
    @just fmt
    @just tg-all test

lint:
    tflint --recursive --init
    tflint --recursive

init:
    terragrunt init -backend=false

# Format all decoupled terragrunt templates
fmt:
    terragrunt hcl fmt
    terraform fmt -recursive

# Standard targeted pipelines
plan-all:
    @just tg-all plan

apply-all:
    @just tg-all apply --terragrunt-non-interactive
