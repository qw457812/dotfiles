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
