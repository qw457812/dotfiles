# @qw457812/dsh-pi-prompts

Expose [Pi](https://github.com/earendil-works/pi) prompt templates as agent-scoped DeepSeek Harness slash commands.

Each direct `*.md` file in Pi's global or project prompts directory becomes a dsh command. The command name is the file stem, while `description` and `argument-hint` are read from YAML frontmatter with the same `yaml.parse` semantics Pi uses.

## Install

Install the bundle into each profile that needs Pi prompts:

```sh
dsh plugin --profile <profile> add @qw457812/dsh-pi-prompts
```

Remove it with:

```sh
dsh plugin --profile <profile> remove @qw457812/dsh-pi-prompts
```

The plugin is profile-scoped; installing it in one profile does not affect other profiles.

## Prompt directories

For every root agent, the plugin loads direct `*.md` children from:

- Global: `$PI_CODING_AGENT_DIR/prompts`, or `~/.pi/agent/prompts` when the environment variable is unset.
- Project: `<session-cwd>/.pi/prompts`, only when that project is trusted by Pi.

Discovery is non-recursive. File symlinks are followed, broken symlinks and invalid dsh command names are skipped, and one bad file does not prevent other templates from loading.

The plugin scans these two directories directly. It does not apply Pi's `settings.json` `prompts` entries (including filters and custom paths), CLI prompt paths, or package-provided prompts. Consequently, a direct file disabled through Pi's resource configuration is still exposed by this plugin.

### Project trust

The plugin reuses Pi's persisted project-trust policy:

1. The nearest decision for the canonical session cwd or one of its ancestors in `<agent-dir>/trust.json` wins.
2. Without a saved decision, global `<agent-dir>/settings.json` `defaultProjectTrust` applies.
3. `always` enables project prompts; `never` and `ask` disable them. If neither a saved decision nor a valid global default is available, the plugin fails closed.

DSH does not currently present Pi's interactive trust prompt. Use Pi's `/trust` command to save a decision, then start a new dsh session.

### Loading and precedence

Templates are loaded when a root agent is created. Start a new session after adding, changing, or trusting a project prompt.

Project templates override same-named global templates. Existing DSH commands take precedence over all prompt templates, so a project cannot replace built-in or extension commands such as `/plan`.

Each agent receives commands from its own recorded session cwd; concurrent sessions from different projects do not share project templates.

## Prompt format

```md
---
description: "Review: focused"
argument-hint: "[scope]"
---

Review $1. Remaining arguments: ${@:2}
```

Supported placeholders mirror Pi:

- `$1`, `$2`, ... for positional arguments.
- `$@` and `$ARGUMENTS` for all arguments.
- `${N:-default}`, `${@:-default}`, and `${ARGUMENTS:-default}` for defaults.
- `${@:N}` and `${@:N:L}` for slices.

Arguments support Pi's single- and double-quoted grouping. Substitution is single-pass, so placeholder-like text inside argument values remains literal.

## Development

```sh
pnpm install
pnpm run check
npm pack --dry-run
```

## License

MIT. Portions are adapted from Pi's MIT-licensed implementation; see [`THIRD_PARTY_NOTICES.md`](./THIRD_PARTY_NOTICES.md).
