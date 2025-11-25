return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-tree/nvim-web-devicons",
    "folke/todo-comments.nvim",
  },
  config = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        local telescope = require("telescope")
        local actions = require("telescope.actions")
        local transform_mod = require("telescope.actions.mt").transform_mod

        local trouble = require("trouble")
        local trouble_telescope = require("trouble.sources.telescope")

        -- create your custom actions
        local custom_actions = transform_mod({
          open_trouble_qflist = function(prompt_bufnr)
            trouble.toggle("quickfix")
          end,
        })

        -- telescope setup with layout_config
        telescope.setup({
          defaults = {
            path_display = { "smart" },
            layout_strategy = "horizontal",
            layout_config = {
              width = 0.8,          -- total width of Telescope
              preview_width = 0.65, -- width of the preview relative to Telescope window
              prompt_position = "top",
            },
            mappings = {
              i = {
                ["<C-k>"] = actions.move_selection_previous,
                ["<C-j>"] = actions.move_selection_next,
                ["<C-q>"] = actions.send_selected_to_qflist + custom_actions.open_trouble_qflist,
                ["<C-t>"] = trouble_telescope.open,
              },
            },
          },
        })

        telescope.load_extension("fzf")

        -- set keymaps
        local keymap = vim.keymap
        keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Fuzzy find files in cwd" })
        keymap.set("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Fuzzy find recent files" })
        keymap.set("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Find string in cwd" })
        keymap.set("n", "<leader>fc", "<cmd>Telescope grep_string<cr>", { desc = "Find string under cursor in cwd" })
        keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<cr>", { desc = "Find todos" })
        keymap.set("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Find keymaps" })
      end,
    })
  end,
}
