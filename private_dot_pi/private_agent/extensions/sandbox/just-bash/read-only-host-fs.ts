import {
  unsafeBytesFromLatin1,
  type BufferEncoding,
  type ByteString,
  type CpOptions,
  type FileContent,
  type FsStat,
  type MkdirOptions,
  type RmOptions,
} from "just-bash";
import { promises as fsPromises, realpathSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { isExpectedMissingPathError, noSuchFileError, readOnlyFsError } from "./fs-errors.ts";

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

export class ReadOnlyHostFs {
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
    await assertReadonlyWriteTargetHasParent(path, "open");
    throw readOnlyFsError("write", path);
  }

  async appendFile(path: string, _content: FileContent): Promise<void> {
    await assertReadonlyWriteTargetHasParent(path, "open");
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
    await assertReadonlyWriteTargetHasParent(path, "mkdir");
    throw readOnlyFsError("mkdir", path);
  }

  async readdir(path: string): Promise<string[]> {
    if (await resolvesToHostBinPath(path)) throw noSuchFileError("scandir", path);
    return fsPromises.readdir(resolve(path));
  }

  async rm(path: string, _options?: RmOptions): Promise<void> {
    await assertReadonlyEntryExists(path, "rm");
    throw readOnlyFsError("rm", path);
  }

  async cp(src: string, dest: string, _options?: CpOptions): Promise<void> {
    await assertReadonlyEntryExists(src, "cp");
    await assertReadonlyWriteTargetHasParent(dest, "cp");
    throw readOnlyFsError("cp", dest);
  }

  async mv(src: string, dest: string): Promise<void> {
    await assertReadonlyEntryExists(src, "mv");
    await assertReadonlyWriteTargetHasParent(dest, "mv");
    throw readOnlyFsError("mv", dest);
  }

  resolvePath(base: string, path: string): string {
    return resolve(base, path);
  }

  getAllPaths(): string[] {
    return [];
  }

  async chmod(path: string, _mode: number): Promise<void> {
    await assertReadonlyTargetExists(path, "chmod");
    throw readOnlyFsError("chmod", path);
  }

  async symlink(_target: string, linkPath: string): Promise<void> {
    await assertReadonlyWriteTargetHasParent(linkPath, "symlink");
    throw readOnlyFsError("symlink", linkPath);
  }

  async link(existingPath: string, newPath: string): Promise<void> {
    await assertReadonlyEntryExists(existingPath, "link");
    await assertReadonlyWriteTargetHasParent(newPath, "link");
    throw readOnlyFsError("link", newPath);
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
    await assertReadonlyTargetExists(path, "utimes");
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

export async function assertReadonlyWriteTargetHasParent(
  path: string,
  operation: string,
): Promise<void> {
  try {
    await fsPromises.stat(dirname(resolve(path)));
  } catch (err) {
    if (isExpectedMissingPathError(err)) throw noSuchFileError(operation, path);
    throw err;
  }
}

export async function assertReadonlyEntryExists(path: string, operation: string): Promise<void> {
  if (isHostBinPath(path)) throw noSuchFileError(operation, path);
  try {
    await fsPromises.lstat(resolve(path));
  } catch (err) {
    if (isExpectedMissingPathError(err)) throw noSuchFileError(operation, path);
    throw err;
  }
}

export async function assertReadonlyTargetExists(path: string, operation: string): Promise<void> {
  if (await resolvesToHostBinPath(path)) throw noSuchFileError(operation, path);
  try {
    await fsPromises.stat(resolve(path));
  } catch (err) {
    if (isExpectedMissingPathError(err)) throw noSuchFileError(operation, path);
    throw err;
  }
}
