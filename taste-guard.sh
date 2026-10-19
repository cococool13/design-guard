#!/usr/bin/env bash
# taste-guard.sh — fail CI when shipped code uses Lucide, Inter, or Geist.
# Lockfiles, dependency folders, license texts, and agent folders are skipped.
# build/, out/, docs/, and skills/ are skipped only at the repo root.
# Per-repo exceptions: .taste-allow (gitignore globs, plus "pattern:" regex lines).
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "usage: taste-guard.sh [ROOT]"
  exit 0
fi

if [[ $# -gt 1 ]]; then
  printf '::error::taste-guard: expected one directory, got %s\n' "$#" >&2
  exit 2
fi

ROOT="${1:-.}"
if [[ ! -d "$ROOT" ]]; then
  printf '::error::taste-guard: not a directory: %s\n' "$ROOT" >&2
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  printf '::error::taste-guard: ripgrep (rg) is not installed\n' >&2
  exit 2
fi

cd "$ROOT"

# Case-sensitive family token. InterVariable, GeistMono, Geist_Mono, and "Geist Mono"
# count. Word boundaries reject Interval, Internal, INTERVAL_MS, and inter-process.
# Ripgrep's default engine has \b and does not have lookahead, so stay with \b.
FONT='\b(?:Inter(?:Variable)?|Geist(?:_Mono|[ _]?Mono)?)\b'
# Lowercase package and file slugs. \b rejects internal and intercom.
SLUG='\b(?:inter|geist)\b'
LUCIDE='\b[Ll][Uu][Cc][Ii][Dd][Ee](?:[A-Z_]|\b)'

SEEN=$(mktemp)
trap 'rm -f "$SEEN"' EXIT
FAIL=0
HITS=0

RG_GLOBS=(
  --glob '!.git/**'
  --glob '!**/*.md'
  --glob '!**/*.mdx'
  --glob '!/docs/**'
  --glob '!**/node_modules/**'
  --glob '!**/dist/**'
  --glob '!/build/**'
  --glob '!**/.next/**'
  --glob '!/out/**'
  --glob '!**/.output/**'
  --glob '!**/.nuxt/**'
  --glob '!**/.svelte-kit/**'
  --glob '!**/.turbo/**'
  --glob '!**/.cache/**'
  --glob '!**/coverage/**'
  --glob '!**/target/**'
  --glob '!**/.build/**'
  --glob '!**/DerivedData/**'
  --glob '!**/.vercel/**'
  --glob '!**/storybook-static/**'
  --glob '!**/.pnp'
  --glob '!**/.pnp.*'
  --glob '!**/.pnp/**'
  --glob '!**/.yarn/**'
  --glob '!**/Pods/**'
  --glob '!**/LICENSE'
  --glob '!**/LICENSE.*'
  --glob '!**/license'
  --glob '!**/license.*'
  --glob '!**/License'
  --glob '!**/License.*'
  --glob '!**/*[Ff][Ff][Ll]*'
  --glob '!**/*[Ll][Ii][Cc][Ee][Nn][Ss][Ee]*.txt'
  --glob '!**/[Oo][Ff][Ll]'
  --glob '!**/[Oo][Ff][Ll].*'
  --glob '!**/*-[Oo][Ff][Ll]*'
  --glob '!**/*_[Oo][Ff][Ll]*'
  --glob '!**/*[Oo][Ff][Ll].txt'
  --glob '!**/*[Oo][Ff][Ll].md'
  --glob '!**/package-lock.json'
  --glob '!**/npm-shrinkwrap.json'
  --glob '!**/yarn.lock'
  --glob '!**/pnpm-lock.yaml'
  --glob '!**/bun.lock'
  --glob '!**/bun.lockb'
  --glob '!**/Cargo.lock'
  --glob '!**/Gemfile.lock'
  --glob '!**/poetry.lock'
  --glob '!**/uv.lock'
  --glob '!**/composer.lock'
  --glob '!**/Podfile.lock'
  --glob '!**/Package.resolved'
  --glob '!**/go.sum'
  --glob '!**/flake.lock'
  --glob '!**/pubspec.lock'
  --glob '!**/.claude/**'
  --glob '!**/.agents/**'
  --glob '!**/.cursor/**'
  --glob '!/skills/**'
  --glob '!**/vendor/**'
  --glob '!**/.design-guard/**'
  --glob '!**/.taste-allow'
  --glob '!**/.taste-allow.example'
)

ALLOW_PATTERNS=()
ALLOW_RES=()
ALLOW_NEG=()

trim() {
  local value="$1"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s' "$value"
}

# Gitignore glob → POSIX ERE. Anchored patterns stay at the scan root.
glob_to_ere() {
  local pat="$1"
  local dir_only=0 anchored=0 no_slash=0 regex="" c
  # A name with no slash matches that file or directory anywhere.
  # Matching a directory also matches everything under it (gitignore).
  if [[ "$pat" != */* ]]; then
    no_slash=1
  fi
  if [[ "$pat" == */ ]]; then
    dir_only=1
    pat="${pat%/}"
  fi
  if [[ "$pat" == /* ]]; then
    anchored=1
    pat="${pat#/}"
  elif [[ "$pat" == */* ]]; then
    anchored=1
  fi
  local rest="$pat"
  while [[ -n "$rest" ]]; do
    c="${rest:0:1}"
    rest="${rest:1}"
    case "$c" in
      '*')
        if [[ "${rest:0:1}" == '*' ]]; then
          rest="${rest:1}"
          if [[ "${rest:0:1}" == '/' ]]; then
            rest="${rest:1}"
            regex+="(.*/)?"
          else
            regex+=".*"
          fi
        else
          regex+="[^/]*"
        fi
        ;;
      '?') regex+="[^/]" ;;
      *)
        # Escape ERE metacharacters, including a literal backslash.
        if [[ $'.+()|[]{}^$\\' == *"$c"* ]]; then
          regex+="\\${c}"
        else
          regex+="$c"
        fi
        ;;
    esac
  done
  if [[ $anchored -eq 1 ]]; then
    regex="^${regex}"
  else
    regex="^(.*/)?${regex}"
  fi
  if [[ $dir_only -eq 1 || $no_slash -eq 1 ]]; then
    regex="${regex}(/.*)?"
  fi
  printf '%s$' "$regex"
}

