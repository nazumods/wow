---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui

local Class, Frame, CleanFrame, Label, Texture = ns.lua.Class, ui.Frame, ui.CleanFrame, ui.Label, ui.Texture
local TopLeft, TopRight = ui.edge.TopLeft, ui.edge.TopRight
local Left, Right, Center = ui.edge.Left, ui.edge.Right, ui.edge.Center

---@class TitleBar: Frame
---@field title Label
---@field icon Frame

---@class TitleFrame: CleanFrame
---@field title string?  initial title text
---@field titlebar TitleBar  title strip across the top (carries `.title` Label and `.icon` Frame)
---@field closeButton Frame  close button in the title bar
---@field _posStore table?  DB-backed store for the remembered drag position (set by RememberPosition)
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
      Left = {o.titlebar, 33, 0},   -- clear the 20px title icon (ends at x=26) with a small gap
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

---@param text string
function TitleFrame:Title(text)
  self.titlebar.title:Text(text)
end

-- Persist this window's dragged position into `store` (typically a DB-backed
-- table, so the position survives /reload and relog — a fresh frame otherwise
-- re-centers, discarding wherever the user dragged it). Restores the saved point
-- now when `store` already holds one, then writes the point back whenever the
-- user finishes dragging. `store` is mutated in place: { point, relPoint, x, y }.
-- Anchors are relative to UIParent (top-level windows), so only the point names
-- and offsets are stored.
---@param store table  the table to read/write the remembered point into
---@return TitleFrame
function TitleFrame:RememberPosition(store)
  self._posStore = store
  if store.point then
    self:ClearAllPoints()
    self._widget:SetPoint(store.point, UIParent, store.relPoint, store.x, store.y)
  end
  local function save()
    local point, _, relPoint, x, y = self._widget:GetPoint(1)
    store.point, store.relPoint, store.x, store.y = point, relPoint, x, y
  end
  -- Two drag paths move the window (see Frame:makeContainerDraggable +
  -- setDragTarget): the body's OnDragStop and the title bar's OnMouseUp. Hook
  -- both so the point is saved no matter which the user grabbed.
  self._widget:HookScript("OnDragStop", save)
  self.titlebar._widget:HookScript("OnMouseUp", save)
  return self
end
