# Binary terragrunt invokes. Prefers tofu; falls back to terraform.
# Override: TG_TF_PATH=terraform just test
export TG_TF_PATH := env("TG_TF_PATH", `command -v tofu 2>/dev/null || command -v terraform 2>/dev/null`)

# Shared provider cache — respected by tofu, terraform, and terragrunt.
export TG_PROVIDER_CACHE_DIR := env("TG_PROVIDER_CACHE_DIR", env("HOME", "/tmp") + "/.terraform.d/plugin-cache")
export TF_PLUGIN_CACHE_DIR   := TG_PROVIDER_CACHE_DIR

test:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$TG_PROVIDER_CACHE_DIR"
    for dir in tf_files/aws/modules; do
        just --justfile {{justfile()}} _test_dir "$dir"
    done

_test_dir dir:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{dir}}
    terragrunt run --all --non-interactive -- test -no-color
