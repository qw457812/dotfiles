/**
 * Accidental-operation gate for Bash, SQL and protected paths, not a security boundary.
 *
 * Only this entry is auto-loaded; it registers the internal tool checks.
 * Git rules and Jev default to ON and reset on /reload.
 * See README.md for commands, coverage, unredacted classifier inputs and failure behavior.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import registerBashChecks from "./bash.ts";
import registerPathChecks from "./paths.ts";
import registerSqlChecks from "./sql.ts";
import { showLog } from "./log.ts";

export { GATE_ENTRY } from "./log.ts";
const USAGE = "Usage: /gate git [on|off] | jev [on|off] | log";

export default function (pi: ExtensionAPI) {
  let gitEnabled = true;
  let jevEnabled = true;
  let lifecycle = new AbortController();

  registerPathChecks(pi);
  registerSqlChecks(
    pi,
    () => jevEnabled,
    () => lifecycle.signal,
  );

  const invalidate = () => {
    lifecycle.abort();
    lifecycle = new AbortController();
  };
  pi.on("session_before_switch", invalidate);
  pi.on("session_before_tree", invalidate);
  pi.on("session_shutdown", invalidate);
  pi.on("session_start", invalidate);

  registerBashChecks(
    pi,
    () => gitEnabled,
    () => jevEnabled,
    () => lifecycle.signal,
  );

  pi.registerCommand("gate", {
    description: "Bash/SQL auto-approval and confirmation (/gate git|jev [on|off], log)",
    getArgumentCompletions(prefix: string) {
      const query = prefix.trimStart().toLowerCase();
      const options = query.includes(" ")
        ? ["git on", "git off", "jev on", "jev off"]
        : ["git", "jev", "log"];
      const items = options
        .filter((item) => item.startsWith(query))
        .map((item) => ({ value: item, label: item }));
      return items.length ? items : null;
    },
    handler: async (args, ctx) => {
      const [rule, value, ...extra] = args.trim().toLowerCase().split(/\s+/);
      if (!rule) {
        ctx.ui.notify(
          `Git approval: ${gitEnabled ? "ON" : "OFF"}; Jev auto-approval: ${jevEnabled ? "ON" : "OFF"}\n${USAGE}`,
          "info",
        );
        return;
      }
      if (rule === "log" && !value && !extra.length) {
        showLog(ctx);
        return;
      }
      if (
        !["git", "jev"].includes(rule) ||
        extra.length ||
        (value && value !== "on" && value !== "off")
      ) {
        ctx.ui.notify(USAGE, "error");
        return;
      }
      if (rule === "git") {
        if (value) gitEnabled = value === "on";
        ctx.ui.notify(`Git approval: ${gitEnabled ? "ON" : "OFF"}`, "info");
      } else {
        if (value) jevEnabled = value === "on";
        ctx.ui.notify(`Jev auto-approval: ${jevEnabled ? "ON" : "OFF"}`, "info");
      }
    },
  });
}
