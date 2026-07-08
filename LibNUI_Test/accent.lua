local toggling = LibNUITest.toggling

-- Live accent swap: a window on a CUSTOM theme (so the swap is scoped to this window,
-- not the shared dark theme), with a RadioGroup driving theme:Apply and a SectionHeader,
-- StatTile, and Badge registered via :Themed to repaint. Picking an accent recolours all
-- three instantly; the titlebar text also follows (registered the same way).
---@return TitleFrame
local function makeAccent()
  local ACCENTS = {
    gold   = {1, 215/255, 0, 1},
    purple = {0.70, 0.50, 1.00, 1},
    green  = {0.30, 0.85, 0.30, 1},
  }

  local theme = LibNUI.Theme{ name = "accent-test" }
  local f = LibNUI.TitleFrame:new{
    name    = "LibNUITest_Accent",
    title   = "Accent Swap",
    theme   = theme,
    special = true,
  }
  f:Size(300, 260)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  local sh = LibNUI.SectionHeader:new{
    parent   = f, text = "Accented Section", summary = "live",
    position = {
      TopLeft  = {f.titlebar, "BOTTOMLEFT", 12, -10},
      TopRight = {f.titlebar, "BOTTOMRIGHT", -12, -10},
    },
  }
  sh:Themed(function(self)   -- re-pull the "header" token on every Apply
    self.title:Color("header")
    self.rule:Color("header")
  end)

  local tile = LibNUI.StatTile:new{
    parent = f, value = "42", subtitle = "accented", borderColor = "header",
    position = { TopLeft = {sh, "BOTTOMLEFT", 0, -12} },
  }
  tile:Themed(function(self)
    self:Colors{ value = "header", border = "header" }
  end)

  local badge = LibNUI.Badge:new{
    parent = f, text = "LIVE",
    position = { Left = {tile, "RIGHT", 10, 0} },
  }
  badge:Themed(function(self) self.label:Color("header") end)

  LibNUI.RadioGroup:new{
    parent   = f,
    header   = "Accent colour",
    selected = "gold",
    options  = {
      { key = "gold",   label = "Gold"   },
      { key = "purple", label = "Purple" },
      { key = "green",  label = "Green"  },
    },
    position = { TopLeft = {tile, "BOTTOMLEFT", 0, -14} },
    onSelect = function(_, key)
      theme:Apply{ colors = { header = ACCENTS[key] } }
    end,
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "accent",
  name = "Accent Swap",
  desc = "Runtime theme:Apply recolours Themed-registered widgets live",
  run  = toggling(makeAccent),
})
