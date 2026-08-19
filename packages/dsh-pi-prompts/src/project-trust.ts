import { existsSync, readFileSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

type TrustFile = Record<string, boolean | null | undefined>;
type DefaultProjectTrust = "always" | "ask" | "never";

/** Resolve a project path the same way Pi keys durable trust decisions. */
function canonicalizeProjectPath(cwd: string): string {
  const resolved = resolve(cwd);
  try {
    return realpathSync(resolved);
  } catch {
    return resolved;
  }
}

function readJsonObject(path: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error(`${path} must contain a JSON object`);
  }
  return parsed as Record<string, unknown>;
}

function readTrustFile(path: string): TrustFile {
  if (!existsSync(path)) return {};
  const parsed = readJsonObject(path);
  const data: TrustFile = {};
  for (const [key, value] of Object.entries(parsed)) {
    if (value !== true && value !== false && value !== null) {
      throw new Error(`${path} has an invalid trust decision for ${JSON.stringify(key)}`);
    }
    data[key] = value;
  }
  return data;
}

function nearestDecision(data: TrustFile, cwd: string): boolean | undefined {
  let current = canonicalizeProjectPath(cwd);
  while (true) {
    const value = data[current];
    if (value === true || value === false) return value;
    const parent = dirname(current);
    if (parent === current) return undefined;
    current = parent;
  }
}

function readDefaultProjectTrust(agentDir: string): DefaultProjectTrust {
  const settingsPath = join(agentDir, "settings.json");
  if (!existsSync(settingsPath)) return "ask";
  const value = readJsonObject(settingsPath).defaultProjectTrust;
  if (value === undefined) return "ask";
  if (value === "always" || value === "ask" || value === "never") return value;
  throw new Error(`${settingsPath} has an invalid defaultProjectTrust value`);
}

/**
 * Resolve project trust using Pi's durable nearest-ancestor decision and global fallback.
 * DSH has no project-trust prompt, so Pi's `ask` fallback fails closed like non-interactive Pi.
 */
export function isProjectTrusted(agentDir: string, cwd: string): boolean {
  const decision = nearestDecision(readTrustFile(join(agentDir, "trust.json")), cwd);
  if (decision !== undefined) return decision;
  return readDefaultProjectTrust(agentDir) === "always";
}
