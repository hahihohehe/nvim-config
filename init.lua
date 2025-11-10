local function get_git_root(path)
  local Path = require("plenary.path")
  local Job = require("plenary.job")
  path = path or vim.fn.expand("%:p")

  local git_root = nil
  Job:new({
    command = "git",
    args = { "-C", Path:new(path):parent().filename, "rev-parse", "--show-toplevel" },
    on_exit = function(j, return_val)
      if return_val == 0 then
        git_root = j:result()[1]
      end
    end,
  }):sync()
  return git_root
end

-- Find the workspace root based on armarx-workspace.json,
-- or fallback to where nvim was opened.
local function find_workspace_root(start_path)
  start_path = start_path or vim.fn.expand("%:p:h")
  local dir = vim.fs.dirname(start_path)
  local found = vim.fs.find("armarx-workspace.json", {
    upward = true,
    path = dir,
  })[1]

  if found then
    return vim.fs.dirname(found)
  end

  -- fallback to the folder where nvim was opened
  return vim.fn.getcwd(-1, -1)  -- startup directory, not changed by :lcd
end

vim.api.nvim_create_user_command("WorkspaceRoot", function()
  print("Workspace root: " .. find_workspace_root())
end, { desc = "Show detected workspace root" })



-- init.lua
vim.opt.rtp:prepend("~/.local/share/nvim/lazy/lazy.nvim")

