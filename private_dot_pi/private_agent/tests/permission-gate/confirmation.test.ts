import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { describe, expect, it, vi } from "vitest";
import {
  confirm,
  confirmationResult,
  type ConfirmationOutcome,
} from "../../extensions/permission-gate/confirmation.ts";

function harness(hasUI = true) {
  const controller = new AbortController();
  const dialog = vi.fn<ExtensionContext["ui"]["confirm"]>().mockResolvedValue(true);
  const emit = vi.fn();
  const abort = vi.fn(() => controller.abort());
  const pi = { events: { emit } } as unknown as ExtensionAPI;
  const ctx = {
    hasUI,
    ui: { confirm: dialog },
    signal: controller.signal,
    abort,
  } as unknown as ExtensionContext;
  return { pi, ctx, controller, dialog, emit, abort };
}

const TITLE = "Approval";
const MESSAGE = "Change data?";

describe("confirm", () => {
  it("returns approval and uses the same notification and dialog content", async () => {
    const h = harness();
    expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("user-approved");
    expect(h.emit).toHaveBeenCalledExactlyOnceWith("my:notification", {
      title: TITLE,
      body: MESSAGE,
    });
    expect(h.dialog).toHaveBeenCalledExactlyOnceWith(TITLE, MESSAGE, {
      signal: h.controller.signal,
    });
    expect(h.abort).not.toHaveBeenCalled();
  });

  it("aborts on denial before releasing the queue", async () => {
    const h = harness();
    h.dialog.mockResolvedValue(false);
    expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("user-denied");
    expect(h.abort).toHaveBeenCalledOnce();
  });

  it("returns no-ui without notifications or dialogs", async () => {
    const h = harness(false);
    expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("no-ui");
    expect(h.dialog).not.toHaveBeenCalled();
    expect(h.emit).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
  });

  it("returns cancellation before no-ui for an already-cancelled operation", async () => {
    const h = harness(false);
    h.controller.abort();
    expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("cancelled");
    expect(h.emit).not.toHaveBeenCalled();
    expect(h.abort).not.toHaveBeenCalled();
  });

  it.each([true, false, "throw"] as const)(
    "cancellation during dialog completion=%s overrides its outcome",
    async (completion) => {
      const h = harness();
      h.dialog.mockImplementation(async () => {
        h.controller.abort();
        if (completion === "throw") throw new Error("private dialog error");
        return completion;
      });
      expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("cancelled");
      expect(h.abort).not.toHaveBeenCalled();
    },
  );

  it("a notification failure returns failure and releases the queue", async () => {
    const h = harness();
    h.emit.mockImplementationOnce(() => {
      throw new Error("private notification error");
    });
    expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("confirmation-failed");
    expect(h.dialog).not.toHaveBeenCalled();
    expect(await confirm(h.pi, h.ctx, TITLE, MESSAGE)).toBe("user-approved");
    expect(h.abort).not.toHaveBeenCalled();
  });

  it("works without an operation signal", async () => {
    const h = harness();
    expect(await confirm(h.pi, { ...h.ctx, signal: undefined }, TITLE, MESSAGE)).toBe(
      "user-approved",
    );
    expect(h.dialog).toHaveBeenCalledExactlyOnceWith(TITLE, MESSAGE);
  });
});

describe("confirmationResult", () => {
  it.each([
    ["user-approved", undefined],
    ["user-denied", "Blocked by user"],
    ["no-ui", "Operation requires user confirmation"],
    ["cancelled", "Permission Gate: operation cancelled"],
    ["confirmation-failed", "User confirmation failed"],
  ] as const)("maps %s to a fixed tool result", (outcome: ConfirmationOutcome, reason) => {
    const h = harness();
    expect(confirmationResult(outcome)).toEqual(reason ? { block: true, reason } : undefined);
    expect(h.abort).not.toHaveBeenCalled();
  });
});
