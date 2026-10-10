import {
  ExtensionEditorComponent,
  initTheme,
  type KeybindingsManager,
  type ExtensionAPI,
  type ExtensionCommandContext,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { Editor, stripTerminalSequences, type TUI, visibleWidth } from "@earendil-works/pi-tui";
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

// Original nonconforming assistant reply; the agent must rewrite it, not the parser.
const mixedChangesRound = `❓ **Q1 — 文件内混合改动**：如果同一个文件里既有本次提交相关、也有无关改动，你希望按 hunk 选择性暂存（例如 \`git add -p\`），对吗？

➡️ 是：只暂存相关 hunk。

---

❓ **Q2 — 无关改动**：无关改动应留在工作区，之后单独提交，而不是为了方便一起暂存，对吗？

➡️ 是：无关改动保持 unstaged。

---

❓ **Q3 — 新文件**：对于 untracked 文件，也只在它属于当前提交时才暂存，对吗？

➡️ 是：不自动把所有新文件都加入暂存区。`;

const keybindings = {
  matches: (data: string, action: string) => action === "app.editor.external" && data === "\x07",
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

function renderText(ui: GrillingAnswerComponent, width = 120): string {
  return ui
    .render(width)
    .map((line) => stripTerminalSequences(line).trimEnd())
    .join("\n");
}

describe("parseGrillingRound", () => {
  it("preserves numbered questions, choices and multiline recommendations", () => {
    expect(questions).toEqual([
      {
        id: "Q1",
        question: "**Q1** - **Scope**: Support Pi only?\n\nOptions: Pi / dsh.",
        recommendation: "Support Pi first.\nKeep the existing /answer command.",
      },
      {
        id: "Q2",
        question: "**Q2** - **Submission**: Require confirmation before submitting?",
        recommendation: "Add a confirmation step.",
      },
    ]);
  });
  it("rejects the original nonconforming round instead of repairing its Markdown", () => {
    expect(() => parseGrillingRound(mixedChangesRound)).toThrow("Ask the agent to rewrite it");
  });
  it.each([
    "**Q1 — Scope**: Use **Pi** and `**literal**`?",
    "**Q1 — Scope: Use Pi?**",
    "**Q1** — **Scope**: Use Pi?",
    "Q1 - **Scope**: Use Pi?",
    "**Q1** - Scope: Use Pi?",
    "**Q1**: Scope?",
    "**q1** - **Scope**: Use Pi?",
    "Q1 -",
    "**Q1** -",
    "**Q1** - ****: Use Pi?",
    "**Q1** - **Scope**：Use Pi?",
  ])("rejects headings that do not follow the skill format: %s", (heading) => {
    expect(() => parseGrillingRound("❓ " + heading + "\n➡️ Yes.")).toThrow(
      "Unsupported grilling question format",
    );
  });
  it("preserves conforming Chinese titles and body Markdown unchanged", () => {
    const question = "**Q1** - **文件内混合改动**: 使用 **Pi** 和 `**literal**`，对吗？";
    expect(parseGrillingRound("❓ " + question + "\n➡️ 使用 **Pi**。")).toEqual([
      { id: "Q1", question, recommendation: "使用 **Pi**。" },
    ]);
  });
  it.each(["Glob `*.ts`", "Literal `**value**`", "Escaped \\*"])(
    "preserves asterisks inside a conforming title: %s",
    (title) => {
      const question = `**Q1** - **${title}**: Use this pattern?`;
      expect(parseGrillingRound("❓ " + question + "\n➡️ Yes.")).toEqual([
        { id: "Q1", question, recommendation: "Yes." },
      ]);
    },
  );
  it("keeps headings and multiline question bodies unchanged", () => {
    expect(parseGrillingRound("❓ **Q1** - **Scope**:\nUse Pi?\n\n- Pi\n- dsh\n➡️ Yes.")).toEqual([
      { id: "Q1", question: "**Q1** - **Scope**:\nUse Pi?\n\n- Pi\n- dsh", recommendation: "Yes." },
    ]);
  });
  it("ignores fenced examples and permits CRLF and arrows without variation selectors", () => {
    expect(
      parseGrillingRound(
        "```markdown\n" +
          round +
          "\n```\n❓ **Q7** - **Option**: Which option?\r\n➡ Recommended option.\r\n---\r\nClosing remarks",
      ),
    ).toEqual([
      {
        id: "Q7",
        question: "**Q7** - **Option**: Which option?",
        recommendation: "Recommended option.",
      },
    ]);
  });
  it("keeps fenced question content without treating it as another question", () => {
    const parsed = parseGrillingRound(
      "❓ **Q1** - **Example**: Show code?\n```\n❓ Q2 - example\n```\n➡️ Yes.",
    );
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
        "❓ **Q1** - **Example**: Show code?\n➡️ Use this example:\n```text\n```not-a-closing-fence\n❓ Q2 - Not a real question\n````",
      ),
    ).toEqual([
      {
        id: "Q1",
        question: "**Q1** - **Example**: Show code?",
        recommendation:
          "Use this example:\n```text\n```not-a-closing-fence\n❓ Q2 - Not a real question\n````",
      },
    ]);
  });
  it.each([
    "```text\n❓ Q1 - Hidden?\n➡️ Yes.",
    round + "\n---\n~~~text\n❓ Q3 - Hidden?\n➡️ Yes.",
    "❓ **Q1** - **Example**: Show code?\n➡️ Yes.\n```\nUnclosed example",
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
    expect(() => parseGrillingRound("❓ **Q1** - **Scope**: Use Pi?")).toThrow("missing");
    expect(() => parseGrillingRound(round.replace("Q2", "Q1"))).toThrow("Duplicate");
    expect(parseGrillingRound("An ordinary response?")).toEqual([]);
    expect(() =>
      parseGrillingRound(round + "\n---\n❓ **Qthree** - Another question?\n➡️ Yes."),
    ).toThrow("Unsupported grilling question format");
  });
});

