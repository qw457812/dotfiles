import { spawnSync } from "node:child_process";

export function readMacOSClipboard(): string | null {
  try {
    // Avoid pi-vim's Node/native-addon helper startup on every put. Use an
    // absolute path so a restricted PATH cannot break clipboard reads.
    const result = spawnSync("/usr/bin/pbpaste", ["-Prefer", "txt"], {
      encoding: "utf8",
      env: { ...process.env, LANG: "en_US.UTF-8", LC_ALL: "en_US.UTF-8" },
      maxBuffer: 1024 * 1024,
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 1000,
    });
    // null lets pi-vim fall back to its unnamed register on failure.
    if (result.error || result.status !== 0 || result.signal) return null;
    return result.stdout ?? "";
  } catch {
    return null;
  }
}
