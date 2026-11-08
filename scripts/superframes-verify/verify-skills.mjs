#!/usr/bin/env node
// verify-skills.mjs — the repo's own gate. Runs in CI and locally:
//
//   node scripts/superframes-verify/verify-skills.mjs
//
// Checks, in the order a failure hurts most:
//   1. Frontmatter parses, and `name` + `description` exist as non-empty strings.
//      One malformed SKILL.md aborts `skills add` for the WHOLE repo.
//   2. `name` matches its directory.
//   3. Descriptions stay under the per-turn budget (every installed description is
//      listed on every agent turn).
//   4. Every relative path written in backticks in a SKILL.md actually exists.
//   5. Shell scripts referenced by a skill are executable and pass `bash -n`.
//   6. .claude/skills and .agents/skills mirror each other byte for byte.
//   7. No inline backtick span contains `!` or `>word` (Claude Code reads those as
//      bash history expansion / redirection and refuses to load the skill).
//
// Exit 1 on any error. Warnings do not fail the build.

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
// Published skills get the strict treatment (path resolution, size budgets).
// The repo-internal mirrors are held to frontmatter and mirror integrity only:
// upstream's internal skills legitimately describe repo-relative paths and long
// descriptions, because they are never installed by name.
const PUBLISHED_ROOT = join(REPO, "skills");
const SKILL_DIRS = [
  { dir: PUBLISHED_ROOT, strict: true },
  { dir: join(REPO, ".claude", "skills"), strict: false },
  { dir: join(REPO, ".agents", "skills"), strict: false },
];
const DESCRIPTION_MAX = 320;

const errors = [];
const warnings = [];
const err = (m) => errors.push(m);
const warn = (m) => warnings.push(m);

// ---------- helpers ----------
function walk(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, e.name);
    if (e.isDirectory()) walk(full, out);
    else if (e.isFile()) out.push(full);
  }
  return out;
}

function frontmatter(text) {
  const m = /^---\r?\n([\s\S]*?)\r?\n---\r?\n/.exec(text);
  if (!m) return null;
  const body = m[1];
  const data = {};
  for (const line of body.split(/\r?\n/)) {
    const kv = /^([A-Za-z][\w-]*):\s*(.*)$/.exec(line);
    if (kv) data[kv[1]] = kv[2].trim();
  }
  return data;
}

// Fenced blocks are safe; only inline backtick spans are scanned.
function inlineSpans(text) {
  const withoutFences = text.replace(/```[\s\S]*?```/g, "");
  return [...withoutFences.matchAll(/`([^`\n]*)`/g)].map((m) => m[1]);
}

// A backtick span that names a file this repo ships.
const PATH_SPAN = /`((?:\.\.\/)*[A-Za-z0-9_][\w.-]*(?:\/[\w.-]+)+\.(?:md|html|json|sh|mjs|py|tsx|ts))(?:#[^`]*)?`/g;

// ---------- 1–5: every skill ----------
let skillCount = 0;
for (const { dir: root, strict } of SKILL_DIRS) {
  for (const file of walk(root)) {
    if (!file.endsWith("SKILL.md")) continue;
    skillCount++;
    const rel = relative(REPO, file);
    const text = readFileSync(file, "utf8");
    const skillDir = dirname(file);

    const fm = frontmatter(text);
    if (!fm) { err(`${rel}: no YAML frontmatter`); continue; }

    for (const key of ["name", "description"]) {
      if (!(key in fm) || fm[key] === "" || fm[key] === "|" || fm[key] === ">-") {
        err(`${rel}: frontmatter is missing a non-empty \`${key}\``);
      }
    }
    if (fm.name && compareName(fm.name, skillDir) === false) {
      err(`${rel}: name "${fm.name}" does not match its directory "${basename(skillDir)}"`);
    }
    if (strict && fm.description) {
      const bytes = Buffer.byteLength(fm.description);
      if (bytes > DESCRIPTION_MAX) {
        err(`${rel}: description is ${bytes} B, over the ${DESCRIPTION_MAX} B budget`);
      }
    }
    // A description containing ": " unquoted breaks YAML; catch the plain form.
    if (fm.description && /^[^"'>|]/.test(fm.description) && fm.description.includes(": ")) {
      warn(`${rel}: description contains ": " unquoted; wrap it in quotes if a loader complains`);
    }

    // Path spans must resolve, relative to the skill directory (published only).
    if (strict) for (const span of text.matchAll(PATH_SPAN)) {
      const p = span[1];
      if (p.includes("<")) continue;
      if (!existsSync(join(skillDir, p))) {
        err(`${rel}: points at \`${p}\`, which does not exist relative to the skill`);
      }
    }

    // Inline spans that Claude Code's bash permission checker misreads.
    for (const span of inlineSpans(text)) {
      if (span.includes("!")) {
        err(`${rel}: inline backtick contains "!" ("${span}") — write the word instead`);
      }
      if (/>\w/.test(span)) {
        err(`${rel}: inline backtick contains ">word" ("${span}") — reads as output redirection`);
      }
    }

    // Shell scripts shipped with the skill.
    for (const f of walk(skillDir)) {
      if (!f.endsWith(".sh")) continue;
      const mode = statSync(f).mode;
      if (!(mode & 0o111)) warn(`${relative(REPO, f)}: not executable (chmod +x)`);
      try {
        execFileSync("bash", ["-n", f], { stdio: "pipe" });
      } catch (e) {
        err(`${relative(REPO, f)}: bash syntax error: ${String(e.stderr || e).split("\n")[0]}`);
      }
    }
  }
}

function basename(p) { return p.split("/").pop(); }
function compareName(name, dir) { return name === basename(dir); }

// ---------- 6: the two mirrors ----------
function hashTree(dir, base = dir, out = new Map()) {
  if (!existsSync(dir)) return out;
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, e.name);
    const rel = relative(base, full).split("\\").join("/");
    if (e.isDirectory()) hashTree(full, base, out);
    else if (e.isFile() && rel !== "README.md") {
      out.set(rel, createHash("sha256").update(readFileSync(full)).digest("hex"));
    }
  }
  return out;
}
const a = hashTree(join(REPO, ".claude", "skills"));
const b = hashTree(join(REPO, ".agents", "skills"));
for (const [k, v] of a) {
  if (!b.has(k)) err(`mirror: only in .claude/skills: ${k}`);
  else if (b.get(k) !== v) err(`mirror: content differs: ${k}`);
}
for (const k of b.keys()) if (!a.has(k)) err(`mirror: only in .agents/skills: ${k}`);

// ---------- 7: the published manifest is current ----------
try {
  execFileSync(process.execPath, [join(REPO, "scripts", "superframes-verify", "gen-manifest.mjs"), "--check"], { stdio: "pipe" });
} catch {
  warn("skills-manifest.json is stale; run node scripts/superframes-verify/gen-manifest.mjs");
}

// ---------- report ----------
for (const w of warnings) console.log(`WARN  ${w}`);
for (const e of errors) console.log(`FAIL  ${e}`);
console.log(
  errors.length === 0
    ? `✓ ${skillCount} SKILL.md files verified: frontmatter, names, descriptions, paths, scripts, mirror`
    : `✗ ${errors.length} problem(s) across ${skillCount} SKILL.md files`
);
process.exit(errors.length === 0 ? 0 : 1);
