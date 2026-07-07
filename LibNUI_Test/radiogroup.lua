local RadioGroup = LibNUI.RadioGroup
local Label      = LibNUI.Label
local toggling   = LibNUITest.toggling
local window     = LibNUITest.window

-- A single-select radio group wired to a readout: proves clicking one row clears the
-- others, re-clicking the selected row keeps it selected, and onSelect fires on change.
---@return TitleFrame
local function makeRadioGroup()
  local f = window("RadioGroup", 240, 220)

  local readout = Label:new{
    parent   = f,
    position = { Bottom = {f, "BOTTOM", 0, 14} },
    text     = "selected: gold",
  }

  RadioGroup:new{
    parent   = f,
    header   = "Accent colour",
    selected = "gold",
    options  = {
      { key = "gold",   label = "Gold"   },
      { key = "purple", label = "Purple" },
      { key = "green",  label = "Green"  },
    },
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 12, -8} },
    onSelect = function(_, key) readout:Text("selected: " .. key) end,
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "radiogroup",
  name = "RadioGroup",
  desc = "Single-select radio group with an onSelect readout",
  run  = toggling(makeRadioGroup),
})
