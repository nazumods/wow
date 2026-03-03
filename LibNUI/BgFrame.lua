local _, ns = ...

local ui = ns.ui
local Class = ns.lua.Class
local Frame, Texture = ui.Frame, ui.Texture

-- frame with a background
local BgFrame = Class(Frame, function(self)
  self.backdrop = Texture:new{
    parent = self,
    layer = ui.layer.Overlay,
    position = { All = true },
    color = self.backdrop and self.backdrop.color or {0, 0, 0, 0.8},
  }
end)
ui.BgFrame = BgFrame

function BgFrame:backdropColor(...) self.backdrop:Color(...); return self end
function BgFrame:backdropTexture(...) self.backdrop:Texture(...); return self end
