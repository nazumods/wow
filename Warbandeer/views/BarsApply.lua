---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Label, Button = ns.lua.Class, ui.Label, ui.Button
local Texture = ui.Texture
local CleanFrame = ui.CleanFrame
local theme = ns.theme

-- ─── Layout ───────────────────────────────────────────────────────────────────

local P, GAP = 12, 4
local LBL_H  = 12    -- title line
local WARN_H = 10    -- "overwrites …" warning line
local LEG_H  = 12    -- legend row (included / excluded swatches)
local FOOT_H = 10    -- footnote line
local TGL_H  = 28
local NUM_W  = 32    -- numbered bar toggles
local BTN_H  = 26    -- apply button
local ACC_W  = 3     -- left accent bar on each toggle
local SW     = 8     -- legend swatch size

local HEAD_H = LBL_H + WARN_H

-- Display toggle → internal profile bars (slot id = (bar-1)*12 + n). Numbered
-- toggles follow the Edit Mode bar names the preview shows; C1-C5 are the
-- stance/class pages, Bonus the possess/override page, Sky the skyriding bar.
-- Pet maps to the pet action bar (petslots), not a slot range. `nl` starts a
-- new row, `off` defaults the toggle unselected.
local TOGGLES = {
  { label = "1",     bars = {1}  },
  { label = "2",     bars = {6}  },
  { label = "3",     bars = {5}  },
  { label = "4",     bars = {3}  },
  { label = "5",     bars = {4}  },
  { label = "6",     bars = {13} },
  { label = "7",     bars = {14} },
  { label = "8",     bars = {15} },
  { label = "C1",    bars = {7},  nl = true },
  { label = "C2",    bars = {8}  },
  { label = "C3",    bars = {9}  },
  { label = "C4",    bars = {10} },
  { label = "C5",    bars = {12} },
  { label = "Bonus", bars = {2},  w = 64, off = true, nl = true },
  { label = "Sky",   bars = {11}, w = 52, off = true },
  { label = "Pet",   pet  = true, w = 52, off = true },
}
-- Exposed for barApplyDefaultsSettings.lua (one checkbox per toggle).
---@type table[]
ns.BarApplyToggles = TOGGLES

-- The default include-state for a toggle: the user's saved preference if set,
-- else the built-in default (`not def.off`). Read when the panel is constructed.
local function defaultOn(def)
  local pref = ns.db.settings.barApplyDefaults[def.label]
  if pref == nil then return not def.off end
  return pref
end

local ROW_W    = 8 * NUM_W + 7 * GAP
local FRAME_W  = P + ROW_W + P
-- Included: brighter gold wash than the row-selected tint so a filled toggle
-- reads as "on"; the apply button uses the same accent to mark it the primary CTA.
local INCL_BG  = { theme.colors.selected[1], theme.colors.selected[2], theme.colors.selected[3], 0.22 }
local APPLY_BG = { theme.colors.gold[1], theme.colors.gold[2], theme.colors.gold[3], 0.20 }
-- Hover always reads as a lift: brighter gold over an included toggle, a faint
-- wash over an (otherwise empty) excluded one.
local HOVER_ON  = { theme.colors.gold[1], theme.colors.gold[2], theme.colors.gold[3], 0.32 }
local HOVER_OFF = theme.colors.hover

-- ─── BarsApplyFrame ───────────────────────────────────────────────────────────
-- Companion box docked below the main window: per-bar include toggles + an
-- apply button that imports the previewed profile onto the logged-in character.

