local _, ns = ...
local ui = ns.ui
local TitleFrame, ScrollFrame = ui.TitleFrame, ui.ScrollFrame

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

  local eb = CreateFrame("EditBox", nil, scroll._widget)
  eb:SetMultiLine(true)
  eb:SetFontObject(GameFontHighlightSmall)
  eb:SetWidth(EB_W)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEscapePressed", function() f:Hide() end)
  scroll:Child(eb)

  f._eb = eb
  return f
end

local function buildContent(db)
  local missing = {}
  for name, toon in pairs(db.characters) do
    local issues = ns.getMissingFields(toon)
    if #issues > 0 then
      table.insert(missing, name .. " - missing " .. table.concat(issues, ", "))
    end
  end

  if #missing == 0 then
    return "All characters have complete data.", 1
  end

  table.sort(missing)
  local lines = { #missing .. " characters missing data:" }
  for _, line in ipairs(missing) do
    table.insert(lines, line)
  end
  return table.concat(lines, "\n"), #lines
end

ns:registerCommand("wmissing", "", function(self)
  if not window then
    window = createWindow()
  end
  local text, count = buildContent(self.db)
  window._eb:SetHeight(math.max(count * LINE_H + 10, 50))
  window._eb:SetText(text)
  window._eb:SetCursorPosition(0)
  window:Show()
end, "Show missing character data in a copyable window")
