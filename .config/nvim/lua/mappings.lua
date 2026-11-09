require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- git
map("n", "<leader>gs", "<cmd>Telescope git_status<cr>", { desc = "Git status files" })

-- diffview
map("n", "<leader>do", "<cmd>DiffviewOpen<cr>", { desc = "Diffview open" })
map("n", "<leader>dh", "<cmd>DiffviewFileHistory %<cr>", { desc = "Diffview file history" })
map("n", "<leader>dc", "<cmd>DiffviewClose<cr>", { desc = "Diffview close" })

-- neotest (require() loads the plugin on first use)
map("n", "<leader>tn", function()
  require("neotest").run.run()
end, { desc = "Test run nearest" })
map("n", "<leader>tf", function()
  require("neotest").run.run(vim.fn.expand "%")
end, { desc = "Test run file" })
map("n", "<leader>ts", function()
  require("neotest").summary.toggle()
end, { desc = "Test toggle summary" })
