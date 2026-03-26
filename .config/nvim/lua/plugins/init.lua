return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre',
    config = function()
      require "configs.conform"
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        -- defaults
        "vim",
        "lua",
        "python",
        "go",
        "bash",
        "yaml",
        "toml",
        "terraform",
        "dockerfile",
        "scala",
        "templ",
        -- web dev
        "html",
        "css",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "vue",
        -- low level
        "c",
        "rust",
        "java",
        "kotlin",
      },
    },
  },
  {
    "williamboman/mason.nvim",
  },
  {
    "neovim/nvim-lspconfig",
     config = function()
       require "configs.lspconfig"
     end,
   },
  {
    "github/copilot.vim",
    lazy = false,
  },
  {
    "scalameta/nvim-metals",
    ft = {"scala", "sbt"},
  },
  {
    "nvim-neotest/neotest",
    ft = {"go", "python", "scala", "javascript", "typescript", "javascriptreact", "typescriptreact", "rust", "kotlin"},
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/neotest-go",
      "nvim-neotest/neotest-python",
      "stevanmilic/neotest-scala",
      "nvim-neotest/neotest-jest",
      "marilari88/neotest-vitest",
      "codymikol/neotest-kotlin",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require "configs.neotest"
    end,
  },
  {
    'mrcjkb/rustaceanvim',
    version = '^5',
    lazy = false,
  },
  {
    'saecki/crates.nvim',
    version = '*',
    config = function()
        require('crates').setup()
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    cmd = {
      "LazyGit",
      "LazyGitConfig",
      "LazyGitCurrentFile",
      "LazyGitFilter",
      "LazyGitFilterCurrentFile",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "greggh/claude-code.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("claude-code").setup()
    end,
  },
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
  },
}
