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
            window = {
                mappings = {
                    ["<C-a>"] = function(state)
                        local node = state.tree:get_node()
                        if node then
                            local path = node:get_id()
                            require("opencode").ask("@file:" .. path .. ": ", { submit = true })
                        end
                    end,
                    ["<C-x>"] = function(state)
                        require("opencode").select()
                    end,
                },
            },
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
    -- {
    --     "nvimtools/none-ls.nvim",
    --     dependencies = { "nvim-lua/plenary.nvim" },
    --     config = function()
    --         local null_ls = require("null-ls")
    --         local venv_bin = vim.fn.expand("~/.config/nvim/.venv/bin")
    --         null_ls.setup({
    --             sources = {
    --                 null_ls.builtins.formatting.clang_format,
    --                 null_ls.builtins.formatting.black.with({
    --                     command = venv_bin .. "/black",
    --                 }),
    --                 null_ls.builtins.formatting.isort.with({
    --                     command = venv_bin .. "/isort",
    --                 }),
    --                 --                  null_ls.builtins.diagnostics.flake8.with({
    --                 --                      command = venv_bin .. "/flake8",
    --                 --                  }),
    --             },
    --         })
    --     end,
    -- },

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
    {
        "uhs-robert/sshfs.nvim",
        opts = {
            -- Refer to the configuration section below
            -- or leave empty for defaults
        },
    },

    {
        "nosduco/remote-sshfs.nvim",
        dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
        opts = {
            -- Refer to the configuration section below
            -- or leave empty for defaults
        },
    },

    {
        "linux-cultist/venv-selector.nvim",
        dependencies = { "neovim/nvim-lspconfig", "nvim-telescope/telescope.nvim" },
        opts = {
            auto_refresh = true,
            fd_binary_name = "fdfind",
            notify_user_on_venv_activation = true,
            on_venv_activate_callback = function(venv_path, venv_python)
                -- venv_path: path to the virtual environment root
                -- venv_python: path to the Python executable
                print("Switched to: " .. venv_path)

                -- Example: Update statusline
                vim.g.current_venv = vim.fn.fnamemodify(venv_path, ":t")
            end,
            debug = true,
        },
        keys = {
            { "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" },
            { "<leader>vc", "<cmd>VenvSelectCached<cr>", desc = "Select Cached Venv" },
        },
    },
    -- {
    --     "yetone/avante.nvim",
    --     -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    --     -- ⚠️ must add this setting! ! !
    --     build = vim.fn.has("win32") ~= 0
    --     and "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false"
    --     or "make",
    --     event = "VeryLazy",
    --     version = false, -- Never set this value to "*"! Never!
    --     ---@module 'avante'
    --     ---@type avante.Config
    --     opts = {
    --         -- add any opts here
    --         -- this file can contain specific instructions for your project
    --         instructions_file = "avante.md",
    --         -- for example
    --         provider = "gemini",
    --         providers = {
    --             claude = {
    --                 endpoint = "https://api.anthropic.com",
    --                 model = "claude-sonnet-4-20250514",
    --                 timeout = 30000, -- Timeout in milliseconds
    --                 extra_request_body = {
    --                     temperature = 0.75,
    --                     max_tokens = 20480,
    --                 },
    --             },
    --             moonshot = {
    --                 endpoint = "https://api.moonshot.ai/v1",
    --                 model = "kimi-k2-0711-preview",
    --                 timeout = 30000, -- Timeout in milliseconds
    --                 extra_request_body = {
    --                     temperature = 0.75,
    --                     max_tokens = 32768,
    --                 },
    --             },
    --             gemini = { 
    --                 endpoint = "https://generativelanguage.googleapis.com/v1beta/models", 
    --                 --model = "gemma-3-27b-it", 
    --                 --model = "gemini-3-flash-preview", 
    --                 --model = "gemini-2.5-pro", 
    --                 model = "gemini-3-pro-preview", 
    --                 timeout = 30000, -- Timeout in milliseconds 
    --                 temperature = 0, 
    --                 max_tokens = 8192, 
    --             },
    --         },
    --     },
    --     dependencies = {
    --         "nvim-lua/plenary.nvim",
    --         "MunifTanjim/nui.nvim",
    --         --- The below dependencies are optional,
    --         "nvim-mini/mini.pick", -- for file_selector provider mini.pick
    --         "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
    --         "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
    --         "ibhagwan/fzf-lua", -- for file_selector provider fzf
    --         "stevearc/dressing.nvim", -- for input provider dressing
    --         "folke/snacks.nvim", -- for input provider snacks
    --         "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
    --         "zbirenbaum/copilot.lua", -- for providers='copilot'
    --         {
    --             -- support for image pasting
    --             "HakonHarnes/img-clip.nvim",
    --             event = "VeryLazy",
    --             opts = {
    --                 -- recommended settings
    --                 default = {
    --                     embed_image_as_base64 = false,
    --                     prompt_for_file_name = false,
    --                     drag_and_drop = {
    --                         insert_mode = true,
    --                     },
    --                     -- required for Windows users
    --                     use_absolute_path = true,
    --                 },
    --             },
    --         },
    --         {
    --             -- Make sure to set this up properly if you have lazy=true
    --             'MeanderingProgrammer/render-markdown.nvim',
    --             opts = {
    --                 file_types = { "markdown", "Avante" },
    --             },
    --             ft = { "markdown", "Avante" },
    --         },
    --     },
    -- },

    {
        "nickjvandyke/opencode.nvim",
        dependencies = {
            -- Recommended for `ask()` and `select()`.
            -- Required for `snacks` provider.
            ---@module 'snacks' <- Loads `snacks.nvim` types for configuration intellisense.
            { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
        },
        config = function()
            ---@type opencode.Opts
            vim.g.opencode_opts = {
                -- Your configuration, if any. Goto definition on the type or field for details.
            }

            -- Required for `opts.events.reload`.
            vim.o.autoread = true

            -- Recommended/example keymaps.
            vim.keymap.set({ "n", "x" }, "<C-a>", function() require("opencode").ask("@this: ", { submit = true }) end, { desc = "Ask opencode…" })
            vim.keymap.set({ "n", "x" }, "<C-x>", function() require("opencode").select() end,                          { desc = "Execute opencode action…" })
            vim.keymap.set({ "n", "t" }, "<leader>at", function() require("opencode").toggle() end,                          { desc = "Toggle opencode" })

            vim.keymap.set({ "n", "x" }, "go",  function() return require("opencode").operator("@this ") end,        { desc = "Add range to opencode", expr = true })
            vim.keymap.set("n",          "goo", function() return require("opencode").operator("@this ") .. "_" end, { desc = "Add line to opencode", expr = true })

            vim.keymap.set("n", "<S-C-u>", function() require("opencode").command("session.half.page.up") end,   { desc = "Scroll opencode up" })
            vim.keymap.set("n", "<S-C-d>", function() require("opencode").command("session.half.page.down") end, { desc = "Scroll opencode down" })

            -- You may want these if you use the opinionated `<C-a>` and `<C-x>` keymaps above — otherwise consider `<leader>o…` (and remove terminal mode from the `toggle` keymap).
            vim.keymap.set("n", "+", "<C-a>", { desc = "Increment under cursor", noremap = true })
            vim.keymap.set("n", "-", "<C-x>", { desc = "Decrement under cursor", noremap = true })
        end,
    },
    {
        "echasnovski/mini.bufremove",
        version = false, -- always latest
        config = function()
            require("mini.bufremove").setup()
        end,
    }
    ,
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },            -- if you use the mini.nvim suite
        -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
        -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
        ---@module 'render-markdown'
        ---@type render.md.UserConfig
        opts = {},
    }




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

