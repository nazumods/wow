---@type LibNUI_AddOn
local ns = select(2, ...)

local ui = ns.ui
local Class = ns.lua.Class
local Frame, Texture = ui.Frame, ui.Texture

-- frame with a background
---@class BgFrame: Frame
---@field backdrop Texture  background texture; pass {color = ...} at construction to override the "backdrop" theme token
local BgFrame = Class(Frame, function(self)
  self.backdrop = Texture:new{
    parent = self,
    layer = ui.layer.Overlay,
    position = { All = true },
    color = self.backdrop and self.backdrop.color or "backdrop",
  }
end)
ui.BgFrame = BgFrame

---@param ... any  Texture:Color args (theme token, rgba table, or channels)
---@return BgFrame
function BgFrame:backdropColor(...) self.backdrop:Color(...); return self end
---@param ... any  Texture:Texture args (path or fileID)
---@return BgFrame
function BgFrame:backdropTexture(...) self.backdrop:Texture(...); return self end
