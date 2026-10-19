import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    // The lifecycle test mocks this generated module. Give it a stable ID even
    // in clean checkouts where Pi has never generated the runtime wrapper.
    alias: [
      {
        find: /^.*\/pi-vim\.generated\.ts$/,
        replacement: fileURLToPath(
          new URL("./tests/fixtures/prompt-editor-pi-vim.ts", import.meta.url),
        ),
      },
    ],
    include: ["tests/**/*.test.ts"],
    hookTimeout: 30_000,
  },
});
