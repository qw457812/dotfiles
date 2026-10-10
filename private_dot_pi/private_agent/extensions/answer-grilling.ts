/**
 * Answer grilling's numbered frontier rounds without a model-based extraction call.
 * Long rounds may be clipped by Pi's fullscreen layout; use regular mode to read them.
 *
 * https://github.com/mattpocock/skills/blob/95249b0b49782349740fd9b8c6ce32b4e59e497a/skills/productivity/grilling/SKILL.md
 */
import {
  ExtensionEditorComponent,
  type KeybindingsManager,
  SettingsManager,
  type ExtensionAPI,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import {
  Editor,
  Key,
  matchesKey,
  truncateToWidth,
  wrapTextWithAnsi,
  type Component,
  type Focusable,
  type TUI,
} from "@earendil-works/pi-tui";

export interface GrillingQuestion {
  id: string;
  question: string;
  recommendation: string;
}

/** Ignore example rounds in fenced code; reject partial rounds rather than silently dropping decisions. */
export function parseGrillingRound(text: string): GrillingQuestion[] {
  const questions: GrillingQuestion[] = [];
  let current:
    | { id: string; body: string[]; recommendation: string[] | null; ended: boolean }
    | undefined;
  let fence: string | undefined;
  const finish = () => {
    if (!current) return;
    const question = current.body.join("\n").trim();
    const recommendation = current.recommendation?.join("\n").trim();
    if (!question || !recommendation)
      throw new Error(`${current.id} is missing its question or ➡️ recommendation`);
    if (questions.some((q) => q.id === current!.id))
      throw new Error(`Duplicate question ID: ${current.id}`);
    questions.push({ id: current.id, question, recommendation });
  };

  for (const line of text.replace(/\r\n/g, "\n").split("\n")) {
    const marker = line.match(/^\s*(`{3,}|~{3,})/);
    const inFence = fence !== undefined;
    if (marker) {
      if (!fence) fence = marker[1];
      else if (
        marker[1][0] === fence[0] &&
        marker[1].length >= fence.length &&
        line.slice(marker[0].length).trim() === ""
      )
        fence = undefined;
    }
    const header =
      !inFence && !marker
        ? line.match(/^\s*❓\s*(?:\*\*)?(Q\d+)(?:\*\*)?\s*[-–—:]\s*(.*)$/i)
        : null;
    if (header) {
      finish();
      current = {
        id: header[1].toUpperCase(),
        body: [header[2]],
        recommendation: null,
        ended: false,
      };
      continue;
    }
    if (!inFence && !marker && /^\s*❓/.test(line)) {
      throw new Error("Unsupported grilling question format. Expected ❓ Qn - question.");
    }
    if (!current || current.ended) continue;
    // Recommendation content ends only at a separator, the next question, or EOF.
    const recommended = !inFence && !marker ? line.match(/^\s*➡\uFE0F?\s*(.*)$/) : null;
    if (recommended && current.recommendation === null) {
      current.recommendation = [recommended[1]];
    } else if (
      !inFence &&
      !marker &&
      current.recommendation &&
      /^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/.test(line)
    ) {
      current.ended = true;
    } else {
      (current.recommendation ?? current.body).push(line);
    }
  }
  if (fence) throw new Error("Unclosed code fence in the grilling round");
  finish();
  return questions;
}

export function formatGrillingAnswers(questions: GrillingQuestion[], answers: string[]): string {
  if (questions.length !== answers.length || answers.some((a) => !a.trim())) {
    throw new Error("Answer every question in this round before submitting");
  }
  return questions.map((q, i) => `${q.id}: ${answers[i].trim()}`).join("\n\n");
}

export class GrillingAnswerComponent implements Component, Focusable {
  private index = 0;
  private reviewing = false;
  private answers: string[];
  private editor: Editor;
  private builtInEditor: ExtensionEditorComponent;
  private hasFocus = false;

  constructor(
    private questions: GrillingQuestion[],
    private tui: TUI,
    private theme: Theme,
    private done: (result: string | null) => void,
    private keybindings: KeybindingsManager,
    externalEditorCommand?: string,
  ) {
    this.answers = questions.map(() => "");
    this.builtInEditor = new ExtensionEditorComponent(
      tui,
      keybindings,
      "",
      "",
      () => {},
      () => this.done(null),
      undefined,
      externalEditorCommand,
    );
    // Reuse the built-in Editor child and Ctrl+G behavior, without its dialog chrome.
    const editor = this.builtInEditor.children.find(
      (child): child is Editor => child instanceof Editor,
    );
    if (!editor) throw new Error("Pi's built-in editor component has no Editor child");
    this.editor = editor;
    this.editor.disableSubmit = true;
    this.editor.onChange = () => this.tui.requestRender();
  }

  get focused(): boolean {
    return this.hasFocus;
  }
  set focused(value: boolean) {
    this.hasFocus = value;
    this.editor.focused = value && !this.reviewing;
  }

  invalidate(): void {
    this.editor.invalidate();
  }

  private navigate(index: number): void {
    if (!this.reviewing) this.answers[this.index] = this.editor.getText();
    this.index = Math.max(0, Math.min(index, this.questions.length - 1));
    this.reviewing = false;
    this.editor.setText(this.answers[this.index]);
    this.focused = this.hasFocus;
  }

  handleInput(data: string): void {
    if (!this.reviewing && this.keybindings.matches(data, "app.editor.external")) {
      this.builtInEditor.handleInput(data);
      return;
    }
    if (matchesKey(data, Key.ctrl("c"))) {
      this.done(null);
      return;
    }
    if (matchesKey(data, Key.escape)) {
      if (this.reviewing) this.navigate(this.index);
      else {
        this.done(null);
        return;
      }
    } else if (matchesKey(data, Key.tab)) {
      this.navigate(this.reviewing ? 0 : this.index + 1);
    } else if (matchesKey(data, Key.shift("tab"))) {
      this.navigate(this.reviewing ? this.questions.length - 1 : this.index - 1);
    } else if (matchesKey(data, Key.enter) && !matchesKey(data, Key.shift("enter"))) {
      if (this.reviewing) {
        this.done(formatGrillingAnswers(this.questions, this.answers));
        return;
      }
      // Only explicit Enter accepts a recommendation; Tab never settles an unanswered decision.
      this.answers[this.index] = this.editor.getText().trim() || "Yes";
      this.editor.setText(this.answers[this.index]);
      if (this.index < this.questions.length - 1) this.navigate(this.index + 1);
      else {
        const missing = this.answers.findIndex((a) => !a.trim());
        if (missing >= 0) this.navigate(missing);
        else {
          this.reviewing = true;
          this.focused = this.hasFocus;
        }
      }
    } else if (!this.reviewing) {
      this.editor.handleInput(data);
    }
    this.tui.requestRender();
  }

  render(width: number): string[] {
    width = Math.max(1, width);
    const lines: string[] = [];
    const add = (text: string) => lines.push(...wrapTextWithAnsi(text, width));
    add(
      this.theme.fg(
        "accent",
        this.theme.bold(`Grilling (${this.index + 1}/${this.questions.length})`),
      ),
    );
    if (this.reviewing) {
      add(this.theme.fg("accent", "Review this round's answers"));
      for (let i = 0; i < this.questions.length; i++) {
        const q = this.questions[i];
        lines.push("");
        add(`${q.id}: ${q.question}`);
        add(this.theme.fg("success", `Recommendation: ${q.recommendation}`));
        add(`Answer: ${this.answers[i]}`);
      }
      lines.push("");
      add(
        this.theme.fg(
          "dim",
          "Enter submit · Tab first question · Shift+Tab last question · Esc back · Ctrl+C cancel",
        ),
      );
    } else {
      const q = this.questions[this.index];
      add(`${q.id}: ${q.question}`);
      lines.push("");
      add(this.theme.fg("success", `➡️ ${q.recommendation}`));
      lines.push("");
      add(
        this.theme.fg(
          "muted",
          "Your answer (leave blank and press Enter to accept the recommendation):",
        ),
      );
      lines.push(...this.editor.render(width).map((line) => truncateToWidth(line, width)));
      const externalKeys = this.keybindings.getKeys("app.editor.external").join("/");
      add(
        this.theme.fg(
          "dim",
          `Enter accept/next · Tab/Shift+Tab navigate · Shift+Enter newline${externalKeys ? ` · ${externalKeys} external editor` : ""} · Esc cancel`,
        ),
      );
    }
    return lines;
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("answer-grilling", {
    description: "Answer a grilling round with recommendations or custom answers",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("answer-grilling requires interactive mode", "error");
        return;
      }
      if (!ctx.isIdle()) {
        ctx.ui.notify("Wait for the current response to finish", "warning");
        return;
      }
      const sessionId = ctx.sessionManager.getSessionId();
      const leafId = ctx.sessionManager.getLeafId();
      const entry = [...ctx.sessionManager.getBranch()]
        .reverse()
        .find((e) => e.type === "message" && e.message.role === "assistant");
      if (!entry || entry.type !== "message" || entry.message.role !== "assistant") {
        ctx.ui.notify("No assistant response found", "info");
        return;
      }
      if (entry.message.stopReason !== "stop") {
        ctx.ui.notify("The latest assistant response is incomplete", "warning");
        return;
      }
      const text = entry.message.content
        .filter((c) => c.type === "text")
        .map((c) => c.text)
        .join("\n");
      let questions: GrillingQuestion[];
      try {
        questions = parseGrillingRound(text);
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
        return;
      }
      if (!questions.length) {
        ctx.ui.notify("No grilling questions found in the latest response (❓ Qn / ➡️)", "info");
        return;
      }
      const result = await ctx.ui.custom<string | null>(
        (tui, theme, keybindings, done) =>
          new GrillingAnswerComponent(
            questions,
            tui,
            theme,
            done,
            keybindings,
            SettingsManager.create(ctx.cwd).getExternalEditorCommand(),
          ),
      );
      if (result === null) return;
      if (
        ctx.sessionManager.getSessionId() !== sessionId ||
        ctx.sessionManager.getLeafId() !== leafId ||
        !ctx.isIdle()
      ) {
        ctx.ui.notify(
          "The session or round has changed. Reopen /answer-grilling before submitting.",
          "warning",
        );
        return;
      }
      pi.sendUserMessage(result, { deliverAs: "followUp" });
    },
  });
}
