---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Button, Tooltip = ui.Frame, ui.Label, ui.Button, ui.Tooltip
local Colors = ns.Colors
local insert = table.insert
local D = ns.detail

local DetailView = ns.views.DetailView

local function sortedCharacters()
  local toons = {}
  for _, t in ipairs(ns.api.GetAllCharacters()) do insert(toons, t) end
  table.sort(toons, function(a, b) return a.name < b.name end)
  return toons
end

-- Titlebar character picker (shown only while the Detail view is active).
---@param parent Frame
---@return Frame
function DetailView:BuildFilter(parent)
  local box = Frame:new{ parent = parent, position = { Height = 20, Width = 130 } }

  box.button = Button:new{
    parent   = box,
    position = { All = true },
    glow     = false,
    OnClick  = function() box.menu:Toggle() end,
  }
  box.label = Label:new{
    parent   = box.button,
    position = { Center = {} },
    text     = self._char.name .. D.CHEVRON,
  }

  local lines = {}
  for _, toon in ipairs(sortedCharacters()) do
    local c = Colors[toon.classKey] or { 1, 1, 1 }
    insert(lines, {
      text       = toon.name,
      color      = c,
      background = { 0, 0, 0, 0 },
      onEnter    = function(line) line.background:Color(1, 1, 1, 0.2) end,
      onLeave    = function(line) line.background:Color(1, 1, 1, 0) end,
      onClick    = function()
        box.menu:Hide()
        self:Select(toon)
      end,
    })
  end
  box.menu = Tooltip:new{
    position = {
      TopRight = { box, ui.edge.BottomRight, 0, 2 },
      Width    = 130,
    },
    -- The warband can hold many characters; cap the menu height and scroll.
    maxHeight = 320,
    lines     = lines,
  }

  self._filter = box
  return box
end