-- ===============
-- SSHFS Setup
-- ===============
require("sshfs").setup({
  -- Your configuration here
})

require('remote-sshfs').setup{
  connections = {
    ssh_configs = { -- which ssh configs to parse for hosts list
      vim.fn.expand "$HOME" .. "/.ssh/config",
      "/etc/ssh/ssh_config",
      -- "/path/to/custom/ssh_config"
    },
    ssh_known_hosts = vim.fn.expand "$HOME" .. "/.ssh/known_hosts",
    -- NOTE: Can define ssh_configs similarly to include all configs in a folder
    -- ssh_configs = vim.split(vim.fn.globpath(vim.fn.expand "$HOME" .. "/.ssh/configs", "*"), "\n")
    sshfs_args = { -- arguments to pass to the sshfs command
      "-o reconnect",
      "-o ConnectTimeout=5",
    },
  },
  mounts = {
    base_dir = vim.fn.expand "$HOME" .. "/.sshfs/", -- base directory for mount points
    unmount_on_exit = true, -- run sshfs as foreground, will unmount on vim exit
  },
  handlers = {
    on_connect = {
      change_dir = true, -- when connected change vim working directory to mount point
    },
    on_disconnect = {
      clean_mount_folders = false, -- remove mount point folder on disconnect/unmount
    },
    on_edit = {}, -- not yet implemented
  },
  ui = {
    select_prompts = false, -- not yet implemented
    confirm = {
      connect = true, -- prompt y/n when host is selected to connect to
      change_dir = false, -- prompt y/n to change working directory on connection (only applicable if handlers.on_connect.change_dir is enabled)
    },
  },
  log = {
    enabled = false, -- enable logging
    truncate = false, -- truncate logs
    types = { -- enabled log types
      all = false,
      util = false,
      handler = false,
      sshfs = false,
    },
  },
}