require("lazy").setup({
  -- File explorer
  --{ "nvim-tree/nvim-tree.lua" },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- optional, for file icons
      "MunifTanjim/nui.nvim",
    },
    config = function()
	require("neo-tree").setup({
	    filesystem = {
		    follow_current_file = true, -- highlight file in tree
		    hijack_netrw_behavior = "open_default", -- replace netrw
		    filtered_items = { hide_dotfiles = false, hide_gitignored = false },
		    use_libuv_file_watcher = true,
            bind_to_cwd = true,
        },
	    })
    end,
  },


  -- Telescope for fuzzy finding
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },

  -- Treesitter for syntax highlighting
  --{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
      config = function()
          require("nvim-treesitter.configs").setup({
              ensure_installed = {
                  "c", "cpp", "python", "lua", "bash", "json", "yaml", "markdown", "vim",
              },
              highlight = {
                  enable = true,          -- enable treesitter-based highlighting
                  additional_vim_regex_highlighting = false,
              },
              indent = { enable = false },
          })
      end,
  },


  -- LSP (language server protocol)
  { "neovim/nvim-lspconfig" },

  -- NEW: nice UI for LSP
  { "nvim-lua/lsp-status.nvim" },
  { "folke/trouble.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "glepnir/lspsaga.nvim", branch = "main" },

  -- Autocompletion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "L3MON4D3/LuaSnip" },

  -- Debugging (DAP)
  { "mfussenegger/nvim-dap" },
  { "rcarriga/nvim-dap-ui" },

  -- Statusline
  --{ "nvim-lualine/lualine.nvim" },
  {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
          require("lualine").setup({
              options = {
                  --theme = "moonfly",   -- matches your Moonfly colorscheme
                  theme = "auto",
                  section_separators = { left = "", right = "" },
                  component_separators = { left = "", right = "" },
                  globalstatus = true, -- Neovim 0.7+
              },
              sections = {
                  lualine_a = { "mode" },
                  lualine_b = { "branch", "diff" },
                  lualine_c = { "filename" },
                  lualine_x = { "encoding", "fileformat", "filetype" },
                  lualine_y = { "progress" },
                  lualine_z = { "location" },
              },
          })
      end,
  },


  -- Git integration
  { "lewis6991/gitsigns.nvim",
      opts = {
          signs = {
              add          = { text = "▎" },
              change       = { text = "▎" },
              delete       = { text = "" },
              topdelete    = { text = "" },
              changedelete = { text = "▎" },
          },
          current_line_blame = true, -- inline git blame
          current_line_blame_opts = {
              virt_text = true,
              virt_text_pos = "eol", -- "eol" | "overlay" | "right_align"
              delay = 500,
          },
          current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
      },
  },
  {
    "tpope/vim-fugitive",
    cmd = {
      "Git",
      "Gdiffsplit",
      "Gvdiffsplit",
      "Gwrite",
      "Gread",
      "Gcommit",
      "Gpush",
      "Gpull",
    },
    keys = {
      { "<leader>gs", "<cmd>Git<CR>", desc = "Git status" },
      { "<leader>gd", "<cmd>Gvdiffsplit<CR>", desc = "Git diff split" },
      { "<leader>gb", "<cmd>Git blame<CR>", desc = "Git blame" },
    },
  },

  -- Git UI: Neogit + Diffview
  {
      "TimUntersberger/neogit",
      dependencies = { "nvim-lua/plenary.nvim", "sindrets/diffview.nvim" },
      config = function()
          local neogit = require("neogit")
          neogit.setup({
              integrations = { diffview = true },
          })

          -- Custom command: always open Neogit in repo of current file
          vim.keymap.set("n", "<leader>gg", function()
              local root = get_git_root()
              if root then
                  neogit.open({ cwd = root })
              else
                  print("Not inside a git repo")
              end
          end, { desc = "Open Neogit in file's repo" })
      end,
  },


  -- Git history & diff viewer
  {
      "sindrets/diffview.nvim",
      dependencies = "nvim-lua/plenary.nvim",
      config = function()
          local dv = require("diffview")

          -- Override commands so they open repo of current file
          vim.keymap.set("n", "<leader>go", function()
              local root = get_git_root()
              if root then
                  vim.cmd("cd " .. root)
                  dv.open()
              else
                  print("Not inside a git repo")
              end
          end, { desc = "Open Diffview in file's repo" })

          vim.keymap.set("n", "<leader>gh", function()
              local root = get_git_root()
              if root then
                  vim.cmd("cd " .. root)
                  dv.file_history()
              else
                  print("Not inside a git repo")
              end
          end, { desc = "File history in file's repo" })
      end,
      keys = {
          { "<leader>gc", "<cmd>DiffviewClose<CR>", desc = "Close diffview" },
      },
  },

  -- Copilot core
  {
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      build = ":Copilot auth",
      opts = {
          suggestion = { enabled = true }, -- disable inline ghost text
          panel = { enabled = true },      -- disable Copilot panel
      },
  },

  -- Copilot <-> cmp bridge
  {
      "zbirenbaum/copilot-cmp",
      dependencies = { "zbirenbaum/copilot.lua" },
      config = function()
          require("copilot_cmp").setup()
      end,
  },

  {
      "akinsho/toggleterm.nvim",
      version = "*",
      config = function()
          require("toggleterm").setup({
              size = 15,
              open_mapping = [[<leader>tt]],
              direction = "float",       -- floating terminal
              close_on_exit = true,      -- auto-close when build finishes
              hide_numbers = true,
              shade_terminals = true,
              shading_factor = 2,
              start_in_insert = true,
              persist_size = true,
              float_opts = {
                  border = "rounded",
                  winblend = 3,
              },
          })

          local Terminal = require("toggleterm.terminal").Terminal
          local build_term = Terminal:new({
              cmd = "echo Hallo",
              direction = "float",
              hidden = true,
              on_exit = function()
                  print("Build finished!")
              end,
          })

          -- Keymap to toggle build terminal
          vim.keymap.set("n", "<leader>tb", function()
              build_term:toggle()
          end, { desc = "Run build script in floating terminal" })
      end,
    },
    {
        "nvimtools/none-ls.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        config = function()
            local null_ls = require("null-ls")
            local venv_bin = vim.fn.expand("~/.config/nvim/.venv/bin")
            null_ls.setup({
                sources = {
                    null_ls.builtins.formatting.clang_format,
                    null_ls.builtins.formatting.black.with({
                        command = venv_bin .. "/black",
                    }),
                    null_ls.builtins.formatting.isort.with({
                        command = venv_bin .. "/isort",
                    }),
                    --                  null_ls.builtins.diagnostics.flake8.with({
                    --                      command = venv_bin .. "/flake8",
                    --                  }),
                },
            })
        end,
    },

    {
	"folke/tokyonight.nvim",
	lazy = false,
	priority = 1000,
	opts = {}
    }, 
    {
	"bluz71/vim-moonfly-colors",
	lazy = false,  -- load immediately
	priority = 1000,
	config = function()
	    vim.cmd([[colorscheme moonfly]])
	end,
    },
    {
        "gmr458/vscode_modern_theme.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("vscode_modern").setup({
                cursorline = true,
                transparent_background = false,
                nvim_tree_darker = true,
            })
            vim.cmd.colorscheme("vscode_modern")
        end,
    },




  -- Sessions
  --{
  --    "rmagatti/auto-session",
  --    config = function()
  --        require("auto-session").setup({
  --            log_level = "error",
  --            auto_session_enabled = true,
  --            auto_restore_enabled = true,
  --            auto_session_suppress_dirs = { "~/" }, -- don’t auto-save sessions in $HOME
  --        })
  --    end,
  --},


  -- Project management
  --{ "ahmedkhalf/project.nvim" },
})

