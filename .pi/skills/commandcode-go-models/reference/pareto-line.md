# Pareto line — Go models

Run `AA_API_KEY=... node scripts/pareto-line.mjs` from the skill directory. It prints Y = AA v5 Intelligence, X = `agentLoopInputPerMTok + 0.25*output` at Go prices, keeping only models whose score exceeds every cheaper scored model. Done when it exits 0 with a non-empty line.

Snapshot 2026-11-26, cheapest to strongest:

1. `thinkingmachines/inkling-2-mini` — 20.1, $0.108/1M
2. `xiaomi/mimo-v2.6-flash` — 26.8, $0.114/1M
3. `meta/muse-ember` — 36.1, $0.158/1M
4. `Qwen/Qwen4-Max` — 42.8, $1.627/1M
5. `moonshotai/Kimi-K3.1-Pro` — 46.6, $3.240/1M

Pick the weakest point that meets the task: MiMo V2.6 Flash for cheap, Muse Ember for ordinary work, Qwen 4 Max then Kimi K3.1 Pro when needed. `inkling-2-mini` is on the line only on cost (AA Cost per Task $0.59, outside the green quadrant), so prefer MiMo when it resolves the task.
