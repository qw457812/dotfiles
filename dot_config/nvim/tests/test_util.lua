local eq = MiniTest.expect.equality
local U = require("util")

local T = MiniTest.new_set()

T["truncate()"] = MiniTest.new_set()

T["truncate()"]["keeps text that already fits"] = function()
  eq(U.truncate("already fits", 20), "already fits")
  eq(U.truncate("中中中", 6), "中中中")
  eq(U.truncate(("e\u{301}"):rep(5), 5), ("e\u{301}"):rep(5))
end

T["truncate()"]["handles width not larger than 1"] = function()
  eq(U.truncate("", 0), "")
  eq(U.truncate("abc", 0), "")
  eq(U.truncate("a", 1), "a")
  eq(U.truncate("中", 1), "…")
end

T["truncate()"]["truncates ASCII from the requested side"] = function()
  eq(U.truncate("abcdefghij", 5), "abcd…")
  eq(U.truncate("abcdefghij", 5, 1), "abcd…")
  eq(U.truncate("abcdefghij", 5, -1), "…ghij")
end

T["truncate()"]["truncates wide characters by display width"] = function()
  eq(U.truncate("很长的中文文件名.txt", 10), "很长的中…")
  eq(U.truncate("很长的中文文件名.txt", 10, -1), "…件名.txt")
  eq(U.truncate("很长的中文文件名.txt", 12), "很长的中文…")
  eq(U.truncate("📁 项目/源码/组件", 8), "📁 项目…")
  eq(U.truncate("📁 项目/源码/组件", 8, -1), "…码/组件")
  eq(U.truncate("中中中中中", 4, -1), "…中")
end

T["truncate()"]["truncates combining characters"] = function()
  eq(U.truncate(("e\u{301}"):rep(5), 4), ("e\u{301}"):rep(3) .. "…")
end

T["truncate()"]["matches mini.test reporter title truncation"] = function()
  eq(U.truncate(("a😈ツ"):rep(40), 74, -1), "…ツ" .. ("a😈ツ"):rep(14))
end

T["truncate()"]["always fits into requested width"] = function()
  local texts = {
    "abcdefghij",
    "很长的中文文件名.txt",
    "📁 项目/源码/组件",
    ("e\u{301}"):rep(5),
  }
  for _, text in ipairs(texts) do
    for width = 0, 20 do
      for _, direction in ipairs({ -1, 1 }) do
        local res = U.truncate(text, width, direction)
        local msg = ("text=%q width=%d direction=%d result=%q"):format(text, width, direction, res)
        assert(vim.api.nvim_strwidth(res) <= width, msg)
        if res ~= text and res ~= "…" and width >= 1 then
          assert(direction == -1 and vim.startswith(res, "…") or vim.endswith(res, "…"), msg)
        end
      end
    end
  end
end

return T
