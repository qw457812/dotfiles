-- https://github.com/craftzdog/dotfiles/blob/b15a238007bd2f9fc9325c9c0f5edb7a8c102e87/dot_config/rex/copy_mode.lua

local scrollback_in_nvim = [[
scrollback=$(mktemp) || exit 1
trap 'rm -f "$scrollback"; rex focus -s "$1" "$2"' EXIT
rex capture -s "$1" -b "$2" --format=vt --trim --unwrap > "$scrollback" || exit 1
nvim --cmd 'lua vim.g.terminal_scrollback_pager = true' \
  -c 'lua U.terminal.colorize()' \
  -- "$scrollback"
]]

rex.action({
  name = "copy_mode",
  title = "Copy Mode (Scrollback in Neovim)",
  run = function(ctx)
    local layer, err = rex.session.new_layer({
      bounds = { 0, 0, 1, 1 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        options = {
          command = { "sh", "-c", scrollback_in_nvim, "rex_copy_mode", ctx.session_id, ctx.block_id },
        },
      }),
    })
    if err then
      error(err, 0)
    end
    return { block_ids = layer.block_ids }
  end,
})

rex.bind("ctrl+b>[", "copy_mode")
rex.bind("ctrl+b>space", "copy_mode")
rex.bind("cmd+space", "copy_mode")
