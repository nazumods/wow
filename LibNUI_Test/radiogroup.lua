local RadioGroup = LibNUI.RadioGroup
local Label      = LibNUI.Label
local toggling   = LibNUITest.toggling
local window     = LibNUITest.window

-- A single-select radio group wired to a readout + fire counter: proves clicking one row
-- clears the others, re-clicking the selected row keeps it selected WITHOUT re-firing
-- onSelect (the counter freezes), and onSelect fires once per genuine change.
---@return TitleFrame
local function makeRadioGroup()
  local f = window("RadioGroup", 240, 220)

  -- The fire counter is the point: a redundant re-fire would rewrite the readout to the
  -- same key and read identically to not firing, so count fires to make the guard visible.
  local fires = 0
  local readout = Label:new{
    parent   = f,
    position = { Bottom = {f, "BOTTOM", 0, 14} },
    text     = "selected: gold  ·  onSelect fired 0x",
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
    onSelect = function(_, key)
      fires = fires + 1
      readout:Text(("selected: %s  ·  onSelect fired %dx"):format(key, fires))
    end,
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "radiogroup",
  name = "RadioGroup",
  desc = "Single-select radio group with an onSelect readout",
  run  = toggling(makeRadioGroup),
})
