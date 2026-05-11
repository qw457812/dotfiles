import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("model_select", async (event, _ctx) => {
    const { model } = event;
    if (model.provider === "deepseek" && model.id === "deepseek-v4-pro") {
      if (pi.getThinkingLevel() !== "xhigh") {
        pi.setThinkingLevel("xhigh");
      }
    }
  });
}
