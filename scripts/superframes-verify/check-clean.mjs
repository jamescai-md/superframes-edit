#!/usr/bin/env node
// check-clean.mjs — nothing that must never be committed.
//   • credentials: a GitHub token, an API key, a private key, a .env file
//   • build output and render artefacts
//   • absolute paths from someone's machine
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join, relative, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const SKIP_DIRS = new Set([".git", "node_modules", "dist", "build", "out", "coverage", "__pycache__"]);

const PATTERNS = [
  [/github_pat_[A-Za-z0-9_]{20,}/, "GitHub fine-grained token"],
  [/gh[pousr]_[A-Za-z0-9]{30,}/, "GitHub classic token"],
  [/AKIA[0-9A-Z]{16}/, "AWS access key"],
  [/sk-[A-Za-z0-9]{32,}/, "OpenAI-style secret key"],
  [/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/, "private key"],
];

// Known upstream fixtures: placeholder values in tests, deliberately committed.
const ALLOW = [
  /^examples\/aws-lambda\/scripts\/check-sam-deploy\.sh$/,
  /^packages\/cli\/src\/capture\/contentExtractor\.test\.ts$/,
  /^packages\/cli\/src\/capture\/fixtures\/capture-fixture-key\.pem$/,
  /^packages\/cli\/src\/telemetry\/agent_runtime(\.test)?\.ts$/,
  /^scripts\/superframes-verify\/check-clean\.mjs$/,
];

const problems = [];
function walk(dir) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (SKIP_DIRS.has(e.name)) continue;
    const full = join(dir, e.name);
    if (e.isDirectory()) { walk(full); continue; }
    if (e.name === ".env" || /\.env\.(local|production)$/.test(e.name)) {
      problems.push(`${relative(REPO, full)}: environment file committed`);
      continue;
    }
    if (/\.(png|jpe?g|webp|gif|mp4|mov|webm|mkv|mp3|wav|m4a|woff2?|ttf|otf|glb|zip|gz|mp4)$/i.test(e.name)) continue;
    if (e.size > 2_000_000) continue;
    let text;
    try { text = readFileSync(full, "utf8"); } catch { continue; }
    const rel = relative(REPO, full).split("\\").join("/");
    if (ALLOW.some((a) => a.test(rel))) continue;
    for (const [re, label] of PATTERNS) {
      if (re.test(text)) problems.push(`${rel}: looks like a ${label}`);
    }
    if (/\/home\/[a-z][\w-]*\/(?:user|src)\//.test(text)) {
      problems.push(`${relative(REPO, full)}: absolute path from a build machine`);
    }
  }
}
walk(REPO);
for (const p of problems) console.log(`FAIL  ${p}`);
console.log(problems.length === 0 ? "✓ no credentials, environment files or build artefacts" : `✗ ${problems.length} problem(s)`);
process.exit(problems.length === 0 ? 0 : 1);
