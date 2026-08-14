if not LazyVim.has_extra("lang.typescript") then
  return {}
end

---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    opts = function()
      if LazyVim.has_extra("lang.typescript.oxc") then
        vim.api.nvim_create_autocmd("BufWritePost", {
          group = vim.api.nvim_create_augroup("oxlint", { clear = true }),
          callback = function(ev)
            if
              vim.list_contains(
                { ".oxlintrc.json", ".oxlintrc.jsonc", "oxlint.config.ts" },
                vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ":t")
              ) and #vim.lsp.get_clients({ name = "oxlint" }) > 0
            then
              Snacks.notify("Restarting oxlint...")
              vim.cmd("lsp restart oxlint")
            end
          end,
        })
      end
    end,
  },

  -- TypeScript 7 renamed the `tsgo` lsp to `tsc` (nvim-lspconfig #4493).
  -- LazyVim only accepts `tsgo`/`vtsls` for `vim.g.lazyvim_ts_lsp`, so keep that global
  -- as-is and swap the servers here until LazyVim registers `tsc` itself.
  {
    "neovim/nvim-lspconfig",
    ---@param opts PluginLspOpts
    opts = function(_, opts)
      if vim.g.lazyvim_ts_lsp ~= "tsgo" then
        return
      end

      -- https://github.com/LazyVim/LazyVim/blob/d07070bf2ff83ae513097d02d71460920af85a91/lua/lazyvim/plugins/extras/lang/typescript/tsgo.lua#L23-L49
      local tsgo = opts.servers.tsgo
      tsgo = tsgo == true and {} or (not tsgo) and { enabled = false } or tsgo --[[@as lazyvim.lsp.Config]]

      return U.extend_tbl(opts, {
        ---@type table<string, lazyvim.lsp.Config|boolean>
        servers = {
          tsgo = {
            enabled = false,
          },
          tsc = U.extend_tbl(vim.deepcopy(tsgo), {
            enabled = true,
            -- upstream lsp/tsc.lua prefers root_dir/node_modules/.bin/tsc unconditionally, but
            -- `--lsp` only exists in TypeScript 7+; a project pinned to TS 5/6 then dies with
            -- "Unknown compiler option '--lsp'" (exit code 1).
            -- see: https://github.com/neovim/nvim-lspconfig/blob/033492baa0972c1a9e3916fc8d634ae6a9b8b155/lsp/tsc.lua#L66-L83
            cmd = function(dispatchers, config)
              local function supports_lsp(bin)
                local ok, sys = pcall(vim.system, { bin, "--version" }, { text = true })
                local res = ok and sys:wait(2000) or {}
                if res.code ~= 0 then
                  return false
                end
                local major = tonumber((res.stdout or ""):match("Version%s+(%d+)"))
                return major ~= nil and major >= 7
              end

              local cmd = "tsc"
              local bins = { "tsc", "tsgo" }
              for _, bin in ipairs(bins) do
                if (config or {}).root_dir then
                  local local_cmd = vim.fs.joinpath(config.root_dir, "node_modules/.bin", bin)
                  if vim.fn.executable(local_cmd) == 1 and supports_lsp(local_cmd) then
                    cmd = local_cmd
                    break
                  end
                end
                if vim.fn.executable(bin) == 1 and supports_lsp(bin) then
                  cmd = bin
                  break
                end
              end
              return vim.lsp.rpc.start({ cmd, "--lsp", "--stdio" }, dispatchers)
            end,
          } --[[@as lazyvim.lsp.Config]]),
        },
      } --[[@as PluginLspOpts]])
    end,
  },
}
