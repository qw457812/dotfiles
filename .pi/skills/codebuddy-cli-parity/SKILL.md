---
name: codebuddy-cli-parity
disable-model-invocation: true
description: Align the pi CodeBuddy provider's outbound HTTP behaviour with an installed CodeBuddy CLI. Use when matching headers, endpoints, query params, or version/UA strings against the CLI, when a CodeBuddy request silently degrades (empty model catalog, missing quota), or when verifying that a claimed CLI behaviour is real rather than inferred.
---

# CodeBuddy CLI parity

The CodeBuddy provider (`private_dot_pi/private_agent/extensions/codebuddy-provider/`) mirrors what the installed CLI sends. **The installed CLI is the only authority.** A parity claim is verified when it is traceable to the bundle, a captured request, or the CLI's own log line — never to a summary of them.

Logs and memory both lie here, in different ways. The CLI logs a fixed header allowlist, so an unlisted header reads as "absent" whether or not it is sent; a summary of a previous investigation goes stale the moment the CLI upgrades. Both failures look identical to a real finding.

Script paths below are relative to this skill directory:

```bash
cd .pi/skills/codebuddy-cli-parity
```

## Steps

1. **Locate the installed CLI and read its version.**

   ```bash
   node scripts/dump-cli-source.mjs product
   ```

   Completion criterion: you have the package directory, `version`, `platform`, `endpoint`, and `prefixPath` in hand, and you have confirmed which `VERSION` the provider pins.

2. **Resolve the disputed value in the bundle, not from notes.**

   ```bash
   node scripts/dump-cli-source.mjs header X-Tenant-Id   # `defs` + every write site
   node scripts/dump-cli-source.mjs symbol runIdentityHeaders
   ```

   `defs` gives the constant that names the header; `writes` lists every place that constant lands in a request bag, with `writeCount` reporting the total. Three forms count, and the bundle uses all three: `obj[CONST] = value`, the object literal `{ [CONST]: value }`, and `setHeaderCaseInsensitive(obj, CONST, value)`. It is the write sites, not the constant, that tell you whether a header is conditional: two sites of one constant can carry different guards, so read all of them and grep the surrounding code when a write sits inside a ternary. `symbol` takes a function that *builds* headers (`runIdentityHeaders`), not one that merely stores identity (`resolveRunIdentity`) — the latter returns a lookup result and shows nothing about emission.

   Completion criterion: you can state, for each header in dispute, the constant, the write sites, and the guard condition (unconditional, `if` enterprise id, `if` department name, …). A zero `writeCount` on a header the logs prove is sent means the constant you matched is not the one used at the emission site — check the `defs` block for a sibling constant before concluding the header is dead.

3. **Confirm the value is actually emitted, using the CLI's own log for the headers it records.**

   ```bash
   node scripts/read-cli-log.mjs --lines 20
   ```

   The log fully covers `user-agent`, `x-domain`, `x-enterprise-id`, `x-product`, `x-request-id`, `x-user-id`. **Treat everything else as uncovered** — a header missing from these lines is not evidence that the CLI withholds it.

   Completion criterion: for each header the log covers, you have an observed value from a real run; for each header it does not cover, you have said explicitly that the log cannot settle it and relied on step 2 instead.

4. **Run both credentials before concluding anything about auth paths.**

   The two credential kinds do not behave alike: an OAuth JWT carries a `sub` the gateway can fall back to, while an opaque `ck_` key carries no claims. Step 5's degradation table depends on that difference, so a conclusion drawn from one credential must not be carried to the other. The provider resolves a stored OAuth credential first and only falls back to `CODEBUDDY_AUTH_TOKEN` when none is stored, so a token exported into the environment proves nothing while `~/.pi/agent/auth.json` still holds a CodeBuddy entry. Isolate the ambient path by pointing `PI_CODING_AGENT_DIR` at a directory whose `auth.json` omits the `codebuddy` key.

   ```bash
   # Build an agent dir that has every entry except a codebuddy credential.
   iso=$(mktemp -d)
   for f in ~/.pi/agent/*; do
     [ "$(basename "$f")" = auth.json ] && continue
     ln -s "$f" "$iso/$(basename "$f")"
   done
   node -e 'const fs=require("fs"),p=process.env.HOME+"/.pi/agent/auth.json";
     const j=JSON.parse(fs.readFileSync(p,"utf8")); delete j.codebuddy;
     fs.writeFileSync(process.argv[1], JSON.stringify(j))' "$iso/auth.json"

   PI_CODING_AGENT_DIR=$iso CODEBUDDY_AUTH_TOKEN=<ck-key> pi --no-session \
     --model codebuddy/glm-5.3-flash
   ```

   That snippet links the rest of `~/.pi/agent/`, so it only isolates the *credential*. A stored model catalog can still satisfy `refreshModels` from cache — `context.stored?.models` is published before any network call — and the provider's own `~/.cache` entries outlive the run. When the question is "does this key produce a live catalog", clear that state too and watch for a network fetch rather than an instant success.

   Completion criterion: any claim about `CODEBUDDY_AUTH_TOKEN` behaviour comes from a run where the stored credential was provably absent and the catalog was demonstrably re-fetched, and any claim about OAuth behaviour comes from a run where the credential was present.

