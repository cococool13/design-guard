# design-guard

Local taste check (`taste-guard.sh`; other repos run it with `.ci/bin/ci-taste`). `bash tests/run.sh` is the fixture self-test.

## Build and release rules

- Checks run on this Mac too. `just check` before claiming done (same command as pre-push and `ship`); `just check-fast` while working. Never `--no-verify`. Land work only with `.ci/bin/ship`: it checks the exact commit, posts `ci/just-check`, and merges or labels the PR `needs-cohen` (CI, hooks, workflows, release paths). Callers run `.ci/bin/ci-taste v1`, so a merge reaches them only when that tag moves.
