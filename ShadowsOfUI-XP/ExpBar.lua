---@class ShadowsOfUI_XP: AddOn
local ns = LibNAddOn(...)
local floor = math.floor
local min = math.min

local Player = ns.wow.Player
local ui, Class = ns.ui, ns.lua.Class
local StatusBar, Texture = ui.StatusBar, ui.Texture
local TopLeft, TopRight = ui.edge.TopLeft, ui.edge.TopRight
local BottomLeft = ui.edge.BottomLeft
local rgba = ns.Colors.rgba

local UnrestedGradientStart = rgba(88, 0, 145, 0.5)
local UnrestedGradientEnd = rgba(154, 8, 252, 0.5)
local RestedGradientStart = rgba(0, 32, 128, 0.5)
local RestedGradientEnd = rgba(0, 64, 255, 0.5)

local ExpBar = Class(StatusBar, function(self)
  -- darken top edge of bar
  self.edge = Texture:new{
    parent = self,
    layer = ui.layer.Overlay,
    color = {1, 1, 1},
    blendMode = "BLEND",
    gradient = {"VERTICAL", rgba(0, 0, 0, 0), rgba(0, 0, 0, 0.5)},
    position = {
      TopLeft = {},
      BottomRight = {self, TopRight, 0, -3},
    },
  }

  -- fade into ui above
  self.fade = Texture:new{
    parent = self,
    layer = ui.layer.Background,
    color = {1, 1, 1},
    blendMode = "BLEND",
    gradient = {"VERTICAL", rgba(0, 0, 0, 0.3), rgba(0, 0, 0, 0)},
    position = {
      TopLeft = {0, 3},
      BottomRight = {self, TopRight},
    },
  }

  -- secondary bar to show rested amount
  self.secondary = Texture:new{
    parent = self,
    name = "$parentRest",
    layer = ui.layer.Artwork,
    color = {0, 0.25, 1, 0.5},
    position = {
      Left = {self.fill, ui.edge.Right},
      Height = self:Height(),
    },
  }
  -- self.secondary._widget:SetGradient("HORIZONTAL", RestedGradientStart, RestedGradientEnd)

  -- percent text
  self.textPercent = self._widget:CreateFontString(nil, "ARTWORK", "SystemFont_Tiny2")
  self.textPercent:SetHeight(self:Height() - 2)
  self.textPercent:SetTextColor(1, 1, 1, 0)

  self.restPercent = self._widget:CreateFontString(nil, "ARTWORK", "SystemFont_Tiny2")
  self.restPercent:SetHeight(self:Height() - 2)
  self.restPercent:SetTextColor(1, 1, 1, 0)

  -- make sure we can get mouse hover events in order to show the text
  self.fadeDelay = 500
  self._widget:SetMouseMotionEnabled(true)
  self:SetScript("OnEnter", function() self:onEnter() end)
  self:SetScript("OnLeave", function() self:onLeave() end)
end, {
  parent = UIParent,
  name = "ShadowsOfUIExpBar",
  position = {
    Height = 7,
    BottomLeft = {},
    BottomRight = {}
  },
  events = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_XP_UPDATE",
    "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION",
    "PLAYER_UPDATE_RESTING",
  },
  backdrop = {0, 0, 0, 0.3},
  fill = {
    color = {1, 1, 1},
    blend = "ADD",
    gradient = {"HORIZONTAL", UnrestedGradientStart, UnrestedGradientEnd},
  },
})

function ExpBar:onUpdate(elapsed)
  if self.fadeTimer > 0 then
    self.fadeTimer = self.fadeTimer - elapsed
    if self.fadeTimer < 0 then self.fadeTimer = 0 end
    self.textPercent:SetTextColor(1, 1, 1, self.fadeTimer / self.fadeDelay)
    self.restPercent:SetTextColor(1, 1, 1, self.fadeTimer / self.fadeDelay)
  end
  if self.fadeTimer == 0 then
    self:stopUpdates()
  end
end

-- mouse enters bar region
function ExpBar:onEnter()
  self.textPercent:SetTextColor(1, 1, 1, 1)
  self.restPercent:SetTextColor(1, 1, 1, 1)
end

-- mouse leaves bar region
function ExpBar:onLeave()
  self.fadeTimer = self.fadeDelay
  self:startUpdates()
end

function ExpBar:update()
  local w = self:Width()
  local xp = Player:GetXPPercent()
  local rest = Player:GetRestPercent()

  self.fill:Width(w * xp)
  self.textPercent:SetPoint(TopRight, self._widget, TopLeft, self.fill:Width() - 3, -1)
  self.textPercent:SetText(floor(xp * 100).."%")

  self.secondary:Width(w * min(rest, 1))
  -- self.secondary:SetPoint(TopLeft, self.fill:Width(), 0)
  self.restPercent:SetPoint(TopLeft, self._widget, TopLeft, self.fill:Width() + 3, -1)
  self.restPercent:SetText(floor(rest * 100).."%")
end

function ExpBar:initNotches()
  -- add the little notches every 10%
  local spacing = self:Width() / 10
  for i=1,9 do
    self['notch'..i] = Texture:new{
      parent = self,
      layer = ui.layer.Overlay,
      color = {1, 1, 1},
      blendMode = "BLEND",
      gradient = {"HORIZONTAL", rgba(0, 0, 0, 0.3), rgba(0, 0, 0, 0.2)},
      position = {
        TopLeft = {spacing * i, 0},
        BottomRight = {self, BottomLeft, spacing * i + 3, 0},
      },
    }
  end
end

function ExpBar:PLAYER_ENTERING_WORLD(login, reload)
  -- register for other events
  if login or reload then
    self:initNotches()
    self:update()
  end
end
function ExpBar:PLAYER_XP_UPDATE() self:update() end
function ExpBar:PLAYER_LEVEL_UP() self:update() end
function ExpBar:UPDATE_EXHAUSTION() self:update() end
function ExpBar:PLAYER_UPDATE_RESTING() self:update() end

function ns:onLoad()
  StatusTrackingBarManager:Hide()
  if not self.wow.Player:isMaxLevel() then
    self.xpBar = ExpBar:new{}
  end
end
