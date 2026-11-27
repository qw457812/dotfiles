# Review prompt-editor against Pi and pi-vim

`PromptEditor extends ModalEditor` uses private APIs from both hosts. Lazy tracks both source checkouts; Pi installs a published CLI and manages pi-vim separately. The source checkout and the loaded npm package are different review surfaces.

## 1. Freeze the ranges

For **both** peers record the installed runtime version: `pi --version` and the loaded pi-vim `package.json` under `getAgentDir()/npm/node_modules/pi-vim` (normally `~/.pi/agent/npm/node_modules/pi-vim`; honor `PI_CODING_AGENT_DIR`). Record separately installed development pins when they differ. For each **in-scope outdated** package:

- **Checkout:** copy `installed..target` from the report header. Inspect those commits in a refreshed librarian cache (read `~/.pi/agent/skills/librarian/SKILL.md`), leaving the lazy checkout and its refs alone.
- **Pi release:** snapshot the [self-update endpoint](https://pi.dev/api/latest-version) once. Require `ok: true`, `packageName` and `version`; record the exact old and target npm package names and versions. The installed package is normally `@earendil-works/pi-coding-agent`.
- **pi-vim release:** use the loaded version as old and freeze the target from `npm view pi-vim version`. If a peer is out of scope, keep its installed runtime fixed without selecting a new release for it.
- **Published revisions:** resolve each exact artifact with `npm view 'package@version' gitHead`. If empty, follow [npm provenance](RELEASE-REV.md) with that exact artifact. Verify and expand each revision to a full hash with `git rev-parse --verify '<rev>^{commit}'` in its matching cache. Compare the lazy and published targets for checkout-only changes; the published range describes the runtime.

**Done when:** the review records both installed peers, all applicable checkout and published ranges (full hashes), and which changes are released. Missing provenance or objects block the exact source review; they do not rule out tests of the exact npm artifact.

## 2. Trace private contracts

Read the log and diff stat for every distinct frozen range. In `private_dot_pi/private_agent/extensions/prompt-editor/`, enumerate private members, generated wrapper exports, and upstream factory behavior mirrored locally. Trace each to its definition and consumers in the exact target. Start with Pi's `packages/tui/src/` (editor, key handling and main/alt-screen renderers) and the coding agent's `custom-editor.ts`, extension types and interactive editor factory. In pi-vim start with `ModalEditor`, its settings and the helper modules imported or re-exported by the wrapper. Follow moved definitions rather than treating that list as exhaustive.

Read the applicable contract checks:

| Changed upstream surface | Check |
| --- | --- |
| Loader, exports, constructor, settings/factory, history, session lifecycle | [Wrapper and replacement lifecycle](REFERENCE.md#wrapper-and-replacement-lifecycle) |
| Render, colorizers, preflight or label placement | [Render and degradation](REFERENCE.md#render-and-degradation) |
| Cursor markers, visibility, renderer switching or terminal focus | [Cursor ownership](REFERENCE.md#cursor-ownership) |
| Input dispatch, pending state, shortcuts, Ex, motion or autocomplete | [Navigation and shortcuts](REFERENCE.md#navigation-and-shortcuts) |
| Visual operators, put, register behavior or clipboard | [Visual paste](REFERENCE.md#visual-paste), [Clipboard transport](REFERENCE.md#clipboard-transport) as applicable |

When testing declarations or behavior during review, use [isolated Pi validation](../pi-runtime/VALIDATE.md#isolated-target-checks). A stale `pi-vim.generated.ts` can masquerade as an API removal: compare it to `ensurePiVimWrapper()` and regenerate in the isolated copy only. For changed render/input behavior, use the actual target components; type checks cannot validate escape sequences or dispatch order.

**Done when:** each affected contract and every structurally accessed private member has a finding: compatible, needs a concrete edit, or intentionally unsupported with a reason. Record static evidence, exact-target tests and follow-ups separately.
