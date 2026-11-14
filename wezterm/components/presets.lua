local wezterm = require("wezterm")
local M = {}

-- Helper: get accent color for current window
local function get_window_accent(window)
  local win_id = tostring(window:window_id())
  local window_themes = wezterm.GLOBAL.window_themes or {}
  local theme = window_themes[win_id] or wezterm.GLOBAL.default_theme or {}
  return theme.accent and theme.accent.bg or "#006AA8"
end

-- Helper: find theme by name
local function find_theme(name)
  for _, t in ipairs(M.themes) do
    if t.name == name then
      return t
    end
  end
  return nil
end

-- Helper: store per-window theme data
local function store_window_theme(win_id, t)
  wezterm.GLOBAL.window_themes = wezterm.GLOBAL.window_themes or {}
  wezterm.GLOBAL.window_themes[win_id] = {
    name = t.name,
    accent = t.accent,
    hai_tab = t.hai_tab,
    fg = t.colors.foreground,
  }
end

-- Helper: format choice label with "← current" indicator
local function format_choice_label(text, is_current, accent_bg)
  if is_current then
    return wezterm.format({
      { Text = text .. " " },
      { Foreground = { Color = accent_bg } },
      { Text = " ← current" },
    })
  end
  return text
end

M.fonts = {
  "FantasqueSansM Nerd Font Mono",
  "MesloLGS Nerd Font Mono",
  "FiraCode Nerd Font Mono",
  "Iosevka Nerd Font Mono",
  "IosevkaTerm Nerd Font Mono",
  "SauceCodePro Nerd Font Mono",
  "JetBrainsMono Nerd Font Mono",
  "Hack Nerd Font Mono",
  "CaskaydiaCove Nerd Font Mono",
  "MonaspiceNe Nerd Font Mono",
  "CommitMono Nerd Font Mono",
  "GeistMono Nerd Font Mono",
  "VictorMono Nerd Font Mono",
  "0xProto Nerd Font Mono",
  "BlexMono Nerd Font Mono",
  "DepartureMono Nerd Font Mono",
  "Maple Mono NF",
}

M.sizes = {
  { name = "tiny", size = 10 },
  { name = "small", size = 12 },
  { name = "compact", size = 13 },
  { name = "default", size = 14 },
  { name = "comfortable", size = 15 },
  { name = "readable", size = 16 },
  { name = "large", size = 18 },
  { name = "bigger", size = 20 },
  { name = "presentation", size = 24 },
  { name = "demo", size = 28 },
  { name = "huge", size = 32 },
}

M.weights = {
  "Thin",
  "ExtraLight",
  "Light",
  "Regular",
  "Medium",
  "DemiBold",
  "Bold",
  "ExtraBold",
  "Black",
}

