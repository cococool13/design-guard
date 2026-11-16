# CI contract. Agents, the pre-push hook and `ship` all run `just check`.
# Kit: .ci/ (vendored with ci-sync; `just ci-drift` shows drift).
# GitHub Actions still run here too (public repo): test.yml runs the same self-test.
set shell := ["bash", "-euo", "pipefail", "-c"]

check:
    .ci/bin/ci-par test gitleaks

# Changed files since origin/main plus uncommitted work. The fixture suite
# (~15 s) runs only when the guard, its fixtures, configs or workflows changed.
check-fast:
    #!/usr/bin/env bash
    set -euo pipefail
    base="$(git merge-base origin/main HEAD)"
    mapfile -t files < <({ git diff --name-only --diff-filter=d "$base"; git ls-files --others --exclude-standard; } | sort -u)
    if [ "${#files[@]}" -eq 0 ]; then echo "check-fast: no changes"; exit 0; fi
    bash -n taste-guard.sh
    if printf '%s\n' "${files[@]}" | grep -qE '^(taste-guard\.sh|tests/|configs/|scripts/|templates/|vendor/|\.github/)'; then
      bash tests/run.sh
    else
      echo "check-fast: guard and fixtures unchanged"
    fi

# No formatter is configured.
fix:
    @echo "fix: no autofixers in this repo"

# From test.yml (taste-guard self-test). Needs ripgrep.
test:
    bash tests/run.sh

# Full history, with the repo's .gitleaks.toml when there is one.
gitleaks:
    .ci/bin/ci-gitleaks

ci-drift:
    .ci/bin/ci-sync --check .

# Whole history (nightly).
gitleaks-full:
    .ci/bin/ci-gitleaks --full
