---@class Warbandeer
local ns = select(2, ...)

-- Void-Dark theme
-- Uses translucent dark surfaces + luminous rarity accents.
--
-- Fonts are bundled in media/fonts/ (Hanken Grotesk display, Geist body, JetBrains
-- Mono numerals/label-caps), matching the mockup's type system.
-- `fontInfo` is the {path, size} tuple passed to Label via SetFont.
--
-- Built as a LibNUI theme (ui.Theme) and passed once on MainWindow, so every
-- widget in the window inherits it. Tokens that share a name with LibNUI's
-- slots (window, border, divider, text, muted, header; fonts title/body)
-- deliberately override the LibNUI dark defaults inside the window; the rest
-- (module, hover, gold, …) are Warbandeer-specific and resolve the same way
-- (e.g. `backdropColor("hover")`). Unset LibNUI tokens fall back to dark.

local FONT = "Interface\\AddOns\\Warbandeer\\media\\fonts\\"

---@type Theme  the Void-Dark LibNUI theme, inherited by every widget in the window
ns.theme = ns.ui.Theme{
  name = "void-dark",
  colors = {
    window   = {0.05, 0.05, 0.06, 0}, -- main content surface (void dark)
    module   = {1, 1, 1, 0.05},          -- "glass-module" inner panel
    moduleHi = {1, 1, 1, 0.08},          -- header strip / hover tint
    hover    = {1, 1, 1, 0.10},          -- row hover highlight
    selected = {0.90, 0.80, 0.50, 0.15}, -- selected-row wash (muted artifact gold #e6cc80)
    track    = {0.5, 0.5, 0.55, 1},      -- progress-bar track (tints the bar texture)
    border   = {0.60, 0.56, 0.46, 0.25}, -- 1px outline
    divider  = {0.60, 0.56, 0.46, 0.20},

    text     = {0.90, 0.886, 0.882, 1},  -- on-surface
    muted    = {0.82, 0.776, 0.671, 1},  -- on-surface-variant / label-caps
    faded    = {0.82, 0.776, 0.671, 0.6},-- on-surface-variant
    header   = {0.82, 0.776, 0.671, 1},  -- table column headers (= muted)

    gold     = {1, 0.82, 0, 1},          -- primary
    orange   = {1, 0.50, 0, 1},          -- legendary / mythic accent
    green    = {0.45, 0.85, 0.45, 1},    -- success
    cyan     = {0.40, 0.80, 0.90, 1},    -- vendor / quartermaster accent
    red      = {0.86, 0.15, 0.15, 1},    -- danger
  },
  -- Bundled fonts (media/fonts/, OFL/Apache): Hanken Grotesk display, Geist body,
  -- JetBrains Mono numerals + label-caps. fontInfo = {path, size} for Label:SetFont.
  -- `title` and `body` double as the LibNUI slots: the window titlebar renders in
  -- `title`, and Labels with no explicit font default to `body`.
  fonts = {
    headline = {FONT .. "HankenGrotesk-Bold.ttf", 18},
    title    = {FONT .. "HankenGrotesk-SemiBold.ttf", 16},
    caps     = {FONT .. "JetBrainsMono-Bold.ttf", 11}, -- rendered UPPERCASE for label-caps
    subcaps  = {FONT .. "JetBrainsMono-Bold.ttf", 8},  -- smaller label-caps for sub-lines
    body     = {FONT .. "Geist-Regular.ttf", 13},
    bodySmall = {FONT .. "Geist-Regular.ttf", 11}, -- smaller body for sub-lines (e.g. gear upgrade hint)
    number   = {FONT .. "JetBrainsMono-SemiBold.ttf", 12}, -- fixed-width numerals for table columns
    statBig  = {FONT .. "JetBrainsMono-SemiBold.ttf", 20},
    stat     = {FONT .. "JetBrainsMono-SemiBold.ttf", 10},
  },
}

-- Publish the theme on LibNUI's shared `ui.themes` registry so sibling addons can
-- render in the same skin without depending on this addon. The standalone
-- /collected window (Warbandeer_Collected) reads `ui.themes["void-dark"]` so its
-- grid + chrome match Warbandeer's embedded collected view 1:1; it falls back to the
-- LibNUI default when this addon isn't loaded. Fonts resolve fine for any consumer
-- since the registration only happens once this addon (which ships them) has loaded.
ns.ui.themes["void-dark"] = ns.theme