M.themes = {
  {
    name = "Coolnight",
    accent = { bg = "#006AA8", fg = "#C7E1F1" },
    hai_tab = { bg = "#0D3B4D", fg = "#24EAF7" },
    colors = {
      foreground = "#CBE0F0",
      background = "#011423",
      cursor_bg = "#47FF9C",
      cursor_border = "#47FF9C",
      cursor_fg = "#011423",
      selection_bg = "#033259",
      selection_fg = "#CBE0F0",
      ansi = { "#214969", "#FF6E6E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
      brights = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },
      split = "#1F6AA5",
      tab_bar = {
        background = "#011423",
        active_tab = { bg_color = "#011423", fg_color = "#C7E1F1" },
        inactive_tab = { bg_color = "#011F35", fg_color = "#7A9DB0" },
        inactive_tab_hover = { bg_color = "#022A45", fg_color = "#C7E1F1" },
        new_tab = { bg_color = "#011F35", fg_color = "#7A9DB0" },
        new_tab_hover = { bg_color = "#022A45", fg_color = "#C7E1F1" },
      },
    },
  },
  {
    name = "Dracula",
    accent = { bg = "#BD93F9", fg = "#282A36" },
    hai_tab = { bg = "#44475A", fg = "#FF79C6" },
    colors = {
      foreground = "#F8F8F2",
      background = "#282A36",
      cursor_bg = "#F8F8F2",
      cursor_border = "#F8F8F2",
      cursor_fg = "#282A36",
      selection_bg = "#44475A",
      selection_fg = "#F8F8F2",
      ansi = { "#21222C", "#FF5555", "#50FA7B", "#F1FA8C", "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2" },
      brights = { "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5", "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF" },
      split = "#6272A4",
      tab_bar = {
        background = "#282A36",
        active_tab = { bg_color = "#282A36", fg_color = "#F8F8F2" },
        inactive_tab = { bg_color = "#21222C", fg_color = "#6272A4" },
        inactive_tab_hover = { bg_color = "#44475A", fg_color = "#F8F8F2" },
        new_tab = { bg_color = "#21222C", fg_color = "#6272A4" },
        new_tab_hover = { bg_color = "#44475A", fg_color = "#F8F8F2" },
      },
    },
  },
  {
    name = "Gruvbox Dark",
    accent = { bg = "#D79921", fg = "#282828" },
    hai_tab = { bg = "#3C3836", fg = "#FABD2F" },
    colors = {
      foreground = "#EBDBB2",
      background = "#282828",
      cursor_bg = "#EBDBB2",
      cursor_border = "#EBDBB2",
      cursor_fg = "#282828",
      selection_bg = "#504945",
      selection_fg = "#EBDBB2",
      ansi = { "#282828", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#A89984" },
      brights = { "#928374", "#FB4934", "#B8BB26", "#FABD2F", "#83A598", "#D3869B", "#8EC07C", "#EBDBB2" },
      split = "#504945",
      tab_bar = {
        background = "#282828",
        active_tab = { bg_color = "#282828", fg_color = "#EBDBB2" },
        inactive_tab = { bg_color = "#1D2021", fg_color = "#928374" },
        inactive_tab_hover = { bg_color = "#3C3836", fg_color = "#EBDBB2" },
        new_tab = { bg_color = "#1D2021", fg_color = "#928374" },
        new_tab_hover = { bg_color = "#3C3836", fg_color = "#EBDBB2" },
      },
    },
  },
  {
    name = "Catppuccin Mocha",
    accent = { bg = "#89B4FA", fg = "#1E1E2E" },
    hai_tab = { bg = "#313244", fg = "#F5C2E7" },
    colors = {
      foreground = "#CDD6F4",
      background = "#1E1E2E",
      cursor_bg = "#F5E0DC",
      cursor_border = "#F5E0DC",
      cursor_fg = "#1E1E2E",
      selection_bg = "#45475A",
      selection_fg = "#CDD6F4",
      ansi = { "#45475A", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#BAC2DE" },
      brights = { "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#F5C2E7", "#94E2D5", "#A6ADC8" },
      split = "#6C7086",
      tab_bar = {
        background = "#1E1E2E",
        active_tab = { bg_color = "#1E1E2E", fg_color = "#CDD6F4" },
        inactive_tab = { bg_color = "#181825", fg_color = "#6C7086" },
        inactive_tab_hover = { bg_color = "#313244", fg_color = "#CDD6F4" },
        new_tab = { bg_color = "#181825", fg_color = "#6C7086" },
        new_tab_hover = { bg_color = "#313244", fg_color = "#CDD6F4" },
      },
    },
  },
  {
    name = "Nord",
    accent = { bg = "#88C0D0", fg = "#2E3440" },
    hai_tab = { bg = "#3B4252", fg = "#8FBCBB" },
    colors = {
      foreground = "#D8DEE9",
      background = "#2E3440",
      cursor_bg = "#D8DEE9",
      cursor_border = "#D8DEE9",
      cursor_fg = "#2E3440",
      selection_bg = "#434C5E",
      selection_fg = "#D8DEE9",
      ansi = { "#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0" },
      brights = { "#4C566A", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#8FBCBB", "#ECEFF4" },
      split = "#434C5E",
      tab_bar = {
        background = "#2E3440",
        active_tab = { bg_color = "#2E3440", fg_color = "#D8DEE9" },
        inactive_tab = { bg_color = "#242933", fg_color = "#4C566A" },
        inactive_tab_hover = { bg_color = "#3B4252", fg_color = "#D8DEE9" },
        new_tab = { bg_color = "#242933", fg_color = "#4C566A" },
        new_tab_hover = { bg_color = "#3B4252", fg_color = "#D8DEE9" },
      },
    },
  },
  {
    name = "Carbon Bloom",
    accent = { bg = "#D86D91", fg = "#17191D" },
    hai_tab = { bg = "#332C34", fg = "#F4A0B8" },
    colors = {
      foreground = "#ECEDEF",
      background = "#201A1F",
      cursor_bg = "#F4A0B8",
      cursor_border = "#F4A0B8",
      cursor_fg = "#201A1F",
      selection_bg = "#68405D",
      selection_fg = "#ECEDEF",
      ansi = { "#332C34", "#E76077", "#77BE8B", "#CFAA58", "#699ECC", "#AD90CF", "#5CB5B4", "#A4A9B2" },
      brights = { "#4C4F58", "#F06F82", "#97D27D", "#E0BA64", "#8CBDE8", "#C6A3EF", "#5CCBD5", "#ECEDEF" },
      split = "#512B3E",
      tab_bar = {
        background = "#201A1F",
        active_tab = { bg_color = "#201A1F", fg_color = "#ECEDEF" },
        inactive_tab = { bg_color = "#17131A", fg_color = "#8C929C" },
        inactive_tab_hover = { bg_color = "#332C34", fg_color = "#ECEDEF" },
        new_tab = { bg_color = "#17131A", fg_color = "#8C929C" },
        new_tab_hover = { bg_color = "#332C34", fg_color = "#ECEDEF" },
      },
    },
  },
  {
    name = "Nocturne Signal",
    accent = { bg = "#FFB38A", fg = "#10172B" },
    hai_tab = { bg = "#1B2635", fg = "#55CBD4" },
    colors = {
      foreground = "#E8EEF7",
      background = "#17131E",
      cursor_bg = "#FFB38A",
      cursor_border = "#FFB38A",
      cursor_fg = "#17131E",
      selection_bg = "#665599",
      selection_fg = "#E8EEF7",
      ansi = { "#1B2635", "#F87488", "#66D29D", "#EFC660", "#6CB1F1", "#BE9BFF", "#4FCBD4", "#97A4B6" },
      brights = { "#4C556E", "#FF7487", "#64D5A0", "#F3C66B", "#8FCBFF", "#C2A2FF", "#55CBD5", "#E8EEF7" },
      split = "#214666",
      tab_bar = {
        background = "#17131E",
        active_tab = { bg_color = "#17131E", fg_color = "#E8EEF7" },
        inactive_tab = { bg_color = "#0F0B14", fg_color = "#8995A8" },
        inactive_tab_hover = { bg_color = "#1B2635", fg_color = "#E8EEF7" },
        new_tab = { bg_color = "#0F0B14", fg_color = "#8995A8" },
        new_tab_hover = { bg_color = "#1B2635", fg_color = "#E8EEF7" },
      },
    },
  },
}

function M.apply(config)
  local font = wezterm.GLOBAL.selected_font or M.fonts[1]
  local size = wezterm.GLOBAL.selected_size or 15
  local weight = wezterm.GLOBAL.selected_weight or "Regular"
  local theme_name = wezterm.GLOBAL.selected_theme or M.themes[1].name

  config.font = wezterm.font(font, { weight = weight })
  config.font_size = size

  -- Initialize per-window theme storage
  wezterm.GLOBAL.window_themes = wezterm.GLOBAL.window_themes or {}

  -- Set default theme colors (used as fallback)
  local t = find_theme(theme_name)
  if t then
    config.colors = t.colors
    wezterm.GLOBAL.default_theme = {
      accent = t.accent,
      hai_tab = t.hai_tab,
      fg = t.colors.foreground,
    }
  end

  -- Register event to apply selected theme to new windows
  wezterm.on("window-config-reloaded", function(window, pane)
    local win_id = tostring(window:window_id())
    local window_themes = wezterm.GLOBAL.window_themes or {}

    -- Only apply if this window doesn't have overrides yet
    if not window_themes[win_id] then
      local selected = wezterm.GLOBAL.selected_theme
      if selected then
        local t = find_theme(selected)
        if t then
          local overrides = window:get_config_overrides() or {}
          -- Only set if not already set
          if not overrides.colors then
            overrides.colors = t.colors
            window:set_config_overrides(overrides)
          end
          store_window_theme(win_id, t)
        end
      end
    end
  end)
end

function M.font_picker()
  return wezterm.action_callback(function(window, pane)
    local accent_bg = get_window_accent(window)

    -- Get current font from window overrides or global
    local overrides = window:get_config_overrides() or {}
    local current_font = wezterm.GLOBAL.selected_font or M.fonts[1]
    -- Check if window has a font override
    if overrides.font then
      -- Extract font name from override (it's a font object)
      for _, f in ipairs(M.fonts) do
        if overrides.font == wezterm.font(f) then
          current_font = f
          break
        end
      end
    end

    -- Sort fonts alphabetically
    local sorted_fonts = {}
    for _, f in ipairs(M.fonts) do
      table.insert(sorted_fonts, f)
    end
    table.sort(sorted_fonts)

    local choices = {}
    for _, f in ipairs(sorted_fonts) do
      table.insert(choices, {
        label = format_choice_label(f, f == current_font, accent_bg),
        id = f,
      })
    end

    window:perform_action(wezterm.action.InputSelector({
      title = "Select Font",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "> ",
      action = wezterm.action_callback(function(win, p, id)
        if id then
          wezterm.GLOBAL.selected_font = id
          local weight = wezterm.GLOBAL.selected_weight or "Regular"
          local ovr = win:get_config_overrides() or {}
          ovr.font = wezterm.font(id, { weight = weight })
          win:set_config_overrides(ovr)
        end
      end),
    }), pane)
  end)
end

function M.size_picker()
  return wezterm.action_callback(function(window, pane)
    local accent_bg = get_window_accent(window)

    -- Get current size from window overrides or global
    local overrides = window:get_config_overrides() or {}
    local current_size = overrides.font_size or wezterm.GLOBAL.selected_size or 15

    local choices = {}
    for _, s in ipairs(M.sizes) do
      local text = s.name .. " (" .. s.size .. ")"
      table.insert(choices, {
        label = format_choice_label(text, s.size == current_size, accent_bg),
        id = tostring(s.size),
      })
    end

    window:perform_action(wezterm.action.InputSelector({
      title = "Select Font Size",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "> ",
      action = wezterm.action_callback(function(win, p, id)
        if id then
          local size = tonumber(id)
          wezterm.GLOBAL.selected_size = size
          win:perform_action(wezterm.action.ResetFontSize, p)
          -- Delay the override to let ResetFontSize complete
          wezterm.time.call_after(0.05, function()
            local ovr = win:get_config_overrides() or {}
            ovr.font_size = size
            win:set_config_overrides(ovr)
          end)
        end
      end),
    }), pane)
  end)
end

function M.weight_picker()
  return wezterm.action_callback(function(window, pane)
    local accent_bg = get_window_accent(window)

    local current_weight = wezterm.GLOBAL.selected_weight or "Regular"

    local choices = {}
    for _, w in ipairs(M.weights) do
      table.insert(choices, {
        label = format_choice_label(w, w == current_weight, accent_bg),
        id = w,
      })
    end

    window:perform_action(wezterm.action.InputSelector({
      title = "Select Font Weight",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "> ",
      action = wezterm.action_callback(function(win, p, id)
        if id then
          wezterm.GLOBAL.selected_weight = id
          local font = wezterm.GLOBAL.selected_font or M.fonts[1]
          local ovr = win:get_config_overrides() or {}
          ovr.font = wezterm.font(font, { weight = id })
          win:set_config_overrides(ovr)
        end
      end),
    }), pane)
  end)
end

function M.theme_picker()
  return wezterm.action_callback(function(window, pane)
    local accent_bg = get_window_accent(window)
    local win_id = tostring(window:window_id())
    local window_themes = wezterm.GLOBAL.window_themes or {}
    local current_theme = (window_themes[win_id] and window_themes[win_id].name)
      or wezterm.GLOBAL.selected_theme
      or M.themes[1].name

    -- Sort themes alphabetically by name
    local sorted_themes = {}
    for _, t in ipairs(M.themes) do
      table.insert(sorted_themes, t)
    end
    table.sort(sorted_themes, function(a, b) return a.name < b.name end)

    local choices = {}
    for _, t in ipairs(sorted_themes) do
      table.insert(choices, {
        label = format_choice_label(t.name, t.name == current_theme, accent_bg),
        id = t.name,
      })
    end

    window:perform_action(wezterm.action.InputSelector({
      title = "Select Theme",
      choices = choices,
      fuzzy = true,
      fuzzy_description = "> ",
      action = wezterm.action_callback(function(win, p, id)
        if id then
          local t = find_theme(id)
          if t then
            -- Update global so new windows inherit this theme
            wezterm.GLOBAL.selected_theme = id
            local ovr = win:get_config_overrides() or {}
            ovr.colors = t.colors
            win:set_config_overrides(ovr)
            -- Update default_theme so new windows get correct status bar colors
            wezterm.GLOBAL.default_theme = {
              accent = t.accent,
              hai_tab = t.hai_tab,
              fg = t.colors.foreground,
            }
            store_window_theme(tostring(win:window_id()), t)
          end
        end
      end),
    }), pane)
  end)
end

return M