if [[ -f .taste-allow ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line=$(trim "$line")
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == pattern:* ]]; then
      pat=$(trim "${line#pattern:}")
      [[ -z "$pat" ]] && continue
      set +e
      printf 'x\n' | rg -q -e "$pat" >/dev/null 2>&1
      status=$?
      set -e
      if [[ $status -eq 2 ]]; then
        printf '::error file=.taste-allow::Invalid pattern: %s\n' "$pat"
        exit 2
      fi
      ALLOW_PATTERNS+=("$pat")
    else
      neg=0
      glob="$line"
      if [[ "$glob" == '!'* ]]; then
        neg=1
        glob="${glob#!}"
      fi
      [[ -z "$glob" ]] && continue
      ALLOW_RES+=("$(glob_to_ere "$glob")")
      ALLOW_NEG+=("$neg")
    fi
  done < .taste-allow
fi

emit() {
  local file="$1" lineno="$2" message="$3"
  file="${file#./}"
  printf '::error file=%s,line=%s::%s\n' "$file" "$lineno" "$message"
  FAIL=1
  HITS=$((HITS + 1))
}

line_allowed() {
  local text="$1" pat
  [[ ${#ALLOW_PATTERNS[@]} -eq 0 ]] && return 1
  for pat in "${ALLOW_PATTERNS[@]}"; do
    if printf '%s\n' "$text" | rg -q -e "$pat"; then
      return 0
    fi
  done
  return 1
}

# Last matching .taste-allow glob wins, same as gitignore.
path_skipped() {
  local path="$1" i ignored=0
  path="${path#./}"
  [[ ${#ALLOW_RES[@]} -eq 0 ]] && return 1
  for i in "${!ALLOW_RES[@]}"; do
    if [[ "$path" =~ ${ALLOW_RES[$i]} ]]; then
      if [[ "${ALLOW_NEG[$i]}" -eq 1 ]]; then
        ignored=0
      else
        ignored=1
      fi
    fi
  done
  [[ "$ignored" -eq 1 ]]
}

# Extra args are passed to rg (usually --glob includes).
search() {
  local message="$1" pattern="$2"
  shift 2
  local out status line file rest lineno text key
  set +e
  # Include globs first, then excludes, so excludes win.
  out=$(rg -n -H --no-heading --color never --hidden --no-ignore --no-ignore-vcs \
    "$@" "${RG_GLOBS[@]}" -e "$pattern" . 2>&1)
  status=$?
  set -e
  if [[ $status -eq 2 ]]; then
    printf '::error::taste-guard: ripgrep failed\n' >&2
    printf '%s\n' "$out" >&2
    exit 2
  fi
  [[ $status -eq 1 || -z "$out" ]] && return 0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    file="${line%%:*}"
    rest="${line#*:}"
    lineno="${rest%%:*}"
    text="${rest#*:}"
    [[ "$lineno" =~ ^[0-9]+$ ]] || continue
    if path_skipped "$file" || line_allowed "$text"; then
      continue
    fi
    key="${file}:${lineno}"
    if grep -Fxq "$key" "$SEEN"; then
      continue
    fi
    printf '%s\n' "$key" >> "$SEEN"
    emit "$file" "$lineno" "$message"
  done <<<"$out"
}

check_font_files() {
  local file base ext key
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if path_skipped "$file"; then
      continue
    fi
    base="${file##*/}"
    ext=$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
      ttf|otf|woff|woff2|ttc|eot) ;;
      *) continue ;;
    esac
    # Inter-Regular.woff2, InterVariable.woff2, GeistMono-Regular.ttf, inter.woff2 match.
    # Interface.ttf, Interval.otf, internal.woff2, and INTERVAL.woff2 do not.
    # POSIX ERE only (bash 3.2): no non-capturing groups.
    if [[ "$base" =~ ^(Inter(Variable)?|Geist(Mono)?|inter|geist)([^a-z].*)?$ ]]; then
      key="${file}:1"
      if grep -Fxq "$key" "$SEEN"; then
        continue
      fi
      printf '%s\n' "$key" >> "$SEEN"
      emit "$file" 1 "Bundled Inter or Geist font file is banned. Use SF Pro on Apple, or a Fontshare face."
    fi
  done < <(rg --files --hidden --no-ignore --no-ignore-vcs --color never "${RG_GLOBS[@]}" . || true)
}

MSG_LUCIDE='Lucide is banned. Use Phosphor (web) or SF Symbols (Swift).'
MSG_PKG='Inter/Geist packages are banned.'
MSG_NEXT='Inter/Geist via next/font is banned.'
MSG_URL='Inter/Geist webfont loads are banned.'
MSG_FACE='Inter/Geist in @font-face src is banned.'
MSG_CSS='Inter/Geist in CSS font-family or --font is banned.'
MSG_TW='Inter/Geist in a Tailwind font is banned.'
MSG_SWIFT='Inter/Geist in SwiftUI is banned. Use SF Pro or SF Mono.'
MSG_MANIFEST='Inter/Geist in a package manifest is banned.'
MSG_FONT='Inter/Geist is banned.'

search "$MSG_PKG" "@fontsource(?:-variable)?/(?:inter|geist)(?:-mono)?"
search "$MSG_URL" "fonts\\.(?:googleapis\\.com|bunny\\.net|gstatic\\.com)[^[:space:]'\"<>)]*(?:${FONT}|${SLUG})"
search "$MSG_NEXT" "import[[:space:]]+(type[[:space:]]+)?\\{[^}]*(?:${FONT})[^}]*\\}[[:space:]]*from[[:space:]]*['\"]next/font/google['\"]"
search "$MSG_NEXT" "\\b(?:Inter|Geist_Mono|Geist)[[:space:]]*\\("
search "$MSG_FACE" "url[[:space:]]*\\([[:space:]]*['\"]?[^)'\"]*(?:${FONT}|${SLUG})|local[[:space:]]*\\([[:space:]]*['\"](?:${FONT})"
search "$MSG_CSS" "(?:font-family[[:space:]]*:|(?:--|\\$)font[A-Za-z0-9_-]*[[:space:]]*:|(?:^|[^A-Za-z_-])font[[:space:]]*:)[[:space:]]*[^;}{]{0,400}?(?:${FONT})" \
  --glob '*.css' --glob '*.scss' --glob '*.sass' --glob '*.less' --glob '*.pcss' \
  --glob '*.vue' --glob '*.svelte' --glob '*.html' --glob '*.htm'
search "$MSG_TW" "font-\\[[[:space:]]*['\"]?(?:${FONT})|\\[font-family:[[:space:]]*['\"]?(?:${FONT})"
search "$MSG_TW" "(?:${FONT})" --glob 'tailwind.config.*'
search "$MSG_SWIFT" "\\.custom[[:space:]]*\\([[:space:]]*['\"](?:${FONT})" --glob '*.swift'
search "$MSG_LUCIDE" "$LUCIDE"
search "$MSG_MANIFEST" "['\"](?:@fontsource(?:-variable)?/)?(?:inter|geist)(?:-mono)?['\"]" \
  --glob 'package.json' --glob '*.podspec'
search "$MSG_MANIFEST" "(?:${FONT})" --glob 'package.json' --glob 'Package.swift' --glob '*.podspec'
# Quoted family ("Inter", 'Geist') or a trailing comma (Inter,). Not a bare word.
search "$MSG_FONT" "['\"](?:${FONT})\\b|(?:^|[^A-Za-z0-9_])(?:Inter(?:Variable)?|Geist(?:Mono)?),"
check_font_files

if [[ "$FAIL" -ne 0 ]]; then
  printf 'taste-guard: %s banned hit(s)\n' "$HITS" >&2
  exit 1
fi

echo "taste-guard: ok"
exit 0
