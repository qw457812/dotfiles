#!/usr/bin/env node

import { createJiti } from "jiti";
import assert from "node:assert/strict";
import {
  chmodSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const jiti = createJiti(import.meta.url);
const { createJustBashOps } = await jiti.import("./just-bash-ops.ts");

const thisFilePath = fileURLToPath(import.meta.url);
const thisDirPath = dirname(thisFilePath);
const isTermux = process.platform === "android" || process.env.PREFIX?.includes("/com.termux/") === true;
const workdir = mkdtempSync(join(thisDirPath, ".tmp-workdir-"));
const extraWriteDir = mkdtempSync(join(thisDirPath, ".tmp-extra-write-"));
const blockedWritePath = join(thisDirPath, `.tmp-blocked-write-${process.pid}.txt`);
const hostBinSymlinkPath = join(thisDirPath, `.tmp-host-bin-link-${process.pid}`);
const defaultTmpWritePath = join(tmpdir(), `pi-sandbox-default-tmp-${process.pid}.txt`);
const ops = createJustBashOps(workdir, { filesystem: { allowWrite: [".", extraWriteDir] } });
const hostOps = createJustBashOps(workdir, {
  hostCommands: ["node"],
  filesystem: { allowWrite: [".", extraWriteDir] },
});
const pythonOps = createJustBashOps(workdir, {
  python: true,
  filesystem: { allowWrite: [".", extraWriteDir] },
});
const javascriptOps = createJustBashOps(workdir, {
  javascript: true,
  filesystem: { allowWrite: [".", extraWriteDir] },
});
const javascriptHostOps = createJustBashOps(workdir, {
  // `node` in hostCommands must win over the js-exec `node` stub.
  javascript: true,
  hostCommands: ["node"],
  filesystem: { allowWrite: [".", extraWriteDir] },
});

async function runWithOps(selectedOps, command, timeout = 5) {
  let output = "";
  const result = await selectedOps.exec(command, workdir, {
    onData: (chunk) => {
      output += chunk.toString("utf8");
    },
    timeout,
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
  const result = await hostOps.exec(command, workdir, {
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

  assert.deepEqual(await run(`printf '%s\n' "$HOME"`), {
    exitCode: 0,
    output: `${homedir()}\n`,
  });

  assert.deepEqual(await run(`printf '%s\n' "$TMPDIR"`), {
    exitCode: 0,
    output: `${tmpdir()}\n`,
  });

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

  const hostNode = await runWithOps(
    hostOps,
    `NODE_HOST_TEST=ok node -e "process.stdout.write((process.env.NODE_HOST_TEST || '') + ':' + process.cwd())"`,
  );
  assert.deepEqual(hostNode, { exitCode: 0, output: `ok:${workdir}` });

  const nodeCommandPath = await runWithOps(hostOps, "command -v node");
  assert.equal(nodeCommandPath.output, "/usr/bin/node\n");
  const nodeAbsolutePath = await runWithOps(
    hostOps,
    `$(command -v node) -e "process.stdout.write('absolute')"`,
  );
  assert.deepEqual(nodeAbsolutePath, { exitCode: 0, output: "absolute" });

  // KNOWN LIMITATION (just-bash): with DiD OFF (forced when host
  // commands are enabled), a command-prefix PATH override like
  // `PATH=<writable-dir> <host-cmd>` makes just-bash resolve the command
  // from that dir instead of dispatching to the registered custom command. The
  // resolved file is NOT spawned on the host: just-bash reads it, strips the
  // shebang, and interprets it as bash *inside the sandbox* (executeUserScript),
  // so writes still hit the read-only host FS (EROFS) and denyRead is enforced.
  // PATH shadowing adds no new read capability, only command confusion.
  // buildHostCommandEnv also ignores the shell PATH for the real spawn.
  // Mitigation: don't allow adversaries to write same-named executables into
  // PATH dirs.

  // Secret-shaped and proxy env vars must be stripped before reaching the
  // unsandboxed host child, otherwise an injected command could exfiltrate
  // them or reroute traffic through an attacker proxy. Use a probe file to
  // avoid quoting issues across the shell -> node boundary.
  const probePath = join(workdir, "env-probe.js");
  writeFileSync(
    probePath,
    'process.stdout.write(process.env.SECRET_API_KEY || process.env.HTTPS_PROXY || "CLEAN");',
  );
  const leakedSecret = await runWithOps(hostOps, `SECRET_API_KEY=leaked node ${probePath}`);
  assert.deepEqual(leakedSecret, { exitCode: 0, output: "CLEAN" });

  const leakedProxy = await runWithOps(
    hostOps,
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
  const leakedLocal = await runWithOps(hostOps, `FOO=leaked; node ${fooProbe}`);
  assert.deepEqual(leakedLocal, { exitCode: 0, output: "FOO=UNSET" });
  const prefixVar = await runWithOps(hostOps, `FOO=prefix node ${fooProbe}`);
  assert.deepEqual(prefixVar, { exitCode: 0, output: "FOO=prefix" });
  const exportedVar = await runWithOps(hostOps, `export FOO=x; node ${fooProbe}`);
  assert.deepEqual(exportedVar, { exitCode: 0, output: "FOO=x" });

  // The just-bash sandbox policy enforces denyRead / allowRead for sandboxed
  // virtual filesystem reads. Host commands remain an explicit escape hatch;
  // they are covered by a separate preflight seam, not by this virtual FS policy.
  const hostSecretPath = join(thisDirPath, `.tmp-host-secret-${process.pid}.txt`);
  const hostSecretDir = mkdtempSync(join(thisDirPath, ".tmp-host-secret-dir-"));
  const hostSecretDirFile = join(hostSecretDir, "secret.txt");
  const symlinkToHostSecretPath = join(workdir, "host-secret-link.txt");
  const deniedRootFileSymlinkPath = join(workdir, "deny-root-file-link.txt");
  const deniedRootDirSymlinkPath = join(workdir, "deny-root-dir-link");
  const allowRootFileSymlinkPath = join(workdir, "allow-root-file-link.txt");
  const allowedSymlinkDir = mkdtempSync(join(thisDirPath, ".tmp-allowed-link-dir-"));
  const allowedSymlinkToHostSecretPath = join(allowedSymlinkDir, "host-secret-link.txt");
  const deniedMoveSource = join(workdir, "denied-move-source.txt");
  const deniedMoveDest = join(workdir, "denied-move-dest.txt");
  const deniedCpDest = join(workdir, "denied-cp-dest.txt");
  const deniedLinkDest = join(workdir, "denied-link-dest.txt");
  const nestedSourceDir = mkdtempSync(join(workdir, "nested-source-"));
  const nestedDeniedChild = join(nestedSourceDir, "secret.txt");
  const nestedCpDest = join(workdir, "nested-cp-dest");
  const nestedMvDest = join(workdir, "nested-mv-dest");
  const cycleSourceDir = mkdtempSync(join(workdir, "cycle-source-"));
  const cycleSourceFile = join(cycleSourceDir, "file.txt");
  const cycleLinkPath = join(cycleSourceDir, "loop");
  const cycleCpDest = join(workdir, "cycle-cp-dest");
  const unreadableSourceDir = mkdtempSync(join(workdir, "unreadable-source-"));
  const unreadableChild = join(unreadableSourceDir, "secret.txt");
  const unreadableMvDest = join(workdir, "unreadable-mv-dest");
  writeFileSync(hostSecretPath, "HOST_ONLY_SECRET\n");
  writeFileSync(hostSecretDirFile, "DIR_SECRET\n");
  writeFileSync(deniedMoveSource, "MOVE_SECRET\n");
  writeFileSync(nestedDeniedChild, "NESTED_SECRET\n");
  writeFileSync(cycleSourceFile, "CYCLE_OK\n");
  writeFileSync(unreadableChild, "UNREADABLE_SECRET\n");
  symlinkSync(cycleSourceDir, cycleLinkPath);
  symlinkSync(hostSecretPath, deniedRootFileSymlinkPath);
  symlinkSync(hostSecretDir, deniedRootDirSymlinkPath);
  symlinkSync(hostSecretPath, allowRootFileSymlinkPath);
  try {
    const deniedReadOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [hostSecretPath] },
    });
    const deniedContentRead = await runWithOps(deniedReadOps, `cat ${hostSecretPath}`);
    assert.notEqual(deniedContentRead.exitCode, 0);
    assert.match(
      deniedContentRead.output,
      /EACCES: permission denied|Permission denied|No such file or directory/i,
    );

    // sandbox-runtime-compatible semantics: denyRead blocks direct reads and
    // metadata, but does not promise complete existence hiding.
    const deniedPathExists = await runWithOps(deniedReadOps, `test -e ${hostSecretPath}; echo $?`);
    assert.deepEqual(deniedPathExists, { exitCode: 0, output: "0\n" });

    const deniedStatRead = await runWithOps(deniedReadOps, `ls ${hostSecretPath}`);
    assert.notEqual(deniedStatRead.exitCode, 0);
    assert.match(
      deniedStatRead.output,
      /EACCES: permission denied|Permission denied|No such file or directory/i,
    );

    const deniedDirOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [hostSecretDir] },
    });
    const deniedDirRead = await runWithOps(deniedDirOps, `ls ${hostSecretDir}`);
    assert.notEqual(deniedDirRead.exitCode, 0);
    assert.match(
      deniedDirRead.output,
      /EACCES: permission denied|Permission denied|No such file or directory/i,
    );

    const deniedChildOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [hostSecretDirFile] },
    });
    const parentListingShowsDeniedChild = await runWithOps(deniedChildOps, `ls ${hostSecretDir}`);
    assert.equal(parentListingShowsDeniedChild.exitCode, 0);
    assert.match(parentListingShowsDeniedChild.output, /secret\.txt/);
    const directDeniedChildRead = await runWithOps(deniedChildOps, `cat ${hostSecretDirFile}`);
    assert.notEqual(directDeniedChildRead.exitCode, 0);

    const allowReadOps = createJustBashOps(workdir, {
      filesystem: {
        allowWrite: [".", extraWriteDir],
        denyRead: [thisDirPath],
        allowRead: [hostSecretPath],
      },
    });
    const allowedHostRead = await runWithOps(allowReadOps, `cat ${hostSecretPath}`);
    assert.deepEqual(allowedHostRead, { exitCode: 0, output: "HOST_ONLY_SECRET\n" });

    symlinkSync(hostSecretPath, symlinkToHostSecretPath);
    const deniedSymlinkRead = await runWithOps(deniedReadOps, `cat ${symlinkToHostSecretPath}`);
    assert.notEqual(deniedSymlinkRead.exitCode, 0);
    assert.match(
      deniedSymlinkRead.output,
      /EACCES: permission denied|Permission denied|No such file or directory/i,
    );

    const deniedSymlinkRootFileOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [deniedRootFileSymlinkPath] },
    });
    const deniedRealTargetViaSymlinkFileRoot = await runWithOps(
      deniedSymlinkRootFileOps,
      `cat ${hostSecretPath}`,
    );
    assert.notEqual(deniedRealTargetViaSymlinkFileRoot.exitCode, 0);

    const deniedSymlinkRootDirOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [deniedRootDirSymlinkPath] },
    });
    const deniedRealTargetViaSymlinkDirRoot = await runWithOps(
      deniedSymlinkRootDirOps,
      `cat ${hostSecretDirFile}`,
    );
    assert.notEqual(deniedRealTargetViaSymlinkDirRoot.exitCode, 0);

    const allowSymlinkRootOps = createJustBashOps(workdir, {
      filesystem: {
        allowWrite: [".", extraWriteDir],
        denyRead: [hostSecretPath],
        allowRead: [allowRootFileSymlinkPath],
      },
    });
    const allowedRealTargetViaSymlinkRoot = await runWithOps(
      allowSymlinkRootOps,
      `cat ${hostSecretPath}`,
    );
    assert.deepEqual(allowedRealTargetViaSymlinkRoot, {
      exitCode: 0,
      output: "HOST_ONLY_SECRET\n",
    });

    symlinkSync(hostSecretPath, allowedSymlinkToHostSecretPath);
    const allowedSymlinkOps = createJustBashOps(workdir, {
      filesystem: {
        allowWrite: [".", extraWriteDir],
        denyRead: [hostSecretPath],
        allowRead: [allowedSymlinkDir],
      },
    });
    const deniedAllowedSymlinkRead = await runWithOps(
      allowedSymlinkOps,
      `cat ${allowedSymlinkToHostSecretPath}`,
    );
    assert.notEqual(deniedAllowedSymlinkRead.exitCode, 0);
    assert.match(
      deniedAllowedSymlinkRead.output,
      /EACCES: permission denied|Permission denied|No such file or directory/i,
    );

    const allowedTargetSymlinkOps = createJustBashOps(workdir, {
      filesystem: {
        allowWrite: [".", extraWriteDir],
        denyRead: [hostSecretPath],
        allowRead: [allowedSymlinkDir, hostSecretPath],
      },
    });
    const allowedTargetSymlinkRead = await runWithOps(
      allowedTargetSymlinkOps,
      `cat ${allowedSymlinkToHostSecretPath}`,
    );
    assert.deepEqual(allowedTargetSymlinkRead, { exitCode: 0, output: "HOST_ONLY_SECRET\n" });

    const deniedWritableSourceOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [deniedMoveSource] },
    });
    const deniedCp = await runWithOps(
      deniedWritableSourceOps,
      `cp ${deniedMoveSource} ${deniedCpDest}`,
    );
    assert.notEqual(deniedCp.exitCode, 0);
    assert.equal(existsSync(deniedCpDest), false);

    const deniedMove = await runWithOps(
      deniedWritableSourceOps,
      `mv ${deniedMoveSource} ${deniedMoveDest}`,
    );
    assert.notEqual(deniedMove.exitCode, 0);
    assert.equal(readFileSync(deniedMoveSource, "utf8"), "MOVE_SECRET\n");
    assert.equal(existsSync(deniedMoveDest), false);

    const deniedLink = await runWithOps(
      deniedWritableSourceOps,
      `ln ${deniedMoveSource} ${deniedLinkDest}`,
    );
    assert.notEqual(deniedLink.exitCode, 0);
    assert.equal(existsSync(deniedLinkDest), false);

    const deniedNestedChildOps = createJustBashOps(workdir, {
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [nestedDeniedChild] },
    });
    const deniedRecursiveCp = await runWithOps(
      deniedNestedChildOps,
      `cp -r ${nestedSourceDir} ${nestedCpDest}`,
    );
    assert.notEqual(deniedRecursiveCp.exitCode, 0);
    assert.equal(existsSync(nestedCpDest), false);

    const deniedRecursiveMv = await runWithOps(
      deniedNestedChildOps,
      `mv ${nestedSourceDir} ${nestedMvDest}`,
    );
    assert.notEqual(deniedRecursiveMv.exitCode, 0);
    assert.equal(existsSync(nestedSourceDir), true);
    assert.equal(existsSync(nestedMvDest), false);

    const cycleSafeCp = await runWithOps(
      createJustBashOps(workdir, {
        filesystem: { allowWrite: [".", extraWriteDir], denyRead: [hostSecretPath] },
      }),
      `cp -r ${cycleSourceDir} ${cycleCpDest}`,
    );
    assert.equal(cycleSafeCp.exitCode, 0);
    assert.equal(existsSync(join(cycleCpDest, "file.txt")), true);

    // Android/Termux reports chmod(000) directories inconsistently enough that
    // this host-permission edge-case test can leave undeletable temp dirs.
    if (
      process.platform !== "win32" &&
      !isTermux &&
      process.getuid?.() !== 0
    ) {
      chmodSync(unreadableSourceDir, 0o000);
      const unreadableDirMv = await runWithOps(
        createJustBashOps(workdir, { filesystem: { allowWrite: [".", extraWriteDir] } }),
        `mv ${unreadableSourceDir} ${unreadableMvDest}`,
      );
      assert.notEqual(unreadableDirMv.exitCode, 0);
      assert.equal(existsSync(unreadableSourceDir), true);
      assert.equal(existsSync(unreadableMvDest), false);
      chmodSync(unreadableSourceDir, 0o700);
    }

    const hostEscapeProbe = join(workdir, "host-escape.js");
    writeFileSync(
      hostEscapeProbe,
      `import { readFileSync } from "node:fs"; process.stdout.write(readFileSync(${JSON.stringify(
        hostSecretPath,
      )}, "utf8"));`,
    );
    const hostEscapeOps = createJustBashOps(workdir, {
      hostCommands: ["node"],
      filesystem: { allowWrite: [".", extraWriteDir], denyRead: [hostSecretPath] },
    });
    const hostEscapeRead = await runWithOps(hostEscapeOps, `node ${hostEscapeProbe}`);
    assert.deepEqual(hostEscapeRead, { exitCode: 0, output: "HOST_ONLY_SECRET\n" });
  } finally {
    rmSync(hostSecretPath, { force: true });
    rmSync(hostSecretDir, { recursive: true, force: true });
    rmSync(allowedSymlinkDir, { recursive: true, force: true });
    rmSync(symlinkToHostSecretPath, { force: true });
    rmSync(deniedRootFileSymlinkPath, { force: true });
    rmSync(deniedRootDirSymlinkPath, { force: true });
    rmSync(allowRootFileSymlinkPath, { force: true });
    rmSync(deniedMoveSource, { force: true });
    rmSync(deniedMoveDest, { force: true });
    rmSync(deniedCpDest, { force: true });
    rmSync(deniedLinkDest, { force: true });
    for (const path of [unreadableSourceDir, unreadableMvDest]) {
      try {
        chmodSync(path, 0o700);
      } catch {
        // Best-effort cleanup: the directory may already be gone on platforms
        // where chmod/readdir semantics differ, and rmSync below is the boundary.
      }
    }
    rmSync(nestedSourceDir, { recursive: true, force: true });
    rmSync(nestedCpDest, { recursive: true, force: true });
    rmSync(nestedMvDest, { recursive: true, force: true });
    rmSync(cycleSourceDir, { recursive: true, force: true });
    rmSync(cycleCpDest, { recursive: true, force: true });
    rmSync(unreadableSourceDir, { recursive: true, force: true });
    rmSync(unreadableMvDest, { recursive: true, force: true });
  }

  // KNOWN LIMITATION (just-bash pipeline): non-UTF-8 binary stdout from a
  // host command is utf8-EXPANDED, not preserved byte-for-byte.
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
  // every builtin once host commands were enabled.
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

  // Regression: redirecting host command stdout (stdoutKind:"bytes") to a
  // file must preserve the original UTF-8 bytes, not mojibake them. just-bash's
  // redirect built-in passes the encoding ("binary" for host command bytes) as
  // the 3rd arg to fs.writeFile/appendFile; DenyFilteredFs previously dropped
  // that arg, so the backing ReadWriteFs defaulted to "utf8" and re-encodes the
  // latin1 byte string (U+00E2 carried from 0xE2) as UTF-8 (c3 a2), corrupting
  // every multibyte sequence. box-drawing ─ (e2 94 80) exercises the full chain.
  //
  // The ops must carry a denyRead entry: applyReadPathPolicy wraps the FS stack
  // with DenyFilteredFs only when denyRead/allowRead is non-empty, so a bare
  // hostOps config (no read policy) would skip the buggy wrapper and pass
  // against the unbuggy bare ReadWriteFs — a false green. The denied path is
  // arbitrary and non-existent; writes are unaffected because DenyFilteredFs
  // gates reads, not writes.
  const denyReadRedirectOps = createJustBashOps(workdir, {
    hostCommands: ["node"],
    filesystem: {
      allowWrite: [".", extraWriteDir],
      denyRead: [join(workdir, "denyread-noop")],
    },
  });
  const redirectProbe = join(workdir, "redirect-utf8-probe.js");
  writeFileSync(redirectProbe, "process.stdout.write(Buffer.from('─','utf8'));");
  const redirectFile = join(workdir, "redirect-utf8.out");
  const redirectResult = await runWithOps(denyReadRedirectOps, `node ${redirectProbe} > ${redirectFile}`);
  assert.equal(redirectResult.exitCode, 0);
  assert.deepEqual(Array.from(readFileSync(redirectFile)), [0xe2, 0x94, 0x80]);

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

  // --- WASM runtime opt-in: python / javascript ---------------------------------
  // Discovery is the right test level here, NOT execution. The WASM runtimes
  // (CPython Emscripten for python3, QuickJS for js-exec) are lazily loaded by
  // just-bash only on first *execution* — and cold-starting CPython WASM can
  // hang for minutes on constrained runtimes (e.g. Termux), so asserting on
  // real execution would make `npm run check` environment-flaky. Discovery
  // (`command -v`) exercises BOTH halves of the wiring without loading WASM:
  //   (1) the `python:true`/`javascript:true` option registers the command in
  //       just-bash's internal registry (via the `new Bash({...})` options),
  //   (2) the SAME option mirrors the command name into `virtualBinCommands`,
  //       which populates the VirtualBinFs stub under /usr/bin that PATH
  //       resolution requires (the registry-only fallback is skipped because
  //       this extension always mounts /usr/bin).
  // Missing either half -> `command -v` returns nothing. Upstream just-bash
  // already covers that a registered command actually executes.

  // Default-off: neither command is discoverable when its option is omitted.
  const pythonMissingByDefault = await run("command -v python3");
  assert.deepEqual(pythonMissingByDefault, { exitCode: 1, output: "" });
  const jsExecMissingByDefault = await run("command -v js-exec");
  assert.deepEqual(jsExecMissingByDefault, { exitCode: 1, output: "" });

  // Opt-in discovery: virtual command stubs appear under /usr/bin (and /bin).
  const python3Path = await runWithOps(pythonOps, "command -v python3");
  assert.deepEqual(python3Path, { exitCode: 0, output: "/usr/bin/python3\n" });
  const pythonAliasPath = await runWithOps(pythonOps, "command -v python");
  assert.deepEqual(pythonAliasPath, { exitCode: 0, output: "/usr/bin/python\n" });
  const jsExecPath = await runWithOps(javascriptOps, "command -v js-exec");
  assert.deepEqual(jsExecPath, { exitCode: 0, output: "/usr/bin/js-exec\n" });
  // `javascript: true` also registers a `node` stub that points to js-exec.
  const jsNodeStubPath = await runWithOps(javascriptOps, "command -v node");
  assert.deepEqual(jsNodeStubPath, { exitCode: 0, output: "/usr/bin/node\n" });

  // Precedence: when `node` is BOTH a js-exec stub AND a hostCommand, the host
  // process wins (customCommands registered last in just-bash's Bash ctor).
  // This dispatches to a real host spawn, never loading the QuickJS WASM, so it
  // stays fast and proves the stub is dormant rather than shadowing host node.
  const hostNodeWinsOverStub = await runWithOps(
    javascriptHostOps,
    `node -e "process.stdout.write('HOST')"`,
  );
  assert.deepEqual(hostNodeWinsOverStub, { exitCode: 0, output: "HOST" });

  console.log("✓ just-bash operations tests passed");
} finally {
  rmSync(workdir, { recursive: true, force: true });
  rmSync(extraWriteDir, { recursive: true, force: true });
  rmSync(blockedWritePath, { force: true });
  rmSync(hostBinSymlinkPath, { force: true });
  rmSync(defaultTmpWritePath, { force: true });
}
