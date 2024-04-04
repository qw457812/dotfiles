version = '0.21.7'
-- https://github.com/sayanarijit/xplr/blob/main/src/init.lua
-- https://github.com/sayanarijit/xplr/commit/ded2e108bf12dd5a8bb3b2bd0a8bdafa73fee410
---@diagnostic disable
local xplr = xplr -- The globally exposed configuration to be overridden.
---@diagnostic enable

-- This is the built-in configuration file that gets loaded and sets the
-- default values when xplr loads, before loading any other custom
-- configuration file.
--
-- You can use this file as a reference to create a your custom config file.
--
-- To create a custom configuration file, you need to define the script version
-- for compatibility checks.
--
-- See https://xplr.dev/en/upgrade-guide
--
-- ```lua
-- version = "0.0.0"
-- ```

-- # Configuration ------------------------------------------------------------
--
-- xplr can be configured using [Lua][1] via a special file named `init.lua`,
-- which can be placed in `~/.config/xplr/` (local to user) or `/etc/xplr/`
-- (global) depending on the use case.
--
-- When xplr loads, it first executes the [built-in init.lua][2] to set the
-- default values, which is then overwritten by another config file, if found
-- using the following lookup order:
--
-- 1. `--config /path/to/init.lua`
-- 2. `~/.config/xplr/init.lua`
-- 3. `/etc/xplr/init.lua`
--
-- The first one found will be loaded by xplr and the lookup will stop.
--
-- The loaded config can be further extended using the `-C` or `--extra-config`
-- command-line option.
--
--
-- [1]: https://www.lua.org
-- [2]: https://github.com/sayanarijit/xplr/blob/main/src/init.lua
-- [3]: https://xplr.dev/en/upgrade-guide

