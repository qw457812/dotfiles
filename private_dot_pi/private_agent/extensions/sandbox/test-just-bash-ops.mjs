#!/usr/bin/env node

import { createJiti } from "jiti";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const jiti = createJiti(import.meta.url);
const { createJustBashOps } = await jiti.import("./just-bash-ops.ts");

const thisFilePath = fileURLToPath(import.meta.url);
const thisDirPath = dirname(thisFilePath);
const workdir = mkdtempSync(join(thisDirPath, ".tmp-workdir-"));
const extraWriteDir = mkdtempSync(join(thisDirPath, ".tmp-extra-write-"));
const blockedWritePath = join(thisDirPath, `.tmp-blocked-write-${process.pid}.txt`);
const defaultTmpWritePath = join(tmpdir(), `pi-sandbox-default-tmp-${process.pid}.txt`);
const ops = createJustBashOps(workdir, undefined, { allowWrite: [".", extraWriteDir] });

async function run(command) {
  let output = "";
  const result = await ops.exec(command, workdir, {
    onData: (chunk) => {
      output += chunk.toString("utf8");
    },
    timeout: 5,
  });
  return { ...result, output };
}

async function runError(command) {
  try {
    const result = await run(command);
    return { result, error: null };
  } catch (error) {
    return { result: null, error };
  }
}

try {
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

  const outsideRead = await run(`head -n 1 ${thisFilePath}`);
  assert.equal(outsideRead.exitCode, 0);
  assert.equal(outsideRead.output, "#!/usr/bin/env node\n");

  const extraWritePath = join(extraWriteDir, "extra-write.txt");
  assert.deepEqual(await run(`printf extra > ${extraWritePath} && cat ${extraWritePath}`), {
    exitCode: 0,
    output: "extra",
  });
  assert.equal(readFileSync(extraWritePath, "utf8"), "extra");

  assert.deepEqual(await run(`printf tmp > ${defaultTmpWritePath} && cat ${defaultTmpWritePath}`), {
    exitCode: 0,
    output: "tmp",
  });
  assert.equal(readFileSync(defaultTmpWritePath, "utf8"), "tmp");

  const blockedWrite = await runError(`printf blocked > ${blockedWritePath}`);
  assert.equal(blockedWrite.result, null);
  assert.match(String(blockedWrite.error), /EROFS: read-only file system, write/);

  const awkStdoutFile = await run(
    `awk 'BEGIN { print "a"; print "b" > "/dev/stdout"; print "c" }'`,
  );
  assert.notEqual(awkStdoutFile.output, "a\nc\nb\n");
  assert.equal(awkStdoutFile.exitCode, 2);
  assert.match(awkStdoutFile.output, /EROFS: read-only file system, write '\/dev\/stdout'/);

  console.log("✓ just-bash operations tests passed");
} finally {
  rmSync(workdir, { recursive: true, force: true });
  rmSync(extraWriteDir, { recursive: true, force: true });
  rmSync(blockedWritePath, { force: true });
  rmSync(defaultTmpWritePath, { force: true });
}
