#!/usr/bin/env node
// Last observed header values, straight from the CLI's own request log.
//
// The CLI records a *fixed allowlist* of headers (LOGGABLE_HEADERS in
// dist/codebuddy.js: user-agent, x-domain, x-enterprise-id, x-product,
// x-request-id, x-user-id). Anything outside it is invisible here, so treat this
// output as evidence for those six and as no evidence at all for the rest.
//
// Usage: node read-cli-log.mjs [--lines N]
// Prints one JSON object per observed /v3/config request, newest last.

import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const linesWanted = (() => {
  const i = process.argv.indexOf("--lines");
  if (i === -1) return 20;
  const raw = process.argv[i + 1];
  const value = Number(raw);
  // `Number(undefined)` and `Number("abc")` are both NaN, and slice(-NaN) silently
  // means "everything", which would quietly invalidate a "I only read 20 lines" claim.
  if (!Number.isInteger(value) || value <= 0) {
    console.error(`--lines needs a positive integer, got ${raw === undefined ? "nothing" : JSON.stringify(raw)}`);
    process.exit(2);
  }
  return value;
})();

const logRoot = join(homedir(), ".codebuddy", "logs");

// A fresh machine or an isolated HOME (the ambient-credential run step 4 asks for) has
// no log directory at all; report that instead of letting readdirSync throw a raw ENOENT.
if (!existsSync(logRoot)) {
  console.error(`no CLI logs under ${logRoot}; run the CLI once first`);
  process.exit(1);
}

function logFiles() {
  const out = [];
  for (const day of readdirSync(logRoot, { withFileTypes: true })) {
    if (!day.isDirectory()) continue;
    const dir = join(logRoot, day.name);
    for (const file of readdirSync(dir, { withFileTypes: true })) {
      if (!file.isFile() || !file.name.endsWith(".log")) continue;
      const path = join(dir, file.name);
      out.push({ path, mtime: statSync(path).mtimeMs });
    }
  }
  return out.sort((a, b) => a.mtime - b.mtime).map((f) => f.path);
}

const files = logFiles();
if (files.length === 0) {
  console.error(`no CLI logs under ${logRoot}; run the CLI once first`);
  process.exit(1);
}

const pattern = /fetch cloud product request headers: (\{[^\n]*\})/g;
const rows = [];
for (const path of files) {
  const text = readFileSync(path, "utf8");
  for (const match of text.matchAll(pattern)) {
    try {
      rows.push({ source: path.split("/").slice(-2).join("/"), headers: JSON.parse(match[1]) });
    } catch (error) {
      // Corrupt evidence must not be reported as a clean read: a caller that sees exit 0
      // would treat the partial rows as the complete set of observed requests.
      console.error(`unparsable header line in ${path}: ${error.message}`);
      console.error(`  ${match[1].slice(0, 200)}`);
      process.exit(1);
    }
  }
}

if (rows.length === 0) {
  console.error("no 'fetch cloud product request headers' lines; the CLI has not synced config yet");
  process.exit(1);
}

for (const row of rows.slice(-linesWanted)) {
  console.log(JSON.stringify(row));
}
