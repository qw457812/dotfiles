/**
 * Git Checkpoint Extension
 *
 * Snapshots the working tree (including untracked files) at each turn_end
 * via `git write-tree`, keyed by the leaf session entryId (the just-finished
 * assistant message). On /fork, prompts the user to restore the working tree
 * and staged state to that snapshot.
 */

import { stat, unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MAX_UNTRACKED_FILE_SIZE = 10 * 1024 * 1024;
const MAX_UNTRACKED_DIR_FILES = 200;
const IGNORED_DIR_NAMES = new Set([
	"node_modules",
	".venv",
	"venv",
	"env",
	".env",
	"dist",
	"build",
	".pytest_cache",
	".mypy_cache",
	".cache",
	".tox",
	"__pycache__",
]);

interface Checkpoint {
	branch: string;
	indexTree: string;
	worktreeTree: string;
	preexistingUntrackedFiles: string[];
	skippedLargeDirs: string[];
}

interface FilteredUntrackedFiles {
	files: string[];
	skippedLargeDirs: string[];
}

export default function (pi: ExtensionAPI) {
	const checkpoints = new Map<string, Checkpoint>();
	let gitDisabled = false;
	let gitChecked = false;

	async function ensureGit(ctx: {
		hasUI: boolean;
		ui: { notify: (m: string, l: "info" | "warning" | "error") => void };
	}) {
		if (gitChecked) return;
		gitChecked = true;
		try {
			const result = await pi.exec("git", ["rev-parse", "--git-dir"]);
			if (result.code === 0) return;
		} catch {
			// handled below
		}

		gitDisabled = true;
		if (ctx.hasUI)
			ctx.ui.notify("git-checkpoint disabled: not a git repository", "warning");
	}

	async function repoRoot(): Promise<string | undefined> {
		const { stdout, code } = await pi.exec("git", ["rev-parse", "--show-toplevel"]);
		return code === 0 ? stdout.trim() || undefined : undefined;
	}

	async function currentBranch(): Promise<string> {
		const { stdout, code } = await pi.exec("git", ["rev-parse", "--abbrev-ref", "HEAD"]);
		return code === 0 ? stdout.trim() || "unknown" : "unknown";
	}

	async function listUntrackedFiles(): Promise<string[]> {
		const { stdout, code } = await pi.exec("git", [
			"ls-files",
			"--others",
			"--exclude-standard",
			"-z",
		]);
		if (code !== 0 || !stdout) return [];
		return stdout.split("\0").filter(Boolean);
	}

	async function listUntrackedDirs(): Promise<string[]> {
		const { stdout, code } = await pi.exec("git", [
			"status",
			"--porcelain",
			"-z",
			"--untracked-files=normal",
		]);
		if (code !== 0 || !stdout) return [];
		return stdout
			.split("\0")
			.filter((entry) => entry.startsWith("?? ") && entry.endsWith("/"))
			.map((entry) => entry.slice(3, -1));
	}

	function shouldIgnoreForSnapshot(path: string): boolean {
		return path.split(/[/\\]/).some((part) => IGNORED_DIR_NAMES.has(part));
	}

	function isPathWithin(path: string, dir: string): boolean {
		if (!dir || dir === ".") return true;
		return path === dir || path.startsWith(`${dir}/`);
	}

	function isPathWithinAny(path: string, dirs: Set<string>): boolean {
		for (const dir of dirs) {
			if (isPathWithin(path, dir)) return true;
		}
		return false;
	}

	function detectLargeDirs(files: string[], dirs: string[]): string[] {
		const counts = new Map<string, number>();
		for (const dir of dirs) counts.set(dir, 0);

		for (const file of files) {
			for (const dir of dirs) {
				if (isPathWithin(file, dir)) counts.set(dir, (counts.get(dir) || 0) + 1);
			}
		}

		return [...counts.entries()]
			.filter(([, count]) => count >= MAX_UNTRACKED_DIR_FILES)
			.map(([dir]) => dir);
	}

	async function filterUntrackedFiles(
		root: string,
		files: string[],
		dirs: string[],
	): Promise<FilteredUntrackedFiles> {
		const skippedLargeDirs = detectLargeDirs(files, dirs);
		const skippedLargeDirSet = new Set(skippedLargeDirs);
		const filtered: string[] = [];

		for (const file of files) {
			if (shouldIgnoreForSnapshot(file)) continue;
			if (isPathWithinAny(file, skippedLargeDirSet)) continue;

			try {
				const s = await stat(join(root, file));
				if (s.isFile() && s.size > MAX_UNTRACKED_FILE_SIZE) continue;
			} catch {
				continue;
			}

			filtered.push(file);
		}

		return { files: filtered, skippedLargeDirs };
	}

	async function gitWithIndex(indexPath: string, args: string[]) {
		return pi.exec("bash", [
			"-c",
			'idx="$1"; shift; GIT_INDEX_FILE="$idx" git "$@"',
			"bash",
			indexPath,
			...args,
		]);
	}

	async function createSnapshot(): Promise<Checkpoint | undefined> {
		const [
			{ stdout: indexTreeOut, code: indexCode },
			branch,
			root,
			preexistingUntrackedFiles,
			untrackedDirs,
		] = await Promise.all([
			pi.exec("git", ["write-tree"]),
			currentBranch(),
			repoRoot(),
			listUntrackedFiles(),
			listUntrackedDirs(),
		]);
		if (indexCode !== 0 || !root) return undefined;

		const indexTree = indexTreeOut.trim();
		if (!indexTree) return undefined;

		const { files: untrackedFilesForSnapshot, skippedLargeDirs } =
			await filterUntrackedFiles(root, preexistingUntrackedFiles, untrackedDirs);

		// Use a temporary index so snapshotting never touches the user's staged state.
		// Start from the real index tree so staged additions are preserved, then add
		// tracked worktree changes and filtered untracked files into the temp index.
		const tmpIndex = join(
			tmpdir(),
			`pi-git-checkpoint-index-${process.pid}-${Date.now()}-${Math.random()
				.toString(36)
				.slice(2)}`,
		);

		try {
			let result = await gitWithIndex(tmpIndex, ["read-tree", indexTree]);
			if (result.code !== 0) return undefined;

			result = await gitWithIndex(tmpIndex, ["add", "-u"]);
			if (result.code !== 0) return undefined;

			const batchSize = 100;
			for (let i = 0; i < untrackedFilesForSnapshot.length; i += batchSize) {
				const batch = untrackedFilesForSnapshot.slice(i, i + batchSize);
				result = await gitWithIndex(tmpIndex, ["add", "--", ...batch]);
				if (result.code !== 0) return undefined;
			}

			const { stdout: worktreeTreeOut, code: worktreeCode } = await gitWithIndex(
				tmpIndex,
				["write-tree"],
			);
			if (worktreeCode !== 0) return undefined;

			const worktreeTree = worktreeTreeOut.trim();
			if (!worktreeTree) return undefined;

			return {
				branch,
				indexTree,
				worktreeTree,
				preexistingUntrackedFiles,
				skippedLargeDirs,
			};
		} finally {
			await unlink(tmpIndex).catch(() => {});
		}
	}

	async function cleanNewUntrackedFiles(checkpoint: Checkpoint): Promise<void> {
		const preexisting = new Set(checkpoint.preexistingUntrackedFiles);
		const skippedLargeDirs = new Set(checkpoint.skippedLargeDirs);
		const current = await listUntrackedFiles();
		const toRemove = current.filter(
			(path) =>
				!preexisting.has(path) &&
				!shouldIgnoreForSnapshot(path) &&
				!isPathWithinAny(path, skippedLargeDirs),
		);
		if (toRemove.length === 0) return;

		const batchSize = 100;
		for (let i = 0; i < toRemove.length; i += batchSize) {
			const batch = toRemove.slice(i, i + batchSize);
			await pi.exec("git", ["clean", "-f", "--", ...batch]);
		}
	}

	pi.on("turn_end", async (_event, ctx) => {
		await ensureGit(ctx);
		if (gitDisabled) return;

		const leaf = ctx.sessionManager.getLeafEntry();
		if (!leaf) return;

		try {
			const checkpoint = await createSnapshot();
			if (checkpoint) checkpoints.set(leaf.id, checkpoint);
		} catch {
			// snapshot failure is non-fatal; skip this turn
		}
	});

	pi.on("session_before_fork", async (event, ctx) => {
		if (!ctx.hasUI) return;

		const checkpoint = checkpoints.get(event.entryId);
		if (!checkpoint) return;

		const branch = await currentBranch();
		if (branch !== checkpoint.branch) {
			ctx.ui.notify(
				`Checkpoint was created on ${checkpoint.branch}, but current branch is ${branch}; not restoring code state.`,
				"warning",
			);
			return;
		}

		const choice = await ctx.ui.select("Restore code state?", [
			"Yes, restore code to that point",
			"No, keep current code",
		]);

		if (choice?.startsWith("Yes")) {
			// First restore files to the full worktree snapshot, clean untracked files
			// created after the checkpoint, then restore the staged state without
			// touching files. This preserves partial-staging boundaries.
			await pi.exec("git", ["read-tree", "-u", "--reset", checkpoint.worktreeTree]);
			await cleanNewUntrackedFiles(checkpoint);
			await pi.exec("git", ["read-tree", "--reset", checkpoint.indexTree]);
			ctx.ui.notify("Code restored to checkpoint", "info");
		}
	});
}
