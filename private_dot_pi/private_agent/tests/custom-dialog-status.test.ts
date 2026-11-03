import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";

import answerExtension from "../extensions/answer.ts";
import loopExtension from "../extensions/loop.ts";
import reviewExtension from "../extensions/review.ts";

function harness(activate: (pi: ExtensionAPI) => void) {
  const commands = new Map<string, Parameters<ExtensionAPI["registerCommand"]>[1]>();
  const custom = vi.fn(async (..._args: unknown[]): Promise<unknown> => null);
  const pi = {
    registerCommand: (name: string, command: Parameters<ExtensionAPI["registerCommand"]>[1]) =>
      commands.set(name, command),
    registerShortcut: vi.fn(),
    registerTool: vi.fn(),
    on: vi.fn(),
    exec: vi.fn(async (_command: string, args: string[]) => {
      let stdout = "";
      if (args[0] === "status") stdout = " M example.ts\n";
      if (args[0] === "branch") stdout = args[1] === "--show-current" ? "feature\n" : "main\nfeature\n";
      if (args[0] === "symbolic-ref") stdout = "origin/main\n";
      if (args[0] === "log") stdout = "abcdef123 Example commit\n";
      return { code: 0, stdout, stderr: "" };
    }),
    sendMessage: vi.fn(),
    sendUserMessage: vi.fn(),
  };
  const ctx = {
    cwd: process.cwd(),
    mode: "tui",
    model: { provider: "openai", id: "test" },
    modelRegistry: { find: () => undefined },
    sessionManager: {
      getBranch: () => [{
        type: "message",
        message: { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "Continue?" }] },
      }],
    },
    ui: { custom, notify: vi.fn() },
  };
  activate(pi as unknown as ExtensionAPI);
  return {
    custom,
    pi,
    run: (name: string) => commands.get(name)!.handler("", ctx as unknown as ExtensionCommandContext),
  };
}

const question = (message: string) => ({ blocked: { kind: "question", message } });

describe("custom dialog program status", () => {
  it("marks Q&A as waiting for input, but not the extraction loader", async () => {
    const h = harness(answerExtension);
    h.custom.mockResolvedValueOnce({ status: "ok", result: { questions: [{ question: "Continue?" }] } });
    await h.run("answer");

    expect(h.custom).toHaveBeenNthCalledWith(1, expect.any(Function));
    expect(h.custom).toHaveBeenNthCalledWith(2, expect.any(Function), question("Answer the extracted questions"));
    expect(h.pi.sendMessage).not.toHaveBeenCalled();
  });

  it("marks the review preset selector as waiting for input", async () => {
    const h = harness(reviewExtension);
    await h.run("review");

    expect(h.custom).toHaveBeenCalledWith(expect.any(Function), question("Select a review preset"));
    expect(h.pi.sendUserMessage).not.toHaveBeenCalled();
  });

  it.each([
    ["baseBranch", "Select a base branch for review"],
    ["commit", "Select a commit to review"],
  ])("marks the %s review selector as waiting for input", async (preset, message) => {
    const h = harness(reviewExtension);
    h.custom.mockResolvedValueOnce(preset);
    await h.run("review");

    expect(h.custom).toHaveBeenNthCalledWith(2, expect.any(Function), question(message));
    expect(h.pi.sendUserMessage).not.toHaveBeenCalled();
  });

  it("marks the loop preset selector as waiting for input", async () => {
    const h = harness(loopExtension);
    await h.run("loop");

    expect(h.custom).toHaveBeenCalledWith(expect.any(Function), question("Select a loop preset"));
    expect(h.pi.sendMessage).not.toHaveBeenCalled();
  });
});
