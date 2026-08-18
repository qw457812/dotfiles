/**
 * Auto-sync chezmoi source <-> target after dsh file edits:
 *   source -> `chezmoi apply`;  target -> `chezmoi re-add`.
 * Commands run under an explicit danger-full-access sandbox policy.
 * @module dsh-plugin-chezmoi
 * @ts-check
 */

import { homedir } from "node:os";
import { isAbsolute, relative, resolve } from "node:path";

/** @typedef {import("@deepseek-ai/cordis").Context} Context */
/** @typedef {import("@deepseek-ai/dsh-shell").ShellExecutor} ShellExecutor */
/** @typedef {import("@deepseek-ai/dsh-shell").ShellRunResult} ShellRunResult */
/** @typedef {import("@deepseek-ai/dsh-sandbox-policy").SandboxPolicyService} SandboxPolicyService */
/** @typedef {import("@deepseek-ai/dsh-tools").ToolExecution} ToolExecution */
/** @typedef {import("@deepseek-ai/dsh-tools").ToolExecutionResult} ToolExecutionResult */

const name = "chezmoi";
const inject = ["shell", "sandboxPolicy"];

/**
 * Single-quote one argument for `bash -c` (POSIX `'\''` escaping).
 * @param {unknown} value
 */
function shellQuote(value) {
  return `'${String(value).replaceAll("'", `'\\''`)}'`;
}

/**
 * @param {string} parent
 * @param {string} child
 */
function isSubpath(parent, child) {
  const rel = relative(parent, child);
  return rel !== "" && !rel.startsWith("..") && !isAbsolute(rel);
}

/**
 * @param {Context} ctx
 * @param {readonly string[]} args
 * @returns {Promise<ShellRunResult | undefined>}
 */
async function runChezmoi(ctx, args) {
  /** @type {ShellExecutor | undefined} */
  const shell = ctx.get("shell");
  /** @type {SandboxPolicyService | undefined} */
  const policy = ctx.get("sandboxPolicy");
  if (shell === undefined || policy === undefined) return undefined;
  try {
    const spec = shell.resolve({
      command: `chezmoi ${args.map(shellQuote).join(" ")}`,
      workdir: homedir(),
      sandboxPolicy: policy.resolve({ mode: "danger-full-access" }),
    });
    return await shell.run(spec);
  } catch {
    return undefined;
  }
}

/**
 * Source edited -> apply to target.
 * @param {Context} ctx
 * @param {string} sourcePath
 */
async function chezmoiApply(ctx, sourcePath) {
  const targetResult = await runChezmoi(ctx, ["target-path", sourcePath]);
  if (targetResult === undefined || targetResult.exitCode !== 0) return;

  const targetPath = targetResult.stdout.text.trim();
  if (!targetPath) return;

  const managedResult = await runChezmoi(ctx, ["managed", targetPath]);
  // File not managed by chezmoi (or the run was cut short)
  if (
    managedResult === undefined ||
    managedResult.exitCode !== 0 ||
    !managedResult.stdout.text.trim()
  )
    return;

  const applyResult = await runChezmoi(ctx, ["apply", "--no-tty", targetPath]);
  if (applyResult === undefined || applyResult.exitCode === 0) return;

  const message =
    applyResult.stderr.text.trim() ||
    `chezmoi exited with code ${applyResult.exitCode ?? "signal"}`;
  ctx.logger.warn(`chezmoi apply failed: ${message}`);
}

/**
 * Target edited -> re-add to source.
 * @param {Context} ctx
 * @param {string} targetPath
 */
async function chezmoiReAdd(ctx, targetPath) {
  const sourceResult = await runChezmoi(ctx, ["source-path", targetPath]);
  // File not managed by chezmoi (or the run was cut short)
  if (sourceResult === undefined || sourceResult.exitCode !== 0) return;

  const sourcePath = sourceResult.stdout.text.trim();
  if (!sourcePath) return;

  const reAddResult = await runChezmoi(ctx, ["re-add", "--no-tty", targetPath]);
  if (reAddResult === undefined || reAddResult.exitCode === 0) return;

  const message =
    reAddResult.stderr.text.trim() ||
    `chezmoi exited with code ${reAddResult.exitCode ?? "signal"}`;
  ctx.logger.warn(`chezmoi re-add failed: ${message}`);
}

/** @param {Context} ctx */
function apply(ctx) {
  /** @type {string | null} */
  let sourceDir = null;
  let queue = Promise.resolve();

  /**
   * Resolve the chezmoi source dir once, as the queue head (never rejects).
   * @returns {Promise<void>}
   */
  async function ensureSourceDir() {
    const result = await runChezmoi(ctx, ["source-path"]);
    sourceDir =
      result !== undefined && result.exitCode === 0 && result.stdout.text.trim() !== ""
        ? result.stdout.text.trim()
        : null;
    if (sourceDir === null) {
      ctx.logger.warn(
        "chezmoi: cannot resolve the chezmoi source directory (`chezmoi source-path` failed); auto-sync disabled",
      );
    }
  }

  /**
   * @param {ToolExecution} exec
   * @param {ToolExecutionResult} result
   * @returns {undefined}
   */
  const onToolResult = (exec, result) => {
    if (result.isError || (exec.name !== "write" && exec.name !== "edit")) return;
    const requestedPath = /** @type {{ file_path?: unknown } | null | undefined} */ (exec.arguments)
      ?.file_path;
    if (typeof requestedPath !== "string") return;
    const cwd = exec.agent?.session?.header?.cwd;
    if (typeof cwd !== "string") return;

    const filePath = resolve(cwd, requestedPath);
    const run = async () => {
      if (sourceDir === null) return;
      if (isSubpath(sourceDir, filePath)) await chezmoiApply(ctx, filePath);
      else await chezmoiReAdd(ctx, filePath);
    };

    const next = queue.then(run, run);
    queue = next.catch(() => {});
  };

  queue = ensureSourceDir();
  ctx.on("tools/result", onToolResult);
}

export { apply, inject, name };
