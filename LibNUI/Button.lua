---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class, unpack = ns.lua.Class, unpack
local Frame, Texture = ui.Frame, ui.Texture

-- https://wowpedia.fandom.com/wiki/UIOBJECT_Button
---@class Button: Frame
---@field _widget table
---@field border table  the hover-glow texture, absent when `glow = false`
---@field glow boolean?  false removes the hover glow entirely
---@field glowAlpha number?  hover-glow opacity 0–1 (default 1) — soften it without removing it
---@field OnClick function
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
    -- "AnyDown"+"AnyUp" are both registered, so this script fires twice per click;
    -- run the handler once, on release, matching the OnMouseUp/OnClick hook path.
    self._widget:SetScript("OnClick", function(_, _, down)
      if not down then self:onClick() end
    end)
  end
  self._widget:RegisterForClicks("AnyDown", "AnyUp")

  -- hover texture
  --
  -- `glowAlpha` softens it without turning it off. It was all-or-nothing before: the texture was
  -- created with no colour set, so it rendered at full strength, and a caller who found that too
  -- strong against a dark row had only `glow = false` — which reads as disabled. Default 1 keeps
  -- every existing button pixel-identical.
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
    if self.glowAlpha then self.border:Alpha(self.glowAlpha) end
  end
end, {
  type = "Button",
  scripts = {
    "OnEnter",
    "OnLeave",
    "OnMouseDown",
    "OnMouseUp",
  },
})
ui.Button = Button

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

function Button:OnMouseDown()
  if self.border then self.border:SetVertexColor(0, 1, 0) end
end

function Button:OnMouseUp()
  if self.border then self.border:SetVertexColor(1, 1, 1) end

  if self.OnClick then
    self:OnClick()
  end
end

function Button:OnEnter()
  if self.border then self.border:Show() end
end

function Button:OnLeave()
  if self.border then self.border:Hide() end
end
