// Report-only Impeccable scan. Findings are written to the job summary.
// The process exits 0 even when the detector reports anti-patterns.
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const detector = path.join(scriptDir, '..', 'vendor', 'impeccable-detector', 'detect-antipatterns.mjs');
const skipNames = new Set(['.design-guard', '.git', 'vendor', 'node_modules']);
const hiddenSource = new Set(['.storybook', '.vitepress', '.vuepress']);
const scannable = new Set([
  '.html', '.htm', '.css', '.scss', '.sass', '.less',
  '.jsx', '.tsx', '.js', '.ts',
  '.vue', '.svelte', '.astro',
]);
const maxRows = 40;

function repoRoot(dir) {
  return fs.existsSync(path.join(dir, '.git')) || fs.existsSync(path.join(dir, '.design-guard'));
}

function sourceTargets(root) {
  if (!repoRoot(root)) return [root];
  let names = [];
  try {
    names = fs.readdirSync(root);
  } catch {
    return [root];
  }
  const targets = [];
  for (const name of names) {
    if (skipNames.has(name)) continue;
    if (name.startsWith('.') && !hiddenSource.has(name)) continue;
    const full = path.join(root, name);
    let stat;
    try {
      stat = fs.statSync(full);
    } catch {
      continue;
    }
    if (stat.isDirectory() || scannable.has(path.extname(name).toLowerCase())) {
      targets.push(full);
    }
  }
  return targets;
}

function cell(value) {
  return String(value ?? '')
    .replace(/\s+/g, ' ')
    .replace(/\|/g, '\\|')
    .slice(0, 160);
}

function relativeTo(root, file) {
  const rel = path.relative(root, file);
  if (rel.startsWith('..') || path.isAbsolute(rel)) return file;
  return rel || file;
}

function render(root, findings, note) {
  const lines = ['## Impeccable (report only)', ''];
  if (note) lines.push(note, '');
  const count = findings.length;
  lines.push(
    count === 0
      ? 'No findings. This step does not fail the job.'
      : `${count} finding${count === 1 ? '' : 's'}. This step does not fail the job.`,
    '',
  );
  if (count > 0) {
    lines.push('| Rule | Location | Snippet |', '| --- | --- | --- |');
    for (const finding of findings.slice(0, maxRows)) {
      const where = `${relativeTo(root, finding.file || '')}:${finding.line || 1}`;
      const rule = finding.advisory ? `${finding.antipattern} (advisory)` : finding.antipattern;
      lines.push(`| ${cell(rule)} | ${cell(where)} | ${cell(finding.snippet)} |`);
    }
    if (count > maxRows) {
      lines.push('', `_${count - maxRows} more findings were omitted from this summary._`);
    }
  }
  lines.push('');
  return lines.join('\n');
}

function writeSummary(markdown) {
  const dest = process.env.GITHUB_STEP_SUMMARY;
  if (dest) fs.appendFileSync(dest, `${markdown}\n`);
  process.stdout.write(`${markdown}\n`);
}

function runDetector(root, targets) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [detector, '--json', ...targets], {
      cwd: root,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const stdout = [];
    const stderr = [];
    child.stdout.on('data', (chunk) => stdout.push(chunk));
    child.stderr.on('data', (chunk) => stderr.push(chunk));
    child.on('error', (error) => resolve({ status: 1, stdout: '', stderr: error.message }));
    child.on('close', (status) => {
      resolve({
        status: status ?? 1,
        stdout: Buffer.concat(stdout).toString('utf8'),
        stderr: Buffer.concat(stderr).toString('utf8'),
      });
    });
  });
}

const root = path.resolve(process.argv[2] || process.cwd());

if (!fs.existsSync(detector)) {
  writeSummary(render(root, [], 'Detector files are not in vendor/impeccable-detector/.'));
  process.exit(0);
}

const targets = repoRoot(root) ? sourceTargets(root) : [root];
if (targets.length === 0) {
  writeSummary(render(root, [], 'No source files to scan.'));
  process.exit(0);
}

const result = await runDetector(root, targets);
let findings = [];
let note = '';
try {
  const parsed = JSON.parse(result.stdout || '[]');
  findings = Array.isArray(parsed) ? parsed : [];
} catch {
  note = 'The detector did not return JSON. Nothing here fails the job.';
}
if (result.status !== 0 && result.status !== 2 && !note) {
  const detail = result.stderr.trim().split('\n').slice(-3).join(' ');
  note = detail
    ? `The detector exited ${result.status}. ${detail}`
    : `The detector exited ${result.status}.`;
}

writeSummary(render(root, findings, note));
process.exit(0);
