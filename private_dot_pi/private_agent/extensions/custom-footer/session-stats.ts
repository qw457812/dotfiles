import type { ExtensionContext } from "@earendil-works/pi-coding-agent";

export function createSessionStatsGetter(ctx: ExtensionContext) {
  let cached:
    | {
        sessionId: string;
        leafId: string | null;
        model: ExtensionContext["model"];
        revision: number;
        stats: ReturnType<typeof calculateStats>;
      }
    | undefined;

  function calculateStats() {
    let input = 0;
    let output = 0;
    let cacheRead = 0;
    let cacheWrite = 0;
    let cost = 0;
    let latestCacheHitRate: number | undefined;

    // Costs cover the whole session, including abandoned branches and summaries.
    for (const entry of ctx.sessionManager.getEntries()) {
      const usage =
        entry.type === "usage" || entry.type === "compaction" || entry.type === "branch_summary"
          ? entry.usage
          : entry.type === "message" &&
              (entry.message.role === "assistant" || entry.message.role === "toolResult")
            ? entry.message.usage
            : undefined;
      if (usage) {
        input += usage.input;
        output += usage.output;
        cacheRead += usage.cacheRead;
        cacheWrite += usage.cacheWrite;
        cost += usage.cost.total;
      }
      if (entry.type === "message" && entry.message.role === "assistant") {
        const promptTokens =
          entry.message.usage.input +
          entry.message.usage.cacheRead +
          entry.message.usage.cacheWrite;
        latestCacheHitRate =
          promptTokens > 0 ? (entry.message.usage.cacheRead / promptTokens) * 100 : undefined;
      }
    }

    let routed: { provider: string; modelId: string; thinkingLevel?: string } | undefined;
    // This API id identifies virtual selections; Pi doesn't export its predicate.
    if (ctx.model?.api === "pi-virtual") {
      // Use projected branch messages, not all entries or failed/aborted responses.
      const messages = ctx.sessionManager.buildSessionProjection().messages;
      for (let i = messages.length - 1; i >= 0; i--) {
        const message = messages[i];
        if (
          message.role === "assistant" &&
          message.stopReason !== "error" &&
          message.stopReason !== "aborted"
        ) {
          const model = ctx.modelRegistry.find(message.provider, message.model);
          if (model && model.api !== "pi-virtual") {
            routed = {
              provider: message.provider,
              modelId: model.id,
              thinkingLevel: message.thinkingLevel,
            };
          }
          break;
        }
      }
    }

    return {
      input,
      output,
      cacheRead,
      cacheWrite,
      cost,
      latestCacheHitRate,
      routed,
      contextUsage: ctx.getContextUsage(),
    };
  }

  return (revision: number) => {
    const sessionId = ctx.sessionManager.getSessionId();
    const leafId = ctx.sessionManager.getLeafId();
    const model = ctx.model;
    if (
      !cached ||
      cached.sessionId !== sessionId ||
      cached.leafId !== leafId ||
      cached.model !== model ||
      cached.revision !== revision
    ) {
      cached = { sessionId, leafId, model, revision, stats: calculateStats() };
    }
    return cached.stats;
  };
}
