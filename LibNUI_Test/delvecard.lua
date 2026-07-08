local CleanFrame   = LibNUI.CleanFrame
local SectionHeader= LibNUI.SectionHeader
local Badge        = LibNUI.Badge
local LabeledValue = LibNUI.LabeledValue
local Timer        = LibNUI.Timer
local toggling     = LibNUITest.toggling
local window       = LibNUITest.window

-- Capstone: the EverythingDelves delve-run summary card, rebuilt entirely from LibNUI
-- widgets — a gold-bordered CleanFrame hosting a SectionHeader (title + rule) + a live
-- Timer, Badge tags, and tight LabeledValue rows with inline icons. Proves the ported
-- widget set covers a real, dense card.

local RED   = {0.95, 0.30, 0.30, 1}    -- tier tag
local CYAN  = {0.45, 0.80, 1.00, 1}    -- variant letter tag
local GREEN = {0.40, 0.85, 0.40, 1}    -- lives
local PILL  = {0, 0, 0, 0.3}           -- barely-there tag fill (not a boxy backdrop)
local SWORD = "Interface/Icons/inv_sword_04"
local TOME  = "Interface/Icons/inv_misc_book_09"

-- Inline the item icon into the value string so it sits next to the name.
local function withIcon(path, text) return ("|T%s:14|t %s"):format(path, text) end

---@return TitleFrame
local function makeDelveCard()
  local f = window("Delve Card", 340, 190)

  -- Gold-bordered card: a CleanFrame (the tooltip-border frame) recoloured gold, dark fill.
  local card = CleanFrame:new{
    parent = f,
    background = {0.03, 0.04, 0.06, 0.98},
    position = { Top = {f.titlebar, "BOTTOM", 0, -16}, Width = 286, Height = 124 },
  }
  card:BorderColor("header")

  local PAD = 10

  -- Header: accent title + rule; live Timer top-right; tier tag after the title.
  local sh = SectionHeader:new{
    parent = card, text = "Collegiate Calamity",
    position = {
      TopLeft  = {card, "TOPLEFT",  PAD, -8},
      TopRight = {card, "TOPRIGHT", -PAD, -8},
    },
  }
  Timer:new{ parent = card, color = "header",
    position = { TopRight = {sh, "TOPRIGHT", 0, -1} } }:Value(25):Start()
  Badge:new{ parent = card, text = "T11", color = RED, fill = PILL,
    position = { Left = {sh.title, "RIGHT", 6, 0} } }

  -- Body rows, kept tight (values in the normal text colour; timer owns the gold).
  local variant = LabeledValue:new{
    parent = card, label = "Variant:", value = "Faculty of Fear", valueColor = "text",
    position = { TopLeft = {sh, "BOTTOMLEFT", 0, -7}, Width = 260 },
  }
  Badge:new{ parent = card, text = "(B)", color = CYAN, fill = PILL,
    position = { Left = {variant.valueLabel, "RIGHT", 5, 0} } }

  local combat = LabeledValue:new{
    parent = card, label = "Combat:", valueColor = "text",
    value = withIcon(SWORD, "Porcelain Blade Tip"),
    position = { TopLeft = {variant, "BOTTOMLEFT", 0, -3}, Width = 260 },
  }
  local utility = LabeledValue:new{
    parent = card, label = "Utility:", valueColor = "text",
    value = withIcon(TOME, "Mandate of Sacred Death"),
    position = { TopLeft = {combat, "BOTTOMLEFT", 0, -3}, Width = 260 },
  }
  local lives = LabeledValue:new{
    parent = card, label = "Lives:", value = "3", valueColor = GREEN,
    position = { TopLeft = {utility, "BOTTOMLEFT", 0, -3}, Width = 64 },
  }
  LabeledValue:new{
    parent = card, label = "Deaths:", value = "0", valueColor = "text",
    position = { Left = {lives, "RIGHT", 18, 0}, Width = 90 },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "delvecard",
  name = "Delve Card",
  desc = "EverythingDelves delve-run card rebuilt from LibNUI widgets",
  run  = toggling(makeDelveCard),
})
