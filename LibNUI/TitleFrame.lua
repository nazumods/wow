local _, ns = ...
local ui = ns.ui

local Class, Frame, CleanFrame, Label, Texture = ns.lua.Class, ui.Frame, ui.CleanFrame, ui.Label, ui.Texture
local TopLeft, TopRight = ui.edge.TopLeft, ui.edge.TopRight
local Left, Right, Center = ui.edge.Left, ui.edge.Right, ui.edge.Center

local TitleFrame = Class(CleanFrame, function(o)
  local theme = o:Theme()
  -- title bar
  o.titlebar = Frame:new{
    parent = o,
    name = "$parentTitle",
    position = {
      TopLeft = {o, TopLeft},
      TopRight = {o, TopRight},
      Height = 30,
    },
    dragTarget = o._widget,
    background = "titlebar",
  }
  o.titlebar.title = Label:new{
    parent = o.titlebar,
    name = "$parentText",
    layer = "OVERLAY",
    font = ui.fonts.SystemFont_Med2,
    fontInfo = theme.fonts.title,
    position = {
      Left = {o.titlebar, 28, 0},
    },
    text = o.title,
    justifyH = Left,
    justifyV = "MIDDLE",
  }

  -- icon
  o.titlebar.icon = Frame:new{
    parent = o.titlebar,
    name = "$parentIcon",
    position = {
      Left = {6, 0},
      Size = {20, 20},
    },
  }
  o.titlebar.icon.icon = Texture:new{
    parent = o.titlebar.icon,
    layer = ui.layer.Artwork,
    path = theme.textures.titleIcon,
    coords = {0.1, 0.9, 0.1, 0.9},
    position = { All = true },
  }

  -- close button
  o.closeButton = Frame:new{
    type = "Button",
    parent = o.titlebar,
    name = "$parentCloseButton",
    position = {
      Width = 30,
      Height = 30,
      Right = {o.titlebar, Right, 0, 0},
    },
    background = {1, 1, 1, 0},
  }
  o.closeButton:SetScript("OnClick", function() o:Hide() end)
  o.closeButton:SetScript("OnEnter", function()
    o.closeButton.icon:SetVertexColor("iconHover")
    o.closeButton.background:Color("closeHover")
  end)
  o.closeButton:SetScript("OnLeave", function()
    o.closeButton.icon:SetVertexColor("icon")
    o.closeButton.background:Color(1, 1, 1, 0)
  end)
  o.closeButton.icon = Texture:new{
    parent = o.closeButton,
    layer = ui.layer.Artwork,
    name = "$parentIcon",
    position = {
      Center = {o.closeButton, Center},
    },
    path = theme.textures.closeIcon,
  }
  o.closeButton.icon:Size(10, 10)
  o.closeButton.icon:SetVertexColor("icon")
end, {
  drag = true,
})
ui.TitleFrame = TitleFrame

function TitleFrame:Title(text)
  self.titlebar.title:Text(text)
end
