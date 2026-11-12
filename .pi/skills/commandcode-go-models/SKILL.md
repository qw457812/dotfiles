---
name: commandcode-go-models
disable-model-invocation: true
description: Add and validate Go-only commandcode model overrides.
---

# commandcode-go-models

Pin: `0137ace` (repo `patlux/pi-commandcode-provider`). Upstream reviewed through `7616ecd` (`v0.8.2`); re-audit past it with `git -C ~/.local/share/nvim/lazy/pi-commandcode-provider log --oneline 7616ecd..origin/main` before trusting the audit below.

## Why the pin holds

Go has no Provider API access. A Go turn reaches `api.commandcode.ai/provider/v1`, reads the 403 `upgrade_required` body, and re-issues on `/alpha/generate` — `src/transport.ts` decides, `src/core.ts` sends. Stay on `0137ace`: `0.8.0` deletes `src/core.ts`, `src/converters.ts`, `src/transcript.ts` and `src/json-schema.ts`, and turns that 403 into a terminal error. Scope is Go-only, so a model outside the Go table gets called out rather than shipped.

## Two catalogs, one of them live

`/provider/v1/models` refreshes every start and supplies ids, names, context windows and `supported_endpoints`. Capabilities — `reasoning`, `input`, output limits, efforts — come from the generated snapshot `src/commandcode-catalog.ts`, frozen at `command-code@1.88.3`. A model published after the pin therefore registers text-only and non-reasoning however capable it is, and a catalog refresh cannot change that. Confirm capability claims against that file, never against the live list.

`~/.pi/agent/commandcode-models.json` (or `$COMMANDCODE_MODELS_CACHE`) holds the last successful live response so startup registers models before any round-trip. Read it to see what registered; leave it alone. Its `reasoning` and `maxTokens` are re-derived from the snapshot on every read, so editing them does nothing, and neither reflects an active override — pi applies overrides above the cache rather than into it.

## Which models are in scope

- `meta/muse-ember` — on the Go table. Price only.
- `deepseek/deepseek-v4.1-flash-ultrafast` — not on Go. `0.8.1` verified its image, reasoning and `off`/`low`/`high`/`max`, but Go cannot run it, and copying another release's capability metadata onto this frozen snapshot means hand-maintaining that release's catalog.
- `claude-fable-5-2`, `google/gemini-4-carbon` — not on Go, and `0.8.2` gives them prices only, with no capability entries even at `7616ecd`.

## Adding an override

1. Confirm the model in the Go table at https://commandcode.ai/docs/plans/go.
   Done when it is listed there with its Go rates.
2. Add it under `providers.commandcode.modelOverrides` in `private_dot_pi/private_agent/models.json`, recording those rates.
   Done when every field you add traces to the Go table or to a capability entry in the pinned snapshot.
3. Validate.
   Done when `chezmoi apply ~/.pi/agent/models.json` leaves source and target identical, `npm --prefix private_dot_pi/private_agent run check` and `run lint` pass, and a small request on the model has `/commandcode-status` reporting a `generate` route.

## Fields

Pi's `ModelOverrideSchema`. `baseUrl` and `apiKey` stay undeclared: the extension owns the catalog and credentials. `baseUrl`, `api`, and routing are not overridable here at all.

- `cost` — display only, never the bill. The field Go overrides need today.
- `input`, `reasoning` — only where the pinned snapshot verifies them.
- `thinkingLevelMap` — pi levels, `off` … `max`. `max` and `xhigh` count as supported only when the key is present; every other level counts as supported unless set to `null`.
- The rest is inert: pi applies them, but the extension re-derives transport state from the catalog, so an override that disagrees with the snapshot produces a model that lies about itself.

```json
"commandcode": {
  "modelOverrides": {
    "meta/muse-ember": {
      "cost": { "input": 0.1, "output": 0.5, "cacheRead": 0.004, "cacheWrite": 0 }
    }
  }
}
```

`meta/muse-ember`'s Go rates were read on 2026-11-12, and upstream priced it 2026-11-11. Both ages drift; re-read the two tables before trusting the numbers.

## Guardrails

- The pin lives in five places, not two: `dot_config/nvim/lua/plugins/ai.lua` (`commit` and the `build` string), `symlinks/pi/agent/settings.json` (the `packages` entry and the `extensionChangelogVersions` key), and `symlinks/nvim/{macos,termux,fedora-asahi}/lazy-lock.json`. Today only macos sits at `0137ace`; termux (`4a64c88`) and fedora-asahi (`d3a7d88`) lag on older snapshots that still carry the fallback. Check the host you are on before assuming anything above.
- The pin is dead once `src/transport.ts` loses `upgrade_required`/`generate`, whatever the version string claims.
- Keys live in the agent's credential store. `models.json` holds `$ENV` templates for other providers, and for commandcode not even those.
