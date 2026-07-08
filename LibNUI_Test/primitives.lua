local StatTile     = LibNUI.StatTile
local LabeledValue = LibNUI.LabeledValue
local IconListItem = LibNUI.IconListItem
local Badge        = LibNUI.Badge
local Label        = LibNUI.Label
local toggling     = LibNUITest.toggling
local window       = LibNUITest.window

-- All four content primitives on one mini dashboard: a StatTile strip (three states +
-- hover tip + a live Value update), LabeledValue stat fields (icon + plain), two
-- IconListItems (item icon + real item tooltip; bullet + custom tooltip), and Badges
-- beside a name (hover legend on "B").
---@return TitleFrame
local function makePrimitives()
  local f = window("Primitives", 340, 330)

  -- StatTile strip: normal / current (accent border) / locked (dimmed)
  local t1 = StatTile:new{
    parent = f, value = "639", subtitle = "1 / 8",
    tooltip = {"Vault Slot 1", "Unlocked at 639 ilvl"},
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 14, -10} },
  }
  local t2 = StatTile:new{
    parent = f, value = "645", subtitle = "4 / 8", borderColor = "header",
    position = { Left = {t1, "RIGHT", 8, 0} },
  }
  local t3 = StatTile:new{
    parent = f, value = "—", subtitle = "locked",
    valueColor = "muted", subtitleColor = "muted",
    position = { Left = {t2, "RIGHT", 8, 0} },
  }
  t3:Colors{ fill = {0, 0, 0, 0.4} }

  -- Tick t1's value up once a second to prove the live Value setter (onUpdate
  -- elapsed arrives in ms; startUpdates arms the pump).
  local n, acc = 639, 0
  f.onUpdate = function(_, elapsed)
    acc = acc + elapsed
    if acc >= 1000 then
      acc = 0
      n = n + 1
      t1:Value(tostring(n))
    end
  end
  f:startUpdates()

  -- LabeledValue block
  local lv1 = LabeledValue:new{
    parent = f, label = "Bountiful Keys:", value = "3",
    icon = 4622270,
    position = { TopLeft = {t1, "BOTTOMLEFT", 0, -14}, Width = 150 },
  }
  local lv2 = LabeledValue:new{
    parent = f, label = "Coffer Shards:", value = "117",
    position = { TopLeft = {lv1, "BOTTOMLEFT", 0, -6}, Width = 150 },
  }

  -- IconListItem rows
  local r1 = IconListItem:new{
    parent = f, icon = 1064187, title = "Trovehunter's Bounty", kind = "Consumable",
    subtitle = "Use inside a Bountiful Delve for bonus loot.",
    itemID = 252415,
    position = {
      TopLeft  = {lv2, "BOTTOMLEFT", 0, -14},
      TopRight = {f, "TOPRIGHT", -14, 0},
    },
  }
  local r2 = IconListItem:new{
    parent = f, title = "Delver's Journey", kind = "Track",
    subtitle = "No icon: renders a bullet; hover shows a custom tooltip.",
    tooltip = {"Delver's Journey", "Custom tooltip lines, no itemID."},
    position = {
      TopLeft  = {r1, "BOTTOMLEFT", 0, -8},
      TopRight = {r1, "BOTTOMRIGHT", 0, -8},
    },
  }

  -- Badges beside a name
  local name = Label:new{
    parent = f, text = "Archival Assault",
    position = { TopLeft = {r2, "BOTTOMLEFT", 0, -14} },
  }
  local b1 = Badge:new{
    parent = f, text = "B", tooltip = "B = Bountiful",
    position = { Left = {name, "RIGHT", 6, 0} },
  }
  Badge:new{
    parent = f, text = "Overcharged", color = "muted",
    position = { Left = {b1, "RIGHT", 4, 0} },
  }

  return f
end

table.insert(LibNUITest.tests, {
  key  = "primitives",
  name = "Content Primitives",
  desc = "StatTile, LabeledValue, IconListItem, Badge on one dashboard",
  run  = toggling(makePrimitives),
})
