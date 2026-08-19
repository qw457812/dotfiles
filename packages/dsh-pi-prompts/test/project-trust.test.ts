import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { afterEach, describe, expect, test } from "vitest";
import { isProjectTrusted } from "../src/project-trust.js";

const temporaryDirs: string[] = [];

afterEach(() => {
  for (const dir of temporaryDirs.splice(0)) rmSync(dir, { recursive: true, force: true });
});

function fixture(): { agentDir: string; workspace: string } {
  const root = mkdtempSync(join(tmpdir(), "dsh-pi-prompts-trust-"));
  temporaryDirs.push(root);
  const agentDir = join(root, "agent");
  const workspace = join(root, "projects", "example", "nested");
  mkdirSync(agentDir);
  mkdirSync(workspace, { recursive: true });
  return { agentDir, workspace };
}

describe("isProjectTrusted", () => {
  test("uses the nearest canonical ancestor decision", () => {
    const { agentDir, workspace } = fixture();
    const project = dirname(realpathSync(workspace));
    writeFileSync(
      join(agentDir, "trust.json"),
      `${JSON.stringify({ [dirname(project)]: false, [project]: true }, null, 2)}\n`,
    );

    expect(isProjectTrusted(agentDir, workspace)).toBe(true);
  });

  test("uses defaultProjectTrust only when no saved decision applies", () => {
    const { agentDir, workspace } = fixture();
    writeFileSync(join(agentDir, "settings.json"), '{"defaultProjectTrust":"always"}\n');
    expect(isProjectTrusted(agentDir, workspace)).toBe(true);

    writeFileSync(join(agentDir, "settings.json"), '{"defaultProjectTrust":"never"}\n');
    expect(isProjectTrusted(agentDir, workspace)).toBe(false);

    writeFileSync(join(agentDir, "settings.json"), '{"defaultProjectTrust":"ask"}\n');
    expect(isProjectTrusted(agentDir, workspace)).toBe(false);
  });

  test("fails closed by throwing on malformed trust inputs", () => {
    const { agentDir, workspace } = fixture();
    writeFileSync(join(agentDir, "trust.json"), '{"/tmp/project":"yes"}\n');
    expect(() => isProjectTrusted(agentDir, workspace)).toThrow(/invalid trust decision/u);

    writeFileSync(join(agentDir, "trust.json"), "{}\n");
    writeFileSync(join(agentDir, "settings.json"), '{"defaultProjectTrust":"sometimes"}\n');
    expect(() => isProjectTrusted(agentDir, workspace)).toThrow(/invalid defaultProjectTrust/u);
  });
});
