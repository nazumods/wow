---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

local unpack = unpack
local Class = ns.lua.Class
local Region = ui.Region

-- https://github.com/Gethe/wow-ui-source/blob/5076663b5454de9e7522320994ea7cc15b2a961c/Interface/AddOns/Blizzard_FontStyles_Shared/SharedFontStyles.xml
-- https://github.com/Gethe/wow-ui-source/blob/5076663b5454de9e7522320994ea7cc15b2a961c/Interface/AddOns/Blizzard_FontStyles_Frame/Mainline/FontStyles.xml
---@type table<string,string>
ui.fonts = ns.lua.maps.toMap({
  "GameFontHighlight", "GameFontHighlightSmall",
  "SystemFont_Med2",
})

---@class Label: Region
local Label = Class(Region, function(self)
  if self.fontObj then self._widget:SetFontObject(self.fontObj) end
  -- fontInfo accepts a theme font slot name ("title", "header", "body") in
  -- place of a {path, size} tuple; an absent slot leaves the font unchanged
  if type(self.fontInfo) == "string" then self.fontInfo = self:Theme().fonts[self.fontInfo] end
  if self.fontInfo then
    self._widget:SetFont(unpack(self.fontInfo))
  elseif not self.fontObj and self.font == ui.fonts.GameFontHighlight and self:Theme().fonts.body then
    -- no explicit font given: a theme `body` font overrides the stock default
    self._widget:SetFont(unpack(self:Theme().fonts.body))
  end
  if self.text then self:Text(self.text) end
  if self.color then self:Color(self.color) end

  if self.justifyH then self._widget:SetJustifyH(self.justifyH) end
  if self.justifyV then self._widget:SetJustifyV(self.justifyV) end
  -- A width-constrained, non-wrapping FontString truncates with an ellipsis instead
  -- of flowing onto extra lines (e.g. long item names in a fixed-width list).
  if self.wordWrap == false then self._widget:SetWordWrap(false) end
end, {
  CreateWidget = function(self)
    return (self.parent._widget or self.parent):CreateFontString(self.name, self.layer, self.font)
  end,
  layer = ui.layer.Artwork,
  font = ui.fonts.GameFontHighlight,
})
ui.Label = Label

---@param text? string|number
---@return string|Label
function Label:Text(text)
  if not text then return self._widget:GetText() end
  self._widget:SetText(text)
  return self
end

-- {path, size[, flags]} tuple (matches the constructor `fontInfo` option). Getter
-- returns the current font as the same tuple.
---@param fontInfo table?
---@return table|Label
function Label:Font(fontInfo)
  if not fontInfo then return {self._widget:GetFont()} end
  self._widget:SetFont(unpack(fontInfo))
  return self
end

---@param justify string?
---@return string|Label
function Label:JustifyH(justify)
  if not justify then return self._widget:GetJustifyH() end
  self._widget:SetJustifyH(justify)
  return self
end

-- Natural (unwrapped) pixel width of the current text, ignoring any width
-- constraint on the FontString — useful for autosizing a column to its content.
---@return number
function Label:StringWidth() return self._widget:GetStringWidth() end

-- Set the text color: a theme token, a color table / ColorMixin, or channels.
---@param r string|table|number  theme color token, rgba table, ColorMixin, or red channel (0–1)
---@param g number?  green channel (0–1)
---@param b number?  blue channel (0–1)
---@param a number?  alpha channel (0–1)
---@return Label
function Label:Color(r, g, b, a)
  if type(r) == "string" then r = self:Theme().colors[r] end
  if type(r) == "table" then
    if r.GetRGBA then
      r, g, b, a = r:GetRGBA()
    else
      r, g, b, a = unpack(r)
    end
  end
  self._widget:SetTextColor(r, g, b, a)
  return self
end
