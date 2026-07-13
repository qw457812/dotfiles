import {
  MountableFs,
  ReadWriteFs,
  type BufferEncoding,
  type ByteString,
  type CpOptions,
  type FileContent,
  type FsStat,
  type MkdirOptions,
  type RmOptions,
} from "just-bash";
import { existsSync, mkdirSync, promises as fsPromises, realpathSync, statSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { isAbsolute, join, relative, resolve } from "node:path";
import type { JustBashFilesystemConfig } from "./config.ts";
import { isExpectedMissingPathError, permissionDeniedError } from "./fs-errors.ts";
import { ReadOnlyHostFs } from "./read-only-host-fs.ts";
import { DiscardDeviceFs, VirtualBinFs } from "./virtual-fs.ts";

export function createJustBashFs(
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

  async writeFile(
    path: string,
    content: FileContent,
    options?: { encoding?: BufferEncoding } | BufferEncoding,
  ): Promise<void> {
    return this.inner.writeFile(path, content, options);
  }

  async appendFile(
    path: string,
    content: FileContent,
    options?: { encoding?: BufferEncoding } | BufferEncoding,
  ): Promise<void> {
    return this.inner.appendFile(path, content, options);
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
