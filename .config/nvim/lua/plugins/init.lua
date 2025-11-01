return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make", -- This is Optional, only if you want to use tiktoken_core to calculate tokens count
    opts = {
    -- add any opts here
    },
    dependencies = {
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    --- The below is optional, make sure to setup it properly if you have lazy=true
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre', -- format on save
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
    "numToStr/Comment.nvim",
    lazy = false,
  },
  {
    "neovim/nvim-lspconfig",
     config = function()
       require "../configs.lspconfig"
     end,
   },
  {"github/copilot.vim",
    lazy = false,
  --  config = function()
    --  vim.g.copilot_no_tab_map = true;
    --  vim.g.copilot_assume_mapped = true;
    --  vim.g.copilot_tab_fallback = "";
   -- end
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
      "antoinemadec/FixCursorHold.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-neotest/neotest-go",
      "nvim-neotest/neotest-python",
      "stevanmilic/neotest-scala",
      "nvim-neotest/neotest-jest",
      "marilari88/neotest-vitest",
      "codymikol/neotest-kotlin",
      "nvim-neotest/nvim-nio",
      -- "rouge8/neotest-rust",
    },
    config = function()
      require "../configs.neotest"
    end,
  },
  {
    'mrcjkb/rustaceanvim',
    version = '^4', -- Recommended
    lazy = false, -- This plugin is already lazy
  },
  {
    'saecki/crates.nvim',
    tag = 'stable',
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
