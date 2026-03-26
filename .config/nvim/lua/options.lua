require "nvchad.options"

-- add yours here!

vim.o.autoread = true

vim.api.nvim_create_autocmd("BufWinEnter", {
  pattern = "*.templ",
  command = "set filetype=templ",
})

vim.api.nvim_create_user_command('Prettier', function()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd('%!prettier --stdin-filepath ' .. vim.fn.shellescape(vim.api.nvim_buf_get_name(0)))
  vim.api.nvim_win_set_cursor(0, cursor_pos)
end, {})
