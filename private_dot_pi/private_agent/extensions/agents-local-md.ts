/**
 * AGENTS.local.md Support
 *
 * Loads `AGENTS.local.md` files as extra project context, layered in addition to
 * (not instead of) the built-in `AGENTS.md` / `AGENTS.override.md` discovery.
 *
 * Semantics mirror pi's native context-file loading. Ported sources (pinned):
 * https://github.com/earendil-works/pi/blob/1355cd36e0b10a3e71c6c78f713b7b36458db27f/packages/coding-agent/src/
 * - core/resource-loader.ts — context-file walk, load order, dedupe, worktree shadowing
 * - core/footer-data-provider.ts — findGitPaths (.git dir, or .git file with gitdir: + commondir)
 * - utils/paths.ts — canonicalizePath (realpath with raw-path fallback)
 * - utils/text.ts — BOM stripping (only U+FEFF; inlined because it is unexported)
 * - core/system-prompt.ts — <project_context> / <project_instructions> rendering format
 *
 * Behavior:
 * - Files are loaded and cached when the session starts; changes take effect
 *   after `/reload`, restarting Pi, or replacing the session
 * - Global: `${PI_CODING_AGENT_DIR ?? ~/.pi/agent}/AGENTS.local.md`, loaded first
 * - Then `AGENTS.local.md` from each ancestor directory of cwd, nearest root first
 * - Deduped by raw path; BOM stripped; non-files and unreadable files skipped
 *   (with a warning), and the walk stops at the filesystem root
 * - Nested linked worktrees: when the worktree root has its own copy, the main
 *   repo's copy is shadowed (same logical repo scope, would double-apply), using
 *   the same gitdir/commondir detection as pi
 * - Honors `--no-context-files` / `-nc`
 *
 * Differences from `AGENTS.override.md`: the `.local` file is additive personal
 * context (typically gitignored) rather than a replacement for sibling files.
 * Intentional deviation: empty files are skipped.
 *
 * Pi's system prompt already wraps all loaded context files in a single
 * `<project_context>` block, so the `<project_instructions>` entries are injected
 * into that existing block (before its closing tag) instead of appending a second
 * wrapper. When no native block exists, one is appended — mirroring pi's formatting.
 */

import { type ExtensionAPI, getAgentDir } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync, realpathSync, statSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";

const LOCAL_CONTEXT_FILENAME = "AGENTS.local.md";

function canonicalizePath(path: string): string {
  try {
    return realpathSync(path);
  } catch {
    return path;
  }
}

function noContextFilesRequested(): boolean {
  const argv = process.argv;
  return argv.includes("--no-context-files") || argv.includes("-nc");
}

function loadLocalContextFileFromDir(dir: string): { path: string; content: string } | null {
  const filePath = join(dir, LOCAL_CONTEXT_FILENAME);
  if (!existsSync(filePath)) return null;
  try {
    if (!statSync(filePath).isFile()) return null;
    let content = readFileSync(filePath, "utf-8");
    if (content.charCodeAt(0) === 0xfeff) content = content.slice(1);
    if (!content.trim()) return null;
    return { path: filePath, content };
  } catch (error) {
    console.error(`Warning: Could not read ${filePath}: ${error}`);
    return null;
  }
}

/**
 * Find git metadata paths by walking up from cwd (ported from pi's
 * core/footer-data-provider.ts; see permalink above). Handles both regular repos
 * (.git directory) and worktrees (.git file with a `gitdir:` pointer and a `commondir` backlink).
 */
