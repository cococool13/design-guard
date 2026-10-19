#!/usr/bin/env bash
# Self-test for taste-guard.sh. Bad fixtures must fail. Clean ones must pass.
set -euo pipefail

cd "$(dirname "$0")/.."
guard="$(pwd)/taste-guard.sh"
fixtures="$(pwd)/tests/fixtures"
# Use the bash that launched this script, so a 3.2 run tests the guard on 3.2.
shell="${BASH:-bash}"

"$shell" -n "$guard"
chmod +x "$guard"

pass=0
fail=0

ok() {
  printf 'ok  %s\n' "$1"
  pass=$((pass + 1))
}

bad() {
  printf 'FAIL %s\n' "$1" >&2
  if [[ -n "${2:-}" ]]; then
    printf '%s\n' "$2" >&2
  fi
  fail=$((fail + 1))
}

run_guard() {
  local dir="$1"
  set +e
  out=$("$shell" "$guard" "$dir" 2>&1)
  status=$?
  set -e
}

expect_fail() {
  local name="$1" dir="$2" needle="${3:-}" absent="${4:-}"
  run_guard "$dir"
  if [[ "$status" -ne 1 ]]; then
    bad "$name expected exit 1, got $status" "$out"
    return
  fi
  if ! grep -q '::error file=[^,]*,line=[0-9][0-9]*::' <<<"$out"; then
    bad "$name missing ::error file:line" "$out"
    return
  fi
  if [[ -n "$needle" ]] && ! grep -q "$needle" <<<"$out"; then
    bad "$name missing [$needle]" "$out"
    return
  fi
  if [[ -n "$absent" ]] && grep -q "$absent" <<<"$out"; then
    bad "$name should not mention [$absent]" "$out"
    return
  fi
  ok "$name"
}

expect_pass() {
  local name="$1" dir="$2"
  run_guard "$dir"
  if [[ "$status" -ne 0 ]]; then
    bad "$name expected exit 0, got $status" "$out"
    return
  fi
  if grep -q '::error ' <<<"$out"; then
    bad "$name printed an error" "$out"
    return
  fi
  ok "$name"
}

expect_fail "lucide package.json" "$fixtures/bad-lucide-pkg" "Lucide is banned"
expect_fail "lucide import" "$fixtures/bad-lucide-import" "Lucide is banned"
expect_fail "LucideIcon" "$fixtures/bad-lucide-icon" "Lucide is banned"
expect_fail "fontsource inter" "$fixtures/bad-fontsource-inter" "packages are banned"
expect_fail "fontsource geist" "$fixtures/bad-fontsource-geist" "packages are banned"
expect_fail "geist package" "$fixtures/bad-geist-package" "package manifest"
expect_fail "next/font import" "$fixtures/bad-next-font" "next/font"
expect_fail "next/font call" "$fixtures/bad-next-font-call" "next/font"
expect_fail "next/font multiline" "$fixtures/bad-next-font-multiline" "Inter/Geist is banned"
expect_fail "google fonts" "$fixtures/bad-google-fonts" "webfont"
expect_fail "bunny fonts" "$fixtures/bad-bunny-fonts" "webfont"
expect_fail "gstatic" "$fixtures/bad-gstatic" "webfont"
expect_fail "font-face url" "$fixtures/bad-font-face" "font-face"
expect_fail "font-face camel file" "$fixtures/bad-font-face-camel" "font-face"
expect_fail "font-face local" "$fixtures/bad-font-face-local" "font-face"
expect_fail "css font-family" "$fixtures/bad-css-family" "file=styles.css,line=1::"
expect_fail "css unquoted" "$fixtures/bad-css-unquoted" "font-family"
expect_fail "css InterVariable" "$fixtures/bad-css-camel" "font-family"
expect_fail "css --font" "$fixtures/bad-css-var" "font-family or --font"
expect_fail "css font shorthand" "$fixtures/bad-css-shorthand" "font-family or --font"
expect_fail "scss \$font" "$fixtures/bad-scss" "font-family or --font"
expect_fail "tailwind class" "$fixtures/bad-tailwind-class" "Tailwind"
expect_fail "tailwind arbitrary" "$fixtures/bad-tailwind-arb" "Tailwind"
expect_fail "tailwind config" "$fixtures/bad-tailwind-config" "Tailwind"
expect_fail "swift custom" "$fixtures/bad-swift" "SwiftUI"
expect_fail "swift GeistMono" "$fixtures/bad-swift-camel" "SwiftUI"
expect_fail "Package.swift" "$fixtures/bad-package-swift" "package manifest"
expect_fail "font file Inter" "$fixtures/bad-font-file" "file=Fonts/Inter-Regular.woff2,line=1::"
expect_fail "font file Geist" "$fixtures/bad-font-geist" "Geist-Regular.otf"
expect_fail "font file GeistMono" "$fixtures/bad-font-geistmono" "GeistMono-Regular.ttf"
expect_fail "font file InterVariable" "$fixtures/bad-font-camel" "InterVariable.woff2"

