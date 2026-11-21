# design-guard

A check that fails when shipped code uses Lucide, Inter, or Geist. Repos run it locally through `just check`, which calls `.ci/bin/ci-taste v1`.

Use Phosphor on the web and SF Symbols in Swift. SF Symbols stay on Apple platforms. For type, use a Fontshare face (or SF Pro and SF Mono on Apple), not Inter or Geist.

## Wire it in

The check runs locally, through `just check`. In a repo with the shared CI kit (`.ci/`), add a `taste` recipe to the `justfile` and list it in `check`:

```just
taste:
    .ci/bin/ci-taste v1
```

`ci-taste` exports the `v1` tag of this repo (from `~/Projects/Design Guard`, or `$DESIGN_GUARD`) and runs `taste-guard.sh` on the files git would commit. Callers pin `v1`, so a merge here reaches them only when that tag moves.

## What it scans

`taste-guard.sh` fails on:

- `package.json` dependencies and `Package.swift`
- `@fontsource` Inter/Geist, `next/font/google`, Google Fonts, Bunny Fonts, and `@font-face` `src`
- CSS, SCSS, and Tailwind `font-family` and `--font` values
- SwiftUI `.custom("Inter...")` or `.custom("Geist...")`
- bundled font files named `Inter*` or `Geist*` (`InterVariable.woff2`, `GeistMono-Regular.otf`)
- Instrument Serif paired with negative `letter-spacing` / `tracking-tighter` (don't use it as a tightly tracked hero face)

Hits are GitHub annotations: `::error file=path,line=N::`.

Font names are case-sensitive and have to look like real use: `font-family`, `fontFamily` (a bare key, a quoted key, or a template-literal value, including in `.vue`, `.svelte`, and `.astro`), an import, `@fontsource`, `geist/...` (`from`, `import()`, or `require`, with or without space), `next/font`, a quoted family (`"Inter"`, `'Inter'`, `"Inter Display"`), or a trailing comma (`Inter,`). `Interval`, `Interface`, `internal`, `INTERVAL_MS`, `INTERNAL_ERROR`, and `inter-process` do not match. `InterVariable`, `InterDisplay`, and `GeistMono` do. Package names and font URLs also match the lowercase slugs `inter` and `geist`.

It skips `*.md` and `*.mdx`, lockfiles, `node_modules`, `vendor/`, `dist/`, `.next`, and the usual caches anywhere in the tree. `build/`, `out/`, `docs/`, and `skills/` are skipped only at the repo root. The same names under `src/` are scanned. It also skips `.pnp`, `.yarn`, `Pods`, and agent folders (`.claude`, `.agents`, `.cursor`). Licence files are skipped only when the basename is `LICENSE`, `LICENCE`, `COPYING`, `NOTICE`, `OFL`, or `FFL`, with an optional `.txt`. A `*OFL*.txt` file under a `fonts/` directory is skipped too. Every `.md` file is already skipped, so a licence named `OFL.md` is not a separate case. `license.ts`, `shuffle.css`, and `raffle.tsx` are scanned. Use `.taste-allow` to skip anything else.

Lint excerpts, if you want them in a repo, are in `configs/`:

- `configs/eslint.banned.js`
- `configs/stylelint.banned.json`
- `configs/swiftlint.banned.yml`

Those files name the banned packages, so add them to `.taste-allow` if you commit them.

## Exceptions

Never add this check to **jcc-*** client repos. Those brands are exempt.

Inside a repo that does run the check, put a `.taste-allow` file at the repo root. See `.taste-allow.example`.

- Globs follow gitignore rules. A slash anchors the pattern to the repo root. A name with no slash, such as `brand`, matches that directory anywhere, including everything under it. A leading `!` puts a path back.
- `pattern: <regex>` skips hits whose line matches that regex (ripgrep syntax).

## Impeccable

The vendored detector runs in report-only mode. Run it locally from the design-guard repo with `node scripts/impeccable-report.mjs <dir>`. It prints a markdown report. Findings never fail a check. `just check` in other repos doesn't run it. Don't install the detector as a user-level hook.

The entry point is `vendor/impeccable-detector/detect-antipatterns.mjs` (`--json`). It scans source files and skips `vendor/`, `.design-guard`, and `node_modules`. `cli/main.mjs` imports `vendor/lib/impeccable-config.mjs` (Apache-2.0, same skill). It installs no packages. It doesn't use Puppeteer or run URL scans.

## Local run

```bash
bash taste-guard.sh
```

Needs ripgrep (`rg`). No network.
