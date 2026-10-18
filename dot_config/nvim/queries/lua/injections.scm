; extends

; MiniTest child Neovim: Lua source strings.
((function_call
  name: (_) @_name
  arguments: (arguments
    .
    (string
      content: (string_content) @injection.content)))
  (#any-of? @_name "child.lua" "child.lua_get" "child.lua_notify")
  (#set! injection.language "lua"))

; MiniTest child Neovim: Vimscript source strings.
((function_call
  name: (_) @_name
  arguments: (arguments
    .
    (string
      content: (string_content) @injection.content)))
  (#any-of? @_name "child.cmd" "child.cmd_capture")
  (#set! injection.language "vim"))
