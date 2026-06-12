#!/usr/bin/env node

import { createJiti } from "jiti";
import assert from "node:assert/strict";

const jiti = createJiti(import.meta.url);
const { createJustBashOps } = await jiti.import("./just-bash-ops.ts");

const ops = createJustBashOps(process.cwd(), undefined, { allowWrite: [".", "/tmp"] });

async function run(command) {
  let output = "";
  const result = await ops.exec(command, process.cwd(), {
    onData: (chunk) => {
      output += chunk.toString("utf8");
    },
    timeout: 5,
  });
  return { ...result, output };
}

assert.deepEqual(await run("echo 1 >/dev/null"), { exitCode: 0, output: "" });
assert.deepEqual(await run("echo x >/dev/dtracehelper"), { exitCode: 0, output: "" });
assert.deepEqual(await run("echo x >/dev/autofs_nowait"), { exitCode: 0, output: "" });
assert.deepEqual(await run("printf x > cp-src && cp cp-src /dev/null"), {
  exitCode: 0,
  output: "",
});

assert.deepEqual(await run("echo stdout >/dev/stdout"), {
  exitCode: 0,
  output: "stdout\n",
});
assert.deepEqual(await run("echo stderr >/dev/stderr"), {
  exitCode: 0,
  output: "stderr\n",
});

const awkStdoutFile = await run(`awk 'BEGIN { print "a"; print "b" > "/dev/stdout"; print "c" }'`);
assert.notEqual(awkStdoutFile.output, "a\nc\nb\n");
assert.equal(awkStdoutFile.exitCode, 2);
assert.match(awkStdoutFile.output, /EROFS: read-only file system, write '\/dev\/stdout'/);

console.log("✓ just-bash operations tests passed");
