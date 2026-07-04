/**
 * Ensure ppt-master bash tool calls run inside the dedicated venv.
 * Repo: https://github.com/hugohe3/ppt-master
 *
 * One-time setup:
 *   python3 -m venv ~/.venvs/ppt-master
 *   source ~/.venvs/ppt-master/bin/activate
 *   pip install -r ~/.pi/agent/git/github.com/hugohe3/ppt-master/requirements.txt
 *
 * When a bash command references `skills/ppt-master`, prepend
 * `source ~/.venvs/ppt-master/bin/activate` for that shell only.
 */

import { isToolCallEventType, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const PPT_MASTER_MARKER = "skills/ppt-master";
const VENV_ACTIVATE = join(homedir(), ".venvs", "ppt-master", "bin", "activate");
const VENV_MARKER = ".venvs/ppt-master";

export default function (pi: ExtensionAPI) {
  let warnedMissingVenv = false;

  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event)) return;

    const command = event.input.command;
    if (!command.includes(PPT_MASTER_MARKER)) return;
    if (command.includes(VENV_MARKER)) return;

    if (!existsSync(VENV_ACTIVATE)) {
      if (!warnedMissingVenv && ctx.hasUI) {
        ctx.ui.notify(`ppt-master venv activate script not found: ${VENV_ACTIVATE}`, "warning");
        warnedMissingVenv = true;
      }
      return;
    }

    event.input.command = [`source "${VENV_ACTIVATE}"`, command].join("\n");
  });
}
