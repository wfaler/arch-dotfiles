return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre',
    config = function()
      require "configs.conform"
    end,
  },
  {
    -- `main` branch (the old `master` is frozen). It doesn't lazy-load, and its
    -- setup takes no parser list: configs/treesitter.lua installs and starts them.
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    opts = {},
    config = function()
      require "configs.treesitter"
    end,
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
    -- Scala: nvim-metals runs Metals (not lspconfig). First use: :MetalsInstall
    -- (needs coursier, `cs`, on PATH).
    "scalameta/nvim-metals",
    ft = { "scala", "sbt" },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local metals = require "metals"
      local nvlsp = require "nvchad.configs.lspconfig"
      local cfg = metals.bare_config()
      cfg.settings = { showImplicitArguments = true, showInferredType = true }
      cfg.on_attach = nvlsp.on_attach
      cfg.capabilities = nvlsp.capabilities
      -- lazy.nvim re-fires FileType after loading, which attaches the first buffer too.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nvim-metals", { clear = true }),
        pattern = { "scala", "sbt" },
        callback = function()
          metals.initialize_or_attach(cfg)
        end,
      })
    end,
  },
  {
    "nvim-neotest/neotest",
    ft = {"go", "python", "scala", "javascript", "typescript", "javascriptreact", "typescriptreact", "rust", "kotlin"},
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
      { "fredrikaverpil/neotest-golang", version = "*" },
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
    version = '^9',
    lazy = false,
  },
  {
    'saecki/crates.nvim',
    version = '*',
    event = { "BufRead Cargo.toml" },
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
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("render-markdown").setup({})
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
