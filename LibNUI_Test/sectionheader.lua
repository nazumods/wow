local SectionHeader = LibNUI.SectionHeader
local toggling      = LibNUITest.toggling
local window        = LibNUITest.window

-- Two stacked section headers: proves the accent title + 1px underline rule spanning the
-- anchored width, and the optional right-aligned summary slot.
---@return TitleFrame
local function makeSectionHeader()
  local f = window("SectionHeader", 300, 150)

  local h1 = SectionHeader:new{
    parent   = f,
    text     = "General",
    position = {
      TopLeft  = {f.titlebar, "BOTTOMLEFT",  12, -12},
      TopRight = {f.titlebar, "BOTTOMRIGHT", -12, -12},
    },
  }

  SectionHeader:new{
    parent   = f,
    text     = "Weekly Progress",
    summary  = "3 / 8",
    position = {
      TopLeft  = {h1, "BOTTOMLEFT",  0, -20},
      TopRight = {h1, "BOTTOMRIGHT", 0, -20},
    },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "sectionheader",
  name = "SectionHeader",
  desc = "Accent heading + underline rule, with an optional right-aligned summary",
  run  = toggling(makeSectionHeader),
})
