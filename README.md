# design-guard

CI check that fails when shipped code uses Lucide, Inter, or Geist.

Use Phosphor on the web and SF Symbols in Swift. SF Symbols stay on Apple platforms. For type, use a Fontshare face (or SF Pro and SF Mono on Apple), not Inter or Geist.

## Wire it in

Copy `templates/taste.yml` to `.github/workflows/taste.yml`.

```yaml
uses: cococool13/design-guard/.github/workflows/guard.yml@v1
secrets: inherit
```

The `v1` tag must exist on this repo before a caller can pin `@v1`. This pull request does not create that tag.

This repo is private. `actions/checkout` cannot use the caller's `GITHUB_TOKEN` to read it. The Actions access setting (Accessible from repositories owned by cococool13) does not grant that either. It only lets other repos call the workflow.

Create a fine-grained token with **Contents: Read** on `cococool13/design-guard` only. Store it on the caller as `DESIGN_GUARD_READ_TOKEN`. The template passes it with `secrets: inherit`. You can pass it explicitly instead:

```yaml
secrets:
  DESIGN_GUARD_READ_TOKEN: ${{ secrets.DESIGN_GUARD_READ_TOKEN }}
```

The workflow fails with a clear error when the secret is missing.

## What it scans

`taste-guard.sh` fails on:

- `package.json` dependencies and `Package.swift`
- `@fontsource` Inter/Geist, `next/font/google`, Google Fonts, Bunny Fonts, and `@font-face` `src`
- CSS, SCSS, and Tailwind `font-family` and `--font` values
- SwiftUI `.custom("Inter...")` or `.custom("Geist...")`
- bundled font files named `Inter*` or `Geist*` (`InterVariable.woff2`, `GeistMono-Regular.otf`)

Hits are GitHub annotations: `::error file=path,line=N::`.

Font names are case-sensitive and have to look like real use: `font-family`, `fontFamily:`, an import, `@fontsource`, `geist/...`, `next/font`, a quoted family (`"Inter"`, `'Inter'`, `"Inter Display"`), or a trailing comma (`Inter,`). `Interval`, `Interface`, `internal`, `INTERVAL_MS`, `INTERNAL_ERROR`, and `inter-process` do not match. `InterVariable`, `InterDisplay`, and `GeistMono` do. Package names and font URLs also match the lowercase slugs `inter` and `geist`.

It skips `*.md` and `*.mdx`, lockfiles, `node_modules`, `vendor/`, `dist/`, `.next`, and the usual caches anywhere in the tree. `build/`, `out/`, `docs/`, and `skills/` are skipped only at the repo root. The same names under `src/` are scanned. It also skips `.pnp`, `.yarn`, `Pods`, and agent folders (`.claude`, `.agents`, `.cursor`). Licence files are skipped only when the basename is `LICENSE`, `LICENCE`, `COPYING`, `NOTICE`, `OFL`, or `FFL`, with an optional `.txt` or `.md`. A `*OFL*.txt` file under a `fonts/` directory is skipped too. `license.ts`, `shuffle.css`, and `raffle.tsx` are scanned. Use `.taste-allow` to skip anything else.

Lint excerpts, if you want them in a repo, are in `configs/`:

- `configs/eslint.banned.js`
- `configs/stylelint.banned.json`
- `configs/swiftlint.banned.yml`

Those files name the banned packages, so add them to `.taste-allow` if you commit them.

## Exceptions

Do not add this workflow to **jcc-*** client repos. Those brands are exempt.

**TBP** (`tbp-website`) is exempt until Cohen decides whether Inter is its brand font.

Inside a repo that does run the check, put a `.taste-allow` file at the repo root. See `.taste-allow.example`.

- Globs follow gitignore rules. A slash anchors the pattern to the repo root. A name with no slash, such as `brand`, matches that directory anywhere, including everything under it. A leading `!` puts a path back.
- `pattern: <regex>` skips hits whose line matches that regex (ripgrep syntax).

## Impeccable

After the taste check, the workflow runs the vendored detector in report-only mode when the design-guard checkout succeeded. A cancelled job or a failed checkout skips the report. A taste failure still publishes it. Findings go to the job summary. They do not fail the job. Do not install the detector as a user-level hook.

The entry point is `vendor/impeccable-detector/detect-antipatterns.mjs` (`--json`). It scans the caller's source files and skips `vendor/`, `.design-guard`, and `node_modules`. `cli/main.mjs` imports `vendor/lib/impeccable-config.mjs` (Apache-2.0, same skill). The step uses `actions/setup-node` and does not install packages. Puppeteer is not used; URL scans are not run.

## Local run

```bash
bash taste-guard.sh
```

Needs ripgrep (`rg`). No network.
