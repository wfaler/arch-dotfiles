local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities

-- Golang config
vim.lsp.config("gopls", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.work", "go.mod", ".git" },
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
})

-- JetBrains Experimental Kotlin LSP (manual setup)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "kotlin",
  callback = function()
    vim.lsp.start({
      name = "kotlin-lsp",
      cmd = { "kotlin-lsp", "--stdio" },
      root_dir = vim.fs.root(0, { "settings.gradle", "settings.gradle.kts", "build.gradle", "build.gradle.kts", ".git" }),
      on_attach = on_attach,
      capabilities = capabilities,
    })
  end,
})

-- rust_analyzer is managed by rustaceanvim — no manual setup needed

-- Python config
vim.lsp.config("pyright", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  filetypes = { "python" },
})

-- Terraform
vim.lsp.config("terraformls", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
})

vim.lsp.config("tflint", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
})

-- typescript & vue
-- Using ts_ls with @vue/typescript-plugin handles both TS and Vue.
-- Volar is no longer needed separately when using hybrid mode.
local function find_plugin_in_node_modules(plugin_name)
  local project_root = vim.fn.getcwd()
  local plugin_path = vim.fn.glob(project_root .. "/node_modules/" .. plugin_name)
  if vim.fn.empty(plugin_path) == 1 then
    return nil
  end
  return plugin_path
end

-- Prefer the project's typescript-svelte-plugin, fall back to the one bundled
-- with Mason's svelte-language-server. Lets .ts/.js files understand .svelte imports.
local svelte_ts_plugin = find_plugin_in_node_modules "typescript-svelte-plugin"
  or vim.fn.stdpath "data" .. "/mason/packages/svelte-language-server/node_modules/typescript-svelte-plugin"

-- Only pass plugins that exist: an entry without a location makes ts_ls fail to initialize.
local ts_plugins = {}
local vue_ts_plugin = find_plugin_in_node_modules "@vue/typescript-plugin"
if vue_ts_plugin then
  table.insert(ts_plugins, { name = "@vue/typescript-plugin", location = vue_ts_plugin, languages = { "vue" } })
end
if vim.uv.fs_stat(svelte_ts_plugin) then
  table.insert(ts_plugins, { name = "typescript-svelte-plugin", location = svelte_ts_plugin, languages = { "svelte" } })
end

vim.lsp.config("ts_ls", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  init_options = {
    plugins = ts_plugins,
  },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
})

-- svelte: handles both <script> and <script lang="ts"> inside .svelte files
vim.lsp.config("svelte", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
})

vim.lsp.config("metals", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  settings = {
    showImplicitArguments = true,
    showInferredType = true,
  },
})

vim.lsp.config("html", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  filetypes = { "html", "templ" },
})

vim.lsp.config("templ", {
  on_attach = on_attach,
  on_init = on_init,
  capabilities = capabilities,
  filetypes = { "templ" },
})

-- Enable all configured servers
vim.lsp.enable({
  "gopls",
  "pyright",
  "terraformls",
  "tflint",
  "ts_ls",
  "svelte",
  "metals",
  "html",
  "templ",
})