-- ================
-- LSP (clangd)
-- ================
require("lspconfig.configs")
local capabilities = vim.lsp.protocol.make_client_capabilities()

vim.lsp.config('clangd', {
  --cmd = { vim.fn.expand("~/tools/tools/clang+llvm/14.0/clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04/bin/clangd") },
  capabilities = capabilities,
})
vim.lsp.enable('clangd')

--local lspconfig = require("lspconfig")
--local capabilities = require("cmp_nvim_lsp").default_capabilities()
--lspconfig.clangd.setup {
--  capabilities = capabilities,
--}

-- ================
-- LSP (Python)
-- ================
local venv_path = vim.fn.expand("~/.config/nvim/.venv")
local pyright_cmd = { venv_path .. "/bin/pyright-langserver", "--stdio" }
local python_path = venv_path .. "/bin/python"
vim.lsp.config('pyright', {
--lspconfig.pyright.setup({
    cmd = pyright_cmd,
    on_init = function(client)
        client.config.settings.python.pythonPath = python_path
    end,
    settings = {
        python = {
            pythonpath = python_path,
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
            },
        },
    },
})
vim.lsp.enable('pyright')

-- ================
-- Completion setup
-- ================
local cmp = require("cmp")
cmp.setup({
  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"]      = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({
    { name = "copilot" },
    { name = "nvim_lsp" },
    { name = "buffer" },
    { name = "path" },
  }),
})

-- Global diagnostic config
--vim.diagnostic.config({
--  virtual_text = false, -- disable inline text
--  signs = true,
--  underline = true,
--  update_in_insert = false,
--  severity_sort = true,
--})

-- Diagnostic signs in the gutter
--local signs = { Error = "✘ ", Warn = "▲ ", Hint = "⚑ ", Info = " " }
--for type, icon in pairs(signs) do
--  local hl = "DiagnosticSign" .. type
--  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
--end

-- Define icons for each diagnostic type
local signs = {
  Error = "✘ ",
  Warn  = "",
  Hint  = "",
  Info  = "",
}

-- Create a table in the new API format
local diagnostic_signs = {}
for type, icon in pairs(signs) do
  diagnostic_signs[type] = { text = icon, texthl = "DiagnosticSign" .. type }
end

-- Configure Neovim diagnostics
vim.diagnostic.config({
  virtual_text = true,       -- show inline messages
  signs = diagnostic_signs,  -- use our icons
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})


-- Trouble (diagnostics list)
require("trouble").setup()
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
  { silent = true, noremap = true, desc = "Document Diagnostics" })
vim.keymap.set("n", "<leader>xw", "<cmd>Trouble diagnostics toggle<cr>",
  { silent = true, noremap = true, desc = "Workspace Diagnostics" })
vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>",
  { silent = true, noremap = true, desc = "Quickfix List" })
vim.keymap.set("n", "<leader>xl", "<cmd>Trouble loclist toggle<cr>",
  { silent = true, noremap = true, desc = "Location List" })

-- Lspsaga (enhanced LSP UI)
require("lspsaga").setup({
  lightbulb = { enable = false },
  ui = { border = "rounded" },
})

vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", { desc = "Hover docs" })
vim.keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>", { desc = "Go to definition" })
vim.keymap.set("n", "gr", "<cmd>Lspsaga finder<CR>", { desc = "References" })
vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>", { desc = "Code action" })
vim.keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", { desc = "Rename" })


