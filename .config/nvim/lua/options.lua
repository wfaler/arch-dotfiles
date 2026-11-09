require "nvchad.options"

-- add yours here!

-- Full diagnostic messages as lines under the cursor's line; elsewhere the sign
-- column marks them. (Inline virtual text would repeat the current line's.)
vim.diagnostic.config {
  virtual_text = false,
  virtual_lines = { current_line = true },
}
