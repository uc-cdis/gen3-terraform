# Prefer tofu when available; fall back to terraform.
# Override with TF=terraform or TF=tofu if needed.
TF := env("TF", `command -v tofu 2>/dev/null || command -v terraform 2>/dev/null`)

test:
    #!/usr/bin/env bash
    set -euo pipefail
    tf={{TF}}
    find tf_files/aws/modules -name "*.tftest.hcl" -not -path "*/.terragrunt-cache/*" \
        | sed 's|/tests/[^/]*||' | sort -u \
        | while IFS= read -r dir; do
            echo "=== $dir ==="
            "$tf" -chdir="$dir" init -input=false -no-color -backend=false 2>/dev/null
            "$tf" -chdir="$dir" test -no-color
          done
