-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

-- The theme lives under base46 (M.ui.theme is ignored). base46 has one dark
-- Catppuccin (mocha-like) plus catppuccin-latte; there is no macchiato.
M.base46 = {
  theme = "catppuccin",
}

-- :MasonInstallAll installs these.
M.mason = {
  pkgs = {
    "tree-sitter-cli", -- nvim-treesitter needs it to build parsers
    "stylua", -- lua formatter (conform)
    "gopls", -- go
    "goimports",
    "templ", -- templ
    "pyright", -- python - removed black explicitly here and added it as a dependency in mise
    "ruff", -- python lint (LSP) and formatter
    "terraform-ls", -- terraform
    "tflint",
    "typescript-language-server", -- typescript
    "vue-language-server", -- vue_ls, plus @vue/typescript-plugin for ts_ls
    "svelte-language-server", -- svelte, plus typescript-svelte-plugin for ts_ls
    "prettier",
    "html-lsp",
    "jdtls", -- java
    "google-java-format",
    "kotlin-lsp", -- kotlin (JetBrains)
  },
}

return M
