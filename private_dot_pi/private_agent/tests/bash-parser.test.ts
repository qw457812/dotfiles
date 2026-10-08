import { describe, expect, it, vi } from "vitest";
import { initializeBashParser, withBashTree } from "../lib/bash-parser.ts";

describe("Shared Bash parser", () => {
  it("reuses initialization and releases trees on success and failure", async () => {
    const [first, second] = await Promise.all([initializeBashParser(), initializeBashParser()]);
    expect(first).toBe(second);
    const originalParse = first.parse.bind(first);
    const deletes: ReturnType<typeof vi.spyOn>[] = [];
    const parse = vi.spyOn(first, "parse").mockImplementation((...args) => {
      const tree = originalParse(...args);
      if (tree) deletes.push(vi.spyOn(tree, "delete"));
      return tree;
    });
    try {
      expect(await withBashTree("git status", (root) => root.hasError)).toBe(false);
      await expect(
        withBashTree("git status", () => {
          throw new Error("visitor failed");
        }),
      ).rejects.toThrow("visitor failed");
      expect(deletes).toHaveLength(2);
      for (const deleted of deletes) expect(deleted).toHaveBeenCalledOnce();
    } finally {
      parse.mockRestore();
    }
  });
});
