#!/usr/bin/env node
// gen-manifest.mjs — write (or --check) skills-manifest.json.
// Fingerprint = short sha256 over a skill's whole directory, text normalised CRLF→LF.
import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join, relative, sep, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const TEXT = new Set([".md",".txt",".mjs",".js",".ts",".jsx",".tsx",".html",".css",".json",".svg",".csv",".yml",".yaml",".sh"]);

function walk(dir, base, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true }).sort((x, y) => x.name.localeCompare(y.name))) {
    const full = join(dir, e.name);
    if (e.isDirectory()) walk(full, base, out);
    else if (e.isFile()) out.push(relative(base, full).split(sep).join("/"));
  }
  return out;
}

function fingerprint(dir) {
  const h = createHash("sha256");
  const files = walk(dir, dir);
  for (const rel of files) {
    h.update(rel); h.update("\0");
    const buf = readFileSync(join(dir, rel));
    const ext = rel.slice(rel.lastIndexOf("."));
    h.update(TEXT.has(ext) ? buf.toString("utf8").replace(/\r\n/g, "\n") : buf);
    h.update("\0");
  }
  return { hash: h.digest("hex").slice(0, 16), files: files.length };
}

const root = join(REPO, "skills");
const skills = {};
for (const name of readdirSync(root, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).sort()) {
  skills[name] = fingerprint(join(root, name));
}
const manifest = { source: "jamescai-md/superframes-edit", skills };
const out = join(REPO, "skills-manifest.json");

if (process.argv.includes("--check")) {
  const current = existsSync(out) ? readFileSync(out, "utf8") : "";
  const next = JSON.stringify(manifest, null, 2) + "\n";
  process.exit(current === next ? 0 : 1);
}
writeFileSync(out, JSON.stringify(manifest, null, 2) + "\n");
console.log(`wrote skills-manifest.json (${Object.keys(skills).length} skills)`);
