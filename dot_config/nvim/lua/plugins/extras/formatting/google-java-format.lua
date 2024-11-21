return {
  {
    "williamboman/mason.nvim",
    opts = { ensure_installed = { "google-java-format" } },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        java = { "google-java-format" },
      },
    },
  },
}
