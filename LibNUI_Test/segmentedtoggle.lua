local SegmentedToggle = LibNUI.SegmentedToggle
local Button          = LibNUI.Button
local Label           = LibNUI.Label
local toggling        = LibNUITest.toggling
local window          = LibNUITest.window

-- Three segmented toggles and a readout, covering what the widget claims:
--
-- * the two-segment case the Collected window uses — one lit, clicking the other moves the rim;
-- * `Select(nil)` from outside, which must leave NO segment lit (the reason this isn't a RadioGroup);
-- * captions of very different lengths, proving every segment takes the widest one's width and
--   nothing ellipsizes — the defect that sent this widget to the library in the first place;
-- * a five-segment row, since nothing about the control is two-sided.
---@return TitleFrame
local function makeSegmentedToggle()
  local f = window("SegmentedToggle", 380, 250)

  local readout = Label:new{
    parent   = f,
    position = { Bottom = {f, "BOTTOM", 0, 14} },
    text     = "picked: armor",
  }

  local modes = SegmentedToggle:new{
    parent   = f,
    height   = 20,
    selected = "armor",
    options  = { { key = "armor", label = "Armor" }, { key = "weapons", label = "Weapons" } },
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 12, -12} },
    onSelect = function(_, key) readout:Text("picked: " .. key) end,
  }

  -- Nothing lit is a state a host can ask for, not just an initial one.
  Button:new{
    parent   = f,
    position = { TopLeft = {modes, "TOPRIGHT", 12, 0}, Width = 120, Height = 20 },
    OnClick  = function()
      -- Written out rather than as `x and nil or y`, which can never yield nil.
      if modes:Selected() then modes:Select(nil) else modes:Select("armor") end
      readout:Text("picked: " .. tostring(modes:Selected()))
    end,
  }:Text("Select(nil) / restore")

  SegmentedToggle:new{
    parent   = f,
    height   = 20,
    selected = "l",
    options  = { { key = "s", label = "Up" }, { key = "l", label = "Considerably longer" } },
    position = { TopLeft = {modes, "BOTTOMLEFT", 0, -16} },
  }

  SegmentedToggle:new{
    parent   = f,
    height   = 20,
    selected = 3,
    options  = {
      { key = 1, label = "One" }, { key = 2, label = "Two" }, { key = 3, label = "Three" },
      { key = 4, label = "Four" }, { key = 5, label = "Five" },
    },
    position = { TopLeft = {modes, "BOTTOMLEFT", 0, -56} },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "segmentedtoggle",
  name = "SegmentedToggle",
  desc = "Segmented mode switch: caption-sized segments, nothing lit on Select(nil)",
  run  = toggling(makeSegmentedToggle),
})
