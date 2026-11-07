return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local gitsigns = require("gitsigns")

    gitsigns.setup({
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
        untracked = { text = "┆" },
      },
      preview_config = {
        border = "rounded",
      },
      on_attach = function(bufnr)
        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        local function next_hunk()
          if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
          else
            gitsigns.nav_hunk("next")
          end
        end

        local function prev_hunk()
          if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
          else
            gitsigns.nav_hunk("prev")
          end
        end

        map("n", "]c", next_hunk, { desc = "Next git change" })
        map("n", "[c", prev_hunk, { desc = "Previous git change" })

        map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "Preview git hunk" })
        map("n", "<leader>hb", gitsigns.toggle_current_line_blame, { desc = "Toggle git blame" })
      end,
    })

    -- Global keymap: Esc closes any floating window
    vim.keymap.set("n", "<Esc>", function()
      -- Check if there's a floating window
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= "" then
          vim.api.nvim_win_close(win, true)
          return
        end
      end
      -- If no float, send normal Esc
      vim.cmd("normal! \\<Esc>")
    end, { desc = "Close floating window or Esc" })
  end,
}
