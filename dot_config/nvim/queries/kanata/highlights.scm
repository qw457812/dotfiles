(line_comment) @comment

(block_comment) @comment

[
  "("
  ")"
] @punctuation.bracket

(quoted_item) @string

(list
  .
  (unquoted_item) @function)

((unquoted_item) @keyword
  (#lua-match? @keyword "^def[%w%-]+$"))

((unquoted_item) @constant
  (#lua-match? @constant "^@"))

((unquoted_item) @variable
  (#lua-match? @variable "^%$"))

((unquoted_item) @number
  (#lua-match? @number "^%d+$"))

((unquoted_item) @boolean
  (#any-of? @boolean "yes" "no"))
