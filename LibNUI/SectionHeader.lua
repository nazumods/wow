---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture

-- A titled section separator: an accent-coloured heading with a 1px divider rule
-- underneath, plus an optional right-aligned summary/status slot on the heading row.
-- The single most-repeated construct when laying out stacked panels. Anchor it with a
-- fixed width (Left+Right to the parent, or a Width) so the rule and the right-aligned
-- summary have an edge to reach; it sizes its own height from the heading.
---@class SectionHeader: Frame
---@field text string             heading text
---@field summary string?         optional right-aligned secondary text (muted)
---@field titleColor string|table heading colour token or rgba (default "header")
---@field dividerColor string|table  rule colour token or rgba (default "divider")
---@field fontInfo table?         {path, size[, flags]} heading font override
---@field underline boolean       draw the 1px rule (default true)
---@field gap number              px between the heading and the rule (default 5)
---@field title Label
---@field summaryLabel Label?
---@field rule Texture?
local SectionHeader = Class(Frame, function(self)
  self.title = Label:new{
    parent   = self,
    text     = self.text,
    color    = self.titleColor,
    fontInfo = self.fontInfo,
    justifyH = ui.justify.Left,
    position = { TopLeft = {self, ui.edge.TopLeft, 0, 0} },
  }

  if self.summary then
    self.summaryLabel = Label:new{
      parent   = self,
      text     = self.summary,
      color    = "muted",
      justifyH = ui.justify.Right,
      position = { TopRight = {self, ui.edge.TopRight, 0, 0} },
    }
  end

  local titleH = self.title:Height()
  if not titleH or titleH < 1 then titleH = 14 end   -- FontString height before layout

  if self.underline then
    self.rule = Texture:new{
      parent   = self,
      layer    = ui.layer.Artwork,
      color    = self.dividerColor,
      position = {
        TopLeft  = {self, ui.edge.TopLeft,  0, -(titleH + self.gap)},
        TopRight = {self, ui.edge.TopRight, 0, -(titleH + self.gap)},
        Height   = 1,
      },
    }
  end

  self:Height(titleH + (self.underline and (self.gap + 1) or 0))
end, {
  type         = "Frame",
  titleColor   = "header",
  dividerColor = "header",   -- accent rule, tied to the heading; the faint "divider" token is a table-footer line
  underline    = true,
  gap          = 5,
})
ui.SectionHeader = SectionHeader

-- Get/set the heading text.
---@param v string?
---@return string|SectionHeader
function SectionHeader:Text(v)
  if v == nil then return self.title:Text() end
  self.title:Text(v)
  return self
end

-- Get/set the right-aligned summary text (only when a summary was configured at build).
---@param v string?
---@return string|SectionHeader|nil
function SectionHeader:Summary(v)
  if not self.summaryLabel then return end
  if v == nil then return self.summaryLabel:Text() end
  self.summaryLabel:Text(v)
  return self
end
