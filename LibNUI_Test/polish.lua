local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- Tier 3 polish folds in one window: Slider caption + live formatted readout, Button
-- ConfirmFlash, a Label with a hover tooltip (hit-rect + Tooltip:Lines/AnchorBeside),
-- TableRow:Highlighted driven by a RadioGroup, and an autosized TabFrame.
---@return TitleFrame
local function makePolish()
  local f = window("Polish", 340, 420)

  local slider = LibNUI.Slider:new{
    parent = f,
    min = 0.5, max = 2.5, step = 0.05, value = 1,
    label = "Scale",
    valueFormat = function(v) return ("%.2f"):format(v) end,
    position = {
      TopLeft  = {f.titlebar, "BOTTOMLEFT", 16, -26},
      TopRight = {f.titlebar, "BOTTOMRIGHT", -16, -26},
      Height   = 14,
    },
  }

  local btn = LibNUI.Button:new{
    parent = f,
    position = { TopLeft = {slider, "BOTTOMLEFT", 0, -12}, Size = {110, 22} },
    glow = false,
    background = "backdrop",
  }
  btn:Text("Set Waypoint")
  btn._widget:SetScript("OnClick", function() btn:ConfirmFlash("Set!") end)

  LibNUI.Label:new{
    parent  = f,
    text    = "hover me for a tooltip",
    color   = "muted",
    tooltip = {"Runed Crest", "Earned from Bountiful Delves.", "Capped at 90 per week."},
    position = { Left = {btn, "RIGHT", 12, 0} },
  }

  -- three rows; the radio picks which is Highlighted
  local rows = {}
  for i = 1, 3 do
    rows[i] = LibNUI.TableRow:new{
      parent = f,
      label  = "Row " .. i,
      position = {
        TopLeft  = {i == 1 and btn or rows[i - 1], "BOTTOMLEFT", 0, i == 1 and -14 or -2},
        Size     = {180, 20},
      },
    }
  end

  LibNUI.RadioGroup:new{
    parent   = f,
    header   = "Highlighted row",
    selected = 1,
    options  = { {key = 1, label = "Row 1"}, {key = 2, label = "Row 2"}, {key = 3, label = "Row 3"} },
    position = { TopLeft = {rows[1], "TOPRIGHT", 16, 14} },
    onSelect = function(_, key)
      for i, row in ipairs(rows) do row:Highlighted(i == key) end
    end,
  }
  rows[1]:Highlighted(true)

  -- fixed offset: below BOTH columns (the radio column is taller than the row stack,
  -- so anchoring off rows[3] would run the tabs into it)
  LibNUI.TabFrame:new{
    parent   = f,
    tabs     = {"New", "A Much Longer Tab", "OK"},
    autosize = true,
    position = {
      TopLeft     = {f, "TOPLEFT", 16, -246},
      BottomRight = {f, "BOTTOMRIGHT", -16, 12},
    },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "polish",
  name = "Tier 3 Polish",
  desc = "Slider caption/readout, ConfirmFlash, Label tooltip, row highlight, autosized tabs",
  run  = toggling(makePolish),
})
