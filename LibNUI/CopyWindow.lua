---@type LibNUI_AddOn
local ns = select(2, ...)
---@class LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local TitleFrame, ScrollFrame, EditBox = ui.TitleFrame, ui.ScrollFrame, ui.EditBox
local Button, Label, Tooltip = ui.Button, ui.Label, ui.Tooltip
local insert = table.insert

local SCROLLBAR_W = 26
local PADDING     = 20
local MIN_W       = 200
local MAX_W       = 1000
local SIZES       = { 9, 10, 12, 14, 16, 18 }

-- Inline down-arrow (atlas markup: |A:atlasName:height:width|a), matching the
-- chevron used by Warbandeer's titlebar dropdowns.
local CHEVRON = "  |A:UI-HUD-ActionBar-PageDownArrow-Disabled:10:10|a"

-- Base font face/flags come from GameFontHighlightSmall; only the size is picked.
-- The chosen size persists account-wide in LibNUI's db.copyFontSize.
local FONT_PATH, BASE_SIZE, FONT_FLAGS = GameFontHighlightSmall:GetFont()
local DEFAULT_SIZE = math.floor(BASE_SIZE + 0.5)

---@class LibNUI
---@field CopyWindow CopyWindow
---@field ShowCopyWindow fun(title: string, text: string)
---@field ToggleCopyWindow fun(title: string, text: string)

---A reusable, copyable scroll window for console-style text output: a windowed
---`TitleFrame` with a scrolling, pre-highlighted `EditBox` and a titlebar
---font-size picker.  Sized to its content and re-titled per `Display` call.  Most
---callers want the shared singleton `ui.ShowCopyWindow(title, text)` rather than
---building their own instance.
---@class CopyWindow: TitleFrame
---@field _eb EditBox       backing multi-line edit box
---@field _fontSize integer current picker font size
---@field _measureFS FontString  hidden string used to measure content width
---@field _text string      cached body text (re-applied on font change)
---@field _count integer     cached line count
---@field _title string      current titlebar text (so ToggleCopyWindow can match it)
local CopyWindow = Class(TitleFrame, function(self)
  self._fontSize = ns.db.copyFontSize or DEFAULT_SIZE

  local scroll = ScrollFrame:new{
    parent   = self,
    position = {
      TopLeft     = {self.titlebar, ui.edge.BottomLeft,  2,  -4},
      BottomRight = {self,          ui.edge.BottomRight, -2,   4},
    },
  }

  local eb = EditBox:new{
    parent    = scroll,
    multiline = true,
    template  = "",
    fontObj   = GameFontHighlightSmall,
    position  = {},
    OnEscapePressed = function() self:Hide() end,
  }
  scroll:Child(eb)

  self._eb = eb
  self:_createPicker()
end, {
  name     = "LibNUICopyWindow",
  title    = "",
  special  = true,
  level    = 600,
  position = { Center = {}, Height = 380 },
})
ui.CopyWindow = CopyWindow

function CopyWindow:_lineHeight() return self._fontSize + 6 end

function CopyWindow:_maxLineWidth(text)
  if not self._measureFS then
    self._measureFS = UIParent:CreateFontString(nil, "ARTWORK")
  end
  self._measureFS:SetFont(FONT_PATH, self._fontSize, FONT_FLAGS)
  local maxW = 0
  for line in text:gmatch("[^\n]+") do
    self._measureFS:SetText(line)
    local w = self._measureFS:GetStringWidth()
    if w > maxW then maxW = w end
  end
  return maxW
end

-- Re-measure and re-apply the cached text at the current font size.
function CopyWindow:_relayout()
  local text, count = self._text, self._count
  local ebW = math.min(math.max(self:_maxLineWidth(text) + PADDING, MIN_W), MAX_W)

  self:Width(ebW + SCROLLBAR_W)
  self._eb:Font({ FONT_PATH, self._fontSize, FONT_FLAGS })
  self._eb:Width(ebW)
  self._eb:Height(math.max(count * self:_lineHeight() + 10, 50))
  self._eb:Text(text)
end

-- Titlebar font-size picker: a labelled button dropping a menu of sizes.
-- Picking a size re-renders the text so the new size takes effect immediately.
function CopyWindow:_createPicker()
  local btn = Button:new{
    parent   = self.titlebar,
    glow     = false,
    position = {
      Right  = { self.closeButton, ui.edge.Left, -4, 0 },
      Width  = 44,
      Height = 18,
    },
  }
  local label = Label:new{
    parent   = btn,
    position = { Center = {} },
    text     = "A " .. self._fontSize .. CHEVRON,
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
        if self._fontSize == sz then return end
        self._fontSize = sz
        ns.db.copyFontSize = sz
        label:Text("A " .. sz .. CHEVRON)
        self:_relayout()
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
  -- The menu is parented to UIParent (so the titlebar/scroll frame can't clip it),
  -- so it won't hide with the window on its own — close it when the window hides
  -- (Escape or the close button), else it orphans on screen. Mirrors FilterDropdown.
  self:SetScript("OnHide", function() menu:Hide() end)
end

---Show `text` under `title`, sizing the window to the content and pre-selecting
---all text so it can be copied immediately.
---@param title string titlebar text
---@param text string body text (multi-line)
---@return CopyWindow
function CopyWindow:Display(title, text)
  local count = 1
  for _ in text:gmatch("\n") do count = count + 1 end

  self:Title(title)
  self._title = title
  self._text  = text
  self._count = count
  self:_relayout()
  self._eb:HighlightText()
  self:Show()
  return self
end

-- Shared singleton, built on first use (mirrors ui.tip / ui.ShowCharacterTooltip).
local shared

---Show arbitrary multi-line text in a shared, copyable scroll window — sized to
---the content and re-titled per call.  For any command that wants console-style
---output the user can actually copy/paste.
---@param title string
---@param text string
function ui.ShowCopyWindow(title, text)
  if not shared then shared = CopyWindow:new{} end
  shared:Display(title, text)
end

---Toggle the shared copy window for a given `title`: if it's already open showing
---that same title, close it; otherwise show `text` under it. Lets a slash command
---that re-runs act as an open/close toggle (matching the suite's window convention),
---while still switching content when a *different* title is requested.
---@param title string
---@param text string
function ui.ToggleCopyWindow(title, text)
  if shared and shared._widget:IsShown() and shared._title == title then
    shared:Hide()
    return
  end
  ui.ShowCopyWindow(title, text)
end
