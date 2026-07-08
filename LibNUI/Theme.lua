---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local setmetatable, pairs, ipairs = setmetatable, pairs, ipairs

---@class Theme
---@field name string?
---@field colors table<string, number[]> rgba tables (0–1 channels) keyed by token name
---@field fonts table<string, table> fontInfo {path, size} tuples keyed by slot (title, header, body)
---@field textures table<string, string> texture paths keyed by slot
---@field _themed function[] repaint callbacks registered via Region:Themed
local Theme = {}

local SLOTS = {"colors", "fonts", "textures"}

-- Swap tokens at runtime: merge `overrides` into this theme IN PLACE (widgets resolve
-- tokens from these same tables, so anything built after Apply styles itself with the
-- new values automatically), then re-run every repaint registered via Region:Themed to
-- restyle what's already on screen. Only the tokens given change; e.g. an accent swap is
-- Apply{ colors = { header = {...} } }.
---@param overrides { colors: table?, fonts: table?, textures: table? }
---@return Theme
function Theme:Apply(overrides)
  for _, slot in ipairs(SLOTS) do
    local src = overrides[slot]
    if src then
      for token, value in pairs(src) do self[slot][token] = value end
    end
  end
  for _, repaint in ipairs(self._themed) do repaint() end
  return self
end

-- The default "dark" theme: the styling LibNUI widgets have always shipped with.
-- Widgets fall back to these tokens whenever no explicit option (and no custom
-- theme) is given. Color options on widgets accept a token name string (e.g.
-- background = "window") which resolves against the widget's active theme.
local dark = {
  name = "dark",
  colors = {
    window      = {0.114, 0.141, 0.165, 1}, -- CleanFrame surface
    border      = {0, 0, 0, 0.5},           -- CleanFrame tooltip-border tint
    titlebar    = {0, 0, 0, 0.5},           -- TitleFrame title strip
    backdrop    = {0, 0, 0, 0.8},           -- BgFrame / StatusBar backdrop
    tooltip     = {0, 0, 0, 0.7},           -- Tooltip surface

    text        = {1, 1, 1, 1},             -- default label / tooltip line text
    header      = {1, 215/255, 0, 1},       -- table column header text (gold)
    muted       = {0.8, 0.8, 0.8, 1},       -- secondary text (keybind labels)

    icon        = {0.7, 0.7, 0.7, 1},       -- titlebar close icon (resting)
    iconHover   = {1, 1, 1, 1},             -- titlebar close icon (hover)
    closeHover  = {1, 0, 0, 0.2},           -- close button hover background

    tabBar      = {0, 0, 0, 0.4},
    tabActive   = {0.20, 0.40, 0.70, 0.90},
    tabInactive = {0.08, 0.08, 0.08, 0.80},

    colEven     = {0, 0, 0, 0.6},           -- alternating column backdrops
    colOdd      = {0, 0, 0, 0.4},
    rowEven     = {0, 0, 0, 0.2},           -- alternating row backdrops
    rowOdd      = {0, 0, 0, 0},
    footer      = {0, 0, 0, 0.2},           -- footer row backdrop
    divider     = {1, 1, 1, 0.05},          -- 1px footer divider line
  },
  -- fontInfo {path, size} tuples; absent slots fall back to the Blizzard font
  -- objects the widgets used before themes existed (title → SystemFont_Med2,
  -- header/body → the widget's `font` option / GameFontHighlight).
  fonts = {},
  textures = {
    titleIcon = "Interface/Icons/inv_10_tailoring2_banner_green.blp",
    closeIcon = "Interface/AddOns/LibNUI/media/close.blp",
  },
  _themed = {},
}
setmetatable(dark, {__index = Theme})

---@type table<string, Theme> themes
ui.themes = { dark = dark }

-- Build a theme from partial overrides: any color/font/texture token not given
-- falls back to the dark theme, so themes only declare what they change.
---@param t table? { name?, colors?, fonts?, textures? }
---@return Theme
function ui.Theme(t)
  t = t or {}
  t.colors = setmetatable(t.colors or {}, {__index = dark.colors})
  t.fonts = setmetatable(t.fonts or {}, {__index = dark.fonts})
  t.textures = setmetatable(t.textures or {}, {__index = dark.textures})
  t._themed = {}
  return setmetatable(t, {__index = Theme})
end
