---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, unpack = ns.lua.Class, unpack
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local GameTooltip, SetOverrideBindingClick = GameTooltip, SetOverrideBindingClick
local GetTime = GetTime
local GetCursorInfo = GetCursorInfo
local canaccessvalue = canaccessvalue -- retail-only (nil elsewhere → every value readable)

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
    return m..':'..string.format("%02d", math.floor(t - m * 60))
  end
  return math.ceil(t)..'s'
end

-- https://wowpedia.fandom.com/wiki/UIOBJECT_Button
---@class Button: Frame
---@field _widget table
---@field border table
---@field cooldown table
---@field itemID number
---@field spellID number
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
    -- "AnyDown"+"AnyUp" are both registered (keybind clicks need both regardless
    -- of the ActionButtonUseKeyDown cvar), so this script fires twice per click;
    -- run the handler once, on release, matching the OnMouseUp/OnClick hook path.
    self._widget:SetScript("OnClick", function(_, _, down)
      if not down then self:onClick() end
    end)
  end
  self._widget:RegisterForClicks("AnyDown", "AnyUp")

  -- https://wowpedia.fandom.com/wiki/Creating_key_bindings
  if self.bindLeftClick then
    SetOverrideBindingClick(self._widget, false, self.bindLeftClick, self._widget:GetName(), "LeftButton")
    if self.kbLabel ~= false then
      self.keybind = Label:new{
        parent = self,
        text = formatKeybind(self.bindLeftClick),
        color = "muted",
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

  -- The cooldown Label is created lazily (see Button:ensureCooldown): a
  -- SecureButton assigns spellID/itemID in its own constructor, which runs AFTER
  -- this parent Button constructor, so they aren't set here for secure spell/toy
  -- buttons — creating it here would skip them and crash on their first cooldown.
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

-- Lazily create the cooldown Label on first use. Not created in the constructor
-- because SecureButton assigns spellID/itemID after the parent Button constructor
-- has already run (see the note there).
function Button:ensureCooldown()
  if not self.cooldown then
    self.cooldown = Label:new{
      parent = self,
      position = {
        All = true,
        Hide = true,
      },
    }
  end
end

-- Getter/setter for the button text. Unlike the standard pattern, the set
-- path also returns the (new) text rather than self.
---@param text string?
---@return string
function Button:Text(text)
  if text ~= nil then
    -- a template-less Button has no font: SetText would render nothing
    if not self._widget:GetFontString() then
      self._widget:SetNormalFontObject("GameFontHighlight")
    end
    self._widget:SetText(text)
  end
  return self._widget:GetText()
end

---@param h string  "LEFT", "CENTER", or "RIGHT"
function Button:TextAlign(h)
  local fs = self._widget:GetFontString()
  if fs then fs:SetJustifyH(h) end
end

-- Transient action feedback: swap the button text to a confirmation string, then restore
-- the original after `ms`. Re-flashing while a flash is pending keeps the original
-- captured by the first flash, so rapid clicks can't bake the confirm text in.
---@param text string?  confirmation text (default "Done!")
---@param ms number?    restore delay in milliseconds (default 1500)
---@return Button
function Button:ConfirmFlash(text, ms)
  if self._flashOriginal == nil then self._flashOriginal = self:Text() end
  self._widget:SetText(text or "Done!")
  self:delay(ms or 1500, function()
    if self._flashOriginal ~= nil then
      self._widget:SetText(self._flashOriginal)
      self._flashOriginal = nil
    end
  end)
  return self
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

  if self.spellID then
    local cd = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(self.spellID)
    local start, duration = cd and cd.startTime, cd and cd.duration
    -- GetSpellCooldown is SecretWhenCooldownsRestricted: startTime/duration can be "secret"
    -- values that raise 'arithmetic on a secret value' when compared/added from tainted addon
    -- code — and a SecureButton clicked in combat is the primary consumer. Treat a secret
    -- reading as "no cooldown shown" (canaccessvalue is retail-only; nil elsewhere → readable).
    if cd and canaccessvalue and (not canaccessvalue(start) or not canaccessvalue(duration)) then
      start, duration = nil, nil
    end
    if start and duration and start > 0 then
      self:ensureCooldown()
      self.cooldownEnd = start + duration
      self._widget:GetNormalTexture():SetDesaturated(true)
      self.cooldown:Text(formatCooldown(duration))
      self.cooldown:Show()
      self:startUpdates()
    end
  elseif self.itemID then
    local start, duration, enable = C_Item.GetItemCooldown(self.itemID)
    if enable and start > 0 then
      self:ensureCooldown()
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

---@param elapsed number  milliseconds since the last update
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
