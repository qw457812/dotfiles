---
name: chezmoi-symlink
description: Convert a chezmoi-managed plain config file into a chezmoi symlink.
disable-model-invocation: true
---

# chezmoi-symlink

Turn a chezmoi-managed plain config file into a **symlink** under this repo's
convention: the real content moves into `symlinks/<app>/...`, and the source
file is replaced by a **pointer** — a `symlink_<name>.tmpl` whose entire body is
the path to that content. Content and pointer are a pair that always move
together; never leave one without the other.

## Steps

1. **Find the file's current source representation and its app bucket.** Get the
   source path and confirm how it's currently managed:

   ```bash
   chezmoi source-path <target>   # e.g. ~/.codex/rules/default.rules
   chezmoi managed | rg '<target>' # confirm it's tracked
   ```

   Distinguish a real plain source file (`dot_*`/`private_*`, not a source
   template ending in `.tmpl`) from an existing **pointer**
   (`symlink_*.tmpl`) — if it's already a pointer, there's nothing to do. If the
   managed source itself ends in `.tmpl`, stop: this workflow is for plain
   source files only, because symlinking a source template would expose
   unrendered template text instead of chezmoi's rendered output. The **app**
   bucket is the app name at the top of `symlinks/` (e.g. `dot_codex` → `codex`,
   nvim configs → `nvim`); match an existing sibling under `symlinks/<app>/` if
   one exists, else mirror the sub-path.

   Completion criterion: you know the exact current source path of the plain
   content file, or you've stopped because the source is a template; in the
   plain-file case, you also know the chosen destination
   `symlinks/<app>/<rest>`.

2. **Move the real content into `symlinks/` with `git mv`.** `symlinks/` is
   git-tracked (it is only `.chezmoiignore`d, which stops chezmoi deploying it,
   not git), so `git mv` preserves history:

   ```bash
   mkdir -p symlinks/<app>/<rest-dir>
   git mv <current-source-path> symlinks/<app>/<rest>
   ```

   Completion criterion: the content lives at `symlinks/<app>/<rest>` and
   `git status` shows it as a rename into `symlinks/`, not an add+delete.

3. **Write the pointer in the vacated source location.** In the exact directory
   the content came from, create `symlink_<basename>.tmpl` whose body is the
   path to the content, rooted at `{{ .chezmoi.sourceDir }}` so it resolves
   regardless of where the source dir lives, with a trailing newline:

   ```text
   {{ .chezmoi.sourceDir }}/symlinks/<app>/<rest>
   ```

   Name = `symlink_<basename>.tmpl`, where `<basename>` is the plain source
   filename you just moved (e.g. `default.rules` → `symlink_default.rules.tmpl`;
   the directory's `dot_`/`private_` prefix already encodes the target location,
   so it carries through unchanged). Do not apply this naming rule to source
   templates like `foo.tmpl`; templated source files are out of scope for this
   workflow.

   Completion criterion: the pointer file exists in the vacated directory with
   exactly that body — one line, `{{ .chezmoi.sourceDir }}` prefix, trailing
   newline.

4. **Apply the pointer and verify the symlink resolves.** Apply the target so
   the pointer is realised, then confirm both chezmoi's view and the live
   target:

   ```bash
   chezmoi apply <target>
   chezmoi dump | rg -A3 '"<basename>"'   # expect "type": "symlink" + "linkname"
   readlink <target>                       # resolves to symlinks/<app>/<rest>
   ```

   Completion criterion: `chezmoi dump` lists the target as
   `"type": "symlink"` with the correct `linkname` **and** `readlink <target>`
   resolves to the real content — both, not one.

## Notes

- This workflow relies on the backing file being ignored by chezmoi; in this
  repo that is provided by `symlinks/` being listed in `.chezmoiignore`.
  `symlinks/` is still git-tracked, which is why `git mv` keeps history and why
  the content lives there at all.
- The pointer's `.tmpl` + `{{ .chezmoi.sourceDir }}` is load-bearing: a bare
  relative path breaks when the source dir moves. Keep the template verbatim.
- If the target isn't managed yet, there's nothing to `git mv` — just place the
  plain content under `symlinks/<app>/...` and write the pointer (step 3
  onward).
