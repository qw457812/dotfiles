--- @sync entry
local function entry(_, job)
  local parent = cx.active.parent
  if not parent then
    return
  end

  local offset = tonumber(job.args[1])
  if not offset then
    return ya.err(job.args[1], "is not a number")
  end

  -- Skip files
  local start = parent.cursor + 1 + offset
  local end_ = offset < 0 and 1 or #parent.files
  local step = offset < 0 and -1 or 1
  for i = start, end_, step do
    local target = parent.files[i]
    if target and target.cha.is_dir then
      return ya.mgr_emit("cd", { target.url })
    end
  end
end

-- https://yazi-rs.github.io/docs/tips#parent-arrow
-- Navigation in the parent directory without leaving the CWD
return { entry = entry }
