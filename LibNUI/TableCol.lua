---@type LibNUI_AddOn
local ns = select(2, ...)
local ui = ns.ui
local Class, BgFrame, Frame = ns.lua.Class, ui.BgFrame, ui.Frame

---@class LibNUI
---@field TableCol TableCol

---@class TableCol: BgFrame
---@field header Frame   the header strip (a Frame so it can carry tooltip scripts); exposes `.label` / `.texture` / `.button` from its AutoWidget content for compatibility
---@field tooltip string|string[]? text (or list of lines) shown when hovering the header
---@field tooltipMaxWidth number? width cap (px) for the header tooltip (default 240)
local TableCol = Class(BgFrame, function(self)
  local p = self.padding or 0

  -- The header is its own Frame at the top of the col so it can carry mouse
  -- scripts (for tooltips). Putting OnEnter directly on the col frame would
  -- fire across the entire column, because cells without their own onEnter
  -- don't intercept mouse motion.
  self.header = Frame:new{
    parent = self,
    name = self.name and self.name.."Header" or nil,
    position = {
      TopLeft = {0, 0},
      TopRight = {0, 0},
      Height = self.headerHeight,
    },
  }

  local contentPosition
  if self.path or (self.atlas and self.atlasSize == false) then
    -- icons would otherwise stretch to fill the header rect (path has no
    -- atlas-size constraint; atlas with atlasSize=false explicitly disables
    -- native sizing). Pin them to a centered square at the top of the header.
    local size = self.headerHeight - 2 * p
    contentPosition = {
      Top = {self.iconOffsetX or 0, -p},
      Size = {size, size},
    }
  else
    contentPosition = {
      TopLeft = {p, -p},
      BottomRight = {-p, p},
    }
  end
  local content = ui.AutoWidget:new{
    parent = self.header,
    -- label
    label = self.label,
    font = self.font,
    fontInfo = not self.font and self:Theme().fonts.header or nil,
    color = self.color or "header",
    justifyH = self.justifyH or ui.justify.Center,
    justifyV = ui.justify.Middle,
    -- texture
    atlas = self.atlas,
    atlasSize = self.atlasSize,
    path = self.path,
    coords = self.coords,
    vertexColor = self.vertexColor,
    layer = (self.path or self.atlas) and ns.ui.layer.Artwork,
    position = contentPosition,
  }
  -- surface the inner widget so existing code (TableFrame:Autosize) that does
  -- `col.header.label` keeps working.
  self.header.label = content.label
  self.header.texture = content.texture
  self.header.button = content.button

  if self.tooltip then
    local lines = type(self.tooltip) == "table" and self.tooltip or {self.tooltip}
    local maxW = self.tooltipMaxWidth or 240
    self.header:SetScript("OnEnter", function()
      ui.tip:ClearLines()
      ui.tip:MaxWidth(maxW)
      for _,l in ipairs(lines) do ui.tip:AddLine(l) end
      ui.tip:ClearAllPoints()
      -- Top-right of the header: tooltip's BottomLeft sits at the header's
      -- TopRight, so it rises up and extends to the right.
      ui.tip:SetPoint(ui.edge.BottomLeft, self.header, ui.edge.TopRight, 2, 2)
      ui.tip:Show()
    end)
    self.header:SetScript("OnLeave", function()
      ui.tip:Hide()
      ui.tip:MaxWidth(nil)
    end)
  end
end)
ui.TableCol = TableCol
