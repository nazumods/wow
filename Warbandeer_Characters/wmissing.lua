local _, ns = ...
local ui = ns.ui
local TitleFrame, ScrollFrame, EditBox = ui.TitleFrame, ui.ScrollFrame, ui.EditBox

local WINDOW_W = 440
local EB_W     = WINDOW_W - 26   -- leave room for the scrollbar
local LINE_H   = 16               -- approx line height for GameFontHighlightSmall

local window = nil

local function createWindow()
  local f = TitleFrame:new{
    name     = "WarbandeerMissingWindow",
    title    = "Missing Data",
    special  = true,
    level    = 600,
    position = {
      Center = {},
      Width  = WINDOW_W,
      Height = 380,
    },
  }

  local scroll = ScrollFrame:new{
    parent   = f,
    position = {
      TopLeft     = {f.titlebar, ui.edge.BottomLeft,  2,  -4},
      BottomRight = {f,          ui.edge.BottomRight, -2,   4},
    },
  }

  local eb = EditBox:new{
    parent    = scroll,
    multiline = true,
    template  = "",
    fontObj   = GameFontHighlightSmall,
    position  = { Width = EB_W },
    OnEscapePressed = function() f:Hide() end,
  }
  scroll:Child(eb)

  f._eb = eb
  return f
end

ns:registerCommand("wmissing", "", function(self)
  if not window then
    window = createWindow()
  end
  local missing = self:getMissingReport()
  local text, count
  if #missing == 0 then
    text, count = "All characters have complete data.", 1
  else
    local lines = { #missing .. " characters missing data:" }
    for _, line in ipairs(missing) do
      table.insert(lines, line)
    end
    text  = table.concat(lines, "\n")
    count = #lines
  end
  window._eb:Height(math.max(count * LINE_H + 10, 50))
  window._eb:Text(text)
  window._eb:CursorPosition(0)
  window:Show()
end, "Show missing character data in a copyable window")