describe("GrillingAnswerComponent", () => {
  it("renders conforming titles without duplicated question IDs in both views", () => {
    const theme = { fg: (_: string, text: string) => text, bold: (text: string) => text } as Theme;
    const done = vi.fn();
    const ui = new GrillingAnswerComponent(
      parseGrillingRound(
        "❓ **Q1** - **Scope**: Use Pi?\n➡️ Yes.\n---\n❓ **Q2** - **Review**: Confirm?\n➡️ Yes.",
      ),
      { requestRender: vi.fn(), terminal: { rows: 24, columns: 80 } } as unknown as TUI,
      theme,
      done,
      keybindings,
    );
    const titles = ["Q1 - Scope: Use Pi?", "Q2 - Review: Confirm?"];
    for (const title of titles) {
      const text = renderText(ui);
      expect(text).toContain(title);
      expect(text).not.toMatch(/^Q\d+:$/m);
      expect(text).not.toContain("**");
      ui.handleInput("\r");
    }
    const review = renderText(ui);
    for (const title of titles) {
      expect(review).toContain(title);
    }
    expect(review).not.toMatch(/^Q\d+:$/m);
    expect(review).not.toContain("**");
    expect(review).toContain("Answer: Yes");
    expect(done).not.toHaveBeenCalled();
    ui.handleInput("\r");
    expect(done).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes");
  });
  it("accepts recommendations with Enter but waits for a final confirmation", () => {
    const { ui, done } = component();
    ui.handleInput("\r");
    ui.handleInput("\r");
    expect(done).not.toHaveBeenCalled();
    const preview = renderText(ui);
    expect(preview).toContain("Review answers (2/2)");
    for (const q of questions) {
      expect(preview).toContain(q.question.replace(/\*\*/g, ""));
      expect(preview).toContain(`Recommendation:\n${q.recommendation}`);
    }
    expect(preview).toContain("Answer: Yes\n");
    expect(preview).not.toContain(" — accept recommendation");
    expect(preview).toContain("Enter send · Tab/Shift+Tab edit · Esc back · Ctrl+C cancel");
    ui.handleInput("\r");
    expect(done).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes");
  });
  it("does not accept skipped blank questions through Tab", () => {
    const { ui, done } = component();
    ui.handleInput("\t");
    ui.handleInput("\r");
    expect(renderText(ui)).toContain("Grilling (1/2) (1 Answered)");
    expect(done).not.toHaveBeenCalled();
  });
  it("preserves custom answers across navigation and allows review edits", () => {
    const { ui, done } = component();
    ui.handleInput("No, support dsh first.");
    ui.handleInput("\r");
    ui.handleInput("\r");
    ui.handleInput("\x1b");
    expect(renderText(ui)).not.toContain("Review answers");
    ui.handleInput("\r");
    ui.handleInput("\r");
    expect(done.mock.calls[0][0]).toBe("Q1: No, support dsh first.\n\nQ2: Yes");
  });
  it("cancels without submitting", () => {
    const { ui, done } = component();
    ui.handleInput("\x1b");
    expect(done).toHaveBeenCalledWith(null);
  });
  it("updates completion progress from live drafts without accepting skipped questions", () => {
    const { ui } = component();
    expect(renderText(ui)).toContain("(0 Answered)");
    ui.handleInput("x");
    expect(renderText(ui)).toContain("(1 Answered)");
    ui.handleInput("\t");
    expect(renderText(ui)).toContain("Grilling (2/2) (1 Answered)");
    ui.handleInput("x");
    expect(renderText(ui)).toContain("(2 Answered)");
    ui.handleInput("\x7f");
    expect(renderText(ui)).toContain("(1 Answered)");
    ui.handleInput("\x1b[Z");
    ui.handleInput("\x7f");
    expect(renderText(ui)).toContain("(0 Answered)");
  });
  it("shows compact static shortcuts for blank drafts, custom answers and skipped questions", () => {
    const { ui } = component();
    for (const input of ["", "\t", "Custom answer", "\r"]) {
      if (input) ui.handleInput(input);
      const text = renderText(ui);
      expect(text).toContain("Your answer (leave blank to accept the recommendation):");
      expect(text).toContain("Enter accept · Tab/Shift+Tab navigate · Esc cancel");
      expect(text).not.toContain("Shift+Enter newline");
      expect(text).not.toContain("Ctrl+G external editor");
    }
    expect(renderText(ui)).toContain("Grilling (1/2) (1 Answered)");
  });
  it("renders Markdown in both views while keeping answers and submission as plain text", () => {
    const question = "# Choose a scope\n\n- **Pi**\n- dsh\n\n```text\n**literal code**\n```";
    const recommendation = "Use **Pi** and `TypeScript`.\n\n- Keep /answer\n- Require review";
    const content = [{ id: "Q1", question, recommendation }];
    const theme = { fg: (_: string, text: string) => text, bold: (text: string) => text } as Theme;
    const done = vi.fn();
    const ui = new GrillingAnswerComponent(
      content,
      { requestRender: vi.fn(), terminal: { rows: 24, columns: 80 } } as unknown as TUI,
      theme,
      done,
      keybindings,
    );
    ui.handleInput("**custom answer**\nSecond line");
    for (const review of [false, true]) {
      if (review) ui.handleInput("\r");
      const text = renderText(ui);
      expect(text).toContain("Choose a scope");
      expect(text).not.toContain("# Choose a scope");
      expect(text).not.toContain("**Pi**");
      expect(text).toContain("**literal code**");
      expect(text).toContain("Use Pi and TypeScript.");
      expect(text).toContain("Keep /answer");
      expect(text).toContain("Require review");
      expect(text).toContain("**custom answer**");
      expect(text).toContain("Second line");
      expect(done).not.toHaveBeenCalled();
    }
    ui.handleInput("\r");
    expect(done).toHaveBeenCalledWith("Q1: **custom answer**\nSecond line");
    expect(content).toEqual([{ id: "Q1", question, recommendation }]);
  });
  it("refreshes cached Markdown colors after theme changes", () => {
    const { ui } = component();
    const dark = ui.render(80).join("\n");
    try {
      initTheme("light");
      ui.invalidate();
      expect(ui.render(80).join("\n")).not.toBe(dark);
      expect(renderText(ui)).toContain("Scope: Support Pi only?");
    } finally {
      initTheme("dark");
    }
  });
  it.each([10, 40, 80, 120])(
    "wraps Markdown lists, tables, code and wide characters at width %i",
    (width) => {
      const theme = {
        fg: (_: string, text: string) => text,
        bold: (text: string) => text,
      } as Theme;
      const content =
        "**中文 🚀**\n\n- Long item with details\n\n| Option | Result |\n| --- | --- |\n| Pi | Supported |\n\n```text\nconst longIdentifier = 123456789;\n```";
      const ui = new GrillingAnswerComponent(
        [{ id: "Q1", question: content, recommendation: content }],
        { requestRender: vi.fn(), terminal: { rows: 24, columns: 80 } } as unknown as TUI,
        theme,
        vi.fn(),
        keybindings,
      );
      for (const review of [false, true]) {
        if (review) ui.handleInput("\r");
        const lines = ui.render(width);
        expect(lines.every((line) => visibleWidth(line) <= width)).toBe(true);
        const compact = lines.map(stripTerminalSequences).join("").replace(/\s/g, "");
        expect(compact).toContain("中文🚀");
        expect(compact).toContain("Longitemwithdetails");
        expect(compact).toContain("constlongIdentifier=123456789;");
      }
    },
  );
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
    const text = lines.map(stripTerminalSequences).join("\n");
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
  expect(renderText(ui)).toContain("Grilling (1/2) (2 Answered)");
  ui.handleInput("\r");
  ui.handleInput("\r");
  ui.handleInput("\x1b[Z");
  expect(renderText(ui)).toContain("Grilling (2/2) (2 Answered)");
  ui.handleInput("\r");
  ui.handleInput("\r");
  expect(done).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes");
});

