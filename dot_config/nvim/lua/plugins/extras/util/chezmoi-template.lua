if not U.path.CHEZMOI then
  return {}
end

---@type LazySpec
return {
  -- alker0/chezmoi.vim and chezmoi-template.nvim both detect template filetypes; use
  -- gotmpl instead of *.chezmoitmpl.
  { "alker0/chezmoi.vim", enabled = false },

  {
    "dpezto/chezmoi-template.nvim",
    lazy = false,
    ---@module "chezmoi-template"
    ---@param opts chezmoi-template.Config
    opts = function(_, opts)
      local has_chezmoi_nvim = LazyVim.has("chezmoi.nvim")

      return U.extend_tbl(opts, {
        source_dir = U.path.CHEZMOI,
        apply = {
          -- The existing chezmoi.nvim integration already watches source files.
          on_save = not has_chezmoi_nvim,
        },
        keymaps = { enabled = true },
        encryption = { enabled = true },
      } --[[@as chezmoi-template.Config]])
    end,
  },

  {
    "nvim-mini/mini.diff",
    optional = true,
    opts = function()
      -- mini.diff's git source has no textconv support, so encrypted sources diff plaintext
      -- against age armor. Decrypt the index baseline below instead.
      --
      -- Alternative:
      -- patch its `H.git_set_ref_text` like this, which also keeps the `.git/index` watcher:
      --[[
diff --git a/lua/mini/diff.lua b/lua/mini/diff.lua
index c83fd34..ec6274c 100644
--- a/lua/mini/diff.lua
+++ b/lua/mini/diff.lua
@@ -1766,7 +1766,7 @@ H.git_set_ref_text = vim.schedule_wrap(function(buf_id)
 
   -- Set
   local stdout = vim.uv.new_pipe()
-  local spawn_opts = { args = { 'show', ':0:./' .. basename }, cwd = cwd, stdio = { nil, stdout, nil } }
+  local spawn_opts = { args = { 'cat-file', '--textconv', ':0:./' .. basename }, cwd = cwd, stdio = { nil, stdout, nil } }
 
   local process, stdout_feed = nil, {}
   local on_exit = function(exit_code)
      ]]
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("chezmoi_template_encrypted_diff", { clear = true }),
        pattern = { "*.age", "*.asc" },
        callback = function(ev)
          -- https://github.com/dpezto/chezmoi-template.nvim/blob/ec545225d2438487d89b9e5146c2d29820d91b87/lua/chezmoi-template/encryption.lua#L111
          if not vim.b[ev.buf].chezmoi_decrypted or vim.b[ev.buf].minidiff_config ~= nil then
            return
          end

          ---@param buf_id integer
          local function attach(buf_id)
            local path = vim.api.nvim_buf_get_name(buf_id)
            local on_fail = vim.schedule_wrap(function()
              require("mini.diff").fail_attach(buf_id)
            end)

            vim.system({
              "git",
              "show",
              ":0:./" .. vim.fs.basename(path),
            }, { cwd = vim.fs.dirname(path), text = true }, function(blob)
              if blob.code ~= 0 then
                return on_fail()
              end
              vim.system({ "chezmoi", "decrypt" }, { stdin = blob.stdout }, function(plain)
                if plain.code ~= 0 then
                  return on_fail()
                end
                vim.schedule(function()
                  require("mini.diff").set_ref_text(buf_id, plain.stdout)
                end)
              end)
            end)
          end

          vim.b[ev.buf].minidiff_config = { source = { { name = "chezmoi-encrypted", attach = attach } } }
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "gotmpl" } },
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = {
      "dpezto/chezmoi-template.nvim",
      shell_command_editor = true,
    },
    opts = {
      sources = {
        default = { "chezmoi" },
        providers = {
          chezmoi = {
            name = "chezmoi",
            module = "chezmoi-template.blink",
          },
        },
      },
    },
  },
}
