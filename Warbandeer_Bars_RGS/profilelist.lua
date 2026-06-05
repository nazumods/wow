local _, ns = ...
local ui = ns.ui

local LIST_W = 180
local PAD    = 8
local ROW_H  = 22

local function ClassColor(class)
  local c = class and C_ClassColor.GetClassColor(class)
  return c and ("|c" .. c:GenerateHexColorMarkup()) or ""
end

local function ProfileLabel(p)
  local prefix = p.autosave and "|cff888888[auto] |r" or ""
  return prefix .. ClassColor(p.class) .. (p.name or "?") .. "|r"
end

---Build a scrollable profile list inside `parent`.
---Returns: scroll frame, Refresh(), GetSelected() -> index
function ns.BuildProfileList(parent, onSelect)
  local scroll = ui.ScrollFrame:new{
    parent   = parent,
    position = {
      TopLeft     = { parent, ui.edge.TopLeft,     PAD,  -PAD },
      BottomRight = { parent, ui.edge.BottomRight, -PAD,  PAD },
    },
  }

  local content = ui.Frame:new{ parent = scroll }
  scroll:Child(content)

  local rows     = {}
  local selected = nil

  local function Refresh()
    for _, r in ipairs(rows) do r:Hide() end
    rows = {}
    local profiles = ns.db.profiles
    local y = 0
    for i, p in ipairs(profiles) do
      local btn = ui.Button:new{
        parent   = content,
        position = {
          TopLeft = { content, ui.edge.TopLeft, 0, -y },
          Width   = LIST_W - PAD * 2,
          Height  = ROW_H,
        },
        onClick = function()
          selected = i
          onSelect(i)
          Refresh()
        end,
      }
      ui.Label:new{
        parent   = btn,
        text     = (selected == i and "|cffffd100> |r" or "  ") .. ProfileLabel(p),
        position = { Left = { btn, ui.edge.Left, 4, 0 }, Top = {}, Bottom = {} },
      }
      rows[#rows+1] = btn
      y = y + ROW_H
    end
    content:Height(math.max(y, 1))
  end

  return scroll, Refresh, function() return selected end
end
