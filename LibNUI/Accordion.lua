---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local Frame, Label, VirtualList = ui.Frame, ui.Label, ui.VirtualList

-- Collapsible sections built on VirtualList: each section is a clickable header row
-- (accent caret + title) whose child rows appear only while expanded. Toggling a header
-- rebuilds the underlying list, so headers and child rows share one pooled, scrolling
-- viewport. The consumer supplies the child-row builders (createRow/updateRow); the header
-- rows are built in.
---@class AccordionSection
---@field key any        stable identity used for expansion state + callbacks
---@field title string   header text
---@field rows any[]?     child-row data emitted while expanded
---@field expanded boolean?  initially expanded

---@class Accordion: Frame
---@field sections AccordionSection[]?  initial sections
---@field spacing number      row gap passed to the VirtualList (default 2)
---@field padding number      inset passed to the VirtualList (default 4)
---@field headerHeight number  header row height in px (default 24)
---@field rowHeight number    fallback child-row height (default 20)
---@field headerColor string|table  caret + title colour (default "header")
---@field scrollbar boolean   themed scrollbar (default true)
---@field createRow fun(acc: Accordion): Frame  build one blank pooled child row (parent to acc:Content())
---@field updateRow fun(acc: Accordion, row: Frame, rowData: any, section: AccordionSection): number?  populate; return height
---@field onToggle fun(acc: Accordion, key: any, expanded: boolean)?  fired when a header toggles
---@field list VirtualList
---@field _expanded table<any, boolean>
local Accordion = Class(Frame, function(self)
  self._expanded = {}
  if self.sections then
    for _, s in ipairs(self.sections) do
      if s.expanded then self._expanded[s.key] = true end
    end
  end

  self.list = VirtualList:new{
    parent    = self,
    position  = { All = true },
    spacing   = self.spacing,
    padding   = self.padding,
    rowHeight = self.rowHeight,
    scrollbar = self.scrollbar,
    typeOf    = function(item) return item.kind end,
    rowTypes  = {
      header = {
        create = function(list) return self:_createHeader(list) end,
        update = function(_, row, item) return self:_updateHeader(row, item.section) end,
      },
      row = {
        create = function() return self.createRow(self) end,
        update = function(_, row, item) return self.updateRow(self, row, item.data, item.section) end,
      },
    },
  }

  if self.sections then self:SetSections(self.sections) end
end, {
  type         = "Frame",
  spacing      = 2,
  padding      = 4,
  headerHeight = 24,
  rowHeight    = 20,
  headerColor  = "header",
  scrollbar    = true,
})
ui.Accordion = Accordion

-- The content child rows parent to (delegates to the inner VirtualList).
---@return Frame
function Accordion:Content() return self.list:Content() end

-- Build a header row: a full-width clickable strip with an accent caret + title and a
-- faint hover highlight; the click toggles the section it currently renders.
---@param list VirtualList
---@return Frame
function Accordion:_createHeader(list)
  local row = Frame:new{
    type       = "Button",
    parent     = list:Content(),
    background = {1, 1, 1, 0},
  }
  row.caret = Label:new{
    parent = row, color = self.headerColor, text = ">",
    position = { Left = {row, 6, 0} },
  }
  row.title = Label:new{
    parent = row, color = self.headerColor, justifyH = ui.justify.Left,
    position = { Left = {row, 20, 0} },
  }
  row:SetScript("OnClick", function() if row._key ~= nil then self:Toggle(row._key) end end)
  row:SetScript("OnEnter", function() row.background:Color(1, 1, 1, 0.08) end)
  row:SetScript("OnLeave", function() row.background:Color(1, 1, 1, 0) end)
  return row
end

---@param row Frame
---@param section AccordionSection
---@return number
function Accordion:_updateHeader(row, section)
  row._key = section.key
  row.caret:Text(self._expanded[section.key] and "v" or ">")
  row.title:Text(section.title)
  return self.headerHeight
end

-- Flatten sections into a header item + (when expanded) its child-row items, and hand the
-- list to the VirtualList.
function Accordion:_rebuild()
  local items = {}
  for _, section in ipairs(self.sections) do
    items[#items + 1] = { kind = "header", section = section }
    if self._expanded[section.key] then
      for _, data in ipairs(section.rows or {}) do
        items[#items + 1] = { kind = "row", data = data, section = section }
      end
    end
  end
  self.list:SetItems(items)
end

-- Replace the section set and re-render (preserving any expansion state by key).
---@param sections AccordionSection[]
---@return Accordion
function Accordion:SetSections(sections)
  self.sections = sections
  self:_rebuild()
  return self
end

---@param key any
---@return boolean
function Accordion:IsExpanded(key) return self._expanded[key] and true or false end

-- Flip a section's expansion, re-render, and fire onToggle.
---@param key any
---@return Accordion
function Accordion:Toggle(key)
  self._expanded[key] = not self._expanded[key]
  self:_rebuild()
  if self.onToggle then self:onToggle(key, self._expanded[key] or false) end
  return self
end

---@param key any
---@return Accordion
function Accordion:Expand(key)
  if not self._expanded[key] then self:Toggle(key) end
  return self
end

---@param key any
---@return Accordion
function Accordion:Collapse(key)
  if self._expanded[key] then self:Toggle(key) end
  return self
end
