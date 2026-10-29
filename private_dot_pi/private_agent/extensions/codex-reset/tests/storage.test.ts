import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, readdir, rm, stat, utimes } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import codexReset from "../index.js";

const accountId = "storage-test-account";
const token = `header.${Buffer.from(
  JSON.stringify({
    "https://api.openai.com/auth": { chatgpt_account_id: accountId },
  }),
).toString("base64url")}.signature`;
let directory: string;

function journalPath() {
  const key = createHash("sha256").update(JSON.stringify(accountId)).digest("hex");
  return join(directory, "codex-reset-redemptions", `${key}.json`);
}

function fixture() {
  let command!: (args: string, ctx: ExtensionCommandContext) => Promise<void>;
  const notify = vi.fn();
  const ctx = {
    modelRegistry: { getApiKeyForProvider: async () => token },
    ui: { confirm: async () => true, notify },
  } as unknown as ExtensionCommandContext;
  codexReset({
    on: vi.fn(),
    registerCommand: (_name: string, config: { handler: typeof command }) => {
      command = config.handler;
    },
  } as unknown as ExtensionAPI);
  return { notify, consume: () => command("consume", ctx) };
}

beforeEach(async () => {
  directory = await mkdtemp(join(tmpdir(), "pi-codex-reset-"));
  vi.stubEnv("PI_CODING_AGENT_DIR", directory);
});

afterEach(async () => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  await rm(directory, { recursive: true, force: true });
});

describe("Codex redemption with real journal files and account locks", () => {
  it("resumes a lost response from a new extension instance using the persisted ID", async () => {
    const bodies: unknown[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string, init: RequestInit) => {
        if (init.method === "POST") {
          bodies.push(JSON.parse(String(init.body)));
          if (bodies.length === 1) throw new Error("Response lost");
          return new Response(JSON.stringify({ code: "already_redeemed" }));
        }
        return new Response(
          JSON.stringify(
            url.endsWith("/usage")
              ? {}
              : {
                  credits: [
                    {
                      id: "credit",
                      status: "available",
                      expires_at: new Date(Date.now() + 60_000).toISOString(),
                    },
                  ],
                },
          ),
        );
      }),
    );
    const first = fixture();
    await first.consume();
    const pending = JSON.parse(await readFile(journalPath(), "utf8"));
    expect(pending.lastCheckedAt).toBe(0);
    expect(pending.attempts[0].status).toBe("pending");
    const reloaded = fixture();
    await reloaded.consume();
    expect(bodies).toHaveLength(2);
    expect(bodies[1]).toEqual(bodies[0]);
    expect(reloaded.notify).toHaveBeenCalledWith(
      expect.stringContaining("Confirmed previously consumed"),
      "info",
    );
    expect(JSON.parse(await readFile(journalPath(), "utf8")).attempts[0].status).toBe(
      "already_redeemed",
    );
    expect((await stat(journalPath())).mode & 0o777).toBe(0o600);
    expect(await readdir(join(directory, "codex-reset-redemptions"))).toEqual([
      journalPath().split("/").at(-1),
    ]);
  });

  it("does not submit another request while a different instance holds the account lock", async () => {
    let finishPost!: (response: Response) => void;
    const post = vi.fn(
      () =>
        new Promise<Response>((resolve) => {
          finishPost = resolve;
        }),
    );
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: RequestInit) => {
        if (init.method === "POST") return post();
        return new Response(JSON.stringify({ credits: [{ id: "credit", status: "available" }] }));
      }),
    );
    const first = fixture();
    const consuming = first.consume();
    await vi.waitFor(() => expect(post).toHaveBeenCalledTimes(1));
    const second = fixture();
    await second.consume();
    expect(post).toHaveBeenCalledTimes(1);
    expect(second.notify).toHaveBeenCalledWith(expect.stringContaining("busy"), "info");
    finishPost(new Response(JSON.stringify({ code: "reset" })));
    await consuming;
    expect(await readdir(join(directory, "codex-reset-redemptions"))).toHaveLength(1);
  });

  it("recovers a stale lock left by a crashed process", async () => {
    await mkdir(`${journalPath()}.lock`, { recursive: true });
    const old = new Date(Date.now() - 3 * 60_000);
    await utimes(`${journalPath()}.lock`, old, old);
    const post = vi.fn();
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: RequestInit) => {
        if (init.method === "POST") {
          post();
          return new Response(JSON.stringify({ code: "reset" }));
        }
        return new Response(JSON.stringify({ credits: [{ id: "credit", status: "available" }] }));
      }),
    );
    await fixture().consume();
    expect(post).toHaveBeenCalledTimes(1);
    expect(JSON.parse(await readFile(journalPath(), "utf8")).attempts[0].status).toBe("reset");
  });
});
