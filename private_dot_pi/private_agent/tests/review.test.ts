import {
  SessionManager,
  type ExtensionAPI,
  type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import reviewExtension from "../extensions/review.ts";

function appendAssistant(session: SessionManager) {
  return session.appendMessage({
    role: "assistant",
    content: [{ type: "text", text: "Review findings" }],
    api: "openai-responses",
    provider: "openai",
    model: "test",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "stop",
    timestamp: 0,
  });
}

function harness() {
  const sessionManager = SessionManager.inMemory("/tmp/review-navigation-test");
  const commands = new Map<string, (args: string, ctx: ExtensionCommandContext) => Promise<void>>();
  const events = new Map<string, (event: unknown, ctx: ExtensionCommandContext) => void>();
  function emitSessionEvent(name: string): void {
    const handler = events.get(name);
    if (!handler) throw new Error(`Missing session event handler: ${name}`);
    handler({}, ctx as unknown as ExtensionCommandContext);
  }

  const originId = sessionManager.appendCustomEntry("test-origin");
  sessionManager.appendCustomEntry("review-session", { active: true, originId });
  const reviewEndId = appendAssistant(sessionManager);
  sessionManager.branch(originId);
  sessionManager.appendCustomEntry("review-session", { active: false });
  const returnId = appendAssistant(sessionManager);
  sessionManager.appendLabelChange(reviewEndId, "code-review-end");

  const ctx = {
    cwd: "/tmp/review-navigation-test",
    mode: "tui",
    sessionManager,
    isIdle: () => true,
    ui: {
      notify: vi.fn(),
      setWidget: vi.fn(),
      setEditorText: vi.fn(),
      select: vi.fn(async () => "Return only"),
    },
    navigateTree: vi.fn(async (id: string) => {
      sessionManager.branch(id);
      emitSessionEvent("session_tree");
      return { cancelled: false };
    }),
  };
  const pi = {
    registerCommand: (
      name: string,
      command: { handler: (args: string, context: ExtensionCommandContext) => Promise<void> },
    ) => {
      commands.set(name, command.handler);
    },
    on: (name: string, handler: (event: unknown, context: ExtensionCommandContext) => void) =>
      events.set(name, handler),
    setLabel: vi.fn((id: string, label: string | undefined) =>
      sessionManager.appendLabelChange(id, label),
    ),
    appendEntry: (type: string, data: unknown) => sessionManager.appendCustomEntry(type, data),
    exec: vi.fn(async () => ({ code: 0, stdout: "", stderr: "" })),
    sendUserMessage: vi.fn(),
  };
  reviewExtension(pi as unknown as ExtensionAPI);
  emitSessionEvent("session_start");

  return {
    ctx,
    pi,
    sessionManager,
    originId,
    reviewEndId,
    returnId,
    run: async (name: string, args = "") => {
      const command = commands.get(name);
      if (!command) throw new Error(`Missing command: ${name}`);
      await command(args, ctx as unknown as ExtensionCommandContext);
    },
  };
}

describe("Review resume navigation", () => {
  it("bookmarks the nearest assistant on the current branch, not metadata or later replies", async () => {
    const h = harness();
    await h.run("resume-review");
    const laterReplyId = appendAssistant(h.sessionManager);
    await h.ctx.navigateTree(h.reviewEndId);
    h.sessionManager.appendCustomEntry("test-metadata");
    await h.run("end-review");
    expect(h.sessionManager.getLabel(h.reviewEndId)).toBe("code-review-end");
    expect(h.sessionManager.getLabel(laterReplyId)).toBeUndefined();
    await h.ctx.navigateTree(h.returnId);
    await h.run("resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(h.reviewEndId, { summarize: false });
  });

  it("replaces the previous endpoint label when saving an earlier reply", async () => {
    const h = harness();
    await h.ctx.navigateTree(h.reviewEndId);
    const laterReplyId = appendAssistant(h.sessionManager);
    await h.run("end-review");
    expect(h.sessionManager.getLabel(laterReplyId)).toBe("code-review-end");
    await h.ctx.navigateTree(h.reviewEndId);
    await h.run("end-review");
    expect(h.sessionManager.getLabel(laterReplyId)).toBeUndefined();
    expect(h.sessionManager.getLabel(h.reviewEndId)).toBe("code-review-end");
    await h.ctx.navigateTree(h.returnId);
    await h.run("resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(h.reviewEndId, { summarize: false });
  });

  it("returns to the position before resuming without moving the saved endpoint", async () => {
    const h = harness();
    const beforeResumeId = h.returnId;
    await h.run("resume-review");
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "Review session resumed. Use /end-resume-review to leave.",
      "info",
    );
    const followUpId = appendAssistant(h.sessionManager);
    await h.run("end-resume-review");
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "Returned to the position before resuming. Use /resume-review to re-enter.",
      "info",
    );
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(beforeResumeId, { summarize: false });
    expect(h.sessionManager.getLabel(beforeResumeId)).toBeUndefined();
    expect(h.sessionManager.getLabel(h.reviewEndId)).toBe("code-review-end");
    expect(h.sessionManager.getLabel(followUpId)).toBeUndefined();
    await h.run("resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(h.reviewEndId, { summarize: false });
  });

  it("returns to the nearest assistant before resuming, ignoring metadata and excluded replies", async () => {
    const h = harness();
    const laterReplyId = appendAssistant(h.sessionManager);
    await h.ctx.navigateTree(h.returnId);
    h.sessionManager.appendCustomEntry("test-return-metadata");
    await h.run("resume-review");
    expect(h.sessionManager.getLabel(h.returnId)).toBe("code-review-resume");
    expect(h.sessionManager.getLabel(laterReplyId)).toBeUndefined();
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(h.returnId, { summarize: false });
  });

  it("allows returning after rewinding to the saved endpoint in the same review", async () => {
    const h = harness();
    await h.ctx.navigateTree(h.reviewEndId);
    const savedEndpointId = appendAssistant(h.sessionManager);
    await h.run("end-review");
    expect(h.sessionManager.getLabel(savedEndpointId)).toBe("code-review-end");
    await h.ctx.navigateTree(h.returnId);
    await h.run("resume-review");
    await h.ctx.navigateTree(savedEndpointId);
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(h.returnId, { summarize: false });
    expect(h.sessionManager.getLabel(h.returnId)).toBeUndefined();
  });

  it("allows returning after rewinding to an earlier reply in the same review", async () => {
    const h = harness();
    await h.ctx.navigateTree(h.reviewEndId);
    const savedEndpointId = appendAssistant(h.sessionManager);
    await h.run("end-review");
    expect(h.sessionManager.getLabel(savedEndpointId)).toBe("code-review-end");
    await h.ctx.navigateTree(h.returnId);
    await h.run("resume-review");
    await h.ctx.navigateTree(h.reviewEndId);
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(h.returnId, { summarize: false });
    expect(h.sessionManager.getLabel(h.returnId)).toBeUndefined();
  });

  it("rejects resuming from inside the review branch", async () => {
    const h = harness();
    await h.run("resume-review");
    h.ctx.navigateTree.mockClear();
    await h.run("resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "Already in a review. Use /tree to move within it.",
      "info",
    );
  });

  it("rejects resuming without a saved endpoint", async () => {
    const h = harness();
    h.sessionManager.appendLabelChange(h.reviewEndId, undefined);
    await h.run("resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "No review branch to resume (use /review and /end-review first)",
      "info",
    );
  });

  it("rejects a return bookmark belonging to a different review branch", async () => {
    const h = harness();
    await h.run("resume-review");
    await h.ctx.navigateTree(h.originId);
    h.sessionManager.appendCustomEntry("review-session", { active: true, originId: h.originId });
    h.ctx.navigateTree.mockClear();
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "This resume position belongs to another review. Use /end-review to return.",
      "info",
    );
  });

  it("does not reuse a consumed bookmark after returning to the old review branch", async () => {
    const h = harness();
    await h.run("resume-review");
    const resumedId = h.sessionManager.getLeafId()!;
    await h.run("end-resume-review");
    await h.ctx.navigateTree(resumedId);
    h.ctx.navigateTree.mockClear();
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
  });

  it("rejects the previous resume bookmark in a new review without clearing it", async () => {
    const h = harness();
    const returnId = h.returnId;
    await h.run("resume-review");
    await h.ctx.navigateTree(h.originId);
    h.ctx.ui.select.mockResolvedValueOnce("Empty branch");
    await h.run("review", "uncommitted");
    expect(h.sessionManager.getLabel(returnId)).toBe("code-review-resume");
    h.ctx.navigateTree.mockClear();
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "This resume position belongs to another review. Use /end-review to return.",
      "info",
    );
  });

  it("preserves the resume bookmark after /end-review for returning from the old resumed branch", async () => {
    const h = harness();
    const beforeResumeId = h.returnId;
    await h.run("resume-review");
    const resumedId = h.sessionManager.getLeafId()!;
    await h.run("end-review");
    expect(h.sessionManager.getLabel(beforeResumeId)).toBe("code-review-resume");
    h.ctx.navigateTree.mockClear();
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
    await h.ctx.navigateTree(resumedId);
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(beforeResumeId, { summarize: false });
    expect(h.sessionManager.getLabel(beforeResumeId)).toBeUndefined();
  });

  it("uses the current return bookmark when revisiting an older resume position in the same review", async () => {
    const h = harness();
    await h.run("resume-review");
    const oldResumeId = h.sessionManager.getLeafId()!;
    await h.run("end-resume-review");
    const newReturnId = appendAssistant(h.sessionManager);
    await h.run("resume-review");
    await h.ctx.navigateTree(oldResumeId);
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(newReturnId, { summarize: false });
  });

  it("rejects resume from a metadata-only branch without an assistant message", async () => {
    const h = harness();
    await h.ctx.navigateTree(h.originId);
    h.sessionManager.appendCustomEntry("test-return-metadata");
    h.ctx.navigateTree.mockClear();
    await h.run("resume-review");
    expect(h.ctx.navigateTree).not.toHaveBeenCalled();
    expect(h.pi.setLabel).not.toHaveBeenCalled();
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "No assistant message on this branch to return to.",
      "info",
    );
  });

  it("propagates navigation errors without modifying bookmarks or reporting success", async () => {
    const h = harness();
    h.ctx.navigateTree.mockRejectedValueOnce(new Error("navigation failed"));
    await expect(h.run("resume-review")).rejects.toThrow("navigation failed");
    expect(h.pi.setLabel).not.toHaveBeenCalled();
    expect(h.ctx.ui.notify).not.toHaveBeenCalled();
  });

  it("leaves bookmarks unchanged when resume navigation is cancelled", async () => {
    const h = harness();
    const entries = h.sessionManager.getEntries();
    h.ctx.navigateTree.mockResolvedValueOnce({ cancelled: true });
    await h.run("resume-review");
    expect(h.pi.setLabel).not.toHaveBeenCalled();
    expect(h.sessionManager.getEntries()).toEqual(entries);
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "Navigation cancelled. Use /resume-review to try again.",
      "info",
    );
  });

  it("preserves the return bookmark when return navigation is cancelled, allowing retry", async () => {
    const h = harness();
    const beforeResumeId = h.returnId;
    await h.run("resume-review");
    h.pi.setLabel.mockClear();
    h.ctx.navigateTree.mockResolvedValueOnce({ cancelled: true });
    await h.run("end-resume-review");
    expect(h.pi.setLabel).not.toHaveBeenCalled();
    expect(h.sessionManager.getLabel(beforeResumeId)).toBe("code-review-resume");
    expect(h.ctx.ui.notify).toHaveBeenLastCalledWith(
      "Navigation cancelled. Use /end-resume-review to try again.",
      "info",
    );
    await h.run("end-resume-review");
    expect(h.ctx.navigateTree).toHaveBeenLastCalledWith(beforeResumeId, { summarize: false });
    expect(h.sessionManager.getLabel(beforeResumeId)).toBeUndefined();
  });
});
