local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- A fixed icon so the preview renders without depending on live spell data.
local ICON = "Interface\\Icons\\Spell_Nature_Lightning"

-- Fill a slot-range bar (base = (bar-1)*12+1) with `n` spell slots.
local function fillBar(slots, base, n)
  for i = 0, n - 1 do slots[#slots + 1] = { id = base + i, type = "spell", index = 1 } end
end

local function makeProfile()
  local slots = {}
  fillBar(slots, 1,  12)   -- Bar 1 (horizontal)
  fillBar(slots, 49, 12)   -- Bar 3 / internal bar 5 (make it vertical below)
  fillBar(slots, 73, 8)    -- Class 1 / internal bar 7 (stance page)
  return {
    char  = "Testchar",
    spec  = "Preview",
    slots = slots,
    petslots = { { id = 1, type = "spell", index = 1 }, { id = 2, type = "spell", index = 1 } },
    binds = { { command = "ACTIONBUTTON1", key1 = "1" }, { command = "ACTIONBUTTON2", key1 = "SHIFT-2" } },
    -- Real geometry: Bar 1 horizontal, internal bar 5 vertical, Class 1 + pet present.
    barLayout = {
      [1]  = { orientation = 0, numIcons = 12, numRows = 1, enabled = true },
      [5]  = { orientation = 1, numIcons = 12, numRows = 1, enabled = true },
      [7]  = { orientation = 0, numIcons = 8,  numRows = 1, enabled = true },
      pet  = { orientation = 0, numIcons = 2,  numRows = 1, enabled = true },
      mainPage = 1,
    },
  }
end

-- ui.BarsPreview rendering a synthetic profile: a horizontal Bar 1, a vertical
-- bar to its right, and a stance page + pet bar in the gold-outlined group below.
---@return TitleFrame
local function makeBarsPreview()
  local f = window("BarsPreview", 440, 360)

  local preview = LibNUI.BarsPreview:new{
    parent   = f,
    position = { TopLeft = {f.titlebar, "BOTTOMLEFT", 8, -8} },
    resolveIcon    = function() return ICON end,
    resolveName    = function(slot) return "Slot " .. tostring(slot.id) end,
    resolvePetIcon = function() return ICON end,
    resolvePetName = function(slot) return "Pet " .. tostring(slot.id) end,
  }
  preview:Set(makeProfile())

  return f
end

table.insert(LibNUITest.tests, {
  key  = "barspreview",
  name = "Bars Preview",
  desc = "ui.BarsPreview real-orientation layout (horizontal + vertical + stance group)",
  run  = toggling(makeBarsPreview),
})
