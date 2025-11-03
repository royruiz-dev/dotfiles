return {
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPre", "BufNewFile" },
  build = ":TSUpdate",
  config = function()
    -- import nvim-treesitter plugin
    local treesitter = require("nvim-treesitter.configs")

    -- configure treesitter
    treesitter.setup({ -- enable syntax highlighting
      highlight = {
        enable = true,
      },
      -- enable indentation
      indent = { enable = true },
      -- ensure these language parsers are installed
      ensure_installed = {
        -- Core scripting & automation
        "bash",
        "python",
        "lua",
        "json",
        "yaml",
        "toml",
        "make",
        "jq",
        "ini",

        -- Infrastructure-as-Code
        "terraform",
        "hcl",
        "dockerfile",
        "go",
        "gomod",
        "gosum",

        -- CI/CD & templating
        "groovy",      -- Jenkinsfiles
        "jinja",       -- Ansible / Helm / Cloud templates
        "gitignore",
        "gitcommit",
        "git_rebase",
        
        -- Cloud & orchestration
        "helm",
        "rego",        -- policy as code (OPA, Gatekeeper)
        "sql",         -- configs or cloud query tools
        "http",        -- API request examples

        -- Documentation / misc
        "markdown",
        "vim",
        "vimdoc",
        "query",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
    })

    -- use bash parser for zsh files
    vim.treesitter.language.register("bash", "zsh")
  end,
}