function commandFixture() {
  let command: Parameters<ExtensionAPI["registerCommand"]>[1] | undefined;
  let shortcut: Parameters<ExtensionAPI["registerShortcut"]>[1] | undefined;
  const registerShortcut = vi.fn((_key: string, options: typeof shortcut) => {
    shortcut = options;
  });
  const sendUserMessage = vi.fn();
  const registerCommand = vi.fn((_name: string, options: typeof command) => {
    command = options;
  });
  grillingAnswer({
    registerCommand,
    registerShortcut,
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
    registerShortcut,
    run: () => command!.handler("", ctx),
    runShortcut: () => shortcut!.handler(ctx),
    state,
    entry,
    ctx,
    notify,
    custom,
    sendUserMessage,
  };
}

describe("answer-grilling command", () => {
  it("registers Alt+, and submits answers through the same workflow", async () => {
    const fixture = commandFixture();
    expect(fixture.registerShortcut).toHaveBeenCalledWith("alt+,", expect.any(Object));
    await fixture.runShortcut();
    expect(fixture.custom).toHaveBeenCalledOnce();
    expect(fixture.sendUserMessage).toHaveBeenCalledWith("Q1: Yes\n\nQ2: Yes", {
      deliverAs: "followUp",
    });
  });
  it("rejects the shortcut while a response is running", async () => {
    const fixture = commandFixture();
    fixture.state.idle = false;
    await fixture.runShortcut();
    expect(fixture.custom).not.toHaveBeenCalled();
    expect(fixture.sendUserMessage).not.toHaveBeenCalled();
    expect(fixture.notify).toHaveBeenCalledWith(
      "Wait for the current response to finish",
      "warning",
    );
  });
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
  it("rejects nonconforming rounds before opening the UI and asks the agent to rewrite them", async () => {
    const fixture = commandFixture();
    fixture.entry.message.content[0].text = round + "\n---\n" + mixedChangesRound;
    await fixture.run();
    expect(fixture.custom).not.toHaveBeenCalled();
    expect(fixture.sendUserMessage).not.toHaveBeenCalled();
    expect(fixture.notify).toHaveBeenCalledWith(
      expect.stringContaining("Ask the agent to rewrite it as ❓ **Qn** - **title**: question"),
      "error",
    );
  });
  it("rejects malformed rounds with an English error", async () => {
    const fixture = commandFixture();
    fixture.entry.message.content[0].text = "❓ **Q1** - **Scope**: Use Pi?";
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
      expect(renderText(ui)).toContain("Grilling (2/2) (2 Answered)");
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
      } as unknown as KeybindingsManager);
      const hint = ui.render(160).join("\n");
      expect(hint).not.toContain("Ctrl+G external editor");
      expect(hint).not.toContain("ctrl+e/alt+e");
      ui.handleInput("\x05");
      expect(open).toHaveBeenCalledWith("\x05");
    } finally {
      open.mockRestore();
    }
  });
  it("renders fixed hints without querying configured keybindings", () => {
    const getKeys = vi.fn();
    const { ui } = component({
      matches: () => false,
      getKeys,
    } as unknown as KeybindingsManager);
    expect(renderText(ui)).toContain("Enter accept · Tab/Shift+Tab navigate · Esc cancel");
    expect(getKeys).not.toHaveBeenCalled();
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