5. **Probe the endpoint when a header is missing or blank.**

   Three shapes mean three different things, and only one of them is a missing-header symptom:

   | Response | Meaning |
   |---|---|
   | `code 0` with a model list | accepted; header state is fine |
   | `code 0` with `models: null` | an identity header was rejected; this is the degrade to chase |
   | `404` / `12403` / HTTP error | the probe is wrong (method, path, or `User-Agent`) |

   Whether a missing `X-User-Id` degrades depends on the credential, because the gateway falls back to the JWT `sub` when one exists. Both domains yield the same table:

   | `Authorization` | `X-Enterprise-Id` | missing `X-User-Id` |
   |---|---|---|
   | OAuth JWT (has `sub`) | absent | falls back to `sub`; catalog still returns |
   | OAuth JWT (has `sub`) | present | `models: null` |
   | opaque `ck_` (no claims) | either | `models: null` |

   With `X-User-Id` present the catalog returns in every combination (34 models without an enterprise id, 36 with one). So the baseline probe carries `X-User-Id` to prove the endpoint works, then drops it to confirm the degrade:

   ```bash
   curl -sS '<endpoint>/v3/config' \
     -H 'Authorization: Bearer <token>' \
     -H 'User-Agent: CLI/<v> CodeBuddy/<v>' \
     -H 'X-User-Id: anonymous' | head -c 200
   ```

   A `404` or `12403` means the probe itself is wrong, not that the tested header was rejected. Set the baseline first, then vary one header at a time and record the pair (header state → response shape) rather than a conclusion. Record which credential you probed with: `models` on a degraded probe is only meaningful within one row of that table.

   Completion criterion: the baseline returns `code 0` with a populated model list, and you have observed the degraded shape by changing exactly one header — reported for the credential type you actually used, with `models: null` stated as such rather than as an empty array or an error.

6. **Encode the finding where the code will keep it.**

   Put the observed fact in the builder that emits the header, phrased as what was observed and how (`observed CLI /v3/config requests carry X, and Y only when Z`). Add a test that fails if the header is dropped or made conditional, and prefer asserting the **default path** — a test that only proves "an explicitly passed header is forwarded" passes while production sends nothing.

   Completion criterion: every header you claim to align has either a test on its default-path value or a comment naming why it cannot be emitted.

## Header categories

Three kinds, and they earn different treatment when they disagree with the CLI:

- **Identity** (`X-User-Id`, `X-Enterprise-Id`, `X-Tenant-Id`, `X-Department-Info`). The CLI sends these unconditionally except department, which appears only with a department name. These gate responses, so alignment is functional, not cosmetic.
- **Session classification** (`X-Product`, `X-Agent-Runtime`, `X-Agent-Type`, `X-Agent-Purpose`, `X-Agent-Intent`, compaction headers). The CLI always sets these; the gateway currently ignores them. Align when pi has the value for real, and prefer a stated limitation over a guessed value — `X-Agent-Type: compaction` is unreachable because pi exposes no per-request compaction marker, and inventing one corrupts telemetry rather than aligning it.
- **Version/UA** (`User-Agent`, `X-IDE-Version`, `X-Product-Version`). The CLI validates only the `CLI/<v> CodeBuddy/<v>` shape, so a stale version is log drift, not breakage. Confirm with a probe before treating a version bump as a fix.

## Pitfalls

- `X-Prefix` paths: auth lives under `/v2/plugin/...` (`product.json`'s `prefixPath`), so dropping the `/v2` segment changes the route.
- The CLI's `/v3/config` failover (`failoverRuntime`, `CONFIG_FETCH_FALLBACK_ADDRESS_KEY`) belongs to the product manager, not to auth. Auth calls one configured endpoint.
- `platform` is `product.json`'s top-level `platform`, the literal `"CLI"` — not the lowercase endpoint kind.
- Quota and catalog requests differ: the usage endpoint needs the `/v2` prefix for opaque `ck_` keys while the unprefixed route accepts OAuth, so a single-route fix breaks one credential type.
