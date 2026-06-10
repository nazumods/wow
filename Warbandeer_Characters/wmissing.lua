---@type Warbandeer_Characters
local ns = select(2, ...)
local ui = ns.ui
local TitleFrame, ScrollFrame, EditBox = ui.TitleFrame, ui.ScrollFrame, ui.EditBox

local SCROLLBAR_W = 26
local LINE_H      = 16
local PADDING     = 20
local MIN_W       = 200

local window    = nil
local measureFS = nil

local function maxLineWidth(text)
  if not measureFS then
    measureFS = UIParent:CreateFontString(nil, "ARTWORK")
    measureFS:SetFontObject(GameFontHighlightSmall)
  end
  local maxW = 0
  for line in text:gmatch("[^\n]+") do
    measureFS:SetText(line)
    local w = measureFS:GetStringWidth()
    if w > maxW then maxW = w end
  end
  return maxW
end

local function createWindow()
  local f = TitleFrame:new{
    name     = "WarbandeerMissingWindow",
    title    = "Missing Data",
    special  = true,
    level    = 600,
    position = { Center = {}, Height = 380 },
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
    position  = {},
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

  local ebW     = math.max(maxLineWidth(text) + PADDING, MIN_W)
  local windowW = ebW + SCROLLBAR_W

  window:Width(windowW)
  window._eb:Width(ebW)
  window._eb:Height(math.max(count * LINE_H + 10, 50))
  window._eb:Text(text)
  window._eb:HighlightText()
  window:Show()
end, "Show missing character data in a copyable window")
