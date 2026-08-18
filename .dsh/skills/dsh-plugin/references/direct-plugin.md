# Direct chezmoi plugin

Use a direct module for machine-local behavior that does not need an independent package or release cycle. A home-level patch affects every profile; choose a profile patch or npm bundle when the behavior must be profile-scoped.

## Layout and module

- Source: `dot_dsh/plugins/dsh-plugin-<name>.mjs`
- Home patch: `dot_dsh/cordis.patch.yml.tmpl`
- Development package and tests: `dot_dsh/plugins/package.json` and its test tree
- Runtime target: `~/.dsh/plugins/` (generated; edit the source path)

Use `.mjs` because the direct module lives outside a package boundary that guarantees `"type": "module"`. Keep JavaScript type-checked with `@ts-check` and JSDoc imports from the exact DSH packages that own the consumed APIs.

A typical home patch row is:

```yaml
- insert:
    - id: example
      name: ../../plugins/dsh-plugin-example.mjs
```

The profile-relative specifier is load-bearing. Confirm it in `dsh --dump-config`; do not replace it with an absolute host path.

## Implementation checks

- Export `name`, `inject`, and `apply` as named ESM exports.
- Put every hard service dependency in `inject`; use `ctx.get()` only for optional services.
- Import declaration merges from the owning package when events or context properties otherwise lack types.
- Use official constructors and helpers for branded IDs, messages, tool definitions, results, and schemas.
- Attach unmanaged resources to `ctx.effect()`; verify teardown, not just startup.
- Add runtime dependencies to the direct-plugin development/runtime package only when the module imports them at runtime.
- Keep profile scope explicit: the home patch is global across profiles.

## Validation

Run the scripts declared by `dot_dsh/plugins/package.json`; in this repository the ordinary gate is:

```sh
pnpm --dir dot_dsh/plugins run check
pnpm --dir dot_dsh/plugins run lint
```

Then apply only the changed plugin and patch targets when a manual apply is authorized, dump every affected profile, and run a fresh tmux check for commands, tools, or UI-visible behavior. The branch is complete when the direct module resolves from its generated target and no unintended profile row was introduced.
