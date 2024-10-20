-- https://yazi-rs.github.io/docs/tips#navigation-wraparound
-- File navigation wraparound
return {
  entry = function(_, args)
    local current = cx.active.current
    local new = (current.cursor + args[1]) % #current.files
    ya.manager_emit("arrow", { new - current.cursor })
  end,
}
