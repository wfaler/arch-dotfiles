-- nvim-treesitter `main` branch: it only installs parsers and ships queries.
-- Highlighting and indent are started per buffer below; the old `ensure_installed`
-- / `highlight = { enable = true }` options of the master branch do nothing here.
-- Installing parsers needs the tree-sitter CLI (Mason package tree-sitter-cli).

pcall(function()
  dofile(vim.g.base46_cache .. "syntax")
  dofile(vim.g.base46_cache .. "treesitter")
end)

local langs = {
  -- nvim / config
  "vim",
  "vimdoc",
  "lua",
  "luadoc",
  "query",
  "printf",
  "bash",
  "yaml",
  "toml",
  "json",
  "dockerfile",
  "terraform",
  "markdown",
  "markdown_inline",
  -- backend
  "go",
  "gomod",
  "gosum",
  "gowork",
  "templ",
  "python",
  "scala",
  "java",
  "kotlin",
  "rust",
  "c",
  -- web
  "html",
  "css",
  "javascript",
  "typescript",
  "tsx",
  "vue",
  "svelte",
}

local ts = require "nvim-treesitter"

-- Install only what is missing (async; a no-op once everything is there).
local installed = ts.get_installed()
local missing = vim.tbl_filter(function(lang)
  return not vim.tbl_contains(installed, lang)
end, langs)
if #missing > 0 then
  if vim.fn.executable "tree-sitter" == 1 then
    ts.install(missing)
  else
    vim.notify("tree-sitter CLI missing: run :MasonInstall tree-sitter-cli", vim.log.levels.WARN)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("user-treesitter", { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if lang and pcall(vim.treesitter.start, args.buf, lang) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
