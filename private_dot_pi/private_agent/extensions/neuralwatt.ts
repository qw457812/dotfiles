/**
 * neuralwatt.ts — mcr_lookup gate
 *
 * neuralwatt-mcr (≥ ca3f615) unconditionally registers an mcr_lookup stub.
 * @see https://github.com/monotykamary/pi-neuralwatt-provider/blob/ca3f61549466a9e2ed34021445331a9f288ba94f/chad-mcr-upstream.ts#L835-L836
 *
 * This extension disables it by default and only enables it for neuralwatt
 * provider + MCR models.
 *
 * Gating strategy:
 *   - session_start: gate based on model (enable or disable)
 *   - model_select: enable-only, never disable once enabled
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const MCR_LOOKUP_TOOL = "mcr_lookup";
const PROVIDER = "neuralwatt";

/**
 * Matches pi-neuralwatt-provider's isMCRModel.
 * @see https://github.com/monotykamary/pi-neuralwatt-provider/blob/ca3f61549466a9e2ed34021445331a9f288ba94f/chad-mcr-upstream.ts#L430-L432
 */
function isMCRModel(modelId: string): boolean {
  return modelId.includes("neuralwatt/") || modelId.endsWith("-long");
}

export default function (pi: ExtensionAPI) {
  // session start: gate based on model (enable or disable)
  pi.on("session_start", (_event, ctx) => {
    const modelId = ctx.model?.id || "";
    const provider = ctx.model?.provider || "";
    const shouldEnable = provider === PROVIDER && isMCRModel(modelId);

    const active = new Set(pi.getActiveTools());
    if (shouldEnable) {
      active.add(MCR_LOOKUP_TOOL);
    } else {
      active.delete(MCR_LOOKUP_TOOL);
    }
    pi.setActiveTools(Array.from(active));
  });

  // model select: enable-only, never disable after first enable
  pi.on("model_select", (event, _ctx) => {
    const modelId = event.model?.id || "";
    const provider = event.model?.provider || "";
    if (provider !== PROVIDER || !isMCRModel(modelId)) return;

    const active = new Set(pi.getActiveTools());
    active.add(MCR_LOOKUP_TOOL);
    pi.setActiveTools(Array.from(active));
  });
}