-- ## Config ------------------------------------------------------------------
--
-- The xplr configuration, exposed via `xplr.config` Lua API contains the
-- following sections.
--
-- See:
--
-- * [xplr.config.general](https://xplr.dev/en/general-config)
-- * [xplr.config.node_types](https://xplr.dev/en/node_types)
-- * [xplr.config.layouts](https://xplr.dev/en/layouts)
-- * [xplr.config.modes](https://xplr.dev/en/modes)

-- ### General Configuration --------------------------------------------------
--
-- The general configuration properties are grouped together in
-- `xplr.config.general`.

-- Set it to `true` to show hidden files by default.
--
-- Type: boolean
-- xplr.config.general.show_hidden = false
xplr.config.general.show_hidden = true

-- ### Node Types -------------------------------------------------------------
--
-- This section defines how to deal with different kinds of nodes (files,
-- directories, symlinks etc.) based on their properties.
--
-- One node can fall into multiple categories. For example, a node can have the
-- *extension* `md`, and also be a *file*. In that case, the properties from
-- the more  specific category i.e. *extension* will be used.
--
-- This can be configured using the `xplr.config.node_types` Lua API.

-- Metadata for the directory nodes.
-- You can set as many metadata as you want.
--
-- Type: nullable string
--
-- Example:
--
-- ```lua
-- xplr.config.node_types.directory.meta.foo = "foo"
-- xplr.config.node_types.directory.meta.bar = "bar"
-- ```
-- https://github.com/sayanarijit/xplr/issues/78
-- xplr.config.node_types.directory.meta.icon = "ð"
xplr.config.node_types.directory.meta.icon = ""

-- Metadata for the file nodes.
-- You can set as many metadata as you want.
--
-- Type: nullable string
--
-- Example:
--
-- ```lua
-- xplr.config.node_types.file.meta.foo = "foo"
-- xplr.config.node_types.file.meta.bar = "bar"
-- ```
-- xplr.config.node_types.file.meta.icon = "ƒ"
xplr.config.node_types.file.meta.icon = ""

-- Metadata for the symlink nodes.
-- You can set as many metadata as you want.
--
-- Type: nullable string
--
-- Example:
--
-- ```lua
-- xplr.config.node_types.symlink.meta.foo = "foo"
-- xplr.config.node_types.symlink.meta.bar = "bar"
-- ```
-- xplr.config.node_types.symlink.meta.icon = "§"
xplr.config.node_types.symlink.meta.icon = ""

-- ### Layouts ----------------------------------------------------------------
--
-- xplr layouts define the structure of the UI, i.e. how many panel we see,
-- placement and size of the panels, how they look etc.
--
-- This is configuration exposed via the `xplr.config.layouts` API.
--
-- `xplr.config.layouts.builtin` contain some built-in panels which can be
-- overridden, but you can't add or remove panels in it.
--
-- You can add new panels in `xplr.config.layouts.custom`.
--
-- ##### Example: Defining Custom Layout
--
-- ```lua
-- xplr.config.layouts.builtin.default = {
--   Horizontal = {
--     config = {
--       margin = 1,
--       horizontal_margin = 1,
--       vertical_margin = 1,
--       constraints = {
--         { Percentage = 50 },
--         { Percentage = 50 },
--       }
--     },
--     splits = {
--       "Table",
--       "HelpMenu",
--     }
--   }
-- }
-- ```
--
-- Result:
--
-- ```
-- ╭ /home ─────────────╮╭ Help [default] ────╮
-- │   ╭─── path        ││.    show hidden    │
-- │   ├▸[ð Desktop/]   ││/    search         │
-- │   ├  ð Documents/  ││:    action         │
-- │   ├  ð Downloads/  ││?    global help    │
-- │   ├  ð GitHub/     ││G    go to bottom   │
-- │   ├  ð Music/      ││V    select/unselect│
-- │   ├  ð Pictures/   ││ctrl duplicate as   │
-- │   ├  ð Public/     ││ctrl next visit     │
-- ╰────────────────────╯╰────────────────────╯
-- ```

-- ### Modes ------------------------------------------------------------------
--
-- xplr is a modal file explorer. That means the users switch between different
-- modes, each containing a different set of key bindings to avoid clashes.
-- Users can switch between these modes at run-time.
--
-- The modes can be configured using the `xplr.config.modes` Lua API.
--
-- `xplr.config.modes.builtin` contain some built-in modes which can be
-- overridden, but you can't add or remove modes in it.

-- ## Function ----------------------------------------------------------------
--
-- While `xplr.config` defines all the static parts of the configuration,
-- `xplr.fn` defines all the dynamic parts using functions.
--
-- See: [Lua Function Calls](https://xplr.dev/en/lua-function-calls)
--
-- As always, `xplr.fn.builtin` is where the built-in functions are defined
-- that can be overwritten.

-- ## Hooks -------------------------------------------------------------------
--
-- This section of the configuration cannot be overwritten by another config
-- file or plugin, since this is an optional lua return statement specific to
-- each config file. It can be used to define things that should be explicit
-- for reasons like performance concerns, such as hooks.
--
-- Plugins should expose the hooks, and require users to subscribe to them
-- explicitly.
--
-- Example:
--
-- ```lua
-- return {
--   -- Add messages to send when the xplr loads.
--   -- This is similar to the `--on-load` command-line option.
--   --
--   -- Type: list of [Message](https://xplr.dev/en/message#message)s
--   on_load = {
--     { LogSuccess = "Configuration successfully loaded!" },
--     { CallLuaSilently = "custom.some_plugin_with_hooks.on_load" },
--   },
--
--   -- Add messages to send when the directory changes.
--   --
--   -- Type: list of [Message](https://xplr.dev/en/message#message)s
--   on_directory_change = {
--     { LogSuccess = "Changed directory" },
--     { CallLuaSilently = "custom.some_plugin_with_hooks.on_directory_change" },
--   },
--
--   -- Add messages to send when the focus changes.
--   --
--   -- Type: list of [Message](https://xplr.dev/en/message#message)s
--   on_focus_change = {
--     { LogSuccess = "Changed focus" },
--     { CallLuaSilently = "custom.some_plugin_with_hooks.on_focus_change" },
--   }
--
--   -- Add messages to send when the mode is switched.
--   --
--   -- Type: list of [Message](https://xplr.dev/en/message#message)s
--   on_mode_switch = {
--     { LogSuccess = "Switched mode" },
--     { CallLuaSilently = "custom.some_plugin_with_hooks.on_mode_switch" },
--   }
--
--   -- Add messages to send when the layout is switched
--   --
--   -- Type: list of [Message](https://xplr.dev/en/message#message)s
--   on_layout_switch = {
--     { LogSuccess = "Switched layout" },
--     { CallLuaSilently = "custom.some_plugin_with_hooks.on_layout_switch" },
--   }
--
--   -- Add messages to send when the selection changes
--   --
--   -- Type: list of [Message](https://xplr.dev/en/message#message)s
--   on_selection_change = {
--     { LogSuccess = "Selection changed" },
--     { CallLuaSilently = "custom.some_plugin_with_hooks.on_selection_change" },
--   }
-- }
-- ```

-- ----------------------------------------------------------------------------
-- > Note:
-- >
-- > It's not recommended to copy the entire configuration, unless you want to
-- > freeze it and miss out on useful updates to the defaults.
-- >
-- > Instead, you can use this as a reference to overwrite only the parts you
-- > want to update.
-- >
-- > If you still want to copy the entire configuration, make sure to put your
-- > customization before the return statement.

-- https://xplr.dev/en/awesome-plugins#theme
-- https://github.com/dtomvan/xpm.xplr
local home = os.getenv("HOME")
local xpm_path = home .. "/.local/share/xplr/dtomvan/xpm.xplr"
local xpm_url = "https://github.com/dtomvan/xpm.xplr"

package.path = package.path
  .. ";"
  .. xpm_path
  .. "/?.lua;"
  .. xpm_path
  .. "/?/init.lua"

os.execute(
  string.format(
    "[ -e '%s' ] || git clone '%s' '%s'",
    xpm_path,
    xpm_url,
    xpm_path
  )
)

-- https://github.com/dtomvan/extra-icons.xplr
require('xpm').setup {
  'dtomvan/xpm.xplr',
  -- { 'dtomvan/extra-icons.xplr',
  --     after = function()
  --         xplr.config.general.table.row.cols[2] = { format = "custom.icons_dtomvan_col_1" }
  --     end
  -- },
  -- https://github.com/prncss-xyz/icons.xplr
  -- 'prncss-xyz/icons.xplr',
  -- https://github.com/sayanarijit/zentable.xplr
  'sayanarijit/zentable.xplr',
}
