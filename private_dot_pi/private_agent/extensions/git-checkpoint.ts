/* eslint-disable no-unreachable */

// Copied from: https://github.com/earendil-works/pi/blob/3e5ad67e0f325d4888f82f9b82966218eb4407f5/packages/coding-agent/examples/extensions/git-checkpoint.ts

// TODO:
// - https://github.com/audibleblink/pi-harness/blob/4cba24c7a84a9054d7ca773ed67cac51a17977f5/extensions/git-checkpoint.ts
// - https://github.com/arpagon/pi-rewind

/**
 * Git Checkpoint Extension
 *
 * Creates git stash checkpoints at each turn so /fork can restore code state.
 * When forking, offers to restore code to that point in history.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	return; // TODO: disabled for now — see BUG(1-3)

	const checkpoints = new Map<string, string>();
	let currentEntryId: string | undefined;

	// Track the current entry ID when user messages are saved

	// TODO: BUG(1): turn_start fires before tool_result on first turn, so
	// currentEntryId is undefined. Also tool_result fires via afterToolCall
	// before the message is persisted; getLeafEntry() returns the wrong leaf.
	pi.on("tool_result", async (_event, ctx) => {
		const leaf = ctx.sessionManager.getLeafEntry();
		if (leaf) currentEntryId = leaf.id;
	});

	pi.on("turn_start", async () => {
		// Create a git stash entry before LLM makes changes

		// TODO: BUG(2): git stash create produces dangling loose objects.
		// git write-tree + read-tree is cleaner.
		const { stdout } = await pi.exec("git", ["stash", "create"]);
		const ref = stdout.trim();
		if (ref && currentEntryId) {
			checkpoints.set(currentEntryId, ref);
		}
	});

	pi.on("session_before_fork", async (event, ctx) => {
		const ref = checkpoints.get(event.entryId);
		if (!ref) return;

		if (!ctx.hasUI) {
			// In non-interactive mode, don't restore automatically
			return;
		}

		const choice = await ctx.ui.select("Restore code state?", [
			"Yes, restore code to that point",
			"No, keep current code",
		]);

		if (choice?.startsWith("Yes")) {
			await pi.exec("git", ["stash", "apply", ref]);
			ctx.ui.notify("Code restored to checkpoint", "info");
		}
	});

	pi.on("agent_end", async () => {
		// Clear checkpoints after agent completes

		// TODO: BUG(3): User typically runs /fork after agent ends. Clearing
		// checkpoints here empties the Map before session_before_fork fires.
		checkpoints.clear();
	});
}
