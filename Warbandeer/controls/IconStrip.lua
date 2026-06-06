local _, ns = ...
local ui = ns.ui
local Class, Frame, Texture = ns.lua.Class, ui.Frame, ui.Texture
local CleanFrame = ui.CleanFrame
local theme = ns.theme

-- Floating navigation rail (Aetheric Glass) docked to the left of the main window.
-- One tinted glyph per view (in display order); replaces the old titlebar-icon
-- dropdown selector. Icons are white TGAs (icons/views/<name>.tga) tinted per state:
-- muted at rest, on-surface on hover, gold + left accent + faint gold wash when
-- active. Hovering shows the view title in `ui.tip` to the right. Clicking fires
-- `onSelect(name)`.

local ICON_PATH = "Interface\\AddOns\\Warbandeer\\icons\\views\\"

local ACTIVE_BG = {1, 0.82, 0, 0.10} -- faint gold wash behind the active icon

---@class IconStrip: CleanFrame
---@field views    table[]                 list of `{ name, title }` in display order
---@field onSelect fun(name: string)?      fired with the view name when an icon is clicked
---@field width    number                  rail width
---@field iconSize number                  glyph size
---@field cellSize number                  per-icon hit-area height
---@field pad      number                  top/bottom padding
---@field gap      number                  vertical gap between icons
---@field logo     Texture                 brand mark at the top
---@field _buttons table<string, Frame>    name -> icon button frame
---@field _active  string?                 currently highlighted view name
local IconStrip = Class(CleanFrame, function(self)
  local c = theme.colors
  local W, ICON, CELL, PAD, GAP = self.width, self.iconSize, self.cellSize, self.pad, self.gap

  -- brand mark
  self.logo = Texture:new{
    parent = self,
    layer = ui.layer.Artwork,
    path = ICON_PATH .. "logo.tga",
    position = { Top = {self, ui.edge.Top, 0, -PAD}, Size = {ICON + 4, ICON + 4} },
  }
  self.logo:SetVertexColor(c.gold)

  -- divider under the brand mark
  local divY = PAD + ICON + 4 + PAD
  self.divider = Texture:new{
    parent = self,
    layer = ui.layer.Artwork,
    position = { Top = {self, ui.edge.Top, 0, -divY}, Size = {W - 12, 1} },
  }
  self.divider:Color(c.divider)

  self._buttons = {}
  local y = divY + GAP
  for _, v in ipairs(self.views) do
    local btn = Frame:new{
      type = "Button",
      parent = self,
      position = { Top = {self, ui.edge.Top, 0, -y}, Width = W - 8, Height = CELL },
      background = {0, 0, 0, 0},
    }
    btn._widget:SetMouseMotionEnabled(true)
    btn._widget:SetMouseClickEnabled(true)

    -- left accent bar (only visible while active)
    btn.accent = Texture:new{
      parent = btn,
      layer = ui.layer.Overlay,
      position = { Left = {btn, ui.edge.Left, -2, 0}, Size = {2, CELL - 8} },
    }
    btn.accent:Color(0, 0, 0, 0)

    btn.icon = Texture:new{
      parent = btn,
      layer = ui.layer.Artwork,
      path = ICON_PATH .. v.name .. ".tga",
      position = { Center = {}, Size = {ICON, ICON} },
    }
    btn.icon:SetVertexColor(c.muted)

    local name, title = v.name, v.title
    btn:SetScript("OnEnter", function()
      if self._active ~= name then
        btn.background:Color(c.moduleHi)
        btn.icon:SetVertexColor(c.text)
      end
      ui.tip:AnchorTo(btn, "ANCHOR_RIGHT", 8, 0)
      ui.tip:ClearLines()
      ui.tip:AddLine(title)
      ui.tip:Show()
    end)
    btn:SetScript("OnLeave", function()
      if self._active ~= name then
        btn.background:Color(0, 0, 0, 0)
        btn.icon:SetVertexColor(c.muted)
      end
      ui.tip:Hide()
    end)
    btn:SetScript("OnMouseUp", function()
      if self.onSelect then self.onSelect(name) end
    end)

    self._buttons[name] = btn
    y = y + CELL + GAP
  end

  self:Width(W)
  self:Height(y - GAP + PAD)
end, {
  width = 46,
  iconSize = 22,
  cellSize = 30,
  pad = 10,
  gap = 4,
  -- anchored to the (already clamped) window; don't clamp independently or the rail
  -- detaches from the window near the screen edge.
  clamped = false,
  background = {0.11372549019, 0.14117647058, 0.16470588235, 0.92},
})
ns.IconStrip = IconStrip

-- Highlight the icon for `name` (gold + accent + faint wash) and reset the rest.
---@param name string
---@return IconStrip
function IconStrip:SetActive(name)
  local c = theme.colors
  self._active = name
  for n, btn in pairs(self._buttons) do
    if n == name then
      btn.background:Color(ACTIVE_BG)
      btn.icon:SetVertexColor(c.gold)
      btn.accent:Color(c.gold)
    else
      btn.background:Color(0, 0, 0, 0)
      btn.icon:SetVertexColor(c.muted)
      btn.accent:Color(0, 0, 0, 0)
    end
  end
  return self
end
