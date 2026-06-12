import type { BashOperations } from "@earendil-works/pi-coding-agent";
import {
  Bash,
  MountableFs,
  ReadWriteFs,
  unsafeBytesFromLatin1,
  type BufferEncoding,
  type ByteString,
  type CpOptions,
  type FileContent,
  type FsStat,
  type MkdirOptions,
  type NetworkConfig,
  type RmOptions,
} from "just-bash";
import { existsSync, promises as fsPromises, mkdirSync, statSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";

export interface JustBashConfig {
  /** Passed through verbatim to just-bash as trusted local NetworkConfig. */
  network?: NetworkConfig;
}

type JustBashFilesystemConfig = { allowWrite?: string[] } | undefined;

function createJustBashFs(
  policyRoot: string,
  filesystem: JustBashFilesystemConfig,
): ReadWriteFs | MountableFs {
  const writeRoots = coalesceWriteRoots(defaultAndConfiguredWriteRoots(policyRoot, filesystem));
  if (writeRoots.includes("/")) return new ReadWriteFs({ root: "/", allowSymlinks: false });

  const fs = new MountableFs({ base: new ReadOnlyHostFs() });
  for (const root of writeRoots) {
    if (isDiscardDevice(root)) {
      fs.mount(root, new DiscardDeviceFs());
      continue;
    }
    if (!ensureWritableDirectory(root)) continue;
    fs.mount(root, new ReadWriteFs({ root, allowSymlinks: false }));
  }
  return fs;
}

class DiscardDeviceFs {
  async readFile(
    path: string,
    _options?: BufferEncoding | { encoding?: BufferEncoding | null },
  ): Promise<string> {
    assertDevicePath(path, "open");
    return "";
  }

  async readFileBytes(path: string): Promise<ByteString> {
    assertDevicePath(path, "open");
    return unsafeBytesFromLatin1("");
  }

  async readFileBuffer(path: string): Promise<Uint8Array> {
    assertDevicePath(path, "open");
    return new Uint8Array();
  }

  async writeFile(path: string, _content: FileContent): Promise<void> {
    assertDevicePath(path, "write");
  }

  async appendFile(path: string, _content: FileContent): Promise<void> {
    assertDevicePath(path, "write");
  }

  async exists(path: string): Promise<boolean> {
    return isDeviceRoot(path);
  }

  async stat(path: string): Promise<FsStat> {
    assertDevicePath(path, "stat");
    return deviceStat();
  }

  async lstat(path: string): Promise<FsStat> {
    return this.stat(path);
  }

  async mkdir(path: string, _options?: MkdirOptions): Promise<void> {
    assertDevicePath(path, "mkdir");
    throw notDirectoryError("mkdir", path);
  }

  async readdir(path: string): Promise<string[]> {
    assertDevicePath(path, "scandir");
    throw notDirectoryError("scandir", path);
  }

  async rm(path: string, _options?: RmOptions): Promise<void> {
    assertDevicePath(path, "rm");
    throw readOnlyFsError("rm", path);
  }

  async cp(src: string, _dest: string, _options?: CpOptions): Promise<void> {
    assertDevicePath(src, "cp");
    throw readOnlyFsError("cp", src);
  }

  async mv(src: string, _dest: string): Promise<void> {
    assertDevicePath(src, "mv");
    throw readOnlyFsError("mv", src);
  }

  resolvePath(base: string, path: string): string {
    return resolve(base, path);
  }

  getAllPaths(): string[] {
    return ["/"];
  }

  async chmod(path: string, _mode: number): Promise<void> {
    assertDevicePath(path, "chmod");
  }

  async symlink(_target: string, linkPath: string): Promise<void> {
    throw readOnlyFsError("symlink", linkPath);
  }

  async link(existingPath: string, _newPath: string): Promise<void> {
    assertDevicePath(existingPath, "link");
    throw readOnlyFsError("link", existingPath);
  }

  async readlink(path: string): Promise<string> {
    assertDevicePath(path, "readlink");
    throw invalidArgumentError("readlink", path);
  }

  async realpath(path: string): Promise<string> {
    assertDevicePath(path, "realpath");
    return "/";
  }

  async utimes(path: string, _atime: Date, _mtime: Date): Promise<void> {
    assertDevicePath(path, "utimes");
  }
}

class ReadOnlyHostFs {
  async readFile(
    path: string,
    options?: BufferEncoding | { encoding?: BufferEncoding | null },
  ): Promise<string> {
    const buffer = await fsPromises.readFile(resolve(path));
    const encoding = typeof options === "string" ? options : (options?.encoding ?? "utf8");
    return Buffer.from(buffer).toString(encoding ?? "utf8");
  }

  async readFileBytes(path: string): Promise<ByteString> {
    const buffer = await fsPromises.readFile(resolve(path));
    return unsafeBytesFromLatin1(Buffer.from(buffer).toString("latin1"));
  }

  async readFileBuffer(path: string): Promise<Uint8Array> {
    return fsPromises.readFile(resolve(path));
  }

  async writeFile(path: string, _content: FileContent): Promise<void> {
    throw readOnlyFsError("write", path);
  }

  async appendFile(path: string, _content: FileContent): Promise<void> {
    throw readOnlyFsError("write", path);
  }

  async exists(path: string): Promise<boolean> {
    try {
      await fsPromises.access(resolve(path));
      return true;
    } catch {
      return false;
    }
  }

  async stat(path: string): Promise<FsStat> {
    return toFsStat(await fsPromises.stat(resolve(path)));
  }

  async lstat(path: string): Promise<FsStat> {
    return toFsStat(await fsPromises.lstat(resolve(path)));
  }

  async mkdir(path: string, _options?: MkdirOptions): Promise<void> {
    throw readOnlyFsError("mkdir", path);
  }

  async readdir(path: string): Promise<string[]> {
    return fsPromises.readdir(resolve(path));
  }

  async rm(path: string, _options?: RmOptions): Promise<void> {
    throw readOnlyFsError("rm", path);
  }

  async cp(src: string, _dest: string, _options?: CpOptions): Promise<void> {
    throw readOnlyFsError("cp", src);
  }

  async mv(src: string, _dest: string): Promise<void> {
    throw readOnlyFsError("mv", src);
  }

  resolvePath(base: string, path: string): string {
    return resolve(base, path);
  }

  getAllPaths(): string[] {
    return [];
  }

  async chmod(path: string, _mode: number): Promise<void> {
    throw readOnlyFsError("chmod", path);
  }

  async symlink(_target: string, linkPath: string): Promise<void> {
    throw readOnlyFsError("symlink", linkPath);
  }

  async link(existingPath: string, _newPath: string): Promise<void> {
    throw readOnlyFsError("link", existingPath);
  }

  async readlink(path: string): Promise<string> {
    return fsPromises.readlink(resolve(path));
  }

  async realpath(path: string): Promise<string> {
    return fsPromises.realpath(resolve(path));
  }

  async utimes(path: string, _atime: Date, _mtime: Date): Promise<void> {
    throw readOnlyFsError("utimes", path);
  }
}

function toFsStat(stat: Awaited<ReturnType<typeof fsPromises.stat>>): FsStat {
  return {
    isFile: stat.isFile(),
    isDirectory: stat.isDirectory(),
    isSymbolicLink: stat.isSymbolicLink(),
    mode: Number(stat.mode),
    size: Number(stat.size),
    mtime: stat.mtime,
  };
}

function readOnlyFsError(operation: string, target: string): Error {
  const error = new Error(
    `EROFS: read-only file system, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EROFS";
  return error;
}

function notDirectoryError(operation: string, target: string): Error {
  const error = new Error(
    `ENOTDIR: not a directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "ENOTDIR";
  return error;
}

function noSuchFileError(operation: string, target: string): Error {
  const error = new Error(
    `ENOENT: no such file or directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "ENOENT";
  return error;
}

function invalidArgumentError(operation: string, target: string): Error {
  const error = new Error(
    `EINVAL: invalid argument, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EINVAL";
  return error;
}

function isDeviceRoot(path: string): boolean {
  return resolve("/", path) === "/";
}

function assertDevicePath(path: string, operation: string): void {
  if (!isDeviceRoot(path)) {
    throw noSuchFileError(operation, path);
  }
}

function deviceStat(): FsStat {
  return {
    isFile: true,
    isDirectory: false,
    isSymbolicLink: false,
    mode: 0o666,
    size: 0,
    mtime: new Date(),
  };
}

function isDiscardDevice(root: string): boolean {
  return root === "/dev/null" || root === "/dev/dtracehelper" || root === "/dev/autofs_nowait";
}

function defaultAndConfiguredWriteRoots(
  policyRoot: string,
  filesystem: JustBashFilesystemConfig,
): string[] {
  return [
    // Keep Termux just-bash write defaults aligned with sandbox-runtime's recommended paths.
    // Source: https://github.com/anthropic-experimental/sandbox-runtime/blob/d455fb453e41d32323fbf13d73bfe017bfa52d8a/src/sandbox/sandbox-utils.ts#L278
    "/dev/stdout",
    "/dev/stderr",
    "/dev/null",
    "/dev/tty",
    "/dev/dtracehelper",
    "/dev/autofs_nowait",
    "/tmp/claude",
    "/private/tmp/claude",
    join(homedir(), ".npm/_logs"),
    join(homedir(), ".claude/debug"),
    process.env.TMPDIR ?? tmpdir(),
    ...(process.env.TMPDIR === undefined || process.env.TMPDIR === tmpdir() ? [] : [tmpdir()]),
    ...(filesystem?.allowWrite ?? []),
  ]
    .map((entry) => normalizeWriteRoot(policyRoot, entry))
    .filter((entry): entry is string => entry !== null);
}

function normalizeWriteRoot(policyRoot: string, entry: string): string | null {
  let value = entry.trim();
  if (value.length === 0) return null;
  if (value.endsWith("/**")) value = value.slice(0, -3);
  if (containsGlobChars(value)) return null;
  if (value === "~") value = homedir();
  else if (value.startsWith("~/")) value = join(homedir(), value.slice(2));
  else if (!isAbsolute(value)) value = resolve(policyRoot, value);
  return resolve(value);
}

function containsGlobChars(value: string): boolean {
  return /[*?[\]]/.test(value);
}

function coalesceWriteRoots(roots: string[]): string[] {
  const sorted = Array.from(new Set(roots)).sort((a, b) => a.length - b.length);
  const kept: string[] = [];
  for (const root of sorted) {
    if (kept.some((existing) => pathWithinRoot(existing, root))) continue;
    kept.push(root);
  }
  return kept;
}

function pathWithinRoot(root: string, target: string): boolean {
  const rel = relative(root, target);
  return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

function ensureWritableDirectory(root: string): boolean {
  try {
    if (existsSync(root)) return statSync(root).isDirectory();
    mkdirSync(root, { recursive: true });
    return statSync(root).isDirectory();
  } catch {
    return false;
  }
}

export function createJustBashOps(
  root: string,
  network: NetworkConfig | undefined,
  filesystem: JustBashFilesystemConfig,
): BashOperations {
  const policyRoot = resolve(root);
  return {
    async exec(command, cwd, { onData, signal, timeout, env }) {
      if (!existsSync(policyRoot)) {
        throw new Error(
          `Working directory does not exist: ${policyRoot}\nCannot execute bash commands.`,
        );
      }

      const virtualCwd = resolve(cwd);
      if (!existsSync(cwd)) {
        throw new Error(`Working directory does not exist: ${cwd}\nCannot execute bash commands.`);
      }
      if (signal?.aborted) {
        throw new Error("aborted");
      }

      const controller = new AbortController();
      const onAbort = () => controller.abort(signal?.reason);
      if (signal) {
        if (signal.aborted) controller.abort(signal.reason);
        else signal.addEventListener("abort", onAbort, { once: true });
      }

      let timedOut = false;
      const timeoutHandle =
        timeout !== undefined && timeout > 0
          ? setTimeout(() => {
              timedOut = true;
              controller.abort(new Error(`timeout:${timeout}`));
            }, timeout * 1000)
          : undefined;

      try {
        const fs = createJustBashFs(policyRoot, filesystem);
        const bash = new Bash({
          fs,
          cwd: virtualCwd,
          ...(env !== undefined ? { env: toStringEnv(env) } : {}),
          ...(network !== undefined ? { network } : {}),
        });
        const result = await bash.exec(command, { signal: controller.signal });
        if (result.stdout.length > 0) onData(Buffer.from(result.stdout, "utf8"));
        if (result.stderr.length > 0) onData(Buffer.from(result.stderr, "utf8"));
        if (signal?.aborted) throw new Error("aborted");
        if (timedOut) throw new Error(`timeout:${timeout}`);
        return { exitCode: result.exitCode };
      } catch (err) {
        if (signal?.aborted) throw new Error("aborted");
        if (timedOut) throw new Error(`timeout:${timeout}`);
        throw err;
      } finally {
        if (timeoutHandle) clearTimeout(timeoutHandle);
        signal?.removeEventListener("abort", onAbort);
      }
    },
  };
}

function toStringEnv(env: NodeJS.ProcessEnv): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(env)) {
    if (typeof value === "string") out[key] = value;
  }
  // With host-wide read access, forwarding Termux's real PATH makes just-bash
  // discover host ELF binaries and try to parse them as shell scripts. Keep the
  // rest of the environment intact, but force command lookup to just-bash's
  // built-ins and virtual commands.
  out.PATH = "/__just_bash_no_host_bins__";
  return out;
}

export function formatAllowedUrlPrefixes(
  entries: NetworkConfig["allowedUrlPrefixes"] | undefined,
): string {
  if (!Array.isArray(entries) || entries.length === 0) return "(none)";
  return entries
    .map((entry) => {
      if (typeof entry === "string") return entry;
      return entry.url;
    })
    .join(", ");
}