-- Status indicator
local lsp_status = require("lsp-status")
lsp_status.register_progress()



-- ==============
-- Keybindings
-- ==============
--vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
--vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover docs" })
--vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
--vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code action" })

-- Toggle file explorer
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>",
  { desc = "Toggle Explorer" })

-- Reveal current file in tree
vim.keymap.set("n", "<leader>o", "<cmd>Neotree reveal<CR>",
  { desc = "Reveal File in Explorer" })

-- Navigate all diagnostics
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous Diagnostic" })

-- Navigate only errors
vim.keymap.set("n", "]e", function() vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Next Error" })
vim.keymap.set("n", "[e", function() vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, { desc = "Prev Error" })

-- Document formatting
vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format file" })

-- Auto-format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Prompts for content regex and optional filetype/glob, runs live_grep
local function live_grep_with_filter(root)
  root = root or vim.fn.getcwd()

  -- Prompt for filetype/glob filter
  local filter_input = vim.fn.input("Filetype/glob filter (comma-separated, leave empty for all): ")
  filter_input = filter_input:match("%S+") or ""  -- trim whitespace

  require("telescope.builtin").live_grep({
    prompt_title = "Live Grep Filtered",
    cwd = root,
    additional_args = function()
      local args = {}
      if filter_input ~= "" then
        for pattern in string.gmatch(filter_input, "[^,]+") do
          pattern = pattern:gsub("^%s*(.-)%s*$", "%1") -- trim spaces

          if pattern:match("^%*") then
            table.insert(args, "--glob=" .. pattern)
          else
            table.insert(args, "--type=" .. pattern)
          end
        end
      end
      return args
    end,
  })
end

-- Search function
vim.keymap.set("n", "<leader>sg", function()
    live_grep_with_filter("/")
end, { desc = "Search global (filtered)" })

vim.keymap.set("n", "<leader>s", function()
    live_grep_with_filter(vim.fn.getcwd())
end, { desc = "Search cwd (filtered)" })

vim.keymap.set("n", "<leader>sp", function()
  local root = get_git_root()
  live_grep_with_filter(root)
end, { desc = "Search project (filtered)" })

vim.keymap.set("n", "<leader>sc", function()
  require("telescope.builtin").keymaps({ prompt_title = "Search Commands" })
end, { desc = "Show search shortcuts" })

vim.keymap.set("n", "<leader>sf", function()
  require("telescope.builtin").find_files({ prompt_title = "Search for Files" })
end, { desc = "Find files" })

vim.keymap.set("n", "<leader>sb", function()
  require("telescope.builtin").buffers({ prompt_title = "Search Buffers" })
end, { desc = "Find buffers" })




-- ===============
-- Other config
-- ===============
-- Use spaces instead of tab characters
vim.opt.expandtab = true
-- Number of spaces to insert for each Tab press
vim.opt.tabstop = 4
-- Number of spaces for auto-indent
vim.opt.shiftwidth = 4
-- Number of spaces for <Tab> in insert mode (same as tabstop)
vim.opt.softtabstop = 4
-- Optional: smart indentation
vim.opt.smartindent = true

-- Enable inlay hints for the current buffer
vim.lsp.inlay_hint.enable(true, { bufnr = 0 })

-- Keymap to toggle inlay hints
vim.keymap.set("n", "<leader>th", function()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
end, { desc = "Toggle Inlay Hints" })

-- Automatically use clang-format for C and C++
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "h", "hpp" },
  callback = function()
    vim.opt_local.formatprg = "clang-format"
  end,
})

-- Enable relative line numbers
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    vim.wo.number = true
    vim.wo.relativenumber = true
  end,
})

--vim.o.clipboard = "unnamedplus"  -- use system clipboard

-- Remove the menu on startup
vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  callback = function()
    vim.cmd([[aunmenu PopUp.How-to\ disable\ mouse]])
    vim.cmd([[aunmenu PopUp.-2-  ]])
  end,
})

-- Reset workspace root
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local root = find_workspace_root()
    if root and root ~= vim.fn.getcwd() then
      vim.cmd("cd " .. vim.fn.fnameescape(root))
      print("Workspace root: " .. root)
    end
  end,
})
