#!/usr/bin/env node

import assert from "node:assert/strict";
import { homedir } from "node:os";
import path from "node:path";
import { createJiti } from "jiti";

const jiti = createJiti(import.meta.url);
const { matchExcludedCommand } = await jiti.import("./excluded-commands.ts");

const cwd = path.join(
  homedir(),
  ".pi",
  "agent",
  "git",
  "github.com",
  "mitsuhiko",
  "agent-stuff",
  "skills",
  "web-browser",
);
const scripts = path.join(cwd, "scripts");
const startScriptPattern =
  "~/.pi/agent/git/github.com/mitsuhiko/agent-stuff/skills/web-browser/scripts/start.js:*";
const navScriptPattern =
  "~/.pi/agent/git/github.com/mitsuhiko/agent-stuff/skills/web-browser/scripts/nav.js:*";
const evalScriptPattern =
  "~/.pi/agent/git/github.com/mitsuhiko/agent-stuff/skills/web-browser/scripts/eval.js:*";
const screenshotScriptPattern =
  "~/.pi/agent/git/github.com/mitsuhiko/agent-stuff/skills/web-browser/scripts/screenshot.js:*";
const patterns = [
  "gh:*",
  "docker:*",
  startScriptPattern,
  navScriptPattern,
  evalScriptPattern,
  screenshotScriptPattern,
];

async function match(command, extraPatterns = patterns, workdir = cwd) {
  return matchExcludedCommand(command, workdir, extraPatterns);
}

assert.equal((await match("gh repo view"))?.pattern, "gh:*");
assert.equal((await match("gh"))?.pattern, "gh:*");
assert.equal(await match("/opt/homebrew/bin/gh repo view"), null);
assert.equal(await match("./gh repo view"), null);
assert.equal(await match("/tmp/gh repo view"), null);
assert.equal((await match('"gh" repo view'))?.pattern, "gh:*");
assert.equal((await match("docker ps"))?.pattern, "docker:*");

assert.equal(
  (await match(`cd ${scripts} && ./nav.js https://example.org --new`))?.pattern,
  navScriptPattern,
);
assert.equal(
  (await match("./scripts/nav.js https://example.org --new"))?.pattern,
  navScriptPattern,
);
assert.equal(await match(`cd ${scripts} && ./evil.js https://example.org --new`), null);
assert.equal(await match("/tmp/skills/web-browser/scripts/nav.js https://example.org --new"), null);

assert.equal(await match("~/bin/gh repo view"), null);
assert.equal((await match("~/bin/gh repo view", ["~/bin/gh:*"]))?.pattern, "~/bin/gh:*");

assert.equal(await match("docker ps && curl https://example.com"), null);
assert.equal(await match("docker ps | tee out.txt"), null);
assert.equal(await match("gh repo view > out.txt"), null);
assert.equal(await match("gh repo view $(pwd)"), null);
assert.equal(await match('docker run "$IMAGE"'), null);
assert.equal(await match("NODE_ENV=test gh repo view"), null);
assert.equal(await match("BROWSER_BIN=/Applications/GoogleChrome.app ./scripts/start.js"), null);
assert.equal(await match("BROWSER_BIN=/tmp/evil ./scripts/start.js"), null);
assert.equal(
  (await match("BROWSER_DEBUG_PORT=9333 ./scripts/start.js"))?.pattern,
  startScriptPattern,
);
assert.equal(await match("BROWSER_DEBUG_PORT=0 ./scripts/start.js"), null);
assert.equal(await match("BROWSER_DEBUG_PORT=65536 ./scripts/start.js"), null);
assert.equal(await match("BROWSER_DEBUG_PORT=abc ./scripts/start.js"), null);
assert.equal(await match("BROWSER_DEBUG_PORT=9333 gh repo view"), null);
assert.equal(await match("BROWSER_BIN=$CHROME ./scripts/start.js"), null);
assert.equal(await match("BROWSER_BIN=`which chrome` ./scripts/start.js"), null);
assert.equal(await match("NODE_OPTIONS=--require=/tmp/hook.js ./scripts/start.js"), null);
assert.equal(await match("timeout 30 gh repo view"), null);
assert.equal(await match("cd $HOME/scripts && ./nav.js https://example.org"), null);
assert.equal(
  await match(`cd ${scripts} && ./nav.js https://example.org && curl https://example.com`),
  null,
);
assert.equal(
  (
    await match(
      `cd ${cwd} && ./scripts/nav.js https://example.com && ./scripts/eval.js 'document.title' && ./scripts/screenshot.js`,
    )
  )?.pattern,
  navScriptPattern,
);
assert.equal(
  await match(
    `cd ${cwd} && ./scripts/nav.js https://example.com && curl https://example.com && ./scripts/screenshot.js`,
  ),
  null,
);
assert.equal(
  (
    await match(
      `cd ${cwd} && ./scripts/eval.js '(() => { const form = document.querySelector("form"); if (!form) return "no-form"; form.submit(); return "submitted"; })()' && sleep 2 && ./scripts/eval.js '({title: document.title, href: location.href})'`,
    )
  )?.pattern,
  evalScriptPattern,
);
assert.equal(
  await match(
    `cd ${cwd} && ./scripts/eval.js 'document.title' && sleep 2s && ./scripts/eval.js 'location.href'`,
  ),
  null,
);
assert.equal(
  await match(
    `cd ${cwd} && ./scripts/eval.js 'document.title' && BROWSER_DEBUG_PORT=9333 sleep 2 && ./scripts/eval.js 'location.href'`,
  ),
  null,
);
assert.equal(
  await match(
    `cd ${cwd} && ./scripts/eval.js 'document.title' && sleep 61 && ./scripts/eval.js 'location.href'`,
  ),
  null,
);
assert.equal(await match("sleep 2"), null);

console.log("✓ excludedCommands matcher tests passed");
