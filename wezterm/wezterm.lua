-- Pull in the wezterm API
local wezterm = require("wezterm")

-- Helper function to equalize all panes
local function equalize_panes(window, pane)
  wezterm.log_info("=== EQUALIZE STARTED ===")

  local tab = window:active_tab()
  if not tab then
    wezterm.log_info("ERROR: No active tab")
    return
  end

  -- Get tab dimensions to help identify truly stacked panes
  local tab_dims = tab:get_size()
  local tab_cols = tab_dims.cols
  local tab_rows = tab_dims.rows
  wezterm.log_info(string.format("Tab size: %dx%d", tab_cols, tab_rows))

  local panes = tab:panes()
  wezterm.log_info(string.format("Found %d panes", #panes))

  if #panes <= 1 then
    wezterm.log_info("Only 1 pane, nothing to equalize")
    return
  end

  -- Get active pane dimensions
  local active_dims = pane:get_dimensions()
  if not active_dims then
    wezterm.log_info("ERROR: No dimensions for active pane")
    return
  end
  local active_cols = active_dims.cols or active_dims.viewport_columns or 0
  local active_rows = active_dims.rows or active_dims.viewport_rows or 0
  local active_id = pane:pane_id()

  wezterm.log_info(string.format("Active pane: %dx%d", active_cols, active_rows))

  -- Collect all pane dimensions
  local all_panes = {}

  for i, p in ipairs(panes) do
    local dims = p:get_dimensions()
    if dims then
      local cols = dims.cols or dims.viewport_columns or 0
      local rows = dims.rows or dims.viewport_rows or 0
      local is_active = (p:pane_id() == active_id)

      wezterm.log_info(string.format("Pane %d: %dx%d %s", i, cols, rows,
        is_active and "(ACTIVE)" or ""))

      table.insert(all_panes, {pane = p, cols = cols, rows = rows, index = i, is_active = is_active})
    end
  end

  -- Identify horizontal columns: panes that are full height OR unique widths from non-full-height panes
  -- Similar to vertical logic: if width < tab_cols, it could be horizontally adjacent
  local full_height_panes = {}
  local not_full_height_panes = {}

  for _, data in ipairs(all_panes) do
    if data.rows >= tab_rows - 5 then
      table.insert(full_height_panes, data)
      wezterm.log_info(string.format("Pane %d is full height (%d ~ %d)", data.index, data.rows, tab_rows))
    else
      table.insert(not_full_height_panes, data)
      wezterm.log_info(string.format("Pane %d is NOT full height (%d < %d)", data.index, data.rows, tab_rows))
    end
  end

  -- For horizontal grouping:
  -- Get unique widths from non-full-height panes (these are stacked vertically, count once)
  -- Plus all full-height panes
  local unique_widths_from_stacked = {}
  local width_seen = {}
  for _, data in ipairs(not_full_height_panes) do
    local key = tostring(data.cols)
    if not width_seen[key] then
      unique_widths_from_stacked[key] = data.cols
      width_seen[key] = true
    end
  end

  local h_width_sum = 0
  -- Add full height panes
  for _, data in ipairs(full_height_panes) do
    h_width_sum = h_width_sum + data.cols
  end
  -- Add unique widths from stacked panes
  for _, width in pairs(unique_widths_from_stacked) do
    h_width_sum = h_width_sum + width
  end

  wezterm.log_info(string.format("Horizontal sum: %d (tab width: %d)", h_width_sum, tab_cols))

  -- Determine horizontal and vertical panes
  local horizontal_panes = {}
  local vertical_panes = {}

  if math.abs(h_width_sum - tab_cols) / tab_cols <= 0.1 then
    -- Widths span full tab - all panes are horizontal neighbors
    wezterm.log_info("Widths span full tab - all panes are horizontal")
    horizontal_panes = all_panes
  else
    -- Not spanning full width, use same-height filter
    wezterm.log_info("Not spanning full tab, filtering by same height")
    for _, data in ipairs(all_panes) do
      if math.abs(data.rows - active_rows) <= 2 then
        table.insert(horizontal_panes, data)
        wezterm.log_info(string.format("  Pane %d: same height (%d ~ %d)", data.index, data.rows, active_rows))
      end
    end
  end

  -- Vertical panes: same width as active, not full height
  for _, data in ipairs(all_panes) do
    if math.abs(data.cols - active_cols) <= 2 and data.rows < tab_rows - 5 then
      table.insert(vertical_panes, data)
      wezterm.log_info(string.format("Pane %d is vertically stacked (height %d < tab %d)", data.index, data.rows, tab_rows))
    end
  end

  local h_count = #horizontal_panes
  local v_count = #vertical_panes
  local total_cols = 0
  local total_rows = 0

  for _, data in ipairs(horizontal_panes) do
    total_cols = total_cols + data.cols
  end

  for _, data in ipairs(vertical_panes) do
    total_rows = total_rows + data.rows
  end

  wezterm.log_info(string.format("Horizontal: %d panes, total width=%d", h_count, total_cols))
  wezterm.log_info(string.format("Vertical: %d panes, total height=%d", v_count, total_rows))

  -- Calculate averages
  local h_avg = h_count > 1 and math.floor(total_cols / h_count) or active_cols
  local v_avg = v_count > 1 and math.floor(total_rows / v_count) or active_rows
  local h_diff = h_avg - active_cols
  local v_diff = v_avg - active_rows

  wezterm.log_info(string.format("Horizontal avg=%d, active=%d, diff=%+d", h_avg, active_cols, h_diff))
  wezterm.log_info(string.format("Vertical avg=%d, active=%d, diff=%+d", v_avg, active_rows, v_diff))

  -- Prioritize dimension with bigger difference
  local prioritize_horizontal = (h_count > 1 and math.abs(h_diff) > 2)
  local prioritize_vertical = (v_count > 1 and math.abs(v_diff) > 2)

  if prioritize_horizontal and prioritize_vertical then
    if math.abs(h_diff) >= math.abs(v_diff) then
      prioritize_vertical = false
    else
      prioritize_horizontal = false
    end
  end

  local adjusted = false

  -- Handle horizontal adjustment (width)
  if prioritize_horizontal then
    if h_diff > 0 then
      wezterm.log_info(string.format("GROW width by %d (trying Left)", h_diff))
      window:perform_action(wezterm.action.AdjustPaneSize{"Left", h_diff}, pane)

      wezterm.time.call_after(0.08, function()
        local new_dims = pane:get_dimensions()
        if new_dims then
          local new_cols = new_dims.cols or new_dims.viewport_columns or 0
          local actual = new_cols - active_cols
          wezterm.log_info(string.format("Result: %d -> %d (change %+d)", active_cols, new_cols, actual))

          if actual < 0 then
            wezterm.log_info("Wrong direction, trying Right")
            window:perform_action(wezterm.action.AdjustPaneSize{"Right", math.abs(actual)}, pane)
            wezterm.time.call_after(0.05, function()
              window:perform_action(wezterm.action.AdjustPaneSize{"Right", h_diff}, pane)
            end)
          elseif actual < h_diff / 2 then
            local remaining = h_diff - actual
            wezterm.log_info(string.format("Partial grow, trying Right for %d more", remaining))
            window:perform_action(wezterm.action.AdjustPaneSize{"Right", remaining}, pane)
          end
        end
      end)
    else
      local shrink = math.abs(h_diff)
      wezterm.log_info(string.format("SHRINK width by %d (trying Right)", shrink))
      window:perform_action(wezterm.action.AdjustPaneSize{"Right", shrink}, pane)

      wezterm.time.call_after(0.08, function()
        local new_dims = pane:get_dimensions()
        if new_dims then
          local new_cols = new_dims.cols or new_dims.viewport_columns or 0
          local actual = new_cols - active_cols
          wezterm.log_info(string.format("Result: %d -> %d (change %+d)", active_cols, new_cols, actual))

          if actual > 0 then
            wezterm.log_info("Wrong direction, trying Left")
            window:perform_action(wezterm.action.AdjustPaneSize{"Left", actual}, pane)
            wezterm.time.call_after(0.05, function()
              window:perform_action(wezterm.action.AdjustPaneSize{"Left", shrink}, pane)
            end)
          elseif math.abs(actual) < shrink / 2 then
            local remaining = shrink - math.abs(actual)
            wezterm.log_info(string.format("Partial shrink, trying Left for %d more", remaining))
            window:perform_action(wezterm.action.AdjustPaneSize{"Left", remaining}, pane)
          end
        end
      end)
    end
    adjusted = true
  end

  -- Handle vertical adjustment (height)
  if prioritize_vertical then
    -- Find pane furthest from average
    local worst_pane = nil
    local worst_diff = 0

    for _, data in ipairs(vertical_panes) do
      local diff = math.abs(v_avg - data.rows)
      if diff > worst_diff and diff > 2 then
        worst_diff = diff
        worst_pane = data
      end
    end

    if worst_pane then
      local target_pane = worst_pane.pane
      local target_rows = worst_pane.rows
      local target_diff = v_avg - target_rows

      wezterm.log_info(string.format("Adjusting pane %d: %d -> %d (diff %+d)",
        worst_pane.index, target_rows, v_avg, target_diff))

      target_pane:activate()

      if target_diff > 0 then
        wezterm.log_info(string.format("GROW height by %d (trying Up)", target_diff))
        window:perform_action(wezterm.action.AdjustPaneSize{"Up", target_diff}, target_pane)

        wezterm.time.call_after(0.08, function()
          local new_dims = target_pane:get_dimensions()
          if new_dims then
            local new_rows = new_dims.rows or new_dims.viewport_rows or 0
            local actual = new_rows - target_rows
            wezterm.log_info(string.format("Result: %d -> %d (change %+d)", target_rows, new_rows, actual))

            if actual < 0 then
              wezterm.log_info("Wrong direction, trying Down")
              window:perform_action(wezterm.action.AdjustPaneSize{"Down", math.abs(actual)}, target_pane)
              wezterm.time.call_after(0.05, function()
                window:perform_action(wezterm.action.AdjustPaneSize{"Down", target_diff}, target_pane)
                pane:activate()
              end)
            else
              pane:activate()
            end
          end
        end)
      else
        local shrink = math.abs(target_diff)
        wezterm.log_info(string.format("SHRINK height by %d (trying Down)", shrink))
        window:perform_action(wezterm.action.AdjustPaneSize{"Down", shrink}, target_pane)

        wezterm.time.call_after(0.08, function()
          local new_dims = target_pane:get_dimensions()
          if new_dims then
            local new_rows = new_dims.rows or new_dims.viewport_rows or 0
            local actual = new_rows - target_rows
            wezterm.log_info(string.format("Result: %d -> %d (change %+d)", target_rows, new_rows, actual))

            if actual > 0 then
              wezterm.log_info("Wrong direction, trying Up")
              window:perform_action(wezterm.action.AdjustPaneSize{"Up", actual}, target_pane)
              wezterm.time.call_after(0.05, function()
                window:perform_action(wezterm.action.AdjustPaneSize{"Up", shrink}, target_pane)
                pane:activate()
              end)
            else
              pane:activate()
            end
          end
        end)
      end
      adjusted = true
    end
  end

  -- Show status
  if adjusted then
    window:set_right_status(wezterm.format({
      {Background={Color="#FFE073"}},
      {Foreground={Color="#000000"}},
      {Attribute={Intensity="Bold"}},
      {Text="  Adjusted  "},
    }))
  else
    window:set_right_status(wezterm.format({
      {Background={Color="#44FFB1"}},
      {Foreground={Color="#000000"}},
      {Attribute={Intensity="Bold"}},
      {Text="  Equal!  "},
    }))
  end
  wezterm.log_info("=== EQUALIZE DONE ===")
end

-- Helper function at module level to show pane size during resize
local function resize_pane_with_feedback(window, pane, direction, amount)
  window:perform_action(wezterm.action.AdjustPaneSize{direction, amount}, pane)

  -- Force immediate status update
  local dims = pane:get_dimensions()
  if dims then
    local cols = dims.cols or dims.viewport_columns or 0
    local rows = dims.rows or dims.viewport_rows or 0
    if cols > 0 and rows > 0 then
      local status = string.format("  %dx%d  ", cols, rows)
      window:set_right_status(wezterm.format({
        {Background={Color="#006AA8"}},
        {Foreground={Color="#C7E1F1"}},
        {Attribute={Intensity="Bold"}},
        {Text=status},
      }))
    end
  end
end

-- Try to load hai component (SAP-specific, gitignored)
local hai_loaded = false
-- wezterm.config_dir returns ~ when loading from ~/.wezterm.lua symlink
-- Resolve symlink to get actual directory containing wezterm.hai.lua
local config_file = wezterm.config_file
local handle = io.popen("readlink '" .. config_file .. "' 2>/dev/null || echo '" .. config_file .. "'")
local resolved = handle:read("*a"):gsub("%s+$", "")
handle:close()
local config_dir = resolved:match("(.*/)")
local hai_path = config_dir .. "wezterm.hai.lua"

-- Check if hai component exists
local hai_file = io.open(hai_path, "r")
if hai_file then
  hai_file:close()
  local ok, err = pcall(function()
    dofile(hai_path)
  end)
  if ok then
    hai_loaded = true
    wezterm.log_info("HAI component loaded from: " .. hai_path)
  else
    wezterm.log_error("Failed to load HAI component: " .. tostring(err))
  end
end

-- If hai not loaded, register basic handlers (dimensions only)
if not hai_loaded then
  wezterm.on("update-status", function(window, pane)
    local dims = pane:get_dimensions()
    if not dims then
      return
    end

    local cols = dims.cols or dims.viewport_columns or 0
    local rows = dims.rows or dims.viewport_rows or 0

    if cols == 0 or rows == 0 then
      return
    end

    window:set_right_status(wezterm.format({
      {Background={Color="#006AA8"}},
      {Foreground={Color="#C7E1F1"}},
      {Text = string.format(" %dx%d ", cols, rows)},
    }))
  end)

  wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local title = tab.tab_title
    if not title or #title == 0 then
      title = tab.active_pane.title
    end

    title = title:gsub("^~", "")

    if not title or #title == 0 or title:match("^%s*$") then
      title = tostring(tab.tab_index + 1)
    end

    if tab.is_active then
      return {
        {Attribute={Intensity="Bold"}},
        {Text = " " .. title .. " "},
      }
    else
      return {
        {Text = " " .. title .. " "},
      }
    end
  end)
end

local function config_builder()
-- This will hold the configuration.
  local config = wezterm.config_builder()

  config.term = "xterm-256color"

  -- -- ---------------------------
  -- -- Helper functions
  -- -- ---------------------------
  -- Show pane size
  local function show_pane_size(window, pane)
    local dims = pane:get_dimensions()
    local text = string.format(
      "Pane Size\n\nWidth: %d | Height: %d",
      dims.cols,
      dims.rows
    )

    window:perform_action(
      wezterm.action.InputSelector {
        title = "Pane Info",
        choices = {
          { label = text, id = "ok" },
        },
        action = wezterm.action.CloseCurrentPane { confirm = false },
      },
      pane
    )
  end

  -- Set initial window size in cells
  config.initial_cols = 160
  config.initial_rows = 50

  -- Status bar update interval (milliseconds) - for responsive hai proxy indicator
  config.status_update_interval = 500

  -- Set initial window size in pixels
  -- config.initial_window_size = {
  --   width = 1200
  --   height = 800
  -- }

  -- config.color_scheme = "Batman"
  -- config.color_scheme = "Catppuccin Frappe"
  -- config.color_scheme = "Catppuccin Macchiato"
  -- config.color_scheme = "Tokyo Night"
  -- config.color_scheme = "Nord"

  config.font = wezterm.font("MesloLGS Nerd Font Mono")
  config.font_size = 15

  config.enable_tab_bar = true
  config.use_fancy_tab_bar = false
  config.hide_tab_bar_if_only_one_tab = false
  config.tab_bar_at_bottom = false
  config.tab_max_width = 32
  config.adjust_window_size_when_changing_font_size = false

  config.window_decorations = "RESIZE"
  config.adjust_window_size_when_changing_font_size = false
  -- config.cell_width = 1.0
  config.line_height = 1.0
  config.window_padding = {
    left = 0,
    right = 0,
    top = 1,
    bottom = 1,
  }
  --
  -- Coolnight colorscheme:
  config.colors = {
    foreground = "#CBE0F0",
    background = "#011423",
    cursor_bg = "#47FF9C",
    cursor_border = "#47FF9C",
    cursor_fg = "#011423",
    selection_bg = "#033259",
    selection_fg = "#CBE0F0",
    ansi = { "#214969", "#FF6E6E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
    brights = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },

    -- Pane divider color
    split = "#1F6AA5",

    -- Tab bar colors
    tab_bar = {
      background = "#001424",  -- Your theme background
      active_tab = {
        bg_color = "#001424",  -- Your theme background
        fg_color = "#C7E1F1",  -- Your theme text color
      },
      inactive_tab = {
        bg_color = "#011F35",  -- Slightly lighter than background
        fg_color = "#7A9DB0",  -- Dimmed version of text color
      },
      inactive_tab_hover = {
        bg_color = "#022A45",  -- Even lighter on hover
        fg_color = "#C7E1F1",  -- Full brightness on hover
      },
      new_tab = {
        bg_color = "#011F35",
        fg_color = "#7A9DB0",
      },
      new_tab_hover = {
        bg_color = "#022A45",
        fg_color = "#C7E1F1",
      },
    },
  }

  -- Pane focus behavior
  config.pane_focus_follows_mouse = false

  -- Pane highlight options
  -- Strong dimming for clear visual distinction
  config.inactive_pane_hsb = {
    saturation = 0.4,  -- Reduce color significantly
    brightness = 0.45,  -- Dim considerably for clear distinction
  }

  -- Cursor emphasis
  config.default_cursor_style = "BlinkingBlock"
  config.cursor_blink_rate = 500

  -- Define key bindings
  config.keys = config.keys or {}

  -- MacOS-style navigation key mappings
  table.insert(config.keys, {key="LeftArrow", mods="CMD", action=wezterm.action.SendKey{key="Home"}})
  table.insert(config.keys, {key="RightArrow", mods="CMD", action=wezterm.action.SendKey{key="End"}})
  table.insert(config.keys, {key="LeftArrow", mods="OPT", action=wezterm.action.SendString("\027b")})
  table.insert(config.keys, {key="RightArrow", mods="OPT", action=wezterm.action.SendString("\027f")})

  -- Pane splitting shortcut key mappings
  -- Split pane to the right
  table.insert(config.keys, {key="d", mods="CMD", action=wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}})
  -- Split pane below
  table.insert(config.keys, {key="d", mods="CMD|SHIFT", action=wezterm.action.SplitVertical{domain="CurrentPaneDomain"}})
  -- Equalize size of panes with size feedback (finer control)
  table.insert(config.keys, {key="RightArrow", mods="CMD|SHIFT", action=wezterm.action_callback(function(window, pane)
    resize_pane_with_feedback(window, pane, "Right", 2)
  end)})
  table.insert(config.keys, {key="LeftArrow", mods="CMD|SHIFT", action=wezterm.action_callback(function(window, pane)
    resize_pane_with_feedback(window, pane, "Left", 2)
  end)})
  table.insert(config.keys, {key="UpArrow", mods="CMD|SHIFT", action=wezterm.action_callback(function(window, pane)
    resize_pane_with_feedback(window, pane, "Up", 1)
  end)})
  table.insert(config.keys, {key="DownArrow", mods="CMD|SHIFT", action=wezterm.action_callback(function(window, pane)
    resize_pane_with_feedback(window, pane, "Down", 1)
  end)})
  -- Show active pane dimensions
  table.insert(config.keys, {key="i", mods="CMD|SHIFT", action=wezterm.action_callback(show_pane_size)})

  -- Equalize all panes - SHIFT+CMD+E
  table.insert(config.keys, {key="e", mods="CMD|SHIFT", action=wezterm.action_callback(equalize_panes)})

  -- Pane navigation (nvim-style)
  table.insert(config.keys, {key="LeftArrow", mods="CMD|CTRL", action=wezterm.action.ActivatePaneDirection("Left")})
  table.insert(config.keys, {key="RightArrow", mods="CMD|CTRL", action=wezterm.action.ActivatePaneDirection("Right")})
  table.insert(config.keys, {key="UpArrow", mods="CMD|CTRL", action=wezterm.action.ActivatePaneDirection("Up")})
  table.insert(config.keys, {key="DownArrow", mods="CMD|CTRL", action=wezterm.action.ActivatePaneDirection("Down")})

  -- Close active pane (use Cmd+W, overrides the MacOS-style close shortcut, change to Cmd+Ctrl+W to not override)
  table.insert(config.keys, {key="w", mods="CMD|CTRL", action=wezterm.action.CloseCurrentPane({confirm=true})})

  -- Toggle hai proxy tab - only if hai component loaded
  if hai_loaded and _G.toggle_hai_stack then
    table.insert(config.keys, {key="h", mods="CMD|SHIFT", action=wezterm.action_callback(_G.toggle_hai_stack)})
  end

  -- -- Override Cmd+C
  -- table.insert(config.keys, {
  --   key = "c",
  --   mods = "CMD",
  --   action = wezterm.action_callback(function(window, pane)
  --     -- Check if there is a selection
  --     local has_selection = window:get_selection_text_for_pane(pane) ~= nil
  --     if has_selection then
  --       window:perform_action(wezterm.action.CopyTo("Clipboard"), pane)
  --     else
  --       -- Nothing selected, clear clipboard
  --       wezterm.clipboard_write("")
  --     end
  --   end)
  -- })
  --
  -- -- Optional: Cmd+V
  -- table.insert(config.keys, {
  --   key = "v",
  --   mods = "CMD",
  --   action = wezterm.action.PasteFrom("Clipboard")
  -- })

  return config
end

return config_builder()
