local Model    = LibNUI.Model
local toggling = LibNUITest.toggling
local window   = LibNUITest.window

-- Shows the logged-in character on a draggable, zoomable model viewer. Drag to
-- spin, scroll to zoom; proves SetUnit + the rotate/zoom mouse wiring.
---@return TitleFrame
local function makeModel()
  local f = window("Model", 280, 380)

  local model = Model:new{
    parent = f,
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT", 4, -4},
      BottomRight = {f, "BOTTOMRIGHT", -4, 4},
    },
  }
  model:Unit("player")

  return f
end

table.insert(LibNUITest.tests, {
  key  = "model",
  name = "Model",
  desc = "DressUpModel viewer with drag-rotate + scroll-zoom",
  run  = toggling(makeModel),
})

-- Renders the player wearing their own main-hand weapon appearance with an enchant
-- illusion overlaid via SlotTransmog — proves the SetItemTransmogInfo path (an illusion
-- has nothing to render on without a host weapon). Zoom into the weapon to see the
-- shimmer. Data-free: hosts on whatever weapon is equipped, overlays a collected illusion.
---@return TitleFrame
local function makeSlotTransmog()
  local f = window("SlotTransmog", 280, 380)

  local model = Model:new{
    parent = f,
    position = {
      TopLeft     = {f.titlebar, "BOTTOMLEFT", 4, -4},
      BottomRight = {f, "BOTTOMRIGHT", -4, 4},
    },
  }
  model:Unit("player")

  -- Host: the player's currently equipped main-hand appearance (an illusion needs a
  -- weapon to sit on). Overlay: the first collected enchant illusion (else the first).
  local mhID = GetInventoryItemID("player", INVSLOT_MAINHAND)
  local host = mhID and select(2, C_TransmogCollection.GetItemInfo(mhID)) or 0
  local illusionID
  for _, ill in ipairs(C_TransmogCollection.GetIllusions() or {}) do
    if ill.isCollected then illusionID = ill.sourceID break end
    illusionID = illusionID or ill.sourceID
  end
  model:SlotTransmog(INVSLOT_MAINHAND, host, { illusionID = illusionID })

  return f
end

table.insert(LibNUITest.tests, {
  key  = "slottransmog",
  name = "SlotTransmog",
  desc = "Weapon appearance + enchant illusion via SetItemTransmogInfo",
  run  = toggling(makeSlotTransmog),
})
