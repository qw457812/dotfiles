import type { BashOperations } from "@earendil-works/pi-coding-agent";
import {
  Bash,
  MountableFs,
  ReadWriteFs,
  getCommandNames,
  getJavaScriptCommandNames,
  getNetworkCommandNames,
  getPythonCommandNames,
  latin1FromBytes,
  unsafeBytesFromLatin1,
  type BufferEncoding,
  type ByteString,
  type Command,
  type ExecResult,
  type CpOptions,
  type FileContent,
  type FsStat,
  type JavaScriptConfig,
  type MkdirOptions,
  type NetworkConfig,
  type RmOptions,
} from "just-bash";
import { existsSync, promises as fsPromises, mkdirSync, realpathSync, statSync } from "node:fs";
import { createRequire } from "node:module";
import { homedir, tmpdir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";

const require = createRequire(import.meta.url);
const { spawn } = require("node:child_process") as typeof import("node:child_process");

export interface JustBashFilesystemConfig {
  /** Write roots plumbed into just-bash's virtual filesystem (MountableFs mounts). */
  allowWrite?: string[];
  /** Read roots whose contents and direct metadata access are denied. */
  denyRead?: string[];
  /** Read roots that override denyRead for content and direct metadata access. */
  allowRead?: string[];
}

export interface JustBashConfig {
  /** Passed through verbatim to just-bash as trusted local NetworkConfig. */
  network?: NetworkConfig;
  /**
   * Filesystem policy for the just-bash sandbox backend. `allowWrite` is
   * plumbed into MountableFs as writable roots; `denyRead` / `allowRead` deny
   * content reads and direct metadata access. Existing configured read roots
   * are matched by both their normalized path and realpath alias. They
   * intentionally do not promise complete existence hiding, matching
   * sandbox-runtime's practical semantics. The rest of the writable defaults —
   * /dev devices, TMPDIR, ~/.npm/_logs, etc. — are supplied by
   * defaultAndConfiguredWriteRoots() inside this module.
   */
  filesystem?: JustBashFilesystemConfig;
  /**
   * Enable the sandboxed `python3`/`python` commands (CPython 3.13 compiled to
   * WASM via Emscripten). Runs ENTIRELY inside just-bash's WASM sandbox: file
   * access goes through the same MountableFs (host read-only outside the
   * configured write roots) and network through the configured NetworkConfig.
   * No host process is spawned. Introduces a CPython WASM runtime security
   * surface, hence opt-in; see just-bash's THREAT_MODEL.md §4.7.
   *
   * Precedence: if a python command name is ALSO in `hostCommands`, the host
   * process wins (customCommands are registered last in just-bash's Bash
   * constructor), so the WASM runtime only takes effect for names NOT claimed
   * by hostCommands.
   */
  python?: boolean;
  /**
   * Enable the sandboxed `js-exec` command (QuickJS WASM) for JavaScript /
   * TypeScript. Runs inside just-bash's WASM sandbox under the same FS/network
   * policy as `python`. A `node` *stub* is registered alongside it that prints
   * a pointer to `js-exec`; if `node` is ALSO in `hostCommands`, the host
   * process wins (customCommands registered last), so the stub is dormant.
   *
   * Note: QuickJS js-exec is NOT a Node.js toolchain — no `node_modules`
   * resolution, no native addons, no `npm install`. For project build tools
   * (tsc/vitest/npm scripts) keep the host command in `hostCommands`.
   */
  javascript?: boolean | JavaScriptConfig;
  /**
   * Escape hatch for commands that just-bash does not implement (for example `git`).
   * These run as REAL HOST PROCESSES via spawn(): they bypass just-bash's
   * filesystem and network restrictions entirely. Any listed command grants
   * full unsandboxed code execution on the host (e.g. `node -e` or `git` with
   * hooks/config/`ext::` transports), so treat the list as a deliberate escape
   * hatch, not a convenience. The child env is scrubbed (proxy and
   * secret-shaped vars removed) and PATH is forced to the host PATH.
   * NOTE: enabling any host command also disables just-bash
   * `defenseInDepth` for that Bash instance (currently required to work
   * around a just-bash bug where command-prefix assignments trigger a DiD
   * violation). Prefer a short explicit allow-list.
   */
  hostCommands?: string[];
}

const JUST_BASH_VIRTUAL_SYSTEM_PATH = "/usr/bin:/bin";

// Env vars that just-bash/shell manage and that must never be forwarded as-is
// to a host child: they describe the *virtual* shell, not the real host cwd/dir.
const HOST_ENV_BLOCKLIST = new Set(["OLDPWD", "PWD", "SHLVL", "_"]);

// Proxy env vars that can redirect host child network traffic. Strip them so a
// host command cannot be pointed at an attacker-controlled proxy by the
// host environment. (Mirrors code-yeongyu/pi-sandbox's PROXY_KEYS set.)
const HOST_ENV_PROXY_BLOCKLIST = new Set([
  "HTTP_PROXY",
  "HTTPS_PROXY",
  "ALL_PROXY",
  "NO_PROXY",
  "http_proxy",
  "https_proxy",
  "all_proxy",
  "no_proxy",
  "npm_config_proxy",
  "npm_config_https_proxy",
]);

// Host env var names that commonly hold secrets (API keys, tokens, cloud creds).
// Host commands run fully unsandboxed, so leaking these lets an injected
// command exfiltrate them over the network. (Pattern adapted from code-yeongyu/pi-sandbox.)
const HOST_ENV_SECRET_PATTERN =
  /(_KEY|_TOKEN|_SECRET|_PASSWORD|_PASSWD|^SSH_AUTH_SOCK$|^AWS_.+|^GCP_.+|^GOOGLE_APPLICATION_CREDENTIALS$)/i;

function createJustBashFs(
  policyRoot: string,
  filesystem: JustBashFilesystemConfig | undefined,
  virtualBinCommands: string[],
) {
  const writeRoots = coalesceWriteRoots(defaultAndConfiguredWriteRoots(policyRoot, filesystem));
  const readPolicy = createReadPathPolicy(policyRoot, filesystem);
  if (writeRoots.includes("/")) {
    return applyReadPathPolicy(new ReadWriteFs({ root: "/", allowSymlinks: false }), readPolicy);
  }

  const fs = new MountableFs({ base: new ReadOnlyHostFs() });
  const virtualBinFs = new VirtualBinFs(virtualBinCommands);
  fs.mount("/usr/bin", virtualBinFs);
  fs.mount("/bin", virtualBinFs);
  for (const root of writeRoots) {
    if (isDiscardDevice(root)) {
      fs.mount(root, new DiscardDeviceFs());
      continue;
    }
    if (!ensureWritableDirectory(root)) continue;
    fs.mount(root, new ReadWriteFs({ root, allowSymlinks: false }));
  }
  return applyReadPathPolicy(fs, readPolicy);
}

interface ReadPathPolicy {
  allowRead: string[];
  denyRead: string[];
}

function createReadPathPolicy(
  policyRoot: string,
  filesystem: JustBashFilesystemConfig | undefined,
): ReadPathPolicy {
  return {
    allowRead: normalizeReadRoots(policyRoot, filesystem?.allowRead),
    denyRead: normalizeReadRoots(policyRoot, filesystem?.denyRead),
  };
}

function normalizeReadRoots(policyRoot: string, entries: string[] | undefined): string[] {
  if (!Array.isArray(entries)) return [];
  return Array.from(
    new Set(entries.flatMap((entry) => normalizeReadRootAliases(policyRoot, entry))),
  );
}

function normalizeReadRootAliases(policyRoot: string, entry: string): string[] {
  const normalized = normalizeWriteRoot(policyRoot, entry);
  if (normalized === null) return [];

  try {
    const real = realpathSync(normalized);
    return real === normalized ? [normalized] : [normalized, real];
  } catch (err) {
    if (isExpectedMissingPathError(err)) return [normalized];
    throw err;
  }
}

function applyReadPathPolicy<T extends ReadWriteFs | MountableFs>(
  fs: T,
  policy: ReadPathPolicy,
): T | DenyFilteredFs {
  if (policy.allowRead.length === 0 && policy.denyRead.length === 0) return fs;
  return new DenyFilteredFs(fs, policy);
}

class DenyFilteredFs {
  constructor(
    private readonly inner: ReadWriteFs | MountableFs,
    private readonly policy: ReadPathPolicy,
  ) {}

  async readFile(
    path: string,
    options?: BufferEncoding | { encoding?: BufferEncoding | null },
  ): Promise<string> {
    await this.assertReadable(path, "open");
    return this.inner.readFile(path, options);
  }

  async readFileBytes(path: string): Promise<ByteString> {
    await this.assertReadable(path, "open");
    return this.inner.readFileBytes(path);
  }

  async readFileBuffer(path: string): Promise<Uint8Array> {
    await this.assertReadable(path, "open");
    return this.inner.readFileBuffer(path);
  }

  async writeFile(path: string, content: FileContent): Promise<void> {
    return this.inner.writeFile(path, content);
  }

  async appendFile(path: string, content: FileContent): Promise<void> {
    return this.inner.appendFile(path, content);
  }

  async exists(path: string): Promise<boolean> {
    // sandbox-runtime does not fully hide denied path existence across backends.
    // Keep exists() observable and enforce denyRead at direct metadata/content
    // calls such as stat/readFile instead.
    return this.inner.exists(path);
  }

  async stat(path: string): Promise<FsStat> {
    await this.assertReadable(path, "stat");
    return this.inner.stat(path);
  }

  async lstat(path: string): Promise<FsStat> {
    await this.assertReadable(path, "lstat");
    return this.inner.lstat(path);
  }

  async mkdir(path: string, options?: MkdirOptions): Promise<void> {
    return this.inner.mkdir(path, options);
  }

  async readdir(path: string): Promise<string[]> {
    await this.assertReadable(path, "scandir");
    // Parent directory listings intentionally remain unfiltered: denyRead
    // blocks direct reads/metadata for denied children, but does not promise
    // full filename hiding.
    return this.inner.readdir(path);
  }

  async rm(path: string, options?: RmOptions): Promise<void> {
    return this.inner.rm(path, options);
  }

  async cp(src: string, dest: string, options?: CpOptions): Promise<void> {
    await this.assertReadableTree(src, "cp");
    return this.inner.cp(src, dest, options);
  }

  async mv(src: string, dest: string): Promise<void> {
    await this.assertReadableTree(src, "rename");
    return this.inner.mv(src, dest);
  }

  resolvePath(base: string, path: string): string {
    return this.inner.resolvePath(base, path);
  }

  getAllPaths(): string[] {
    return this.inner
      .getAllPaths()
      .filter((path) => !isReadDeniedByPath(resolve(path), this.policy));
  }

  async chmod(path: string, mode: number): Promise<void> {
    return this.inner.chmod(path, mode);
  }

  async symlink(target: string, linkPath: string): Promise<void> {
    return this.inner.symlink(target, linkPath);
  }

  async link(existingPath: string, newPath: string): Promise<void> {
    await this.assertReadable(existingPath, "link");
    return this.inner.link(existingPath, newPath);
  }

  async readlink(path: string): Promise<string> {
    await this.assertReadable(path, "readlink");
    return this.inner.readlink(path);
  }

  async realpath(path: string): Promise<string> {
    await this.assertReadable(path, "realpath");
    return this.inner.realpath(path);
  }

  async utimes(path: string, atime: Date, mtime: Date): Promise<void> {
    return this.inner.utimes(path, atime, mtime);
  }

  private async assertReadable(
    path: string,
    operation: string,
  ): Promise<{ requested: string; real: string | null }> {
    const requested = resolve(path);
    let real: string | null = null;
    try {
      real = await fsPromises.realpath(requested);
    } catch (err) {
      if (!isExpectedMissingPathError(err)) throw err;
      // The requested path may not exist yet. Fall back to policy matching the
      // requested path; the wrapped filesystem will report the real error.
    }

    if (isReadDeniedByRequestAndRealPath(requested, real, this.policy)) {
      throw permissionDeniedError(operation, path);
    }

    return { requested, real };
  }

  private async assertReadableTree(
    path: string,
    operation: string,
    seen = new Set<string>(),
  ): Promise<void> {
    const { requested, real } = await this.assertReadable(path, operation);

    const seenKey = real ?? requested;
    if (seen.has(seenKey)) return;
    seen.add(seenKey);

    const stat = await this.inner.stat(path);
    if (!stat.isDirectory) return;

    const entries = await this.inner.readdir(path);
    for (const entry of entries) {
      await this.assertReadableTree(join(path, entry), operation, seen);
    }
  }
}

function isReadDeniedByRequestAndRealPath(
  requested: string,
  real: string | null,
  policy: ReadPathPolicy,
): boolean {
  if (isReadDeniedByPath(requested, policy)) return true;
  // A symlink/request-path allowRead must not override denyRead on the real
  // target. The real target needs its own allowRead match.
  return real !== null && real !== requested && isReadDeniedByPath(real, policy);
}

function isReadDeniedByPath(path: string, policy: ReadPathPolicy): boolean {
  if (policy.allowRead.some((root) => pathWithinRoot(root, path))) return false;
  return policy.denyRead.some((root) => pathWithinRoot(root, path));
}

function isExpectedMissingPathError(err: unknown): boolean {
  const code = (err as NodeJS.ErrnoException | undefined)?.code;
  return code === "ENOENT" || code === "ENOTDIR";
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

class VirtualBinFs {
  private readonly commands: Set<string>;
  private readonly sortedCommands: string[];

  constructor(commandNames: string[]) {
    this.sortedCommands = Array.from(new Set(commandNames)).sort();
    this.commands = new Set(this.sortedCommands);
  }

  async readFile(
    path: string,
    options?: BufferEncoding | { encoding?: BufferEncoding | null },
  ): Promise<string> {
    const buffer = await this.readFileBuffer(path);
    const encoding = typeof options === "string" ? options : (options?.encoding ?? "utf8");
    return Buffer.from(buffer).toString(encoding ?? "utf8");
  }

  async readFileBytes(path: string): Promise<ByteString> {
    const buffer = await this.readFileBuffer(path);
    return unsafeBytesFromLatin1(Buffer.from(buffer).toString("latin1"));
  }

  async readFileBuffer(path: string): Promise<Uint8Array> {
    const commandName = this.commandNameForPath(path);
    if (!commandName) {
      if (isDeviceRoot(path)) throw isDirectoryError("read", path);
      throw noSuchFileError("open", path);
    }
    return Buffer.from(`# just-bash virtual command stub: ${commandName}\n`, "utf8");
  }

  async writeFile(path: string, _content: FileContent): Promise<void> {
    throw readOnlyFsError("write", path);
  }

  async appendFile(path: string, _content: FileContent): Promise<void> {
    throw readOnlyFsError("write", path);
  }

  async exists(path: string): Promise<boolean> {
    return isDeviceRoot(path) || this.commandNameForPath(path) !== null;
  }

  async stat(path: string): Promise<FsStat> {
    if (isDeviceRoot(path)) return directoryStat();
    const commandName = this.commandNameForPath(path);
    if (commandName) return virtualCommandStat(commandName);
    throw noSuchFileError("stat", path);
  }

  async lstat(path: string): Promise<FsStat> {
    return this.stat(path);
  }

  async mkdir(path: string, options?: MkdirOptions): Promise<void> {
    if (isDeviceRoot(path) && options?.recursive) return;
    throw readOnlyFsError("mkdir", path);
  }

  async readdir(path: string): Promise<string[]> {
    if (!isDeviceRoot(path)) throw notDirectoryError("scandir", path);
    // Copy: shared across /usr/bin and /bin mounts — don't let consumers mutate it.
    return [...this.sortedCommands];
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
    return ["/", ...this.sortedCommands.map((command) => `/${command}`)];
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
    if (!isDeviceRoot(path) && !this.commandNameForPath(path)) {
      throw noSuchFileError("readlink", path);
    }
    throw invalidArgumentError("readlink", path);
  }

  async realpath(path: string): Promise<string> {
    if (isDeviceRoot(path) || this.commandNameForPath(path)) return resolve("/", path);
    throw noSuchFileError("realpath", path);
  }

  async utimes(path: string, _atime: Date, _mtime: Date): Promise<void> {
    throw readOnlyFsError("utimes", path);
  }

  private commandNameForPath(path: string): string | null {
    const normalized = resolve("/", path);
    if (normalized === "/") return null;
    const commandName = normalized.slice(1);
    if (commandName.includes("/")) return null;
    return this.commands.has(commandName) ? commandName : null;
  }
}

// just-bash treats /usr/bin and /bin specially during command resolution:
// commands found in those system PATH dirs dispatch to the registered command
// implementation, while commands found elsewhere are interpreted as user
// scripts. Exposing the real host /usr/bin would make PATH resolution see host
// ELF/Mach-O binaries; hiding it entirely makes `command -v git` return a path
// that cannot be executed. Mount virtual stub directories instead: registered
// commands are discoverable at stable system paths, but host binaries are never
// read from /usr/bin or /bin.
//
// Ref (permalink, v3.0.x @ 9481331):
// https://github.com/vercel-labs/just-bash/blob/9481331f54fdcbfa1b81b313d756cd7f541d7018/packages/just-bash/src/interpreter/command-resolution.ts#L154-L163
const HIDDEN_HOST_BIN_DIRS = hiddenHostBinDirs(["/usr/bin", "/bin"]);

function hiddenHostBinDirs(dirs: string[]): string[] {
  const hidden = new Set<string>();
  for (const dir of dirs) {
    const resolved = resolve(dir);
    hidden.add(resolved);
    try {
      hidden.add(realpathSync(resolved));
    } catch {
      // Directory may not exist on every platform (for example /usr on Termux).
    }
  }
  return Array.from(hidden);
}

function isHostBinPath(path: string): boolean {
  const p = resolve(path);
  return HIDDEN_HOST_BIN_DIRS.some((dir) => p === dir || p.startsWith(`${dir}/`));
}

async function resolvesToHostBinPath(path: string): Promise<boolean> {
  if (isHostBinPath(path)) return true;
  try {
    return isHostBinPath(await fsPromises.realpath(resolve(path)));
  } catch {
    return false;
  }
}

class ReadOnlyHostFs {
  async readFile(
    path: string,
    options?: BufferEncoding | { encoding?: BufferEncoding | null },
  ): Promise<string> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("open", path);
    const buffer = await fsPromises.readFile(resolve(path));
    const encoding = typeof options === "string" ? options : (options?.encoding ?? "utf8");
    return Buffer.from(buffer).toString(encoding ?? "utf8");
  }

  async readFileBytes(path: string): Promise<ByteString> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("open", path);
    const buffer = await fsPromises.readFile(resolve(path));
    return unsafeBytesFromLatin1(Buffer.from(buffer).toString("latin1"));
  }

  async readFileBuffer(path: string): Promise<Uint8Array> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("open", path);
    return fsPromises.readFile(resolve(path));
  }

  async writeFile(path: string, _content: FileContent): Promise<void> {
    throw readOnlyFsError("write", path);
  }

  async appendFile(path: string, _content: FileContent): Promise<void> {
    throw readOnlyFsError("write", path);
  }

  async exists(path: string): Promise<boolean> {
    if (await resolvesToHostBinPath(path)) return false;
    try {
      await fsPromises.access(resolve(path));
      return true;
    } catch {
      return false;
    }
  }

  async stat(path: string): Promise<FsStat> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("stat", path);
    return toFsStat(await fsPromises.stat(resolve(path)));
  }

  async lstat(path: string): Promise<FsStat> {
    if (isHostBinPath(path)) throw noSuchFileError("lstat", path);
    return toFsStat(await fsPromises.lstat(resolve(path)));
  }

  async mkdir(path: string, _options?: MkdirOptions): Promise<void> {
    throw readOnlyFsError("mkdir", path);
  }

  async readdir(path: string): Promise<string[]> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("scandir", path);
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
    if (isHostBinPath(path)) throw noSuchFileError("readlink", path);
    return fsPromises.readlink(resolve(path));
  }

  async realpath(path: string): Promise<string> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("realpath", path);
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

