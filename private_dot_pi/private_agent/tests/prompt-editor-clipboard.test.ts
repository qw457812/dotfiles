import { spawn, spawnSync } from "node:child_process";
import { EventEmitter } from "node:events";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  installClipboardBridge,
  readMacOSClipboard,
  readTermuxClipboard,
  writeTermuxClipboard,
} from "../extensions/prompt-editor/clipboard.ts";

vi.mock("node:child_process", () => ({ spawn: vi.fn(), spawnSync: vi.fn() }));

const platformDescriptor = Object.getOwnPropertyDescriptor(process, "platform")!;
const sync = vi.mocked(spawnSync);
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
function setPlatform(platform: string) {
  Object.defineProperty(process, "platform", { ...platformDescriptor, value: platform });
}
function mockChild() {
  const stdin = Object.assign(new EventEmitter(), { end: vi.fn() });
  const child = Object.assign(new EventEmitter(), { stdin, kill: vi.fn() });
  vi.mocked(spawn).mockReturnValue(child as unknown as ReturnType<typeof spawn>);
  return child;
}
beforeEach(() => vi.resetAllMocks());
afterEach(() => {
  Object.defineProperty(process, "platform", platformDescriptor);
  vi.unstubAllEnvs();
});

describe("prompt-editor macOS clipboard", () => {
  it("reads text directly with pbpaste and preserves Unicode, whitespace and newlines", () => {
    const text = " 中文 😀\nsecond line\n";
    sync.mockReturnValue(result({ stdout: text }));
    expect(readMacOSClipboard()).toBe(text);
    expect(sync).toHaveBeenCalledWith(
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
    sync.mockReturnValue(result());
    expect(readMacOSClipboard()).toBe("");
  });

  it.each([
    { status: 1 },
    { status: null, signal: "SIGTERM" },
    { error: Object.assign(new Error("timed out"), { code: "ETIMEDOUT" }) },
    { error: Object.assign(new Error("too large"), { code: "ENOBUFS" }) },
  ])("returns null for failed reads so pi-vim can use its register: %j", (failure) => {
    sync.mockReturnValue(result({ stdout: "partial", ...failure }));
    expect(readMacOSClipboard()).toBeNull();
  });

  it("falls back when spawning throws", () => {
    sync.mockImplementation(() => {
      throw new Error("spawn failed");
    });
    expect(readMacOSClipboard()).toBeNull();
  });
});

describe("Termux clipboard reads", () => {
  it.each([" 中文 😀\nsecond line\n", ""])("preserves text %j", (text) => {
    sync.mockReturnValue(result({ stdout: text }));
    expect(readTermuxClipboard()).toBe(text);
    expect(sync).toHaveBeenCalledWith("termux-clipboard-get", [], {
      encoding: "utf8",
      maxBuffer: 1024 * 1024,
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 1000,
      windowsHide: true,
    });
  });
  it.each([
    { status: 1 },
    { status: null, signal: "SIGTERM" },
    { error: Object.assign(new Error("timeout"), { code: "ETIMEDOUT" }) },
    { error: Object.assign(new Error("too large"), { code: "ENOBUFS" }) },
  ])("discards partial output on failure: %j", (failure) => {
    sync.mockReturnValue(result({ stdout: "partial", ...failure }));
    expect(readTermuxClipboard()).toBeNull();
  });
  it("returns null when spawning throws", () => {
    sync.mockImplementation(() => {
      throw new Error("spawn failed");
    });
    expect(readTermuxClipboard()).toBeNull();
  });
});

describe("clipboard bridge", () => {
  function editor() {
    return { setClipboardReadFn: vi.fn(), setClipboardFn: vi.fn() };
  }
  it("overrides only reads on macOS without probing commands", () => {
    setPlatform("darwin");
    const target = editor();
    installClipboardBridge(target);
    expect(target.setClipboardReadFn).toHaveBeenCalledWith(readMacOSClipboard);
    expect(target.setClipboardFn).not.toHaveBeenCalled();
    expect(sync).not.toHaveBeenCalled();
  });
  it.each([
    ["android", ""],
    ["linux", "/data/data/com.termux/files/usr"],
  ])("installs Termux hooks on %s with PREFIX=%s", (platform, prefix) => {
    setPlatform(platform);
    vi.stubEnv("PREFIX", prefix);
    sync.mockReturnValue(result());
    const target = editor();
    installClipboardBridge(target);
    expect(target.setClipboardReadFn).toHaveBeenCalledWith(readTermuxClipboard);
    expect(target.setClipboardFn).toHaveBeenCalledWith(writeTermuxClipboard);
    expect(sync.mock.calls.map((call) => call[1])).toEqual([
      ["-c", 'command -v "$1" >/dev/null 2>&1', "sh", "termux-clipboard-get"],
      ["-c", 'command -v "$1" >/dev/null 2>&1', "sh", "termux-clipboard-set"],
    ]);
    expect(sync.mock.calls.every((call) => call[2]?.timeout === 1000)).toBe(true);
  });
  it("leaves other platforms untouched", () => {
    setPlatform("linux");
    vi.stubEnv("PREFIX", "");
    const target = editor();
    installClipboardBridge(target);
    expect(target.setClipboardReadFn).not.toHaveBeenCalled();
    expect(target.setClipboardFn).not.toHaveBeenCalled();
    expect(sync).not.toHaveBeenCalled();
  });
  it.each([0, 1])("requires both Termux commands (missing %i)", (missing) => {
    setPlatform("android");
    sync.mockReturnValueOnce(result({ status: missing === 0 ? 1 : 0 }));
    sync.mockReturnValueOnce(result({ status: 1 }));
    const target = editor();
    installClipboardBridge(target);
    expect(target.setClipboardReadFn).not.toHaveBeenCalled();
    expect(target.setClipboardFn).not.toHaveBeenCalled();
  });
  it("treats failed probes as unavailable", () => {
    setPlatform("android");
    sync.mockReturnValue(result({ error: new Error("timeout") }));
    const target = editor();
    installClipboardBridge(target);
    expect(target.setClipboardReadFn).not.toHaveBeenCalled();
    expect(target.setClipboardFn).not.toHaveBeenCalled();
  });
  it("allows editors without clipboard hooks", () => {
    setPlatform("android");
    sync.mockReturnValue(result());
    expect(() => installClipboardBridge({})).not.toThrow();
  });
});

describe("Termux clipboard writes", () => {
  it("writes text through stdin and resolves on successful close", async () => {
    const child = mockChild();
    const text = " 中文 😀\n";
    const write = writeTermuxClipboard(text);
    expect(spawn).toHaveBeenCalledWith("termux-clipboard-set", [], {
      stdio: ["pipe", "ignore", "ignore"],
      windowsHide: true,
    });
    expect(child.stdin.end).toHaveBeenCalledWith(text);
    child.emit("close", 0);
    await expect(write).resolves.toBeUndefined();
  });
  it.each([1, null])("preserves circuit-breaker metadata on close %s", async (code) => {
    const child = mockChild();
    const write = writeTermuxClipboard("text");
    child.emit("close", code);
    await expect(write).rejects.toMatchObject({
      code: "TERMUX_CLIPBOARD_SET_FAILED",
      syscall: "spawn termux-clipboard-set",
    });
  });
  it("preserves thrown spawn errors", async () => {
    const error = new Error("spawn failed");
    vi.mocked(spawn).mockImplementation(() => {
      throw error;
    });
    await expect(writeTermuxClipboard("text")).rejects.toBe(error);
  });
  it("preserves emitted child errors", async () => {
    const child = mockChild();
    const write = writeTermuxClipboard("text");
    const error = new Error("child failed");
    child.emit("error", error);
    await expect(write).rejects.toBe(error);
  });
  it("rejects missing stdin", async () => {
    const child = Object.assign(new EventEmitter(), { stdin: null, kill: vi.fn() });
    vi.mocked(spawn).mockReturnValue(child as unknown as ReturnType<typeof spawn>);
    await expect(writeTermuxClipboard("text")).rejects.toMatchObject({
      code: "TERMUX_CLIPBOARD_SET_FAILED",
      syscall: "spawn termux-clipboard-set",
      message: "termux-clipboard-set stdin unavailable",
    });
  });
  it("wraps stdin errors for the circuit breaker", async () => {
    const child = mockChild();
    const write = writeTermuxClipboard("text");
    child.stdin.emit("error", new Error("broken pipe"));
    await expect(write).rejects.toMatchObject({
      code: "TERMUX_CLIPBOARD_SET_FAILED",
      syscall: "spawn termux-clipboard-set",
      message: "termux-clipboard-set stdin error: broken pipe",
    });
  });
  it("does not spawn when already aborted", async () => {
    const controller = new AbortController();
    const reason = new Error("cancelled");
    controller.abort(reason);
    await expect(writeTermuxClipboard("text", controller.signal)).rejects.toBe(reason);
    expect(spawn).not.toHaveBeenCalled();
  });
  it("kills aborted writes, preserves the reason, and ignores late events", async () => {
    const child = mockChild();
    const controller = new AbortController();
    const removeListener = vi.spyOn(controller.signal, "removeEventListener");
    const write = writeTermuxClipboard("text", controller.signal);
    const reason = new Error("cancelled");
    controller.abort(reason);
    child.emit("close", 0);
    child.stdin.emit("error", new Error("late error"));
    await expect(write).rejects.toBe(reason);
    expect(child.kill).toHaveBeenCalledWith("SIGKILL");
    expect(removeListener).toHaveBeenCalledWith("abort", expect.any(Function));
  });
  it("uses a fallback abort message even when kill throws", async () => {
    const child = mockChild();
    child.kill.mockImplementation(() => {
      throw new Error("kill failed");
    });
    const controller = new AbortController();
    const write = writeTermuxClipboard("text", controller.signal);
    controller.abort("cancelled");
    await expect(write).rejects.toThrow("clipboard write aborted");
  });
  it("removes the abort listener on success", async () => {
    const child = mockChild();
    const controller = new AbortController();
    const removeListener = vi.spyOn(controller.signal, "removeEventListener");
    const write = writeTermuxClipboard("text", controller.signal);
    child.emit("close", 0);
    await write;
    expect(removeListener).toHaveBeenCalledWith("abort", expect.any(Function));
    controller.abort();
    expect(child.kill).not.toHaveBeenCalled();
  });
});
