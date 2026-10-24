#!/usr/bin/env node
// Extract ground truth for a header or constant from the installed CLI bundle, so parity
// claims rest on the shipped code rather than on a summary of it that can go stale.
//
// Usage:
//   node dump-cli-source.mjs header X-Tenant-Id      # constant + every write site
//   node dump-cli-source.mjs symbol runIdentityHeaders
//   node dump-cli-source.mjs product                  # product.json facts
//
// Exit codes: 0 found, 1 CLI not installed, 2 nothing matched.

import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

function cliPackageDir() {
  const which = spawnSync("sh", ["-c", "command -v codebuddy"], { encoding: "utf8" });
  const bin = which.stdout?.trim();
  if (!bin) return undefined;
  const real = spawnSync("readlink", ["-f", bin], { encoding: "utf8" }).stdout?.trim();
  return real ? real.replace(/\/bin\/[^/]+$/, "") : undefined;
}

const pkgDir = cliPackageDir();
if (!pkgDir) {
  console.error("codebuddy CLI not found on PATH");
  process.exit(1);
}

const bundlePath = join(pkgDir, "dist", "codebuddy.js");
const productPath = join(pkgDir, "product.json");
const [mode, subject] = process.argv.slice(2);

function bundle() {
  if (!existsSync(bundlePath)) {
    console.error(`missing ${bundlePath}`);
    process.exit(1);
  }
  return readFileSync(bundlePath, "utf8");
}

function grep(text, pattern, window = 200) {
  const out = [];
  for (const match of text.matchAll(pattern)) {
    const start = Math.max(0, match.index - window);
    const end = Math.min(text.length, match.index + match[0].length + window);
    out.push(text.slice(start, end).replace(/\s+/g, " "));
  }
  return out;
}

function escapeRe(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

if (mode === "header") {
  if (!subject) {
    console.error("usage: dump-cli-source.mjs header <Header-Name>");
    process.exit(2);
  }
  const text = bundle();

  // The header name is defined once as a constant (`el.X="X-Name"`) and every write
  // refers to that constant, so resolve the identifier first, then search for it.
  const defs = grep(text, new RegExp(`[A-Za-z_$][\\w$]*="${escapeRe(subject)}"`, "g"), 40);
  const constant = new RegExp(`([A-Za-z_$][\\w$]*)="${escapeRe(subject)}"`).exec(text)?.[1];

  // All three write forms must be matched. Matching only `=` reports "never sent" for
  // headers that are always sent; matching only bracket forms misses every header
  // written through the helper.
  const writes = constant
    ? grep(
        text,
        new RegExp(
          String.raw`(?:\[\s*(?:[A-Za-z_$][\w$]*\.)?${constant}\s*\]\s*[=:]|setHeaderCaseInsensitive\([^,]+,\s*(?:[a-z]{2}\.)?${constant}\b)`,
          "g",
        ),
        180,
      )
    : [];

  if (!constant) {
    console.log(JSON.stringify({ constant: null, writeCount: 0, defs: [], writes: [] }, null, 1));
    process.exit(2);
  }

  console.log(JSON.stringify({ constant, writeCount: writes.length, defs, writes }, null, 1));
}

if (mode === "symbol") {
  if (!subject) {
    console.error("usage: dump-cli-source.mjs symbol <identifier>");
    process.exit(2);
  }
  const text = bundle();
  const hits = grep(text, new RegExp(`(?:function|const|let)\\s+${escapeRe(subject)}\\b`, "g"), 400);
  if (hits.length === 0) {
    console.error(`no definition of ${subject}`);
    process.exit(2);
  }
  for (const hit of hits.slice(0, 3)) console.log(`${hit}\n`);
}

if (mode === "product") {
  const facts = JSON.parse(readFileSync(productPath, "utf8"));
  console.log(
    JSON.stringify(
      {
        version: JSON.parse(readFileSync(join(pkgDir, "package.json"), "utf8")).version,
        platform: facts.platform,
        endpoint: facts.endpoint,
        officialEndpoints: facts.officialEndpoints,
        prefixPath: facts.authentication?.attributes?.prefixPath,
        attrPlatform: facts.authentication?.attributes?.platform ?? null,
      },
      null,
      1,
    ),
  );
}

if (!mode) {
  console.error("usage: dump-cli-source.mjs <header|symbol|product> [subject]");
  process.exit(2);
}
