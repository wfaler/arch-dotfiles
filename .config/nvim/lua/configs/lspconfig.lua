local lspconfig = require "lspconfig"
local util = require "lspconfig/util"
local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities

-- Golang config
lspconfig.gopls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_dir = util.root_pattern("go.work", "go.mod", ".git"),
  settings = {
    gopls = {
      completeUnimported = true,
      usePlaceholders = true,
      analyses = {
        unusedparams = true,
        assign = true,
        bools = true,
        defers = true,
        deprecated = true,
        errorsas = true,
        loopclosure = true,
        shadow = true,
        unusedresult = true,
      },
    },
  },
}

-- JetBrains Experimental Kotlin LSP (manual setup)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "kotlin",
  callback = function()
    vim.lsp.start({
      name = "kotlin-lsp",
      cmd = { "kotlin-lsp", "--stdio" },
      root_dir = util.root_pattern("settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts", ".git")(vim.fn.expand("%:p:h")),
      on_attach = on_attach,
      capabilities = capabilities,
    })
  end,
})

lspconfig.rust_analyzer.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      assist = {
        importMergeBehavior = "last",
        importPrefix = "by_self",
      },
      cargo = {
        loadOutDirsFromCheck = true,
      },
      procMacro = {
        enable = true,
      },
    },
  },
}
-- Python config
lspconfig.pyright.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "python" },
}
-- Terraform
lspconfig.terraformls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
lspconfig.tflint.setup {
  on_attach = on_attach,
  capabilities = capabilities,
}
-- typescript & vue
local function find_plugin_in_node_modules(plugin_name)
  local project_root = vim.fn.getcwd()
  local plugin_path = vim.fn.glob(project_root .. "/node_modules/" .. plugin_name)
  if vim.fn.empty(plugin_path) == 1 then
    -- Fallback to a global path or error handling
    return "/opt/homebrew/lib/node_modules/" .. plugin_name
  end
  return plugin_path
end

lspconfig.ts_ls.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  init_options = {
    plugins = {
      {
        name = "@vue/typescript-plugin",
        location = find_plugin_in_node_modules "@vue/typescript-plugin",
        languages = { "vue" },
      },
    },
  },
  filetypes = { "typescript", "typescriptreact", "vue" },
}
lspconfig.metals.setup {
  -- Metals-specific configuration
  on_attach = on_attach,
  capabilities = capabilities,
  settings = {
    showImplicitArguments = true,
    showInferredType = true,
    -- other Metals settings
  },
}

lspconfig.html.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "html", "templ" },
}

lspconfig.templ.setup {
  on_attach = on_attach,
  capabilities = capabilities,
  filetypes = { "templ" },
}

local function get_typescript_server_path(root_dir)
  local project_root = util.find_node_modules_ancestor(root_dir)
  return project_root and (util.path.join(project_root, "node_modules", "typescript", "lib")) or ""
end

local volar_init_options = {
  typescript = {
    tsdk = "",
  },
}

lspconfig.volar.setup {
  cmd = { "vue-language-server", "--stdio" },
  filetypes = { "vue" },
  root_dir = util.root_pattern "package.json",
  init_options = volar_init_options,
  on_new_config = function(new_config, new_root_dir)
    if
      new_config.init_options
      and new_config.init_options.typescript
      and new_config.init_options.typescript.tsdk == ""
    then
      new_config.init_options.typescript.tsdk = get_typescript_server_path(new_root_dir)
    end
  end,

  on_attach = on_attach,
}