---@class BarsApplyFrame: CleanFrame
---@field _profile table?
---@field _toggles table[]
---@field _previewFrame BarsPreviewFrame?   set by BarsView so toggle hover can highlight the matching preview bar
---@field title Label
---@field warn Label
---@field applyBtn Button
local BarsApplyFrame = Class(CleanFrame, function(self)
  self._profile = nil
  self._toggles = {}

  self.title = Label:new{
    parent   = self, fontInfo = theme.fonts.body, color = theme.colors.text,
    position = { TopLeft = {P, -P}, Width = FRAME_W - 2 * P, Height = LBL_H },
    wordWrap = false,
  }
  self.warn = Label:new{
    parent   = self, fontInfo = theme.fonts.subcaps, color = theme.colors.faded,
    position = { TopLeft = {P, -(P + LBL_H)}, Width = FRAME_W - 2 * P, Height = WARN_H },
    wordWrap = false,
  }

  -- Legend: gold swatch = included, red swatch = excluded.
  self:_legend()

  local x, y = P, -(P + HEAD_H + GAP + LEG_H + 2 * GAP)
  for i, def in ipairs(TOGGLES) do
    if def.nl then x, y = P, y - TGL_H - GAP end
    local w = def.w or NUM_W
    local b = Button:new{
      parent     = self,
      glow       = false,
      background  = INCL_BG,
      position    = { TopLeft = {x, y}, Width = w, Height = TGL_H },
    }
    b.accent = Texture:new{
      parent   = b, layer = ui.layer.Overlay,
      position = { TopLeft = {0, 0}, Width = ACC_W, Height = TGL_H },
    }
    b.label = Label:new{
      parent   = b, fontInfo = {theme.fonts.caps[1], 13}, color = theme.colors.muted,
      justifyH = ui.justify.Center,
      position = { All = true },
      text     = def.label:upper(),
    }
    b._def = def
    b._on  = defaultOn(def)
    b.OnClick = function()
      b._on = not b._on
      self:_paintToggle(b)
      self:_updateApplyLabel()
    end
    -- Hover: emphasise the toggle and light up the bar it controls in the preview.
    b.OnEnter = function()
      b.background:Color(b._on and HOVER_ON or HOVER_OFF)
      self:_highlightBars(b._def, true)
    end
    b.OnLeave = function()
      self:_paintToggle(b)
      self:_highlightBars(b._def, false)
    end
    self._toggles[i] = b
    x = x + w + GAP
  end

  y = y - TGL_H - GAP
  Label:new{
    parent   = self, fontInfo = theme.fonts.subcaps, color = theme.colors.faded,
    position = { TopLeft = {P, y}, Width = FRAME_W - 2 * P, Height = FOOT_H },
    text     = "Keybindings and outfits are never changed.",
    wordWrap = false,
  }

  y = y - FOOT_H - GAP
  self.applyBtn = Button:new{
    parent     = self,
    glow       = true,
    background  = APPLY_BG,
    position    = { TopLeft = {P, y}, Width = FRAME_W - 2 * P, Height = BTN_H },
    OnClick     = function() self:_apply() end,
  }
  self.applyBtn:Text("APPLY")
  self.applyBtn:TextAlign("CENTER")

  self:Width(FRAME_W)
  self:Height(-y + BTN_H + P)
  self:Hide()
end, {
  -- anchored to the (already clamped) main window — same rule as the preview
  clamped    = false,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})
---@class Warbandeer
---@field BarsApplyFrame BarsApplyFrame
ns.BarsApplyFrame = BarsApplyFrame

-- Two-swatch legend explaining the toggle colour code.
function BarsApplyFrame:_legend()
  local legY = -(P + HEAD_H + GAP)
  local function pair(x, color, text)
    Texture:new{
      parent   = self, color = color, layer = ui.layer.Overlay,
      position = { TopLeft = {x, legY - (LEG_H - SW) / 2}, Width = SW, Height = SW },
    }
    Label:new{
      parent   = self, fontInfo = theme.fonts.subcaps, color = theme.colors.muted,
      position = { TopLeft = {x + SW + 4, legY}, Width = 64, Height = LEG_H },
      text     = text, wordWrap = false,
    }
  end
  pair(P, theme.colors.gold, "INCLUDED")
  pair(P + SW + 4 + 64 + GAP, theme.colors.red, "EXCLUDED")
end

-- Flat toggle wash: gold fill + gold accent when included, empty + red accent when skipped.
function BarsApplyFrame:_paintToggle(b)
  if b._on then
    b.background:Color(INCL_BG)
    b.label:Color(theme.colors.text)
    b.accent:Color(theme.colors.gold)
  else
    b.background:Color(0, 0, 0, 0)
    b.label:Color(theme.colors.muted)
    b.accent:Color(theme.colors.red)
  end
end

-- Light up (or clear) the preview bars a toggle controls, so its mapping is visible.
function BarsApplyFrame:_highlightBars(def, on)
  local preview = self._previewFrame
  if not (preview and def.bars) then return end
  for _, bar in ipairs(def.bars) do preview:HighlightProfileBar(bar, on) end
end

-- Apply button caption tracks the number of included toggles.
function BarsApplyFrame:_updateApplyLabel()
  local n = 0
  for _, b in ipairs(self._toggles) do if b._on then n = n + 1 end end
  self.applyBtn:Text(n > 0 and ("APPLY " .. n .. " BAR" .. (n > 1 and "S" or "")) or "APPLY")
end

function BarsApplyFrame:_apply()
  if not (self._profile and WarbandeerBarsApi) then return end
  -- Macros always restore (macro slots on included bars need them); bindings
  -- and outfits never — an import shouldn't silently rewrite keybinds.
  local include   = { bars = false, macros = true, petbar = false, bindings = false, outfits = false }
  local barFilter = {}
  for _, b in ipairs(self._toggles) do
    if b._def.pet then
      include.petbar = b._on
    else
      if b._on then include.bars = true end
      for _, bar in ipairs(b._def.bars) do barFilter[bar] = b._on end
    end
  end
  WarbandeerBarsApi:Restore(self._profile, include, false, barFilter)
  self.applyBtn:ConfirmFlash("APPLIED", 1200)
end

---Point the apply panel at a profile and show it; hide if profile is nil.
---@param profile table?
function BarsApplyFrame:Set(profile)
  if not (profile and WarbandeerBarsApi) then self:Hide(); return end
  self._profile = profile
  local char = WarbandeerBarsApi:GetCurrentCharacter():upper()
  self.title:Text("APPLY TO " .. char)
  self.warn:Text("OVERWRITES " .. char .. "'S BARS")
  for _, b in ipairs(self._toggles) do self:_paintToggle(b) end
  self:_updateApplyLabel()
  self:Show()
end
