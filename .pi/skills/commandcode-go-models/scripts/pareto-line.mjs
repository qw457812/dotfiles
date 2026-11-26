// Prints the AA Pareto line for Command Code Go models:
// Y = Intelligence Index, X = agent cost at Go prices (USD per 1M agent-loop tokens).
//
// Usage: AA_API_KEY=... node pareto-line.mjs [--json] [--include-unscored]
//
// Sources:
//   - https://commandcode.ai/docs/plans/go — models list is server-rendered inside
//     self.__next_f.push chunks; the rendered <table> is a subset, so decode the chunks.
//   - https://artificialanalysis.ai/api/v2/language/models/free — x-api-key header,
//     insufficient quota/401 falls back to the MCP-backed cache in ~/.pi/agent/mcp-auth.json
//     (nothing to do here; exit with an error instead).
//
// X = agentLoopInputPerMTok + 0.25*outputCost — Command Code's own agent-loop input cost
// (30% new input / 70% cache read) plus the output share at the 800:200 input:output shape.

const GO_URL = "https://commandcode.ai/docs/plans/go";
const AA_URL = "https://artificialanalysis.ai/api/v2/language/models/free";
const FLAGS = new Set(process.argv.slice(2));

function num(value) {
  if (value === null || value === undefined || value === "$undefined") return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function error(message) {
  console.error(`pareto-line: ${message}`);
  process.exit(1);
}

async function fetchText(url) {
  let res;
  try {
    res = await fetch(url, { headers: { "accept-language": "en-US,en;q=0.9,ja;q=0.8" } });
  } catch (e) {
    error(`fetch ${url} failed: ${e.cause?.code || e.message}`);
  }
  if (!res.ok) error(`fetch ${url}: HTTP ${res.status}`);
  return await res.text();
}

/**
 * Returns { models, goCount } where models are the Go-filtered catalog entries.
 * The models array is a page-props object, not a plain array in the stream, so
 * it lives inside one self.__next_f.push chunk after '"models":['. The chunk
 * is decoded JSON text; slice the array by bracket depth so we never depend
 * on where the array ends in the stream.
 */
function parseGoCatalog(html) {
  const re = /self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)/g;
  for (const match of html.matchAll(re)) {
    let text;
    try {
      text = JSON.parse(match[1]);
    } catch {
      continue; // one malformed chunk must not discard the catalog
    }
    const marker = '"models":[';
    const start = text.indexOf(marker);
    if (start === -1) continue;
    const arrayStart = start + marker.length - 1; // at '['
    let depth = 0;
    let inString = false;
    let escaped = false;
    let end = -1;
    for (let i = arrayStart; i < text.length; i++) {
      const ch = text[i];
      if (inString) {
        if (escaped) escaped = false;
        else if (ch === '\\') escaped = true;
        else if (ch === '"') inString = false;
        continue;
      }
      if (ch === '"') inString = true;
      else if (ch === '[' || ch === '{') depth++;
      else if (ch === ']' || ch === '}') {
        depth--;
        if (depth === 0) { end = i + 1; break; }
      }
    }
    if (end === -1) continue;
    const models = JSON.parse(text.slice(arrayStart, end));
    if (!Array.isArray(models)) continue;
    const go = models.filter((m) => m && m.minPlanName === "Go");
    if (go.length === 0) error("Go catalog: no models with minPlanName=Go");
    return { models: go, goCount: go.length, total: models.length };
  }
  error("Go catalog: models array not found in page chunks");
}

async function fetchAA() {
  const apiKey = process.env.AA_API_KEY;
  if (!apiKey) error("AA_API_KEY is required (free tier key, header x-api-key)");
  const out = [];
  let page = 1;
  let body;
  for (;;) {
    const url = `${AA_URL}?page=${page}`;
    let res;
    try {
      res = await fetch(url, { headers: { "x-api-key": apiKey } });
    } catch (e) {
      error(`fetch ${url} failed: ${e.cause?.code || e.message}`);
    }
    if (res.status === 401) error("AA_API_KEY rejected (401) — check the key");
    if (res.status === 429) error("AA rate limit hit (429)");
    if (!res.ok) error(`fetch ${url}: HTTP ${res.status}`);
    body = await res.json();
    out.push(...body.data);
    if (!body.pagination?.has_more) break;
    page += 1;
  }
  return { models: out, version: body.intelligence_index_version };
}

