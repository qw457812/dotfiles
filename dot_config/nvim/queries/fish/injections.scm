; extends

((command
  name: (word) @_cmd
  argument: [
    (single_quote_string)
    (double_quote_string)
  ] @injection.content)
  (#eq? @_cmd "jq")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "jq"))

((command
  name: (word) @_cmd
  argument: [
    (single_quote_string)
    (double_quote_string)
  ] @injection.content)
  (#eq? @_cmd "awk")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "awk"))
