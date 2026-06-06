local _, ns = ...

-- Void-Dark theme
-- Uses translucent dark surfaces + luminous rarity accents.
--
-- Fonts are bundled in media/fonts/ (Hanken Grotesk display, Geist body, JetBrains
-- Mono numerals/label-caps), matching the mockup's type system.
-- `fontInfo` is the {path, size} tuple passed to Label via SetFont.

local FONT = "Interface\\AddOns\\Warbandeer\\media\\fonts\\"

---@class Theme
---@field colors table<string, number[]>
---@field fonts table<string, table>
ns.theme = {
  colors = {
    window   = {0.05, 0.05, 0.06, 0.92}, -- main content surface (void dark)
    module   = {1, 1, 1, 0.05},          -- "glass-module" inner panel
    moduleHi = {1, 1, 1, 0.08},          -- header strip / hover tint
    hover    = {1, 1, 1, 0.10},          -- row hover highlight
    track    = {0.5, 0.5, 0.55, 1},      -- progress-bar track (tints the bar texture)
    border   = {0.60, 0.56, 0.46, 0.25}, -- 1px outline
    divider  = {0.60, 0.56, 0.46, 0.20},

    text     = {0.90, 0.886, 0.882, 1},  -- on-surface
    muted    = {0.82, 0.776, 0.671, 1},  -- on-surface-variant / label-caps

    gold     = {1, 0.82, 0, 1},          -- primary
    orange   = {1, 0.50, 0, 1},          -- legendary / mythic accent
    green    = {0.45, 0.85, 0.45, 1},    -- success
    red      = {0.86, 0.15, 0.15, 1},    -- danger
  },
  -- Bundled fonts (media/fonts/, OFL/Apache): Hanken Grotesk display, Geist body,
  -- JetBrains Mono numerals + label-caps. fontInfo = {path, size} for Label:SetFont.
  fonts = {
    headline = {FONT .. "HankenGrotesk-Bold.ttf", 18},
    title    = {FONT .. "HankenGrotesk-SemiBold.ttf", 16},
    caps     = {FONT .. "JetBrainsMono-Bold.ttf", 11}, -- rendered UPPERCASE for label-caps
    subcaps  = {FONT .. "JetBrainsMono-Bold.ttf", 8},  -- smaller label-caps for sub-lines
    body     = {FONT .. "Geist-Regular.ttf", 13},
    statBig  = {FONT .. "JetBrainsMono-SemiBold.ttf", 20},
    stat     = {FONT .. "JetBrainsMono-SemiBold.ttf", 10},
  },
}
