import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";
import { describe, expect, test } from "vitest";

const packageRoot = fileURLToPath(new URL("..", import.meta.url));

describe("npm bundle manifest", () => {
  test("publishes a dsh bundle with the expected runtime entry", () => {
    const manifest = JSON.parse(readFileSync(`${packageRoot}/package.json`, "utf8")) as Record<
      string,
      unknown
    >;
    expect(manifest).toMatchObject({
      name: "@qw457812/dsh-pi-prompts",
      version: "0.1.2",
      keywords: expect.arrayContaining(["dsh-plugin"]),
      main: "./lib/index.js",
      types: "./lib/index.d.ts",
      files: ["lib", "cordis.patch.yml", "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md"],
      publishConfig: { access: "public", registry: "https://registry.npmjs.org/" },
      dsh: { bundle: { patch: "./cordis.patch.yml" } },
      dependencies: { yaml: "2.9.0" },
    });
    expect(manifest).not.toHaveProperty("private");
  });

  test("mounts the published package name", () => {
    const patch = parseYaml(readFileSync(`${packageRoot}/cordis.patch.yml`, "utf8"));
    expect(patch).toEqual([
      {
        insert: [{ id: "pi-prompts", name: "@qw457812/dsh-pi-prompts" }],
      },
    ]);
  });
});
