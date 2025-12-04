; extends

((command
  name: (command_name) @_cmd
  argument: (raw_string) @injection.content)
  (#eq? @_cmd "jq")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "jq"))

((command
  name: (command_name) @_cmd
  argument: (raw_string) @injection.content)
  (#eq? @_cmd "awk")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "awk"))
