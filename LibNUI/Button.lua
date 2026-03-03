local _, ns = ...
-- luacheck: globals NumberFontNormalSmallGray CreateFont GetCursorInfo
local ui = ns.ui
local Class, unpack = ns.lua.Class, unpack
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local GameTooltip, SetOverrideBindingClick = GameTooltip, SetOverrideBindingClick
local GetItemCooldown, GetTime = GetItemCooldown, GetTime
local GetCursorInfo = GetCursorInfo

local file, _, flags = NumberFontNormalSmallGray:GetFont()
local keybindFont = CreateFont("LibNUIButtonKeybind")
keybindFont:SetFont(file, 7, flags)

local patterns = {
  ["ALT%-"] = "a-", -- alt
  ["CTRL%-"] = "c-", -- ctrl
  ["SHIFT%-"] = "s-", -- shift
}

local function formatKeybind(bind)
  for p,s in pairs(patterns) do
    bind = bind:gsub(p, s)
  end
  return bind
end

local function formatCooldown(t)
  if t > 3600 then -- > 1h
    return math.floor(t / 3600)..'h'
  end
  if t > 60 then -- > 1m
    local m = math.floor(t / 60)
    return m..':'..(t - m * 60)
  end
end

-- https://wowpedia.fandom.com/wiki/UIOBJECT_Button
---@class Button
---@field _widget table
---@field border table
---@field cooldown table
---@field itemID number
---@field tooltip table
---@field OnChange function
---@field OnClick function
---@field startUpdates function
---@field stopUpdates function
local Button = Class(Frame, function(self)
  if self.normal then
    if self.normal.texture then
      self._widget:SetNormalTexture(self.normal.texture)
    end
    if self.normal.coords then
      self._widget:GetNormalTexture():SetTexCoord(unpack(self.normal.coords))
    end
  end

  if self.onClick then
    self._widget:SetScript("OnClick", function() self:onClick() end)
  end
  self._widget:RegisterForClicks("AnyDown", "AnyUp")

  -- https://wowpedia.fandom.com/wiki/Creating_key_bindings
  if self.bindLeftClick then
    SetOverrideBindingClick(self._widget, false, self.bindLeftClick, self._widget:GetName(), "LeftButton")
    if self.kbLabel ~= false then
      self.keybind = Label:new{
        parent = self,
        text = formatKeybind(self.bindLeftClick),
        color = {0.8, 0.8, 0.8, 1},
        fontObj = keybindFont,
        position = {
          TopRight = {0, -2},
          Height = 7,
        },
      }
    end
  end

  -- hover texture
  if self.glow ~= false then
    self.border = Texture:new{
      parent = self,
      layer = ui.layer.Overlay,
      path = "interface/buttons/UI-ActionButton-Border",
      blendMode = "ADD",
      position = {
        All = true,
        Hide = true,
      },
      coords = {0.21, 0.77, 0.24, 0.79},
    }
  end

  -- cooldown
  if self.itemID then
    self.cooldown = Label:new{
      parent = self,
      position = {
        All = true,
        Hide = true,
      },
    }
  end
end, {
  type = "Button",
  scripts = {
    "OnEnter",
    "OnLeave",
    "OnMouseDown",
    "OnMouseUp",
    "OnReceiveDrag",
  },
})
ui.Button = Button

function Button:Text(text)
  if text ~= nil then
    self._widget:SetText(text)
  end
  return self._widget:GetText()
end

function Button:OnReceiveDrag()
  if not self.OnChange then return end
  local infoType, a, _, c, _ = GetCursorInfo()
  if "mount" == infoType and self.tooltip and self.tooltip.mountSpellId then
    self:OnChange(a) -- mountId
  elseif "spell" == infoType and self.tooltip and self.tooltip.spellId then
    self:OnChange(c) -- spellId
  elseif "item" == infoType and self.tooltip and self.tooltip.itemId then
    self:OnChange(a) -- itemId
  end
end

function Button:OnMouseDown()
  if self.border then self.border:SetVertexColor(0, 1, 0) end
end

function Button:OnMouseUp()
  if self.border then self.border:SetVertexColor(1, 1, 1) end

  if self.itemID then
    local start, duration, enable = GetItemCooldown(self.itemID)
    if enable == 1 and start > 0 then
      self.cooldownEnd = start + duration
      self._widget:GetNormalTexture():SetDesaturated(true)
      self.cooldown:Text(formatCooldown(duration))
      self.cooldown:Show()
      self:startUpdates()
    end
  end

  if self.OnClick then
    self:OnClick()
  end
end

function Button:OnEnter()
  if self.border then self.border:Show() end
  if self.tooltip then
    local gt = self.tooltip._widget
    if not gt then
      gt = GameTooltip
      if self.tooltip.owner then
        gt:SetOwner(unpack(self.tooltip.owner))
      else
        gt:SetOwner(self._widget, "ANCHOR_TOPRIGHT", -2, 0)
      end
      if self.tooltip.point then
        gt:SetPoint(unpack(self.tooltip.point))
      end
    end
    local td = self.tooltip
    if td.itemId then
      gt:SetOwnedItemByID(td.itemId)
    elseif td.toyId then
      gt:SetToyByItemID(td.toyId)
    elseif td.spellId then
      gt:SetSpellByID(td.spellId)
    elseif td.mountSpellId then
      gt:SetMountBySpellID(td.mountSpellId)
    end
    gt:Show()
  end
end

function Button:OnLeave()
  if self.border then self.border:Hide() end
  if self.tooltip then (self.tooltip._widget or GameTooltip):Hide() end
end

function Button:onUpdate(elapsed)
  local remaining = self.cooldownEnd - GetTime()
  if remaining < 0 then
    self:stopUpdates()
    self.cooldown:Hide()
    self._widget:GetNormalTexture():SetDesaturated(false)
    return
  end
  self.cooldown:Text(formatCooldown(remaining))
end