expect_pass "clean project" "$fixtures/ok-clean"
expect_pass "Interval Interface internal" "$fixtures/ok-false-positive"
expect_pass "INTERVAL_MS INTERNAL inter-process" "$fixtures/ok-font-case"
expect_fail "quoted Inter and Inter comma" "$fixtures/bad-font-token" "file=src/fonts.ts,line=1::"
expect_fail "geist/font/sans import" "$fixtures/bad-geist-import" "file=src/app.tsx,line=1::"
run_guard "$fixtures/bad-geist-import"
if grep -q 'file=src/app.tsx,line=2::' <<<"$out"; then
  ok "geist/font/mono import"
else
  bad "missing geist/font/mono" "$out"
fi
expect_fail "unquoted fontFamily Inter" "$fixtures/bad-font-family-js" "file=src/theme.ts,line=1::"
expect_fail "InterDisplay" "$fixtures/bad-inter-display" "file=styles.css,line=1::"
run_guard "$fixtures/bad-inter-display"
if grep -q 'file=styles.css,line=2::' <<<"$out"; then
  ok "Inter Display"
else
  bad "missing Inter Display" "$out"
fi
# 'Inter' and the Inter, import line are the other two true-positive forms.
run_guard "$fixtures/bad-font-token"
if grep -q "file=src/fonts.ts,line=2::" <<<"$out" && grep -q "file=src/fonts.ts,line=4::" <<<"$out"; then
  ok "single-quoted Inter and Inter comma"
else
  bad "missing 'Inter' or Inter, hit" "$out"
fi
expect_pass "docs" "$fixtures/ok-docs"
expect_pass "ignored paths" "$fixtures/ok-ignored"
expect_pass "taste-allow glob and pattern" "$fixtures/ok-allow"
expect_fail "taste-allow leaves other files" "$fixtures/bad-allow-rest" "src/app.css" "brand/"

