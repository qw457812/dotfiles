---@type LazySpec
return {
  {
    "oysandvik94/curl.nvim",
    cmd = "CurlOpen",
    keys = {
      { "<leader>C", "<cmd>CurlOpen<cr>", desc = "Open Curl (cwd)" },
    },
    ---@module "curl"
    ---@type curl_config
    opts = {
      open_with = "buffer",
      show_request_duration_limit = 1,
    },
  },
}
