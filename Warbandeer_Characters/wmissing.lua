---@type Warbandeer_Characters
local ns = select(2, ...)
local ui = ns.ui
local insert = table.insert
local TitleFrame, ScrollFrame, EditBox = ui.TitleFrame, ui.ScrollFrame, ui.EditBox
local Button, Label, Tooltip = ui.Button, ui.Label, ui.Tooltip

local SCROLLBAR_W = 26
local PADDING     = 20
local MIN_W       = 200
local SIZES       = { 9, 10, 12, 14, 16, 18 }

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a), matching the
-- chevron used by Warbandeer's titlebar dropdowns.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:10:10|a"

-- Base font face/flags come from GameFontHighlightSmall; only the size is picked.
-- The chosen size persists account-wide in db.ui.wmissingFontSize (loaded when the
-- window is first built, since db isn't ready at file-load time).
local FONT_PATH, BASE_SIZE, FONT_FLAGS = GameFontHighlightSmall:GetFont()
local fontSize = math.floor(BASE_SIZE + 0.5)

local window    = nil
local measureFS = nil

local function lineHeight() return fontSize + 6 end

local function maxLineWidth(text)
  if not measureFS then
    measureFS = UIParent:CreateFontString(nil, "ARTWORK")
  end
  measureFS:SetFont(FONT_PATH, fontSize, FONT_FLAGS)
  local maxW = 0
  for line in text:gmatch("[^\n]+") do
    measureFS:SetText(line)
    local w = measureFS:GetStringWidth()
    if w > maxW then maxW = w end
  end
  return maxW
end

-- Re-measure and re-apply the cached report at the current font size.
local function relayout()
  local text, count = window._text, window._count
  local ebW     = math.max(maxLineWidth(text) + PADDING, MIN_W)
  local windowW = ebW + SCROLLBAR_W

  window:Width(windowW)
  window._eb:Font({ FONT_PATH, fontSize, FONT_FLAGS })
  window._eb:Width(ebW)
  window._eb:Height(math.max(count * lineHeight() + 10, 50))
  window._eb:Text(text)
end

-- Titlebar font-size picker: a labelled button dropping a menu of sizes.
-- Picking a size re-renders the report so the new size takes effect immediately.
local function createPicker(f)
  local btn = Button:new{
    parent   = f.titlebar,
    glow     = false,
    position = {
      Right  = { f.closeButton, ui.edge.Left, -4, 0 },
      Width  = 44,
      Height = 18,
    },
  }
  local label = Label:new{
    parent   = btn,
    position = { Center = {} },
    text     = "A " .. fontSize .. CHEVRON,
  }

  local menu
  local lines = {}
  for _, sz in ipairs(SIZES) do
    insert(lines, {
      text       = tostring(sz),
      background = { 0, 0, 0, 0 },
      onEnter    = function(line) line.background:Color(1, 1, 1, 0.2) end,
      onLeave    = function(line) line.background:Color(1, 1, 1, 0) end,
      onClick    = function()
        menu:Hide()
        if fontSize == sz then return end
        fontSize = sz
        ns.db.ui.wmissingFontSize = sz
        label:Text("A " .. sz .. CHEVRON)
        relayout()
      end,
    })
  end
  menu = Tooltip:new{
    position = {
      TopRight = { btn, ui.edge.BottomRight, 0, 2 },
      Width    = 44,
    },
    lines = lines,
  }
  btn.OnClick = function() menu:Toggle() end
end

local function createWindow()
  fontSize = ns.db.ui.wmissingFontSize or fontSize

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
  createPicker(f)
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

  window._text  = text
  window._count = count
  relayout()
  window._eb:HighlightText()
  window:Show()
end, "Show missing character data in a copyable window")
