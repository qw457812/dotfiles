local request_timeout = 2

---@module "lazy"
---@type LazySpec
return {
  {
    "LazyVim/LazyVim",
    ---@module "lazyvim"
    ---@type LazyVimOptions|{}
    opts = {
      icons = {
        kinds = {
          Minuet = "󱗻 ",
          Claude = "󰋦 ",
          OpenAI = "󱢆 ",
          Gemini = " ",
          Groq = " ",
          OpenRouter = "󱂇 ",
          Ollama = "󰳆 ",
          DeepSeek = " ",
        },
      },
    },
  },

  -- https://github.com/milanglacier/nvim/blob/f19f427127b75eebf8f0f46e28f6e2c72d629de9/lua/plugins/completion.lua
  {
    "milanglacier/minuet-ai.nvim",
    lazy = true,
    opts = {
      provider = "openai_compatible",
      request_timeout = request_timeout,
      throttle = 2000,
      debounce = 800,
      add_single_line_entry = false,
      n_completions = 1,
      provider_options = {
        openai_compatible = {
          api_key = "OPENROUTER_API_KEY",
          end_point = "https://openrouter.ai/api/v1/chat/completions",
          model = "google/gemini-2.5-flash-preview-05-20",
          name = "Gemini", -- blink kind_icon: LazyVim.config.icons.kinds.Gemini
          optional = {
            max_tokens = 256,
            top_p = 0.9,
            provider = {
              sort = "throughput", -- prioritize throughput for faster completion
            },
          },
        },
      },
    },
  },

  {
    "milanglacier/minuet-ai.nvim",
    opts = function()
      local has_nvim_cmp = LazyVim.has_extra("coding.nvim-cmp")
      local cmp_engine = has_nvim_cmp and "cmp" or "blink"

      Snacks.util.set_hl({ [has_nvim_cmp and "CmpItemKindMinuet" or "BlinkCmpItemKindMinuet"] = "MiniIconsRed" })

      -- see: https://github.com/milanglacier/minuet-ai.nvim/blob/ef001ddff241d5d4f27cb37a2c331c576965cce3/lua/minuet/init.lua#L158-L169
      U.toggle.ai_cmps.minuet = Snacks.toggle({
        name = "Minuet",
        get = function()
          return package.loaded["minuet"] ~= nil and require("minuet").config[cmp_engine].enable_auto_complete
        end,
        set = function(state)
          require("minuet").config[cmp_engine].enable_auto_complete = state
        end,
      })
    end,
  },

  {
    "saghen/blink.cmp",
    optional = true,
    dependencies = "milanglacier/minuet-ai.nvim",
    ---@module "blink.cmp"
    ---@type blink.cmp.Config
    opts = {
      sources = {
        default = { "minuet" },
        providers = {
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            score_offset = 99,
            async = true,
            timeout_ms = request_timeout * 1000 + 100,
          },
        },
      },
    },
  },

  {
    "nvim-cmp",
    optional = true,
    dependencies = "milanglacier/minuet-ai.nvim",
    opts = function(_, opts)
      table.insert(opts.sources, 1, {
        name = "minuet",
        group_index = 1,
        priority = 99,
      })

      opts.performance = opts.performance or {}
      opts.performance.fetching_timeout =
        math.max(opts.performance.fetching_timeout or 500, request_timeout * 1000 + 100)
    end,
  },

  -- https://github.com/milanglacier/minuet-ai.nvim/blob/3207ecff6781eb38d7f122fe062bc2d6cd35c3cd/lua/minuet/lualine.lua
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      local utils = require("lualine.utils.utils")
      local minuet = require("lualine.component"):extend()

      function minuet:init(options)
        minuet.super.init(self, options)

        -- https://github.com/nvim-lualine/lualine.nvim/blob/afece9bbf960f908cbaffebaa4b5a0506e9dc8ed/lua/lualine/components/diff/init.lua#L47-L56
        -- stylua: ignore
        self.highlights = {
          ok = self:create_hl({ fg = utils.extract_color_from_hllist("fg", { "Special" }, "#65BCFF") }, "minuet_ok"),
          pending = self:create_hl({ fg = utils.extract_color_from_hllist("fg", { "DiagnosticWarn" }, "#FFC777") }, "minuet_pending"),
        }

        self.processing = false
        self.n_requests, self.n_finished_requests = 1, 0
        -- self.provider, self.model = nil, nil

        local group = vim.api.nvim_create_augroup("minuet_lualine", {})
        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "MinuetRequestStartedPre",
          callback = function(ev)
            local data = ev.data
            self.processing = false
            self.n_requests, self.n_finished_requests = data.n_requests, 0
            -- self.provider, self.model = data.name, data.model
          end,
        })
        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "MinuetRequestStarted",
          callback = function()
            self.processing = true
          end,
        })
        vim.api.nvim_create_autocmd("User", {
          group = group,
          pattern = "MinuetRequestFinished",
          callback = function()
            self.n_finished_requests = self.n_finished_requests + 1
            if self.n_finished_requests == self.n_requests then
              self.processing = false
            end
          end,
        })
      end

      function minuet:update_status()
        local color = self:format_hl(self.processing and self.highlights.pending or self.highlights.ok)
        local icon = LazyVim.config.icons.kinds.Minuet
        if self.processing then
          local progress = self.n_requests > 1 and ("%s󰿟%s"):format(self.n_finished_requests + 1, self.n_requests)
            or ""
          -- return ("%s%s%s %s"):format(color, icon, progress, Snacks.util.spinner())
          return color .. icon .. progress
        else
          return color .. icon
        end
      end

      table.insert(opts.sections.lualine_x, 6, {
        minuet,
        cond = function()
          if U.toggle.ai_cmps.minuet then
            return U.toggle.ai_cmps.minuet:get()
          end
          return package.loaded["minuet"] ~= nil
        end,
      })
    end,
  },
}
