import {
  ExtensionEditorComponent,
  initTheme,
  type KeybindingsManager,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { Editor, type TUI, visibleWidth } from "@earendil-works/pi-tui";
import { describe, expect, it, vi } from "vitest";
import grillingAnswer, {
  formatGrillingAnswers,
  GrillingAnswerComponent,
  parseGrillingRound,
} from "../extensions/answer-grilling.js";

initTheme("dark");

const round = `Questions for this round:
❓ **Q1** - **Scope**: Support Pi only?

Options: Pi / dsh.

➡️ Support Pi first.
Keep the existing /answer command.

---

❓ **Q2** - **Submission**: Require confirmation before submitting?

➡️ Add a confirmation step.`;
const questions = parseGrillingRound(round);

const keybindings = {
  matches: (data: string, action: string) => action === "app.editor.external" && data === "\x07",
  getKeys: () => ["ctrl+g"],
} as unknown as KeybindingsManager;

function component(bindings: KeybindingsManager = keybindings) {
  const done = vi.fn();
  const theme = { fg: (_: string, text: string) => text, bold: (text: string) => text } as Theme;
  const runtime = {
    requestRender: vi.fn(),
    terminal: { rows: 24, columns: 80 },
  };
  const ui = new GrillingAnswerComponent(
    questions,
    runtime as unknown as TUI,
    theme,
    done,
    bindings,
  );
  return { ui, done, runtime };
}

describe("parseGrillingRound", () => {
  it("preserves numbered questions, choices and multiline recommendations", () => {
    expect(questions).toEqual([
      {
        id: "Q1",
        question: "**Scope**: Support Pi only?\n\nOptions: Pi / dsh.",
        recommendation: "Support Pi first.\nKeep the existing /answer command.",
      },
      {
        id: "Q2",
        question: "**Submission**: Require confirmation before submitting?",
        recommendation: "Add a confirmation step.",
      },
    ]);
  });
  it("ignores fenced examples and permits plain headings, CRLF and arrows without variation selectors", () => {
    expect(
      parseGrillingRound(
        "```markdown\n" +
          round +
          "\n```\n❓ Q7 — Which option?\r\n➡ Recommended option.\r\n---\r\nClosing remarks",
      ),
    ).toEqual([{ id: "Q7", question: "Which option?", recommendation: "Recommended option." }]);
  });
  it("keeps fenced question content without treating it as another question", () => {
    const parsed = parseGrillingRound("❓ **Q1** - Example?\n```\n❓ Q2 - example\n```\n➡️ Yes.");
    expect(parsed).toHaveLength(1);
    expect(parsed[0].question).toContain("❓ Q2 - example");
  });
  it.each(["```", "~~~"])("ignores invalid closing lines inside %s fences", (fence) => {
    const example = `${fence}text\n${fence}not-a-closing-fence\n❓ Q9 - Example?\n➡️ Example recommendation.\n${fence} \t`;
    expect(parseGrillingRound(example + "\n" + round)).toEqual(questions);
  });
  it("permits a longer closing fence and keeps fenced recommendation content intact", () => {
    expect(
      parseGrillingRound(
        "❓ Q1 - Example?\n➡️ Use this example:\n```text\n```not-a-closing-fence\n❓ Q2 - Not a real question\n````",
      ),
    ).toEqual([
      {
        id: "Q1",
        question: "Example?",
        recommendation:
          "Use this example:\n```text\n```not-a-closing-fence\n❓ Q2 - Not a real question\n````",
      },
    ]);
  });
  it.each([
    "```text\n❓ Q1 - Hidden?\n➡️ Yes.",
    round + "\n---\n~~~text\n❓ Q3 - Hidden?\n➡️ Yes.",
    "❓ Q1 - Example?\n➡️ Yes.\n```\nUnclosed example",
    "```\n~~~",
    "````\n```",
  ])("rejects the entire round for an unclosed fence", (text) => {
    expect(() => parseGrillingRound(text)).toThrow("Unclosed code fence");
  });
  it("retains closing remarks as recommendation content unless separated explicitly", () => {
    const closing = "Please answer this round.";
    expect(parseGrillingRound(round + "\n" + closing).at(-1)?.recommendation).toBe(
      "Add a confirmation step.\n" + closing,
    );
    expect(parseGrillingRound(round + "\n---\n" + closing)).toEqual(questions);
  });
  it("rejects missing recommendations and duplicate identifiers", () => {
    expect(() => parseGrillingRound("❓ Q1 - Question?")).toThrow("missing");
    expect(() => parseGrillingRound(round.replace("Q2", "Q1"))).toThrow("Duplicate");
    expect(parseGrillingRound("An ordinary response?")).toEqual([]);
    expect(() =>
      parseGrillingRound(round + "\n---\n❓ **Qthree** - Another question?\n➡️ Yes."),
    ).toThrow("Unsupported grilling question format");
  });
});

describe("GrillingAnswerComponent", () => {
  it("accepts recommendations with Enter but waits for a final confirmation", () => {
    const { ui, done } = component();
    ui.handleInput("\r");
    ui.handleInput("\r");
    expect(done).not.toHaveBeenCalled();
    const preview = ui.render(120).join("\n");
    expect(preview).toContain("Review this round's answers");
    for (const q of questions) {
      expect(preview).toContain(`${q.id}: ${q.question}`);
      expect(preview).toContain(`Recommendation: ${q.recommendation}`);
    }
    expect(preview).toContain("Answer: Yes");
    ui.handleInput("\r");
    expect(done).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes");
  });
  it("does not accept skipped blank questions through Tab", () => {
    const { ui, done } = component();
    ui.handleInput("\t");
    ui.handleInput("\r");
    expect(ui.render(80).join("\n")).toContain("Grilling (1/2)");
    expect(done).not.toHaveBeenCalled();
  });
  it("preserves custom answers across navigation and allows review edits", () => {
    const { ui, done } = component();
    ui.handleInput("No, support dsh first.");
    ui.handleInput("\r");
    ui.handleInput("\r");
    ui.handleInput("\x1b");
    expect(ui.render(80).join("\n")).not.toContain("Review this round's answers");
    ui.handleInput("\r");
    ui.handleInput("\r");
    expect(done.mock.calls[0][0]).toBe("Q1: No, support dsh first.\n\nQ2: Yes");
  });
  it("cancels without submitting", () => {
    const { ui, done } = component();
    ui.handleInput("\x1b");
    expect(done).toHaveBeenCalledWith(null);
  });
  it.each([10, 40, 80, 120])("fits rendered lines to width %i", (width) => {
    const { ui } = component();
    expect(ui.render(width).every((line) => visibleWidth(line) <= width)).toBe(true);
  });
});

it("separates answers with a blank line without indenting multiline content", () => {
  expect(
    formatGrillingAnswers(questions, [
      "  First line\nQ2: mentioned in this answer\nMore details  ",
      " Yes ",
    ]),
  ).toBe("Q1: First line\nQ2: mentioned in this answer\nMore details\n\nQ2: Yes");
});

it("rejects incomplete answer collections", () => {
  expect(() => formatGrillingAnswers(questions, ["yes", ""])).toThrow("every question");
  expect(() => formatGrillingAnswers(questions, ["yes"])).toThrow("every question");
});

it("preserves long question and recommendation content in both views", () => {
  const question = Array.from({ length: 100 }, (_, i) => `question-${i}`).join("\n");
  const recommendation = Array.from({ length: 100 }, (_, i) => `recommendation-${i}`).join("\n");
  const theme = { fg: (_: string, text: string) => text, bold: (text: string) => text } as Theme;
  const tui = { requestRender: vi.fn(), terminal: { rows: 24, columns: 80 } } as unknown as TUI;
  const ui = new GrillingAnswerComponent(
    [{ id: "Q1", question, recommendation }],
    tui,
    theme,
    vi.fn(),
    keybindings,
  );
  for (const reviewing of [false, true]) {
    if (reviewing) ui.handleInput("\r");
    const lines = ui.render(40);
    expect(lines.length).toBeGreaterThan(200);
    const text = lines.join("\n");
    for (let i = 0; i < 100; i++) {
      expect(text).toContain(`question-${i}`);
      expect(text).toContain(`recommendation-${i}`);
    }
    expect(lines.every((line) => visibleWidth(line) <= 40)).toBe(true);
  }
});

it("returns from review to the first or last question without losing answers", () => {
  const { ui, done } = component();
  ui.handleInput("\r");
  ui.handleInput("\r");
  ui.handleInput("\t");
  expect(ui.render(80).join("\n")).toContain("Grilling (1/2)");
  ui.handleInput("\r");
  ui.handleInput("\r");
  ui.handleInput("\x1b[Z");
  expect(ui.render(80).join("\n")).toContain("Grilling (2/2)");
  ui.handleInput("\r");
  ui.handleInput("\r");
  expect(done).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes");
});

function commandFixture() {
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  const sendUserMessage = vi.fn();
  const registerCommand = vi.fn((_name: string, options: typeof command) => {
    command = options;
  });
  grillingAnswer({
    registerCommand,
    sendUserMessage,
  } as unknown as ExtensionAPI);
  const state = { sessionId: "session", leafId: "leaf", idle: true };
  const entry = {
    id: "assistant",
    type: "message",
    message: { role: "assistant", stopReason: "stop", content: [{ type: "text", text: round }] },
  };
  const notify = vi.fn();
  const custom = vi.fn(async (..._args: unknown[]): Promise<string | null> => "Q1: Yes\n\nQ2: Yes");
  const ctx = {
    mode: "tui",
    isIdle: () => state.idle,
    sessionManager: {
      getSessionId: () => state.sessionId,
      getLeafId: () => state.leafId,
      getBranch: () => [entry],
    },
    ui: { notify, custom },
  } as unknown as ExtensionCommandContext;
  return {
    registerCommand,
    run: () => command!.handler("", ctx),
    state,
    entry,
    ctx,
    notify,
    custom,
    sendUserMessage,
  };
}

describe("answer-grilling command", () => {
  it("sends only the answers when the session is unchanged", async () => {
    const fixture = commandFixture();
    expect(fixture.registerCommand).toHaveBeenCalledWith("answer-grilling", expect.any(Object));
    await fixture.run();
    expect(fixture.sendUserMessage).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes", {
      deliverAs: "followUp",
    });
  });
  it.each(["sessionId", "leafId", "idle"] as const)(
    "does not submit when %s changes",
    async (key) => {
      const fixture = commandFixture();
      fixture.custom.mockImplementation(async () => {
        if (key === "idle") fixture.state.idle = false;
        else fixture.state[key] = "changed";
        return "Q1: Yes\n\nQ2: Yes";
      });
      await fixture.run();
      expect(fixture.sendUserMessage).not.toHaveBeenCalled();
      expect(fixture.notify).toHaveBeenCalledWith(
        expect.stringContaining("Reopen /answer-grilling"),
        "warning",
      );
    },
  );
  it("does not send anything on cancellation", async () => {
    const fixture = commandFixture();
    fixture.custom.mockResolvedValue(null);
    await fixture.run();
    expect(fixture.sendUserMessage).not.toHaveBeenCalled();
  });
  it("rejects a round with an unclosed example rather than opening a partial questionnaire", async () => {
    const fixture = commandFixture();
    fixture.entry.message.content[0].text = round + "\n---\n```\n❓ Q3 - Hidden?\n➡️ Yes.";
    await fixture.run();
    expect(fixture.custom).not.toHaveBeenCalled();
    expect(fixture.sendUserMessage).not.toHaveBeenCalled();
    expect(fixture.notify).toHaveBeenCalledWith(
      "Unclosed code fence in the grilling round",
      "error",
    );
  });
  it("rejects malformed rounds with an English error", async () => {
    const fixture = commandFixture();
    fixture.entry.message.content[0].text = "❓ Q1 - Question?";
    await fixture.run();
    expect(fixture.custom).not.toHaveBeenCalled();
    expect(fixture.notify).toHaveBeenCalledWith(
      "Q1 is missing its question or ➡️ recommendation",
      "error",
    );
  });
});

