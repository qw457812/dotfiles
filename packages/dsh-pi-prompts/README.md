# @qw457812/dsh-pi-prompts

Expose [Pi](https://github.com/earendil-works/pi) prompt templates as DeepSeek Harness slash commands.

Each direct `*.md` file in Pi's prompts directory becomes a dsh command. The command name is the file stem, while `description` and `argument-hint` are read from YAML frontmatter with the same `yaml.parse` semantics Pi uses.

## Install

Install the bundle into the `web` profile:

```sh
dsh plugin --profile web add @qw457812/dsh-pi-prompts
```

Remove it with:

```sh
dsh plugin --profile web remove @qw457812/dsh-pi-prompts
```

The plugin is profile-scoped; install it separately in each profile that needs Pi prompts.

## Prompt directory

The plugin follows Pi's directory resolution:

- `$PI_CODING_AGENT_DIR/prompts` when `PI_CODING_AGENT_DIR` is set, including `~/...` and `file://...` values.
- `~/.pi/agent/prompts` otherwise.

Prompt files are loaded when the plugin starts. Restart dsh after adding or changing a prompt file.

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
