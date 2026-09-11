test:
    #!/usr/bin/env bash
    set -euo pipefail
    find tf_files/ -name "*.tftest.hcl" \
        | sed 's|/tests/[^/]*||' | sort -u \
        | xargs -I{} sh -c 'echo "=== {} ===" && terraform -chdir={} init -input=false -no-color 2>/dev/null && terraform -chdir={} test'
