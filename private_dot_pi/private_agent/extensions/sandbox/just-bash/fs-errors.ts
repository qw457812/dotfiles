import type { FsStat } from "just-bash";
import { resolve } from "node:path";

export function isExpectedMissingPathError(err: unknown): boolean {
  const code = (err as NodeJS.ErrnoException | undefined)?.code;
  return code === "ENOENT" || code === "ENOTDIR";
}

export function readOnlyFsError(operation: string, target: string): Error {
  const error = new Error(
    `EROFS: read-only file system, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EROFS";
  return error;
}

export function notDirectoryError(operation: string, target: string): Error {
  const error = new Error(
    `ENOTDIR: not a directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "ENOTDIR";
  return error;
}

export function isDirectoryError(operation: string, target: string): Error {
  const error = new Error(
    `EISDIR: illegal operation on a directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EISDIR";
  return error;
}

export function noSuchFileError(operation: string, target: string): Error {
  const error = new Error(
    `ENOENT: no such file or directory, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "ENOENT";
  return error;
}

export function permissionDeniedError(operation: string, target: string): Error {
  const error = new Error(
    `EACCES: permission denied, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EACCES";
  return error;
}

export function invalidArgumentError(operation: string, target: string): Error {
  const error = new Error(
    `EINVAL: invalid argument, ${operation} '${target}'`,
  ) as NodeJS.ErrnoException;
  error.code = "EINVAL";
  return error;
}

export function isDeviceRoot(path: string): boolean {
  return resolve("/", path) === "/";
}

export function assertDevicePath(path: string, operation: string): void {
  if (!isDeviceRoot(path)) {
    throw noSuchFileError(operation, path);
  }
}

export function deviceStat(): FsStat {
  return {
    isFile: true,
    isDirectory: false,
    isSymbolicLink: false,
    mode: 0o666,
    size: 0,
    mtime: new Date(),
  };
}

export function directoryStat(): FsStat {
  return {
    isFile: false,
    isDirectory: true,
    isSymbolicLink: false,
    mode: 0o555,
    size: 0,
    mtime: new Date(),
  };
}

export function virtualCommandStat(commandName: string): FsStat {
  return {
    isFile: true,
    isDirectory: false,
    isSymbolicLink: false,
    mode: 0o555,
    size: Buffer.byteLength(`# just-bash virtual command stub: ${commandName}\n`, "utf8"),
    mtime: new Date(),
  };
}
