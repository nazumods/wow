---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Label, Button = ns.lua.Class, ui.Label, ui.Button
local CleanFrame = ui.CleanFrame
local theme = ns.theme

-- ─── Layout ───────────────────────────────────────────────────────────────────

local P, GAP = 12, 4
local LBL_H  = 12
local HINT_H = 10    -- "click to toggle" hint line
local TGL_H  = 20
local NUM_W  = 26    -- numbered bar toggles
local BTN_H  = 22    -- apply button

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
  { label = "Bonus", bars = {2},  w = 50, off = true, nl = true },
  { label = "Sky",   bars = {11}, w = 40, off = true },
  { label = "Pet",   pet  = true, w = 40, off = true },
}

local ROW_W    = 8 * NUM_W + 7 * GAP
local FRAME_W  = P + ROW_W + P
local OFF_BG   = { theme.colors.red[1], theme.colors.red[2], theme.colors.red[3], 0.18 }

-- ─── BarsApplyFrame ───────────────────────────────────────────────────────────
-- Companion box docked below the main window: per-bar include toggles + an
-- apply button that imports the previewed profile onto the logged-in character.

---@class BarsApplyFrame: CleanFrame
---@field _profile table?
---@field _toggles table[]
local BarsApplyFrame = Class(CleanFrame, function(self)
  self._profile = nil
  self._toggles = {}

  self.title = Label:new{
    parent   = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {P, -P}, Width = FRAME_W - 2 * P, Height = LBL_H },
    wordWrap = false,
  }

  Label:new{
    parent   = self, fontInfo = theme.fonts.subcaps, color = theme.colors.muted,
    position = { TopLeft = {P, -(P + LBL_H + GAP)}, Width = FRAME_W - 2 * P, Height = HINT_H },
    text     = "CLICK TO TOGGLE",
    wordWrap = false,
  }

  local x, y = P, -(P + LBL_H + GAP + HINT_H + 2 * GAP)
  for i, def in ipairs(TOGGLES) do
    if def.nl then x, y = P, y - TGL_H - GAP end
    local w = def.w or NUM_W
    local b = Button:new{
      parent     = self,
      glow       = false,
      background = theme.colors.selected,
      position   = { TopLeft = {x, y}, Width = w, Height = TGL_H },
    }
    b.label = Label:new{
      parent   = b, fontInfo = {theme.fonts.caps[1], 10},
      justifyH = ui.justify.Center,
      position = { All = true },
      text     = def.label:upper(),
    }
    b._def = def
    b._on  = not def.off
    b.OnClick = function()
      b._on = not b._on
      self:_paintToggle(b)
    end
    self._toggles[i] = b
    x = x + w + GAP
  end

  y = y - TGL_H - 2 * GAP
  self.applyBtn = Button:new{
    parent     = self,
    glow       = false,
    background = theme.colors.moduleHi,
    position   = { TopLeft = {P, y}, Width = FRAME_W - 2 * P, Height = BTN_H },
    OnClick    = function() self:_apply() end,
  }
  Label:new{
    parent   = self.applyBtn, fontInfo = {theme.fonts.caps[1], 10},
    justifyH = ui.justify.Center,
    position = { All = true },
    text     = "APPLY",
  }

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

-- Flat toggle wash: muted gold when included, red when skipped.
function BarsApplyFrame:_paintToggle(b)
  if b._on then
    b.background:Color(theme.colors.selected)
    b.label:Color(theme.colors.text)
  else
    b.background:Color(OFF_BG)
    b.label:Color(theme.colors.muted)
  end
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
end

---Point the apply panel at a profile and show it; hide if profile is nil.
---@param profile table?
function BarsApplyFrame:Set(profile)
  if not (profile and WarbandeerBarsApi) then self:Hide(); return end
  self._profile = profile
  self.title:Text("APPLY TO " .. WarbandeerBarsApi:GetCurrentCharacter():upper())
  for _, b in ipairs(self._toggles) do self:_paintToggle(b) end
  self:Show()
end
