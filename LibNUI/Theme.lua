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
  -- A runtime font swap introduces paths the constructor never saw, and the widgets repainted just
  -- below are the first to ask for them — exactly the case `_preload` exists to get in front of.
  if overrides.fonts then self:_preload() end
  for _, repaint in ipairs(self._themed) do repaint() end
  return self
end

-- Throwaway FontStrings holding every theme TTF resident, keyed by path. Kept for the session on
-- purpose: dropping one would let its file unload and re-open the race below.
local preloader, preloaded = nil, {}

-- Make every font file this theme declares resident, before any real widget asks for one.
--
-- A FontString built while its TTF is still loading gets a glyph run against a font that isn't there
-- yet, and nothing invalidates it afterwards: the text is set, the rect is correct, SetFont reports
-- success — and it never draws (nazumods/wow#718). Only the FIRST label to request a given file
-- survives, being the one whose SetFont triggers the load; every label built during that load is
-- blank, and everything built afterwards is fine. That ordering is by font FILE, not by clock time,
-- which is why one row of a grid could render while the rest of the same grid did not.
--
-- So the race is removed rather than papered over: one throwaway FontString per distinct path,
-- created when the theme is — addon load time, long before a window exists — so it is the throwaway
-- that takes the hit instead of a real caption. Both the holder and its strings are ANCHORED and
-- alpha-0 rather than hidden or unanchored: an unanchored region, or one on a hidden frame, is never
-- laid out, and so never builds the glyph run that is what actually pulls the file into residency.
--
-- Once per path per session: themes share files, and re-preloading a resident one does nothing.
function Theme:_preload()
  for _, info in pairs(self.fonts or {}) do
    local path = info and info[1]
    if path and not preloaded[path] then
      if not preloader then
        preloader = CreateFrame("Frame", nil, UIParent)
        preloader:SetPoint("TOPLEFT")
        preloader:SetSize(1, 1)
        preloader:SetAlpha(0)
      end
      local fs = preloader:CreateFontString(nil, "BACKGROUND")
      fs:SetPoint("TOPLEFT")
      fs:SetFont(path, info[2] or 12, "")
      fs:SetText(".")   -- SetFont opens the file; a glyph run is what makes it resident
      preloaded[path] = fs
    end
  end
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
    highlight   = {1, 215/255, 0, 0.25},    -- translucent active-row overlay (TableRow:Highlighted)
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
  setmetatable(t, {__index = Theme})
  t:_preload()
  return t
end