const normalize = (s) =>
  String(s || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");

function matchAA(go, aaModels) {
  const bySlug = new Map(aaModels.map((m) => [m.slug, m]));
  const byName = new Map();
  for (const m of aaModels) {
    const key = normalize(m.name.replace(/\s*\((?:Max|Xhigh|High)\)\s*/gi, ""));
    if (!byName.has(key)) byName.set(key, []);
    byName.get(key).push(m);
  }
  const rows = [];
  for (const g of go) {
    let aa = bySlug.get(g.slug);
    let how = "slug";
    if (!aa) {
      const candidates = byName.get(normalize(g.name)) || [];
      if (candidates.length === 1) {
        aa = candidates[0];
        how = "name";
      }
    }
    const score = aa ? num(aa.evaluations?.artificial_analysis_intelligence_index) : null;
    rows.push({
      id: g.id,
      slug: g.slug,
      name: g.name,
      aaSlug: aa?.slug ?? null,
      aaName: aa?.name ?? null,
      match: how,
      score,
      agentLoopInputPerMTok: num(g.agentLoopInputPerMTok),
      input: num(g.inputCost),
      output: num(g.outputCost),
      cacheRead: num(g.cacheReadCost),
      blended: num(g.blendedCostPerMTok),
    });
  }
  return rows;
}

const [goHtml, aa] = await Promise.all([fetchText(GO_URL), fetchAA()]);
const { models: goModels, goCount } = parseGoCatalog(goHtml);
const rows = matchAA(goModels, aa.models);

const scored = rows
  .filter((r) => r.score !== null && r.agentLoopInputPerMTok !== null)
  .map((r) => ({
    ...r,
    cost: r.agentLoopInputPerMTok + 0.25 * r.output,
  }))
  .sort((a, b) => a.cost - b.cost || b.score - a.score);

const pareto = [];
let best = -Infinity;
for (const r of scored) {
  if (r.score > best) {
    pareto.push(r);
    best = r.score;
  }
}

const unverified = scored.filter((r) => {
  const expected = 0.3 * r.input + 0.7 * r.cacheRead;
  return Math.abs(expected - r.agentLoopInputPerMTok) > 0.002;
});

const result = {
  date: new Date().toISOString().slice(0, 10),
  sources: {
    go: GO_URL,
    goModels: goCount,
    aa: AA_URL,
    aaVersion: aa.version,
    aaScored: scored.length,
  },
  paretoLine: pareto.map((r) => ({
    id: r.id,
    name: r.name,
    aaSlug: r.aaSlug,
    score: r.score,
    agentCost: Number(r.cost.toFixed(4)),
  })),
  dominated: scored
    .filter((r) => !pareto.includes(r))
    .map((r) => ({ id: r.id, score: r.score, agentCost: Number(r.cost.toFixed(4)) })),
  unscored: FLAGS.has("--include-unscored")
    ? rows.filter((r) => r.score === null).map((r) => ({ id: r.id, name: r.name }))
    : undefined,
  warnings: unverified.length
    ? [`agentLoopInputPerMTok != 0.3*input+0.7*cacheRead for: ${unverified.map((r) => r.id).join(", ")}`]
    : [],
};

if (FLAGS.has("--json")) {
  console.log(JSON.stringify(result, null, 2));
} else {
  console.log(`Pareto line — Command Code Go × AA v${aa.version} (scored ${result.sources.aaScored} of ${goCount} Go models)`);
  for (const p of result.paretoLine) {
    console.log(`${p.id}\t${p.score}\t$${p.agentCost.toFixed(3)}/1M`);
  }
  if (result.warnings.length) console.warn(`warning: ${result.warnings.join("; ")}`);
}
