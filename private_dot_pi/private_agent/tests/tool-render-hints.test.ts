import { describe, expect, it, vi } from "vitest";

import {
  rebuildWebfetchResultRenderComponent,
  WebfetchResultRenderComponent,
} from "../extensions/webfetch/render.ts";
import {
  rebuildWebsearchResultRenderComponent,
  WebsearchResultRenderComponent,
} from "../extensions/websearch/render.ts";

const theme = { fg: (_color: string, text: string) => text };
const result = {
  details: { url: "https://example.com", format: "text" as const, provider: "exa" as const },
  content: [{ type: "text", text: Array.from({ length: 12 }, (_, i) => `line ${i}`).join("\n") }],
};

for (const [name, Component, rebuild] of [
  ["webfetch", WebfetchResultRenderComponent, rebuildWebfetchResultRenderComponent],
  ["websearch", WebsearchResultRenderComponent, rebuildWebsearchResultRenderComponent],
] as const) {
  describe(`${name} host keybinding hints`, () => {
    it("uses live host bindings even when the collapsed output is cached", () => {
      const component = new Component();
      let binding = "ctrl+alt+o";
      const hints = {
        keyText: vi.fn(() => binding),
        keyHint: vi.fn((_key: string, description: string) => `${binding} ${description}`),
      };
      rebuild(component, result, { expanded: false, isPartial: false }, theme, {}, false, hints);

      expect(component.render(80).join("\n")).toContain("ctrl+alt+o to expand");
      expect(hints.keyHint).toHaveBeenCalledWith("app.tools.expand", "to expand");

      binding = "alt+e";
      expect(component.render(80).join("\n")).toContain("alt+e to expand");
    });

    it("does not request an expand hint for expanded output", () => {
      const component = new Component();
      const hints = { keyText: vi.fn(), keyHint: vi.fn() };
      rebuild(component, result, { expanded: true, isPartial: false }, theme, {}, false, hints);

      expect(component.render(80).join("\n")).toContain("line 11");
      expect(hints.keyHint).not.toHaveBeenCalled();
    });
  });
}