# Negation: brand/** is skipped, brand/keep.css is put back.
neg=$(mktemp -d)
mkdir -p "$neg/brand" "$neg/src"
cat > "$neg/.taste-allow" << 'EOF'
brand/**
!brand/keep.css
EOF
printf 'body { font-family: "Inter", sans-serif; }\n' > "$neg/brand/old.css"
printf 'body { font-family: "Inter", sans-serif; }\n' > "$neg/brand/keep.css"
printf 'body { font-family: Switzer, sans-serif; }\n' > "$neg/src/ok.css"
expect_fail "taste-allow negation" "$neg" "brand/keep.css" "brand/old.css"
rm -rf "$neg"

# A broken pattern: line is a tool error.
badpat=$(mktemp -d)
printf 'pattern: (\n' > "$badpat/.taste-allow"
printf 'ok\n' > "$badpat/a.txt"
set +e
out=$("$shell" "$guard" "$badpat" 2>&1)
status=$?
set -e
rm -rf "$badpat"
if [[ "$status" -eq 2 ]] && grep -q 'Invalid pattern' <<<"$out"; then
  ok "invalid taste-allow pattern"
else
  bad "invalid pattern expected exit 2" "$out"
fi

# vendor/ names the banned fonts inside the detector. Those files must not fail the guard.
vend=$(mktemp -d)
mkdir -p "$vend/vendor/impeccable-detector" "$vend/src"
printf 'body { font-family: "Inter", sans-serif; }\nimport "lucide-react";\n' > "$vend/vendor/impeccable-detector/rules.js"
printf 'body { font-family: Switzer, sans-serif; }\n' > "$vend/src/ok.css"
expect_pass "vendor directory ignored" "$vend"
printf 'body { font-family: "Geist", sans-serif; }\n' > "$vend/src/bad.css"
expect_fail "vendor ignore still scans source" "$vend" "src/bad.css" "vendor/"
rm -rf "$vend"

set +e
out=$("$shell" "$guard" . 2>&1)
status=$?
set -e
if grep -q 'vendor/impeccable-detector' <<<"$out"; then
  bad "real detector tree tripped taste-guard" "$out"
else
  ok "real detector tree ignored"
fi

# Detector report: findings are printed, and the wrapper still exits 0.
summary=$(mktemp)
set +e
GITHUB_STEP_SUMMARY="$summary" node scripts/impeccable-report.mjs "$fixtures/detector-hit" >"$summary.out" 2>"$summary.err"
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  bad "detector report expected exit 0, got $status" "$(cat "$summary" "$summary.out" "$summary.err")"
elif ! grep -q 'overused-font' "$summary"; then
  bad "detector report did not find overused-font" "$(cat "$summary" "$summary.err")"
elif ! grep -q 'does not fail the job' "$summary"; then
  bad "detector report missing job-summary note" "$(cat "$summary")"
else
  ok "detector report-only"
fi
rm -f "$summary" "$summary.out" "$summary.err"

# A repo-shaped tree skips vendor/ and still reports source.
repo=$(mktemp -d)
mkdir -p "$repo/.git" "$repo/vendor" "$repo/src"
cat > "$repo/vendor/bad.html" << 'EOF'
<!DOCTYPE html><style>body { font-family: Inter, sans-serif; }</style>
EOF
cat > "$repo/README.md" << 'EOF'
body { font-family: Inter, sans-serif; }
EOF
cat > "$repo/src/hit.html" << 'EOF'
<!DOCTYPE html><style>body { font-family: Inter, sans-serif; }</style>
EOF
summary=$(mktemp)
set +e
GITHUB_STEP_SUMMARY="$summary" node scripts/impeccable-report.mjs "$repo" >/dev/null
status=$?
set -e
if [[ "$status" -ne 0 ]]; then
  bad "detector on repo expected exit 0, got $status" "$(cat "$summary")"
elif grep -q 'vendor/bad.html' "$summary"; then
  bad "detector scanned vendor/" "$(cat "$summary")"
elif grep -q 'README.md' "$summary"; then
  bad "detector scanned README.md" "$(cat "$summary")"
elif ! grep -q 'src/hit.html' "$summary"; then
  bad "detector missed caller source" "$(cat "$summary")"
else
  ok "detector scans source not vendor"
fi
rm -rf "$repo" "$summary"

# A bare allow entry matches that directory name anywhere, not a longer name.
bare=$(mktemp -d)
mkdir -p "$bare/brand" "$bare/src/brand" "$bare/branding" "$bare/src"
printf 'brand\n' > "$bare/.taste-allow"
printf 'body { font-family: "Inter", sans-serif; }\n' > "$bare/brand/tokens.css"
printf 'body { font-family: "Inter", sans-serif; }\n' > "$bare/src/brand/x.css"
printf 'body { font-family: "Inter", sans-serif; }\n' > "$bare/branding/x.css"
printf 'body { font-family: "Inter", sans-serif; }\n' > "$bare/src/app.css"
run_guard "$bare"
if [[ "$status" -ne 1 ]]; then
  bad "bare brand allow expected exit 1, got $status" "$out"
elif ! grep -q 'file=src/app.css,' <<<"$out"; then
  bad "bare brand allow missed src/app.css" "$out"
elif ! grep -q 'file=branding/x.css,' <<<"$out"; then
  bad "bare brand allow skipped branding/" "$out"
elif grep -q 'file=brand/' <<<"$out" || grep -q 'file=src/brand/' <<<"$out"; then
  bad "bare brand allow scanned a brand directory" "$out"
else
  ok "bare brand allow matches the directory"
fi
rm -rf "$bare"

# Top-level build/out/docs/skills, license files, .pnp, .yarn, and Pods are
# skipped. The same names under src/ are not.
run_guard "$fixtures/bad-nested-skip"
if [[ "$status" -ne 1 ]]; then
  bad "nested skip expected exit 1, got $status" "$out"
else
  missing=""
  for needle in \
    'file=src/build/app.css,' \
    'file=src/out/app.css,' \
    'file=src/docs/site.css,' \
    'file=src/skills/note.js,' \
    'file=src/ofLine.ts,' \
    'file=src/app.tsx,' \
    'file=SIL-FFL.txt,'
  do
    if ! grep -q "$needle" <<<"$out"; then
      missing="${missing} ${needle}"
    fi
  done
  extra=""
  for absent in \
    'file=build/' \
    'file=out/' \
    'file=docs/' \
    'file=skills/' \
    'file=LICENSE,' \
    'file=license.txt,' \
    'file=OFL.md,' \
    'fonts/Face-OFL.txt' \
    '.pnp' \
    '.yarn/' \
    'Pods/'
  do
    if grep -q "$absent" <<<"$out"; then
      extra="${extra} ${absent}"
    fi
  done
  if [[ -n "$missing" ]]; then
    bad "nested skip missed:${missing}" "$out"
  elif [[ -n "$extra" ]]; then
    bad "nested skip should not mention:${extra}" "$out"
  else
    ok "top-level skips and license files"
  fi
fi

# Ordinary names that merely contain "ffl" or "license" are scanned.
# Real licence basenames, and *OFL*.txt under fonts/, are not.
run_guard "$fixtures/bad-not-license"
if [[ "$status" -ne 1 ]]; then
  bad "not-license expected exit 1, got $status" "$out"
else
  missing=""
  for needle in \
    'file=shuffle.css,' \
    'file=raffle.tsx,' \
    'file=license.ts,' \
    'file=notfonts/Inter-OFL.txt,' \
    'file=SIL-FFL.txt,'
  do
    if ! grep -q "$needle" <<<"$out"; then
      missing="${missing} ${needle}"
    fi
  done
  extra=""
  for absent in \
    'file=LICENSE,' \
    'file=license.txt,' \
    'file=LICENCE.md,' \
    'file=COPYING,' \
    'file=NOTICE.txt,' \
    'file=OFL.md,' \
    'file=FFL,' \
    'file=FFL.txt,' \
    'file=fonts/Inter-OFL.txt,'
  do
    if grep -q "$absent" <<<"$out"; then
      extra="${extra} ${absent}"
    fi
  done
  if [[ -n "$missing" ]]; then
    bad "not-license missed:${missing}" "$out"
  elif [[ -n "$extra" ]]; then
    bad "not-license skipped a real licence? no, it scanned:${extra}" "$out"
  else
    ok "licence basenames only"
  fi
fi

# Missing directory is a tool error, not a taste failure.
set +e
out=$("$shell" "$guard" "$fixtures/does-not-exist" 2>&1)
status=$?
set -e
if [[ "$status" -eq 2 ]] && grep -q 'not a directory' <<<"$out"; then
  ok "missing directory"
else
  bad "missing directory expected exit 2" "$out"
fi

# The reusable workflow must check out its own commit, require the read token,
# and still publish the Impeccable report after a taste failure.
wf=".github/workflows/guard.yml"
if grep -F -q 'repository: ${{ job.workflow_repository }}' "$wf" \
  && grep -F -q 'ref: ${{ job.workflow_sha }}' "$wf" \
  && grep -F -q 'required: true' "$wf" \
  && ! grep -F -q 'secrets.GITHUB_TOKEN' "$wf" \
  && grep -F -q 'DESIGN_GUARD_READ_TOKEN is missing' "$wf" \
  && grep -F -q 'id: design-guard' "$wf" \
  && grep -F -q "steps.design-guard.outcome == 'success' && !cancelled()" "$wf" \
  && ! grep -F -q 'if: always()' "$wf"; then
  ok "workflow checkout, token, and report gate"
else
  bad "workflow file drifted from the review fixes" "$(cat "$wf")"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
