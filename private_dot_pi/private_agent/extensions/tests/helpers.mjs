// Shared helpers for the no-model-call golden checks (see *-golden.mjs).
//
// Run any suite from the chezmoi source root:
//   node private_dot_pi/private_agent/extensions/tests/<name>-golden.mjs
//
// The suites load the mirror TypeScript modules through jiti (the one beside
// pi-coding-agent's install), so no transpile step or test runner is needed.
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));

/** Locate jiti beside pi's install (see the sync skill's verification recipe). */
function findJiti() {
  const require = createRequire(import.meta.url);
  try {
    return require.resolve("jiti/lib/jiti.mjs");
  } catch {
    // Not hoisted — walk up looking at pi-coding-agent's nested copy too.
  }
  let dir = here;
  for (let i = 0; i < 8; i++) {
    for (const candidate of [
      "node_modules/jiti/lib/jiti.mjs",
      "node_modules/@earendil-works/pi-coding-agent/node_modules/jiti/lib/jiti.mjs",
    ]) {
      const path = join(dir, candidate);
      if (existsSync(path)) return path;
    }
    dir = dirname(dir);
  }
  throw new Error("jiti not found — run npm install under private_dot_pi/private_agent first");
}

let jitiInstance;
/** Import a mirror TypeScript module relative to extensions/tests. */
export async function loadTs(relativePath) {
  jitiInstance ??= await import(pathToFileURL(findJiti())).then((m) =>
    m.createJiti(import.meta.url),
  );
  return jitiInstance.import(resolve(here, relativePath));
}

let failures = 0;

export function check(name, condition, detail) {
  if (condition) {
    console.log("ok  ", name);
  } else {
    failures++;
    console.log("FAIL", name, detail === undefined ? "" : `\n     ${JSON.stringify(detail)}`);
  }
}

export function equal(name, got, want) {
  check(name, Object.is(got, want), { got, want });
}

export function summary(label) {
  console.log(failures ? `${label}: ${failures} FAILURE(S)` : `${label}: all checks pass`);
  return failures;
}
