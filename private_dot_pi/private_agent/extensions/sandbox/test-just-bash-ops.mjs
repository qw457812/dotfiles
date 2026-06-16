#!/usr/bin/env node

import { createJiti } from "jiti";
import assert from "node:assert/strict";
import { existsSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
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
const hostBinSymlinkPath = join(thisDirPath, `.tmp-host-bin-link-${process.pid}`);
const defaultTmpWritePath = join(tmpdir(), `pi-sandbox-default-tmp-${process.pid}.txt`);
const ops = createJustBashOps(workdir, { filesystem: { allowWrite: [".", extraWriteDir] } });
const passthroughOps = createJustBashOps(workdir, {
  dangerouslyPassthroughCommands: ["node"],
  filesystem: { allowWrite: [".", extraWriteDir] },
});

async function runWithOps(selectedOps, command) {
  let output = "";
  const result = await selectedOps.exec(command, workdir, {
    onData: (chunk) => {
      output += chunk.toString("utf8");
    },
    timeout: 5,
  });
  return { ...result, output };
}

async function run(command) {
  return runWithOps(ops, command);
}

async function runError(command) {
  try {
    const result = await run(command);
    return { result, error: null };
  } catch (error) {
    return { result: null, error };
  }
}

async function runBinary(command) {
  const chunks = [];
  const result = await passthroughOps.exec(command, workdir, {
    onData: (chunk) => {
      chunks.push(Buffer.from(chunk));
    },
    timeout: 5,
  });
  return { ...result, buffer: Buffer.concat(chunks) };
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

  const hostsRead = await run("head -n 1 /etc/hosts");
  assert.equal(hostsRead.exitCode, 0);
  assert.ok(hostsRead.output.length > 0);

  assert.deepEqual(await run("which ls"), { exitCode: 0, output: "/usr/bin/ls\n" });

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

  const missingNode = await run(`node -e "process.stdout.write('x')"`);
  assert.equal(missingNode.exitCode, 127);
  assert.match(missingNode.output, /command not found/);

  const passthroughNode = await runWithOps(
    passthroughOps,
    `NODE_PASSTHROUGH_TEST=ok node -e "process.stdout.write((process.env.NODE_PASSTHROUGH_TEST || '') + ':' + process.cwd())"`,
  );
  assert.deepEqual(passthroughNode, { exitCode: 0, output: `ok:${workdir}` });

  const nodeCommandPath = await runWithOps(passthroughOps, "command -v node");
  assert.equal(nodeCommandPath.output, "/usr/bin/node\n");
  const nodeAbsolutePath = await runWithOps(
    passthroughOps,
    `$(command -v node) -e "process.stdout.write('absolute')"`,
  );
  assert.deepEqual(nodeAbsolutePath, { exitCode: 0, output: "absolute" });

  // KNOWN LIMITATION (just-bash): with DiD OFF (forced when passthrough
  // commands are enabled), a command-prefix PATH override like
  // `PATH=<writable-dir> <passthrough-cmd>` makes just-bash resolve the command
  // from that dir instead of dispatching to the registered custom command. The
  // resolved file is NOT spawned on the host: just-bash reads it, strips the
  // shebang, and interprets it as bash *inside the sandbox* (executeUserScript),
  // so writes still hit the read-only host FS (EROFS). NOTE: just-bash's FS
  // does NOT enforce `denyRead`, so reads of host files are wide open for ANY
  // sandboxed command (builtin `cat` included) — PATH shadowing adds no new
  // read capability, only command confusion. buildHostCommandEnv also ignores
  // the shell PATH for the real spawn. Mitigation: don't allow adversaries to
  // write same-named executables into PATH dirs.

  // Secret-shaped and proxy env vars must be stripped before reaching the
  // unsandboxed host child, otherwise an injected command could exfiltrate
  // them or reroute traffic through an attacker proxy. Use a probe file to
  // avoid quoting issues across the shell -> node boundary.
  const probePath = join(workdir, "env-probe.js");
  writeFileSync(
    probePath,
    'process.stdout.write(process.env.SECRET_API_KEY || process.env.HTTPS_PROXY || "CLEAN");',
  );
  const leakedSecret = await runWithOps(passthroughOps, `SECRET_API_KEY=leaked node ${probePath}`);
  assert.deepEqual(leakedSecret, { exitCode: 0, output: "CLEAN" });

  const leakedProxy = await runWithOps(
    passthroughOps,
    `HTTPS_PROXY=http://evil.invalid node ${probePath}`,
  );
  assert.deepEqual(leakedProxy, { exitCode: 0, output: "CLEAN" });

  // Only EXPORTED shell variables and command-prefix assignments may reach the
  // host child — a non-exported shell local must NOT leak, since the child is
  // fully unsandboxed and bash itself would not forward it. buildHostCommandEnv
  // overlays ctx.exportedEnv (exported vars ∪ tempExportedVars), not the full
  // ctx.env table.
  const fooProbe = join(workdir, "env-foo.js");
  writeFileSync(fooProbe, 'process.stdout.write("FOO=" + (process.env.FOO || "UNSET"));');
  const leakedLocal = await runWithOps(passthroughOps, `FOO=leaked; node ${fooProbe}`);
  assert.deepEqual(leakedLocal, { exitCode: 0, output: "FOO=UNSET" });
  const prefixVar = await runWithOps(passthroughOps, `FOO=prefix node ${fooProbe}`);
  assert.deepEqual(prefixVar, { exitCode: 0, output: "FOO=prefix" });
  const exportedVar = await runWithOps(passthroughOps, `export FOO=x; node ${fooProbe}`);
  assert.deepEqual(exportedVar, { exitCode: 0, output: "FOO=x" });

  // KNOWN LIMITATION (pre-existing, just-bash path): createJustBashFs only
  // consumes `allowWrite`; config `denyRead` is NOT plumbed through, so the
  // read-only host FS lets ANY sandboxed command read arbitrary host files
  // (including ~/.ssh keys). This is independent of passthrough/PATH shadowing
  // — a plain builtin `cat` reads the same. Pin the gap here so a future fix
  // that enforces denyRead flips this assertion intentionally rather than by
  // accident.
  const hostSecretPath = join(thisDirPath, `.tmp-host-secret-${process.pid}.txt`);
  writeFileSync(hostSecretPath, "HOST_ONLY_SECRET\n");
  try {
    const hostRead = await run(`cat ${hostSecretPath}`);
    assert.equal(hostRead.exitCode, 0);
    assert.equal(hostRead.output, "HOST_ONLY_SECRET\n");
  } finally {
    rmSync(hostSecretPath, { force: true });
  }

  // KNOWN LIMITATION (just-bash pipeline): non-UTF-8 binary stdout from a
  // host passthrough command is utf8-EXPANDED, not preserved byte-for-byte.
  // just-bash carries output as a JS string, so raw bytes 0x80-0xFF pass
  // through logResult's decode (which falls back to the latin1 string when the
  // strict UTF-8 decode fails) and then Buffer.from(..., "utf8") re-encodes
  // each codepoint: 0xFF -> c3 bf, 0x80 -> c2 80, 0x00 -> 00. Valid UTF-8 and
  // ASCII round-trip fine; only raw binary is affected, which git/gh/node never
  // emit over stdout. Pin the expanded form so a future just-bash fix flips it
  // intentionally.
  const binaryProbe = join(workdir, "binary-probe.js");
  writeFileSync(binaryProbe, "process.stdout.write(Buffer.from([0x41, 0xFF, 0x80, 0x00, 0x42]));");
  const binaryOut = await runBinary(`node ${binaryProbe}`);
  assert.equal(binaryOut.exitCode, 0);
  assert.deepEqual(Array.from(binaryOut.buffer), [0x41, 0xc3, 0xbf, 0xc2, 0x80, 0x00, 0x42]);

  // Builtin output carrying a Latin-1-range codepoint (é = U+00E9) must render
  // as correct UTF-8 (c3 a9), not a lone latin1 byte (e9). This is the case a
  // logResult-bypass + codepoint-heuristic approach got wrong: é's charCode 233
  // is indistinguishable from byte 0xE9 by a >0xff test, so the heuristic
  // emitted 0xe9 (mojibake). Letting logResult's decode run (it throws on lone
  // 0xe9 and returns the original Unicode string) and UTF-8 encoding at the
  // boundary keeps it correct. Guards the Termux-wide regression that affected
  // every builtin once passthrough was enabled.
  const builtinTextOut = await runBinary(`printf 'café'`);
  assert.equal(builtinTextOut.exitCode, 0);
  assert.deepEqual(Array.from(builtinTextOut.buffer), [0x63, 0x61, 0x66, 0xc3, 0xa9]);

  // Host command output that is already valid UTF-8 (café = c3 a9) also
  // round-trips byte-for-byte: logResult decodes c3 a9 -> U+00E9, then the
  // boundary UTF-8 encode restores c3 a9.
  const latin1TextProbe = join(workdir, "latin1-text-probe.js");
  writeFileSync(latin1TextProbe, "process.stdout.write(Buffer.from('café','utf8'));");
  const latin1TextOut = await runBinary(`node ${latin1TextProbe}`);
  assert.equal(latin1TextOut.exitCode, 0);
  assert.deepEqual(Array.from(latin1TextOut.buffer), [0x63, 0x61, 0x66, 0xc3, 0xa9]);

  const awkStdoutFile = await run(
    `awk 'BEGIN { print "a"; print "b" > "/dev/stdout"; print "c" }'`,
  );
  assert.notEqual(awkStdoutFile.output, "a\nc\nb\n");
  assert.equal(awkStdoutFile.exitCode, 2);
  assert.match(awkStdoutFile.output, /EROFS: read-only file system, write '\/dev\/stdout'/);

  // Host files are generally readable, but host binaries under /bin and /usr/bin
  // are intentionally hidden behind virtual command-stub mounts. Symlinks that
  // resolve into those host bin dirs are hidden too.
  const virtualSh = await run("cat /bin/sh");
  assert.equal(virtualSh.exitCode, 0);
  assert.match(virtualSh.output, /just-bash virtual command stub: sh/);
  if (existsSync("/bin/sh")) {
    symlinkSync("/bin/sh", hostBinSymlinkPath);
    const hostBinSymlinkRead = await run(`cat ${hostBinSymlinkPath}`);
    assert.equal(hostBinSymlinkRead.exitCode, 1);
    assert.match(hostBinSymlinkRead.output, /No such file or directory/);
  }

  console.log("✓ just-bash operations tests passed");
} finally {
  rmSync(workdir, { recursive: true, force: true });
  rmSync(extraWriteDir, { recursive: true, force: true });
  rmSync(blockedWritePath, { force: true });
  rmSync(hostBinSymlinkPath, { force: true });
  rmSync(defaultTmpWritePath, { force: true });
}
