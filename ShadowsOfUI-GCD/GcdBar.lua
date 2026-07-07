---@class ShadowsOfUI_GCD: AddOn
local ns = LibNAddOn(...)

-- "Changelog" button in settings (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")
local ui, Class = ns.ui, ns.lua.Class
local StatusBar, Texture = ui.StatusBar, ui.Texture
local rgba = ns.Colors.rgba

local GcdFillStart = rgba(120, 170, 255, 0.9)
local GcdFillEnd   = rgba(200, 220, 255, 0.6)

local GCD_BASE  = 1.5
local BAR_WIDTH = 150
local BAR_HEIGHT = 4

local GcdBar = Class(StatusBar, function(self)
  self:Width(BAR_WIDTH)
  self:Height(BAR_HEIGHT)
  -- fallback position; PLAYER_ENTERING_WORLD reanchors to PRD if available
  self:SetPoint(ui.edge.Bottom, UIParent, ui.edge.Bottom, 0, 170)

  self.edge = Texture:new{
    parent = self,
    layer  = ui.layer.Overlay,
    blendMode = "BLEND",
    gradient  = {"VERTICAL", rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.5)},
    position  = {
      TopLeft     = {},
      BottomRight = {self, ui.edge.TopRight, 0, -2},
    },
  }

  self._gcdStart    = 0
  self._gcdDuration = 0
  self._lastCastGUID = nil
  self._barWidth    = BAR_WIDTH
  self:Hide()
end, {
  parent   = UIParent,
  name     = "ShadowsOfUIGcdBar",
  backdrop = {0, 0, 0, 0.4},
  fill = {
    color    = {1, 1, 1},
    blend    = "ADD",
    gradient = {"HORIZONTAL", GcdFillStart, GcdFillEnd},
  },
  events = {
    "PLAYER_ENTERING_WORLD",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_SUCCEEDED",
  },
})

function GcdBar:PLAYER_ENTERING_WORLD()
  local primary   = PrimaryResourceBar
  local secondary = SecondaryResourceBar
  if not (primary and secondary) then return end
  self._barWidth = primary:GetWidth()
  self._widget:ClearAllPoints()
  -- Two anchors let the frame fill the gap exactly, adapting to whatever space exists.
  self._widget:SetPoint("TOPLEFT",     primary,   "BOTTOMLEFT", 0, -2)
  self._widget:SetPoint("BOTTOMRIGHT", secondary, "TOPRIGHT",  0,  2)
end

local function trackGcd(self, unit, castGUID, spellID)
  if unit ~= "player" then return end
  -- START and SUCCEEDED both fire for the same cast (shared castGUID); deduplicate
  -- so each physical cast only starts one GCD cycle.
  if castGUID == self._lastCastGUID then return end
  self._lastCastGUID = castGUID
  -- All WoW stat/cooldown APIs return secret values in the tainted context of a
  -- secure action bar press. GetTime() is safe; use a fixed base GCD duration.
  self._gcdStart    = GetTime()
  self._gcdDuration = GCD_BASE
  self.fill:Width(self._barWidth)
  self:Show()
  self:startUpdates()
end

function GcdBar:UNIT_SPELLCAST_START(unit, castGUID, spellID)
  trackGcd(self, unit, castGUID, spellID)
end

function GcdBar:UNIT_SPELLCAST_CHANNEL_START(unit, castGUID, spellID)
  trackGcd(self, unit, castGUID, spellID)
end

function GcdBar:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
  trackGcd(self, unit, castGUID, spellID)
end

function GcdBar:onUpdate(elapsed)
  local remaining = (self._gcdStart + self._gcdDuration) - GetTime()
  if remaining <= 0 then
    self:Hide()
    self:stopUpdates()
    return
  end
  self.fill:Width(self._barWidth * remaining / self._gcdDuration)
end

function ns:onLoad()
  self.gcdBar = GcdBar:new{}
end
