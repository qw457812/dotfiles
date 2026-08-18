# Source-loaded direct plugin

Use a direct module for machine-local behavior that does not need an independent package or release cycle. A home-level patch affects every profile; choose a profile patch or npm bundle when the behavior must be profile-scoped.

## Layout and loading

- Source and development package: `dsh-plugins/`
- Home patch: `dot_dsh/cordis.patch.yml.tmpl`
- Runtime module: loaded in place from `dsh-plugins/`

DSH does not scan a conventional plugins directory: the home patch must explicitly name each module. Keep `.mjs` so the ESM contract stays visible independently of surrounding package metadata, and type-check JavaScript with `@ts-check` plus JSDoc imports from the packages that own the consumed APIs.

## Implementation checks

- Export `name`, `inject`, and `apply` as named ESM exports.
- Put every hard service dependency in `inject`; use `ctx.get()` only for optional services.
- Import declaration merges from the owning package when events or context properties otherwise lack types.
- Use official constructors and helpers for branded IDs, messages, tool definitions, results, and schemas.
- Attach unmanaged resources to `ctx.effect()`; verify teardown, not just startup.
- Add runtime dependencies to `dsh-plugins/package.json` only when a direct module imports them at runtime.
- Keep profile scope explicit: the home patch is global across profiles.

## Validation

Run the scripts declared by `dsh-plugins/package.json`; in this repository the ordinary gate is:

```sh
pnpm --dir dsh-plugins run check
pnpm --dir dsh-plugins run lint
```

Dump every affected profile and confirm the resolved row points to the source module. Run a fresh tmux check for commands, tools, or other UI-visible behavior when applicable.
