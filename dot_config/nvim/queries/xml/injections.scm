; extends

; MyBatis
((element
  (STag
    (Name) @_name)
  (content) @injection.content)
  (#any-of? @_name "sql" "select" "insert" "update" "delete")
  (#set! injection.include-children)
  (#set! injection.language "sql"))
