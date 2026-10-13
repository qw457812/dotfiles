import { mkdtemp, mkdir, rename, rm, utimes, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

let home: string;
let root: string;
const now = new Date(2026, 5, 15, 12);
const timestamp = new Date(2026, 5, 15, 9).toISOString();

function message(id: string | undefined, role = "assistant", time = timestamp) {
  return {
    type: "message",
    id,
    timestamp: time,
    message: {
      role,
      ...(role === "assistant"
        ? { provider: "test", model: "model", usage: { totalTokens: 100, cost: { total: 0.1 } } }
        : {}),
    },
  };
}

async function session(directory: string, hour: number, entries: unknown[]) {
  const startedAt = new Date(2026, 5, 15, hour).toISOString();
  const dir = path.join(root, directory);
  await mkdir(dir, { recursive: true });
  const filePath = path.join(dir, `${startedAt.replace(/[:.]/g, "-")}_${directory}.jsonl`);
  await writeFile(
    filePath,
    [{ type: "session", timestamp: startedAt, cwd: `/${directory}` }, ...entries]
      .map((entry) => JSON.stringify(entry))
      .join("\n"),
  );
  return filePath;
}

async function breakdown() {
  const { computeBreakdown } = await import("../extensions/session-breakdown.js");
  return (await computeBreakdown()).ranges.get(30)!;
}

describe("session breakdown fork/branch usage", () => {
  beforeEach(async () => {
    vi.resetModules();
    home = await mkdtemp(path.join(os.tmpdir(), "pi-breakdown-test-"));
    root = path.join(home, ".pi", "agent", "sessions");
    vi.spyOn(os, "homedir").mockReturnValue(home);
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(now);
  });
  afterEach(async () => {
    vi.useRealTimers();
    vi.restoreAllMocks();
    await rm(home, { recursive: true, force: true });
  });

  it("deduplicates copied history but preserves session/model presence and branch requests", async () => {
    const user = message("user", "user");
    const shared = message("shared");
    const original = message("original");
    // Directory ordering must not let a newer fork claim the original usage.
    await session("z-original", 9, [user, shared, original]);
    await session("a-fork", 10, [user, shared, original, message("fork")]);
    await session("b-branch", 11, [user, shared]);
    const range = await breakdown();
    expect(range.sessions).toBe(3);
    expect(range.modelSessions.get("test/model")).toBe(3);
    expect(range.totalMessages).toBe(4);
    expect(range.totalTokens).toBe(300);
    expect(range.totalCost).toBeCloseTo(0.3);
    expect(range.modelTokens.get("test/model")).toBe(300);
    expect(range.groupedModelTokens.get("model")).toBe(300);
    expect(range.cwdTokens.get("/z-original")).toBe(200);
    expect(range.cwdTokens.get("/a-fork")).toBe(100);
    expect(range.cwdTokens.get("/b-branch")).toBe(0);
    expect(range.days.at(-1)?.tokens).toBe(300);
  });

  it("keeps short-ID collisions with different timestamps and messages without IDs", async () => {
    await session("original", 9, [message("same"), message(undefined)]);
    await session("fork", 10, [
      message("same", "assistant", new Date(2026, 5, 15, 10).toISOString()),
      message(undefined),
    ]);
    const range = await breakdown();
    expect(range.totalMessages).toBe(4);
    expect(range.totalTokens).toBe(400);
    expect(range.totalCost).toBeCloseTo(0.4);
  });

  it("sorts unknown filename times last with a stable path tie-breaker", async () => {
    const shared = message("shared");
    await session("z-original", 9, [shared]);
    for (const directory of ["b-unknown", "a-unknown"]) {
      const filePath = await session(directory, 10, [shared, message("unknown-shared")]);
      const renamed = path.join(path.dirname(filePath), "session.jsonl");
      await rename(filePath, renamed);
      await utimes(renamed, now, now);
    }
    const range = await breakdown();
    expect(range.sessions).toBe(3);
    expect(range.totalTokens).toBe(200);
    expect(range.cwdTokens.get("/z-original")).toBe(100);
    expect(range.cwdTokens.get("/a-unknown")).toBe(100);
    expect(range.cwdTokens.get("/b-unknown")).toBe(0);
  });

  it("counts copied history when the source session is unavailable", async () => {
    await session("fork", 10, [message("shared"), message("new")]);
    const range = await breakdown();
    expect(range.sessions).toBe(1);
    expect(range.totalTokens).toBe(200);
  });
});