describe("Ctrl+G built-in editing", () => {
  it("opens the external editor directly and preserves edited text across navigation", () => {
    const open = vi
      .spyOn(ExtensionEditorComponent.prototype, "handleInput")
      .mockImplementation(function (this: ExtensionEditorComponent, data: string) {
        expect(data).toBe("\x07");
        const editor = this.children.find((child): child is Editor => child instanceof Editor)!;
        expect(editor.getText()).toBe("Second draft");
        editor.setText("Edited answer\nwith details");
      });
    try {
      const { ui, done } = component();
      ui.handleInput("First draft");
      ui.handleInput("\t");
      ui.handleInput("Second draft");
      ui.handleInput("\x07");
      expect(open).toHaveBeenCalledOnce();
      expect(done).not.toHaveBeenCalled();
      expect(ui.render(120).join("\n")).toContain("Grilling (2/2)");
      ui.handleInput("\x1b[Z");
      ui.handleInput("\t");
      ui.handleInput("\r");
      expect(done).not.toHaveBeenCalled();
      ui.handleInput("\r");
      expect(done).toHaveBeenCalledWith("Q1: First draft\n\nQ2: Edited answer\nwith details");
    } finally {
      open.mockRestore();
    }
  });
  it("uses the configured external-editor shortcut", () => {
    const open = vi
      .spyOn(ExtensionEditorComponent.prototype, "handleInput")
      .mockImplementation(() => {});
    try {
      const { ui } = component({
        matches: (data: string, action: string) =>
          action === "app.editor.external" && data === "\x05",
        getKeys: () => ["ctrl+e", "alt+e"],
      } as unknown as KeybindingsManager);
      const hint = ui.render(160).join("\n");
      expect(hint).toContain("ctrl+e/alt+e external editor");
      expect(hint).not.toContain("ctrl+g");
      ui.handleInput("\x05");
      expect(open).toHaveBeenCalledWith("\x05");
    } finally {
      open.mockRestore();
    }
  });
  it("omits the external-editor hint when no shortcut is bound", () => {
    const { ui } = component({
      matches: () => false,
      getKeys: () => [],
    } as unknown as KeybindingsManager);
    expect(ui.render(160).join("\n")).not.toContain("external editor");
  });
  it("does not open an editor on the review screen", () => {
    const open = vi
      .spyOn(ExtensionEditorComponent.prototype, "handleInput")
      .mockImplementation(() => {});
    try {
      const { ui, done } = component();
      ui.handleInput("\r");
      ui.handleInput("\r");
      ui.handleInput("\x07");
      expect(open).not.toHaveBeenCalled();
      expect(done).not.toHaveBeenCalled();
    } finally {
      open.mockRestore();
    }
  });
});
