import { tmpdir } from "node:os";
import { posix } from "node:path";

export const TEMP_DIRECTORIES = [
  "/tmp",
  "/var/tmp",
  tmpdir(),
  ...(process.platform === "darwin" ? ["/private/tmp", "/private/var/tmp"] : []),
]
  .map((path) => posix.normalize(path).replace(/\/+$/, ""))
  .filter((path) => posix.isAbsolute(path));
