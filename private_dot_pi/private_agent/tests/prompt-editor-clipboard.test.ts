import { spawnSync } from "node:child_process";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { readMacOSClipboard } from "../extensions/prompt-editor/macos-clipboard.js";

vi.mock("node:child_process", () => ({ spawnSync: vi.fn() }));

const spawn = vi.mocked(spawnSync);
function result(overrides: Record<string, unknown> = {}) {
  return {
    pid: 1,
    output: [],
    stdout: "",
    stderr: "",
    status: 0,
    signal: null,
    ...overrides,
  } as ReturnType<typeof spawnSync>;
}

beforeEach(() => vi.resetAllMocks());

describe("prompt-editor macOS clipboard", () => {
  it("reads text directly with pbpaste and preserves Unicode, whitespace and newlines", () => {
    const text = " 中文 😀\nsecond line\n";
    spawn.mockReturnValue(result({ stdout: text }));
    expect(readMacOSClipboard()).toBe(text);
    expect(spawn).toHaveBeenCalledWith(
      "/usr/bin/pbpaste",
      ["-Prefer", "txt"],
      expect.objectContaining({
        encoding: "utf8",
        env: expect.objectContaining({ LANG: "en_US.UTF-8", LC_ALL: "en_US.UTF-8" }),
        timeout: 1000,
        maxBuffer: 1024 * 1024,
      }),
    );
  });

  it("keeps an empty clipboard distinct from a failed read", () => {
    spawn.mockReturnValue(result());
    expect(readMacOSClipboard()).toBe("");
  });

  it.each([
    { status: 1 },
    { status: null, signal: "SIGTERM" },
    { error: Object.assign(new Error("timed out"), { code: "ETIMEDOUT" }) },
    { error: Object.assign(new Error("too large"), { code: "ENOBUFS" }) },
  ])("returns null for failed reads so pi-vim can use its register: %j", (failure) => {
    spawn.mockReturnValue(result({ stdout: "partial", ...failure }));
    expect(readMacOSClipboard()).toBeNull();
  });

  it("falls back when spawning throws", () => {
    spawn.mockImplementation(() => {
      throw new Error("spawn failed");
    });
    expect(readMacOSClipboard()).toBeNull();
  });
});