function isDirectoryError(operation: string, target: string): Error {
  const error = new Error(
    `EISDIR: illegal operation on a directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EISDIR";
  return error;
}

function noSuchFileError(operation: string, target: string): Error {
  const error = new Error(
    `ENOENT: no such file or directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "ENOENT";
  return error;
}

function permissionDeniedError(operation: string, target: string): Error {
  const error = new Error(
    `EACCES: permission denied, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EACCES";
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

function directoryStat(): FsStat {
  return {
    isFile: false,
    isDirectory: true,
    isSymbolicLink: false,
    mode: 0o555,
    size: 0,
    mtime: new Date(),
  };
}

function virtualCommandStat(commandName: string): FsStat {
  return {
    isFile: true,
    isDirectory: false,
    isSymbolicLink: false,
    mode: 0o555,
    size: Buffer.byteLength(`# just-bash virtual command stub: ${commandName}\n`, "utf8"),
    mtime: new Date(),
  };
}

function isDiscardDevice(root: string): boolean {
  return root === "/dev/null" || root === "/dev/dtracehelper" || root === "/dev/autofs_nowait";
}

function defaultAndConfiguredWriteRoots(
  policyRoot: string,
  filesystem: JustBashFilesystemConfig | undefined,
): string[] {
  return [
    // Keep just-bash write defaults aligned with sandbox-runtime's recommended paths.
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

function normalizeHostCommands(entries: JustBashConfig["hostCommands"]): string[] {
  if (!Array.isArray(entries)) return [];
  return Array.from(
    new Set(
      entries
        .filter((entry): entry is string => typeof entry === "string")
        .map((entry) => entry.trim())
        .filter((entry) => entry.length > 0 && isBareCommandName(entry)),
    ),
  );
}

// A bare command name: alphanumeric with optional internal `.`, `-`, `_`
// separators — never leading/trailing punctuation and never pure punctuation.
// Rejects ".", "..", "---", ".git", "123." etc. (not real binaries; they would
// only fail at spawn or collide with shell forms like `.`/`source`). The
// charset still bans path separators and shell metacharacters. All real
// command names (node, git, npm, python3.11, gcc-13, 7z, 2to3, ...) pass.
function isBareCommandName(value: string): boolean {
  return /^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$/.test(value);
}

function createHostCommands(commandNames: string[]): Command[] {
  return commandNames.map((commandName) => ({
    name: commandName,
    trusted: true,
    async execute(args, ctx) {
      // Pass ctx.exportedEnv (NOT ctx.env): a real host child must inherit only
      // the shell's EXPORTED variables plus command-prefix assignments, matching
      // bash semantics. just-bash's ctx.env is the full variable table, so using
      // it would leak non-exported shell locals (e.g. `FOO=bar; cmd` without
      // `export`) to the unsandboxed host process. ctx.exportedEnv is the union
      // of permanently exported vars and tempExportedVars (prefix assignments),
      // built by the interpreter's buildExportedEnv().
      return executeHostCommand(commandName, args, ctx.cwd, ctx.exportedEnv, ctx.stdin, ctx.signal);
    },
  }));
}

function isUnsafeHostEnvKey(key: string): boolean {
  return (
    HOST_ENV_BLOCKLIST.has(key) ||
    HOST_ENV_PROXY_BLOCKLIST.has(key) ||
    HOST_ENV_SECRET_PATTERN.test(key)
  );
}

function buildHostCommandEnv(
  exportedEnv: Readonly<Record<string, string>> | undefined,
  cwd: string,
): NodeJS.ProcessEnv {
  // Start from the host environment but drop proxy/secret keys: host
  // commands run fully unsandboxed, so forwarding secrets would let an injected
  // command exfiltrate them, and forwarding a proxy var would let it reroute
  // traffic to an attacker-controlled host.
  const out: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (value === undefined || isUnsafeHostEnvKey(key)) continue;
    out[key] = value;
  }

  // Overlay the shell's EXPORTED variables only. This mirrors bash child-process
  // inheritance: permanently exported vars plus command-prefix assignments
  // (just-bash tracks the latter as tempExportedVars and includes them in
  // ctx.exportedEnv). Overlaying the full ctx.env instead would leak
  // non-exported shell locals to the real host process. PATH is forced to the
  // host PATH below regardless, so a shell PATH override cannot drive host
  // binary resolution (it must not point at just-bash's virtual bin dir).
  for (const [key, value] of Object.entries(exportedEnv ?? {})) {
    if (isUnsafeHostEnvKey(key)) continue;
    out[key] = value;
  }

  out.PATH = process.env.PATH;
  out.PWD = cwd;
  if (out.GIT_PAGER === undefined) out.GIT_PAGER = "cat";
  if (out.PAGER === undefined) out.PAGER = "cat";
  return out;
}

async function executeHostCommand(
  commandName: string,
  args: string[],
  cwd: string,
  env: Readonly<Record<string, string>> | undefined,
  stdin: ByteString,
  signal?: AbortSignal,
): Promise<ExecResult> {
  return new Promise((resolve) => {
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    let settled = false;

    const finish = (result: ExecResult) => {
      if (settled) return;
      settled = true;
      signal?.removeEventListener("abort", onAbort);
      resolve(result);
    };

    const child = spawn(commandName, args, {
      cwd,
      env: buildHostCommandEnv(env, cwd),
      detached: process.platform !== "win32",
      stdio: ["pipe", "pipe", "pipe"],
    });

    const killChild = () => {
      if (!child.pid) return;
      if (process.platform !== "win32") {
        try {
          process.kill(-child.pid, "SIGKILL");
          return;
        } catch {
          // Fall through to direct child kill.
        }
      }
      child.kill("SIGKILL");
    };

    const onAbort = () => {
      killChild();
    };

    if (signal) {
      if (signal.aborted) onAbort();
      else signal.addEventListener("abort", onAbort, { once: true });
    }

    child.stdout?.on("data", (chunk) => {
      stdoutChunks.push(Buffer.from(chunk));
    });
    child.stderr?.on("data", (chunk) => {
      stderrChunks.push(Buffer.from(chunk));
    });

    child.on("error", (error) => {
      const errno = error as NodeJS.ErrnoException;
      finish({
        stdout: "",
        stderr:
          errno.code === "ENOENT"
            ? `bash: ${commandName}: command not found\n`
            : `bash: ${commandName}: ${error instanceof Error ? error.message : String(error)}\n`,
        exitCode: errno.code === "ENOENT" ? 127 : 1,
      });
    });

    child.on("close", (code) => {
      finish({
        // Carry raw bytes through as a latin1 byte buffer (stdoutKind: "bytes")
        // so binary output (git cat-file --batch, gzipped blobs, ...) survives
        // the just-bash pipeline instead of being mojibake'd by a UTF-8 decode
        // here. Bash.exec() re-decodes valid UTF-8 at its output boundary;
        // invalid UTF-8 stays byte-clean through to onData.
        stdout: Buffer.concat(stdoutChunks).toString("latin1"),
        stderr: Buffer.concat(stderrChunks).toString("latin1"),
        exitCode: code ?? (signal?.aborted ? 130 : 1),
        stdoutKind: "bytes",
        stdoutEncoding: "binary",
      });
    });

    // A child that exits before reading stdin (e.g. `git apply` on a bad patch,
    // or `gh` ignoring piped input) will close the write end and emit EPIPE on
    // the still-pending write. Without a listener Node would crash the process
    // with an uncaught 'error' event; swallow it as an expected condition.
    child.stdin?.on("error", () => {});
    child.stdin?.end(Buffer.from(latin1FromBytes(stdin), "latin1"));
  });
}

export function createJustBashOps(
  root: string,
  config: JustBashConfig | undefined,
): BashOperations {
  const policyRoot = resolve(root);
  const filesystem = config?.filesystem;
  const hostCommandNames = normalizeHostCommands(config?.hostCommands);
  const hostCommands = createHostCommands(hostCommandNames);
  // Command discovery is two-layered: (1) just-bash's Bash constructor only
  // registers a command in its internal registry when its option is set
  // (python/javascript/network/custom), and (2) THIS extension overrides
  // /usr/bin and /bin with a VirtualBinFs whose readdir/exists/stat are driven
  // solely by this list. Because VirtualBinFs always mounts /usr/bin, just-bash's
  // registry-only fallback (command-resolution.ts, taken when /usr/bin is
  // absent) NEVER runs here — so a command missing from virtualBinCommands is
  // invisible even if it is registered. Therefore every opt-in command set must
  // be mirrored into virtualBinCommands with the SAME condition as the
  // `new Bash({...})` call below.
  const virtualBinCommands = Array.from(
    new Set([
      ...getCommandNames(),
      ...(config?.network !== undefined ? getNetworkCommandNames() : []),
      ...(config?.python === true ? getPythonCommandNames() : []),
      ...(config?.javascript ? getJavaScriptCommandNames() : []),
      ...hostCommandNames,
    ]),
  );

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
        const fs = createJustBashFs(policyRoot, filesystem, virtualBinCommands);
        const bash = new Bash({
          fs,
          cwd: virtualCwd,
          ...(env !== undefined ? { env: toStringEnv(env) } : {}),
          ...(config?.network !== undefined ? { network: config.network } : {}),
          ...(config?.python === true ? { python: true } : {}),
          ...(config?.javascript ? { javascript: config.javascript } : {}),
          ...(hostCommands.length > 0
            ? {
                customCommands: hostCommands,
                // defenseInDepth is disabled for this Bash instance because of
                // a just-bash 3.x bug: with DiD ON, *any* command-prefix
                // assignment (`VAR=value cmd ...`, including builtins) trips a
                // `dynamic import of Node.js builtin 'node:module'` violation.
                // That breaks the common `GIT_AUTHOR_NAME=... git commit`
                // idiom, so DiD must be off whenever host commands are
                // registered. (The import is just-bash's own ESM-loader hook
                // used to enforce DiD; see its defense-in-depth-box.ts.)
                //
                // NOTE on PATH shadowing: with DiD OFF, just-bash resolves
                // commands via PATH *before* dispatching to custom commands.
                // `PATH=<writable-dir> <host-cmd>` can therefore resolve
                // to a same-named file in that dir instead of the registered
                // command. That file is NOT executed on the host — just-bash
                // reads it, strips the shebang, and interprets it as bash
                // *inside the sandbox* (executeUserScript). It is NOT spawned
                // on the host, so it cannot bypass the read-only host FS
                // (writes still throw EROFS) or the network policy. denyRead
                // is still enforced by DenyFilteredFs for sandboxed commands,
                // so PATH shadowing does not bypass the just-bash read policy;
                // the only effect is that the host command silently runs
                // a sandboxed same-named script instead of the host binary.
                // buildHostCommandEnv ignores the shell PATH for the real spawn
                // (always process.env.PATH).
                // The practical risk is reliability/confusion: an agent may
                // believe it ran host `node` while actually running a sandboxed
                // same-named script. Mitigation: don't allow adversaries to
                // write same-named executables into PATH dirs.
                // TODO: drop `defenseInDepth: false` once just-bash fixes the
                //       prefix-assignment import so DiD can stay on.
                defenseInDepth: false,
              }
            : {}),
        });
        // Let Bash.exec's output-boundary decode (logResult ->
        // decodeBinaryToUtf8) run normally. It decodes valid-UTF-8 byte
        // sequences in the latin1 pipeline buffer back to Unicode (e.g. host
        // bytes c3 a9 -> U+00E9), and Buffer.from(result.stdout, "utf8") below
        // re-encodes that to the original bytes — so valid UTF-8 from both host
        // commands and builtins round-trips correctly. Non-UTF-8 binary output
        // is utf8-expanded (an inherent limitation of just-bash's string-based
        // pipeline, since byte 0xE9 and codepoint U+00E9 are indistinguishable
        // once collapsed into a JS string); that only affects raw binary from a
        // host command, never the text output of git/gh/node.
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
  // With host-wide read access, forwarding the real host PATH makes just-bash
  // discover host ELF/Mach-O binaries and try to parse them as shell scripts.
  // Keep command lookup through the virtual /usr/bin and /bin mounts created by
  // createJustBashFs().
  out.PATH = JUST_BASH_VIRTUAL_SYSTEM_PATH;
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
