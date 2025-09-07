if not LazyVim.has_extra("lang.nix") then
  return {}
end

---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "nix",
        callback = function(ev)
          if vim.fn.executable("nixfmt") == 0 then
            vim.b[ev.buf].autoformat = false
          end
        end,
      })
    end,
  },
}
