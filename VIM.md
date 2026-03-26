# Neovim Cheatsheet (NvChad v2.5)

Leader key: **Space**

## General

| Shortcut | Action |
|----------|--------|
| `;` | Enter command mode (same as `:`) |
| `jk` | Exit insert mode (same as `Esc`) |
| `u` | Undo |
| `Ctrl+r` | Redo |
| `.` | Repeat last action |

## Movement

| Shortcut | Action |
|----------|--------|
| `h j k l` | Left, down, up, right |
| `w` / `b` | Jump forward/backward by word |
| `e` | Jump to end of word |
| `0` / `$` | Start/end of line |
| `^` | First non-blank character |
| `gg` / `G` | Top/bottom of file |
| `Ctrl+d` / `Ctrl+u` | Half-page down/up |
| `{` / `}` | Jump by paragraph |
| `%` | Jump to matching bracket |
| `f{char}` / `F{char}` | Jump to next/prev char on line |
| `t{char}` / `T{char}` | Jump to before next/prev char on line |

## Editing

| Shortcut | Action |
|----------|--------|
| `i` / `a` | Insert before/after cursor |
| `I` / `A` | Insert at start/end of line |
| `o` / `O` | New line below/above |
| `dd` | Delete line |
| `yy` | Yank (copy) line |
| `p` / `P` | Paste after/before cursor |
| `ciw` | Change inner word |
| `ci"` | Change inside quotes |
| `di(` | Delete inside parentheses |
| `>>` / `<<` | Indent/unindent line |
| `gc` | Toggle comment (visual or `gcc` for line) |

## Search

| Shortcut | Action |
|----------|--------|
| `/` | Search forward |
| `?` | Search backward |
| `n` / `N` | Next/prev match |
| `*` / `#` | Search word under cursor forward/backward |

## Buffers (Tabs)

| Shortcut | Action |
|----------|--------|
| `Space + b` | Open buffer picker |
| `Tab` | Next buffer |
| `Shift+Tab` | Previous buffer |
| `Space + x` | Close current buffer |

## File Tree (NvimTree)

| Shortcut | Action |
|----------|--------|
| `Ctrl+n` | Toggle file tree |
| `Space + e` | Focus file tree |
| `a` | Create new file/dir (in tree) |
| `d` | Delete file (in tree) |
| `r` | Rename file (in tree) |
| `c` / `p` | Copy/paste file (in tree) |

## Telescope (Fuzzy Finder)

| Shortcut | Action |
|----------|--------|
| `Space + ff` | Find files |
| `Space + fw` | Live grep (search in files) |
| `Space + fb` | Find buffers |
| `Space + fh` | Help tags |
| `Space + fo` | Old (recent) files |
| `Space + gs` | Git status files |

## LSP

| Shortcut | Action |
|----------|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `K` | Hover documentation |
| `Space + ra` | Rename symbol |
| `Space + ca` | Code action |
| `Space + ds` | Diagnostic loclist |
| `[d` / `]d` | Prev/next diagnostic |

## Diffview

| Shortcut | Action |
|----------|--------|
| `Space + do` | Open diffview |
| `Space + dh` | File history (current file) |
| `Space + dc` | Close diffview |

## LazyGit

| Shortcut | Action |
|----------|--------|
| `:LazyGit` | Open LazyGit |
| `:LazyGitCurrentFile` | LazyGit for current file |

## Neotest

| Shortcut | Action |
|----------|--------|
| `Space + tn` | Run nearest test |
| `Space + tf` | Run tests in current file |
| `Space + ts` | Toggle test summary |

## Window Management

| Shortcut | Action |
|----------|--------|
| `Ctrl+h/j/k/l` | Navigate between splits |
| `:vsp` | Vertical split |
| `:sp` | Horizontal split |
| `Ctrl+w + q` | Close split |
| `Ctrl+w + =` | Equalize split sizes |

## Claude Code

| Shortcut | Action |
|----------|--------|
| `Ctrl+,` | Toggle Claude Code terminal |
| `Space + ac` | Toggle Claude Code terminal (alt) |
| `Space + cC` | Continue last conversation |
| `Space + cV` | Verbose mode |
| `:ClaudeCode` | Toggle Claude Code terminal |
| `:ClaudeCodeContinue` | Resume most recent conversation |
| `:ClaudeCodeResume` | Interactive conversation picker |
| `:ClaudeCodeVerbose` | Open with verbose logging |

## Which-Key

Press **Space** and wait — a popup shows all available `<leader>` mappings.