local actions = require("telescope.actions")

require("telescope").setup({
  defaults = {
    mappings = {
      i = {
        ["<C-d>"] = actions.delete_buffer,
      },
      n = {
        ["dd"] = actions.delete_buffer,
      },
    },
  },
})

-- ==================
-- Markdown rendering
-- ==================
require('render-markdown').setup({
    completions = { lsp = { enabled = true } },
    latex = { enabled = true },
    bullet = {
        -- Turn on / off list bullet rendering
        enabled = true,
        icons = { '▪', '▫', '▸', '▹' },
        --icons = { '▸', '▹', '▪', '▫' },
        --icons = { '●', '○', '◆', '◇' },
    },
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
-- require("venv-selector").setup({
--     auto_refresh = true,  -- automatically detect venv on buffer enter
--     changed_venv_hooks = {
--         -- This function is called whenever a venv is activated
--         function(venv)
--             if venv then
--                 vim.env.VIRTUAL_ENV = venv
--             end
--
--             -- Restart Pyright to pick up new Python environment
--             for _, client in ipairs(vim.lsp.get_active_clients({ name = "pyright" })) do
--                 client:stop()
--             end
--
--             vim.defer_fn(function()
--                 lsp.start({
--                     name = "pyright",
--                     cmd = pyright_cmd,
--                     root_dir = vim.fs.dirname(vim.fs.find({ "pyproject.toml", ".git" }, { upward = true })[1] or vim.loop.cwd()),
--                     on_init = function(client)
--                         client.config.settings.python.pythonPath = python_path
--                     end,
--                     settings = {
--                         python = {
--                             pythonpath = vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV .. "/bin/python" or vim.g.python3_host_prog,
--                             analysis = {
--                                 autoSearchPaths = true,
--                                 useLibraryCodeForTypes = true,
--                                 diagnosticMode = "openFilesOnly",
--                             },
--                         },
--                     }})
--                 end, 100)  -- small delay to allow previous client to fully stop
--
--             require("lspconfig").pyright.setup{}  -- start Pyright
--         end,
--         function(venv)
--             print("Changed venv to: " .. venv)
--         end,
--     },
-- })
local venv_path = vim.fn.expand("~/.config/nvim/.venv")
local pyright_cmd = { venv_path .. "/bin/pyright-langserver", "--stdio" }
local python_path = venv_path .. "/bin/python"
vim.lsp.config('pyright', {
--lspconfig.pyright.setup({
    cmd = pyright_cmd,
    on_init = function(client)
        client.config.settings.python.pythonPath = python_path
    end,
    on_new_config = function(new_config, _)
        local venv = os.getenv("VIRTUAL_ENV") or current_venv
        if vim.loop.fs_stat(venv .. "/bin/python") then
            new_config.settings.python.pythonPath = venv .. "/bin/python"
        else
            new_config.settings.python.pythonPath = "python" -- fallback
        end
    end,
    settings = {
        python = {
            --pythonpath = vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV .. "/bin/python" or vim.g.python3_host_prog,
            pythonPath = require("venv-selector").python() or vim.g.python3_host_prog,
            analysis = {
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
            },
        },
    },
})
vim.lsp.enable('pyright')

require("venv-selector").setup({
    auto_refresh = true,
    fd_binary_name = "fdfind",
    notify_user_on_venv_activation = true,
    on_venv_activate_callback = function(venv_path, venv_python)
        -- venv_path: path to the virtual environment root
        -- venv_python: path to the Python executable
        print("Switched to: " .. venv_path)

        -- Example: Update statusline
        vim.g.current_venv = vim.fn.fnamemodify(venv_path, ":t")
    end,
    debug = true,
})


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

vim.keymap.set("n", "<leader>bd", function()
  require("mini.bufremove").delete()
end, { desc = "Delete buffer" })

vim.keymap.set("n", "<leader>bD", function()
  require("mini.bufremove").wipeout()
end, { desc = "Wipeout buffer" })





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

vim.api.nvim_create_user_command("SetWorkspaceRoot", function()
    local root = find_workspace_root()
    if root and root ~= vim.fn.getcwd() then
      vim.cmd("cd " .. vim.fn.fnameescape(root))
      print("Workspace root: " .. root)
    else
      print("Workspace root is already set to: " .. root)
    end
  print("Workspace root: " .. find_workspace_root())
end, { desc = "Set workspace root" })