function findGitPaths(cwd: string): { repoDir: string; commonGitDir: string } | null {
  let dir = cwd;
  while (true) {
    const gitPath = join(dir, ".git");
    if (existsSync(gitPath)) {
      try {
        const stat = statSync(gitPath);
        if (stat.isFile()) {
          const content = readFileSync(gitPath, "utf8").trim();
          if (content.startsWith("gitdir: ")) {
            const gitDir = resolve(dir, content.slice(8).trim());
            if (!existsSync(join(gitDir, "HEAD"))) return null;
            const commonDirPath = join(gitDir, "commondir");
            const commonGitDir = existsSync(commonDirPath)
              ? resolve(gitDir, readFileSync(commonDirPath, "utf8").trim())
              : gitDir;
            return { repoDir: dir, commonGitDir };
          }
          // Malformed .git file (no gitdir: pointer): keep walking up, like pi.
        } else if (stat.isDirectory()) {
          if (!existsSync(join(gitPath, "HEAD"))) return null;
          return { repoDir: dir, commonGitDir: gitPath };
        }
      } catch {
        return null;
      }
    }
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
}

/**
 * The main repo's AGENTS.local.md that a nested linked worktree's own copy
 * shadows (ported from pi's resource-loader.ts): both occupy the same logical
 * repository scope, so loading both would apply that context twice. Returns the
 * shadowed main-repo path (canonicalized) only when cwd sits inside a linked
 * worktree that is itself nested under the main worktree root and carries its
 * own AGENTS.local.md.
 */
function findShadowedLocalContextFile(cwd: string): string | undefined {
  const gitPaths = findGitPaths(cwd);
  if (!gitPaths) return undefined;
  const commonGitDir = canonicalizePath(gitPaths.commonGitDir);
  const worktreeRoot = canonicalizePath(gitPaths.repoDir);
  const mainRepoRoot = dirname(commonGitDir);
  // Not true for an ordinary repo (same dir) or a sibling worktree, whose main
  // repo is not an ancestor of cwd.
  if (!worktreeRoot.startsWith(`${mainRepoRoot}${sep}`)) return undefined;
  // dirname of the common git dir must actually be the checked-out main repo.
  if (canonicalizePath(join(mainRepoRoot, ".git")) !== commonGitDir) return undefined;
  return loadLocalContextFileFromDir(worktreeRoot)
    ? join(mainRepoRoot, LOCAL_CONTEXT_FILENAME)
    : undefined;
}

function loadLocalContextFiles(cwd: string): Array<{ path: string; content: string }> {
  if (noContextFilesRequested()) return [];

  const contextFiles: Array<{ path: string; content: string }> = [];
  const seenPaths = new Set<string>();

  const globalContext = loadLocalContextFileFromDir(resolve(getAgentDir()));
  if (globalContext) {
    contextFiles.push(globalContext);
    seenPaths.add(globalContext.path);
  }

  const ancestorContextFiles: Array<{ path: string; content: string }> = [];

  const resolvedCwd = resolve(cwd);
  const shadowedContextFile = findShadowedLocalContextFile(resolvedCwd);
  let currentDir = resolvedCwd;

  while (true) {
    const localContextFile = loadLocalContextFileFromDir(currentDir);
    const isShadowed =
      shadowedContextFile !== undefined &&
      canonicalizePath(localContextFile?.path ?? "") === shadowedContextFile;
    if (localContextFile && !isShadowed && !seenPaths.has(localContextFile.path)) {
      ancestorContextFiles.unshift(localContextFile);
      seenPaths.add(localContextFile.path);
    }

    const parentDir = dirname(currentDir);
    if (parentDir === currentDir) break;
    currentDir = parentDir;
  }

  contextFiles.push(...ancestorContextFiles);

  return contextFiles;
}

function formatContextFilesForPrompt(files: Array<{ path: string; content: string }>): string {
  return files
    .map(
      ({ path: filePath, content }) =>
        `<project_instructions path="${filePath}">\n${content}\n</project_instructions>\n\n`,
    )
    .join("");
}

export default function (pi: ExtensionAPI) {
  let localContextFiles: Array<{ path: string; content: string }> = [];

  pi.on("before_agent_start", (event) => {
    if (localContextFiles.length === 0) return;

    const instructions = formatContextFilesForPrompt(localContextFiles);
    const closeTag = "</project_context>";
    const idx = event.systemPrompt.lastIndexOf(closeTag);
    if (idx === -1) {
      return {
        systemPrompt:
          event.systemPrompt +
          `\n\n<project_context>\n\nProject-specific instructions and guidelines:\n\n${instructions}${closeTag}\n`,
      };
    }
    return {
      systemPrompt: event.systemPrompt.slice(0, idx) + instructions + event.systemPrompt.slice(idx),
    };
  });

  pi.on("session_start", async (_event, ctx) => {
    localContextFiles = loadLocalContextFiles(ctx.cwd);
    if (localContextFiles.length > 0) {
      ctx.ui.notify(`Loaded ${localContextFiles.length} AGENTS.local.md file(s)`, "info");
    }
  });
}
