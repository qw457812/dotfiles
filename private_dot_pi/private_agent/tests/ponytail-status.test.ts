import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import ponytailStatus from "../extensions/ponytail-status.js";

const { readFileSync } = vi.hoisted(() => ({ readFileSync: vi.fn() }));
vi.mock("node:fs", () => ({ readFileSync }));

function fixture() {
  const handlers = new Map<string, (event: unknown, ctx: ExtensionContext) => Promise<void>>();
  const entries: unknown[] = [];
  const setStatus = vi.fn();
  const ctx = {
    sessionManager: { getBranch: () => entries },
    ui: { theme: { fg: (_color: string, text: string) => text }, setStatus },
  } as unknown as ExtensionContext;
  ponytailStatus({
    on: (event: string, handler: (event: unknown, ctx: ExtensionContext) => Promise<void>) => {
      handlers.set(event, handler);
    },
  } as unknown as ExtensionAPI);
  return {
    entries,
    setStatus,
    async emit(event: string) {
      const handler = handlers.get(event);
      expect(handler).toBeDefined();
      await handler!({}, ctx);
      vi.runAllTimers();
    },
  };
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.stubEnv("PONYTAIL_DEFAULT_MODE", "");
  readFileSync.mockReset();
  readFileSync.mockReturnValue('{"defaultMode":"off"}');
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

describe("ponytail status", () => {
  it("normalizes the environment default before falling back to config", async () => {
    vi.stubEnv("PONYTAIL_DEFAULT_MODE", " LiTe ");
    const f = fixture();
    await f.emit("session_start");
    expect(f.setStatus).toHaveBeenLastCalledWith("ponytail", "󱖿 lite");
  });

  it("strips a BOM and normalizes the config default", async () => {
    readFileSync.mockReturnValue('\uFEFF{"defaultMode":" ULTRA "}');
    const f = fixture();
    await f.emit("session_start");
    expect(f.setStatus).toHaveBeenLastCalledWith("ponytail", "󱖿 ultra");
  });

  it.each([42, "review", null])("rejects invalid default %j", async (defaultMode) => {
    readFileSync.mockReturnValue(JSON.stringify({ defaultMode }));
    const f = fixture();
    await f.emit("session_start");
    expect(f.setStatus).toHaveBeenLastCalledWith("ponytail", "󱖿 full");
  });

  it("restores the compact status from the active branch after tree navigation", async () => {
    const f = fixture();
    await f.emit("session_start");
    expect(f.setStatus).toHaveBeenLastCalledWith("ponytail", undefined);
    f.entries.push({ type: "custom", customType: "ponytail-mode", data: { mode: "lite" } });
    await f.emit("session_tree");
    expect(f.setStatus).toHaveBeenLastCalledWith("ponytail", "󱖿 lite");
    f.entries.length = 0;
    await f.emit("session_tree");
    expect(f.setStatus).toHaveBeenLastCalledWith("ponytail", undefined);
  });
});
