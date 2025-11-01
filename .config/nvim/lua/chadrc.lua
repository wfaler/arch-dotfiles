-- This file  needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}
vim.api.nvim_create_autocmd("BufWinEnter", {
        pattern = "*.templ",
        command = "set filetype=templ",
})
-- invoke prettier on save for js, ts etc files

vim.api.nvim_create_user_command('Prettier', function()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)  -- Save cursor position
    vim.cmd('%!prettier --stdin-filepath ' .. vim.fn.shellescape(vim.api.nvim_buf_get_name(0)))
    vim.api.nvim_win_set_cursor(0, cursor_pos)  -- Restore cursor position
end, {})


M.ui = {
   theme = "catppuccin",
   catppuccin_flavour = "macchiato"
}

M.mason.pkgs = {
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
}

return M
