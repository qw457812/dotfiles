---
name: commandcode-go-models
disable-model-invocation: true
description: Add and validate Go-only commandcode model overrides.
---

# commandcode-go-models

Pin: `0137ace` (repo `patlux/pi-commandcode-provider`). Upstream reviewed through `origin/main` at `a063270` (2026-11-23, one commit past `v0.8.7`); re-audit past it with `git -C ~/.local/share/nvim/lazy/pi-commandcode-provider log --oneline a063270..origin/main` before trusting the audit below.

## Why the pin holds

Go has no Provider API access. A Go turn reaches `api.commandcode.ai/provider/v1`, reads the 403 `upgrade_required` body, and re-issues on `/alpha/generate` — `src/transport.ts` decides, `src/core.ts` sends. Stay on `0137ace`: `0.8.0` deletes `src/core.ts`, `src/converters.ts`, `src/transcript.ts` and `src/json-schema.ts`, and turns that 403 into a terminal error; every later release keeps it deleted. Do not bump the pin to pick up new models — that removes the fallback. Update the model data below instead.

Scope is Go-only, so a model outside the Go table gets called out rather than shipped.

## Two catalogs, one of them live

`/provider/v1/models` refreshes every start and supplies ids, names, context windows and `supported_endpoints`. Capabilities — `reasoning`, `input`, output limits, efforts — come from the generated snapshot `src/commandcode-catalog.ts`, frozen at `command-code@1.88.3`. A model published after the pin therefore registers text-only and non-reasoning however capable it is, and a catalog refresh cannot change that. `models.json` overrides are the only way to fill that gap; confirm capability claims against the upstream snapshot you transcribe, never against the live list.

`~/.pi/agent/commandcode-models.json` (or `$COMMANDCODE_MODELS_CACHE`) holds the last successful live response so startup registers models before any round-trip. Read it to see what registered; leave it alone. Its `reasoning` and `maxTokens` are re-derived from the snapshot on every read, so editing them does nothing, and neither reflects an active override — pi applies overrides above the cache rather than into it.

## Which models are in scope

Six Go models postdate the 1.88.3 snapshot and carry overrides transcribed from upstream 1.93.2 (`a063270`, 2026-11-23) and the Go table read 2026-11-26:

`meta/muse-ember`, `Qwen/Qwen4-Max`, `tencent/hy4`, `tencent/hy4-flash`, `thinkingmachines/inkling-2-mini`, `recursive/flint-v1.0:free`.

Keep the set exact. `deepseek/deepseek-v4.1-flash-ultrafast`, `claude-fable-5-2` and `google/gemini-4-carbon` now have upstream capability entries, but none is on the Go table, so a Go account cannot run them; leave them unoverridden rather than copying metadata for models the plan rejects.

## Adding an override

1. Confirm the model in the Go table at https://commandcode.ai/docs/plans/go.
   Done when it is listed there with its Go rates.
2. Add it under `providers.commandcode.modelOverrides` in `private_dot_pi/private_agent/models.json`, taking capabilities from `git show origin/main:src/commandcode-catalog.ts` and prices from `git show origin/main:src/pricing.ts`.
   Done when every field traces to the Go table or to those two upstream files, and `thinkingLevelMap` mirrors `MODEL_EFFORTS` exactly (present level → its own name, absent level → `null`, omit `xhigh`/`max` when unsupported).
3. Validate.
   Done when `chezmoi apply ~/.pi/agent/models.json` leaves source and target identical, `npm --prefix private_dot_pi/private_agent run check` and `run lint` pass, and a small request on the model has `/commandcode-status` reporting a `generate` route.

## Fields

Pi's `ModelOverrideSchema`. `baseUrl` and `apiKey` stay undeclared: the extension owns the catalog and credentials. `baseUrl`, `api`, and routing are not overridable here at all.

- `cost` — display only, never the bill. Every new Go model needs it because the pinned pricing snapshot predates them.
- `input`, `reasoning` — only where the cited upstream snapshot verifies them.
- `thinkingLevelMap` — pi levels, `off` … `max`. `max` and `xhigh` count as supported only when the key is present; every other level counts as supported unless set to `null`. Omit `off`: the generate transport maps it to "no reasoning".
- Those four reach the generate transport: `src/core.ts` reads `model.reasoning`, `model.input`, `model.thinkingLevelMap` and `model.cost`. The rest of pi's override fields are inert here, so leave them out rather than guessing.

```json
"commandcode": {
  "modelOverrides": {
    "meta/muse-ember": {
      "reasoning": true,
      "input": ["text", "image"],
      "thinkingLevelMap": {
        "minimal": null, "low": "low", "medium": "medium",
        "high": "high", "xhigh": "xhigh", "max": "max"
      },
      "cost": { "input": 0.1, "output": 0.5, "cacheRead": 0.004, "cacheWrite": 0 }
    }
  }
}
```

Prices and efforts drift. The 2026-11-26 Go read and the 2026-11-23 upstream snapshot both age; re-read the two sources before trusting the numbers.

An override fixes pi's model metadata, not the extension's own diagnostics: `/commandcode-status` still prints `capabilities: not explicitly catalogued` and `price: unknown`, and the extension warns once per model, because `src/diagnostics.ts` reads the pinned 1.88.3 snapshot. pi's usage footer uses the override, so treat that mismatch as expected.

## Guardrails

- The pin lives in five places, not two: `dot_config/nvim/lua/plugins/ai.lua` (`commit` and the `build` string), `symlinks/pi/agent/settings.json` (the `packages` entry and the `extensionChangelogVersions` key), and `symlinks/nvim/{macos,termux,fedora-asahi}/lazy-lock.json`. Today only macos sits at `0137ace`; termux (`4a64c88`) and fedora-asahi (`d3a7d88`) lag on older snapshots that still carry the fallback. Check the host you are on before assuming anything above.
- The pin is dead once `src/transport.ts` loses `upgrade_required`/`generate`, whatever the version string claims.
- Keys live in the agent's credential store. `models.json` holds `$ENV` templates for other providers, and for commandcode not even those.
