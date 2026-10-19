#!/usr/bin/env bash
# Self-test for taste-guard.sh. Bad fixtures must fail. Clean ones must pass.
set -euo pipefail

cd "$(dirname "$0")/.."
guard="$(pwd)/taste-guard.sh"
fixtures="$(pwd)/tests/fixtures"

bash -n "$guard"
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
  out=$(bash "$guard" "$dir" 2>&1)
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
out=$(bash "$guard" "$badpat" 2>&1)
status=$?
set -e
rm -rf "$badpat"
if [[ "$status" -eq 2 ]] && grep -q 'Invalid pattern' <<<"$out"; then
  ok "invalid taste-allow pattern"
else
  bad "invalid pattern expected exit 2" "$out"
fi

# Missing directory is a tool error, not a taste failure.
set +e
out=$(bash "$guard" "$fixtures/does-not-exist" 2>&1)
status=$?
set -e
if [[ "$status" -eq 2 ]] && grep -q 'not a directory' <<<"$out"; then
  ok "missing directory"
else
  bad "missing directory expected exit 2" "$out"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
