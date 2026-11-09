local nvlsp = require "nvchad.configs.lspconfig"

-- Shared by every server below.
vim.lsp.config("*", {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
})

-- Golang
vim.lsp.config("gopls", {
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

-- Python: pyright for types, ruff for lint diagnostics and quick fixes.
-- Hover stays with pyright so the two don't both answer K.
vim.lsp.config("ruff", {
  on_attach = function(client, bufnr)
    client.server_capabilities.hoverProvider = false
    nvlsp.on_attach(client, bufnr)
  end,
})

-- Java (Mason's jdtls; needs JDK 21+ on PATH)
-- Kotlin: JetBrains' kotlin-lsp (Mason package kotlin-lsp), lspconfig's kotlin_lsp.
-- Scala: nvim-metals sets Metals up itself (plugins/init.lua), not lspconfig.
-- Rust: rustaceanvim manages rust-analyzer, no setup here.

-- TypeScript, Vue and Svelte.
-- ts_ls runs the Vue and Svelte TypeScript plugins so .ts files understand .vue and
-- .svelte imports; vue_ls handles the rest of .vue files (Vue language tools v3).
-- Each plugin comes from the project's node_modules if present, else from Mason.
local mason_pkgs = vim.fn.stdpath "data" .. "/mason/packages/"

local function ts_plugin(name, mason_path)
  local project = vim.fn.getcwd() .. "/node_modules/" .. name
  for _, path in ipairs { project, mason_pkgs .. mason_path } do
    if vim.uv.fs_stat(path) then
      return path
    end
  end
end

-- Only pass plugins that exist: an entry without a location makes ts_ls fail to initialize.
local ts_plugins = {}
local vue_plugin = ts_plugin("@vue/typescript-plugin", "vue-language-server/node_modules/@vue/language-server")
if vue_plugin then
  table.insert(ts_plugins, { name = "@vue/typescript-plugin", location = vue_plugin, languages = { "vue" } })
end
local svelte_plugin =
  ts_plugin("typescript-svelte-plugin", "svelte-language-server/node_modules/typescript-svelte-plugin")
if svelte_plugin then
  table.insert(ts_plugins, { name = "typescript-svelte-plugin", location = svelte_plugin, languages = { "svelte" } })
end

-- TypeScript 7 (the native compiler) ships its own language server, `tsc --lsp`
-- (lspconfig's "tsc"). Pick per project by the TypeScript it has installed:
-- 7+ gets tsc, older (or none) keeps ts_ls. TS 7 can't load TypeScript plugins,
-- so .vue files always stay on ts_ls for the Vue plugin.
local function ts_major(root)
  local ok, pkg = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(root .. "/node_modules/typescript/package.json"), "\n"))
  end)
  local v = ok and type(pkg) == "table" and vim.version.parse(pkg.version or "")
  return v and v.major or 0
end

-- lspconfig's own root detection (lockfile or .git, skipping Deno), before overriding.
local ts_ls_root = vim.lsp.config.ts_ls.root_dir

vim.lsp.config("tsc", {
  -- Always the project's own TypeScript 7 (root_dir only attaches where it exists).
  cmd = function(dispatchers, config)
    local bin = vim.fs.joinpath(config.root_dir, "node_modules/.bin/tsc")
    return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers)
  end,
  root_dir = function(bufnr, on_dir)
    ts_ls_root(bufnr, function(root)
      if ts_major(root) >= 7 and vim.fn.executable(root .. "/node_modules/.bin/tsc") == 1 then
        on_dir(root)
      end
    end)
  end,
})

vim.lsp.config("ts_ls", {
  init_options = { plugins = ts_plugins },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
  root_dir = function(bufnr, on_dir)
    ts_ls_root(bufnr, function(root)
      if ts_major(root) < 7 or vim.bo[bufnr].filetype == "vue" then
        on_dir(root)
      end
    end)
  end,
})

vim.lsp.config("html", {
  filetypes = { "html", "templ" },
})

vim.lsp.enable {
  "gopls",
  "templ",
  "pyright",
  "ruff",
  "jdtls",
  "kotlin_lsp",
  "terraformls",
  "tflint",
  "ts_ls",
  "tsc",
  "vue_ls",
  "svelte",
  "html",
}
