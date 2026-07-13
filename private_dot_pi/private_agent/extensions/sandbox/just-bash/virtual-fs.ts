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
import { resolve } from "node:path";
import {
  assertDevicePath,
  deviceStat,
  directoryStat,
  invalidArgumentError,
  isDeviceRoot,
  isDirectoryError,
  noSuchFileError,
  notDirectoryError,
  readOnlyFsError,
  virtualCommandStat,
} from "./fs-errors.ts";

export class DiscardDeviceFs {
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

export class VirtualBinFs {
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
