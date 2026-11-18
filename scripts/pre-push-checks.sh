#!/bin/sh
# Repo checks for .githooks/pre-push. CI can call this same script.
set -eu
cd "$(dirname "$0")/.."
bash tests/run.sh
