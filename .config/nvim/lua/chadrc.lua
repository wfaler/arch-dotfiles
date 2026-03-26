-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.ui = {
   theme = "catppuccin",
   catppuccin_flavour = "macchiato"
}

M.mason = {
  pkgs = {
    "gopls", -- go
    "templ", -- templ
    "goimports", -- go
    "pyright", -- python - removed black explicitly here and added it as a dependency in mise
    "ruff",
    "terraform-ls", -- terraform
    "tflint",
    "typescript-language-server", -- typescript
    "vue-language-server",
    "prettier",
    "html-lsp",
    "jdtls",
    "google-java-format",
    "kotlin-language-server",
  },
}

return M
