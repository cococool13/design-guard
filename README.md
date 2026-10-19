# design-guard

CI check that fails when shipped code uses Lucide, Inter, or Geist.

Use Phosphor on the web and SF Symbols in Swift. SF Symbols stay on Apple platforms. For type, use a Fontshare face (or SF Pro and SF Mono on Apple), not Inter or Geist.

## Wire it in

Copy `templates/taste.yml` to `.github/workflows/taste.yml`.

```yaml
uses: cococool13/design-guard/.github/workflows/guard.yml@v1
```

Forge tags `v1` after this merges. Callers pin `@v1`.

This repo is private. The workflow checks out the caller, checks out design-guard, installs ripgrep, and runs `taste-guard.sh`. The caller's token can read design-guard only if you do one of these:

1. Open [Actions settings](https://github.com/cococool13/design-guard/settings/actions). Under **Access**, choose **Accessible from repositories owned by the user cococool13**. Save. The caller's `GITHUB_TOKEN` can then read this repo.
2. Or add a secret named `DESIGN_GUARD_READ_TOKEN` that can read this repo, and pass `secrets: inherit` (the template already does).

`secrets: inherit` is safe with option 1. Option 2 needs it.

## What it scans

`taste-guard.sh` fails on:

- `package.json` dependencies and `Package.swift`
- `@fontsource` Inter/Geist, `next/font/google`, Google Fonts, Bunny Fonts, and `@font-face` `src`
- CSS, SCSS, and Tailwind `font-family` and `--font` values
- SwiftUI `.custom("Inter...")` or `.custom("Geist...")`
- bundled font files named `Inter*` or `Geist*` (`InterVariable.woff2`, `GeistMono-Regular.otf`)

Hits are GitHub annotations: `::error file=path,line=N::`.

It skips docs (`*.md`, `*.mdx`, `docs/`), lockfiles, `node_modules`, `vendor/`, build output (`dist`, `build`, `.next`, and the usual caches), OFL license texts, and agent folders (`.claude`, `.agents`, `.cursor`, `skills/`).

`Interval`, `Interface`, and `internal` do not match. `InterVariable` and `GeistMono` do.

Lint excerpts, if you want them in a repo, are in `configs/`:

- `configs/eslint.banned.js`
- `configs/stylelint.banned.json`
- `configs/swiftlint.banned.yml`

Those files name the banned packages, so add them to `.taste-allow` if you commit them.

## Exceptions

Do not add this workflow to **jcc-*** client repos. Those brands are exempt.

**TBP** (`tbp-website`) is exempt until Cohen decides whether Inter is its brand font.

Inside a repo that does run the check, put a `.taste-allow` file at the repo root. See `.taste-allow.example`.

- Globs follow gitignore rules. A slash anchors the pattern to the repo root. A leading `!` puts a path back.
- `pattern: <regex>` skips hits whose line matches that regex (ripgrep syntax).

## Impeccable

After the taste check, the workflow runs the vendored detector in report-only mode. Findings go to the job summary. They do not fail the job. Do not install the detector as a user-level hook.

The entry point is `vendor/impeccable-detector/detect-antipatterns.mjs` (`--json`). It scans the caller's source files and skips `vendor/`, `.design-guard`, and `node_modules`. `cli/main.mjs` imports `vendor/lib/impeccable-config.mjs` (Apache-2.0, same skill). The step uses `actions/setup-node` and does not install packages. Puppeteer is not used; URL scans are not run.

## Local run

```bash
bash taste-guard.sh
```

Needs ripgrep (`rg`). No network.
