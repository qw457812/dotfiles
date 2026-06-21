#!/usr/bin/env node

import assert from "node:assert/strict";
import { createJiti } from "jiti";

const jiti = createJiti(import.meta.url);
const { DEFAULT_CONFIG, deepMerge, resolveBackend, effectiveExcludedCommands } =
  await jiti.import("./index.ts");

// --- DEFAULT_CONFIG ----------------------------------------------------------

// Regression guard (P1): the justBash backend MUST default to cwd write access,
// otherwise every file write on Termux/Android throws EROFS. test-just-bash-ops.mjs
// passes an explicit filesystem and so CANNOT catch this — only DEFAULT_CONFIG can.
assert.ok(
  DEFAULT_CONFIG.justBash?.filesystem?.allowWrite?.includes("."),
  "DEFAULT_CONFIG.justBash.filesystem.allowWrite includes '.'",
);
assert.ok(
  DEFAULT_CONFIG.justBash?.filesystem?.allowWrite?.includes("/tmp"),
  "DEFAULT_CONFIG.justBash.filesystem.allowWrite includes '/tmp'",
);
assert.ok(
  DEFAULT_CONFIG.justBash?.filesystem?.denyRead?.includes("~/.ssh"),
  "DEFAULT_CONFIG.justBash.filesystem.denyRead includes '~/.ssh'",
);
assert.ok(
  DEFAULT_CONFIG.justBash?.filesystem?.denyRead?.includes("~/.aws"),
  "DEFAULT_CONFIG.justBash.filesystem.denyRead includes '~/.aws'",
);
assert.ok(
  DEFAULT_CONFIG.justBash?.filesystem?.denyRead?.includes("~/.gnupg"),
  "DEFAULT_CONFIG.justBash.filesystem.denyRead includes '~/.gnupg'",
);
assert.equal(DEFAULT_CONFIG.enabled, true);
// backend is intentionally unset — auto-resolved via isTermux().
assert.equal(DEFAULT_CONFIG.backend, undefined);
assert.ok(
  Array.isArray(DEFAULT_CONFIG.sandboxRuntime?.network?.allowedDomains) &&
    DEFAULT_CONFIG.sandboxRuntime.network.allowedDomains.includes("github.com"),
  "DEFAULT sandboxRuntime.network.allowedDomains present",
);

// --- deepMerge -------------------------------------------------------------

// Nested network merge is field-by-field: DEFAULT allowedDomains preserved,
// override deniedDomains replaces the DEFAULT [].
{
  const merged = deepMerge(
    {
      sandboxRuntime: {
        network: { allowedDomains: ["a.com"], deniedDomains: [] },
        filesystem: { allowWrite: ["."] },
      },
    },
    { sandboxRuntime: { network: { deniedDomains: ["evil.com"] } } },
  );
  assert.deepEqual(merged.sandboxRuntime.network, {
    allowedDomains: ["a.com"],
    deniedDomains: ["evil.com"],
  });
  assert.deepEqual(merged.sandboxRuntime.filesystem.allowWrite, ["."]);
}

// justBash block merges independently of sandboxRuntime.
{
  const merged = deepMerge(
    { justBash: { hostCommands: ["git"] } },
    { justBash: { excludedCommands: ["bash checkout.sh:*"] } },
  );
  assert.deepEqual(merged.justBash.hostCommands, ["git"]);
  assert.deepEqual(merged.justBash.excludedCommands, ["bash checkout.sh:*"]);
}

// backend / enabled / top-level excludedCommands are replaced wholesale.
{
  const merged = deepMerge(
    { backend: "sandboxRuntime", excludedCommands: ["a"] },
    { backend: "justBash", excludedCommands: ["b"] },
  );
  assert.equal(merged.backend, "justBash");
  assert.deepEqual(merged.excludedCommands, ["b"]);
}

// justBash.filesystem merges field-by-field: override allowWrite replaces the
// DEFAULT list, while a DEFAULT justBash block is never dropped entirely.
{
  const merged = deepMerge(DEFAULT_CONFIG, {
    justBash: { filesystem: { allowWrite: ["~/projects"] } },
  });
  // The P1 default ("." and "/tmp") is REPLACED, not concatenated — array merge
  // is wholesale. Callers who customize allowWrite must re-include "." if they
  // still want cwd writes.
  assert.deepEqual(merged.justBash.filesystem.allowWrite, ["~/projects"]);
  assert.deepEqual(merged.justBash.filesystem.denyRead, ["~/.ssh", "~/.aws", "~/.gnupg"]);
}

// justBash.filesystem denyRead / allowRead merge field-by-field.
{
  const merged = deepMerge(DEFAULT_CONFIG, {
    justBash: { filesystem: { allowRead: ["~/.ssh/known_hosts"] } },
  });
  assert.deepEqual(merged.justBash.filesystem.allowWrite, [".", "/tmp"]);
  assert.deepEqual(merged.justBash.filesystem.denyRead, ["~/.ssh", "~/.aws", "~/.gnupg"]);
  assert.deepEqual(merged.justBash.filesystem.allowRead, ["~/.ssh/known_hosts"]);
}

// --- resolveBackend --------------------------------------------------------

assert.equal(resolveBackend({ backend: "justBash" }), "justBash");
assert.equal(resolveBackend({ backend: "sandboxRuntime" }), "sandboxRuntime");
{
  // auto falls back to platform: justBash on Termux/Android, sandboxRuntime otherwise.
  const isTermux =
    process.platform === "android" || (process.env.PREFIX ?? "").includes("/com.termux/");
  assert.equal(resolveBackend({}), isTermux ? "justBash" : "sandboxRuntime");
  assert.equal(resolveBackend({ backend: undefined }), isTermux ? "justBash" : "sandboxRuntime");
}

// --- effectiveExcludedCommands --------------------------------------------

// Shared (top-level) ∪ backend-specific.
{
  const config = {
    excludedCommands: ["gh:*", "docker:*"],
    justBash: { excludedCommands: ["bash checkout.sh:*"] },
  };
  assert.deepEqual(effectiveExcludedCommands(config, "justBash"), [
    "gh:*",
    "docker:*",
    "bash checkout.sh:*",
  ]);
  // sandboxRuntime backend only sees the shared list.
  assert.deepEqual(effectiveExcludedCommands(config, "sandboxRuntime"), ["gh:*", "docker:*"]);
}

// Dedup when the same pattern appears in both shared and backend-specific.
{
  const config = {
    excludedCommands: ["gh:*"],
    sandboxRuntime: { excludedCommands: ["gh:*", "docker:*"] },
  };
  assert.deepEqual(effectiveExcludedCommands(config, "sandboxRuntime"), ["gh:*", "docker:*"]);
}

// Empty when neither is set.
{
  assert.deepEqual(effectiveExcludedCommands({}, "justBash"), []);
  assert.deepEqual(effectiveExcludedCommands({ excludedCommands: [] }, "sandboxRuntime"), []);
}

console.log("✓ config (schema split + backend resolution) tests passed");
