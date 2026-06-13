---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local TitleFrame, Frame, Button = ui.TitleFrame, ui.Frame, ui.Button
local Texture, Label, Model = ui.Texture, ui.Label, ui.Model
local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs
local GetSourcesForSlot = C_TransmogSets.GetSourcesForSlot
local getParts = C_TransmogSets.GetSetPrimaryAppearances
local GetSourceInfo = C_TransmogCollection.GetSourceInfo
local GetItemIcon = C_Item.GetItemIconByID
local RequestItem = C_Item.RequestLoadItemDataByID
local GetAtlasInfo = C_Texture.GetAtlasInfo
local find, any = ns.lua.lists.find, ns.lua.maps.any
local GameTooltip = GameTooltip
local floor, ceil, max = math.floor, math.ceil, math.max

-- selection-border colors, status colors, and panel backing
local SELECTED = {0.85, 0.65, 0.13, 1}
local IDLE     = {0.20, 0.20, 0.24, 1}
local PANEL    = {0.05, 0.05, 0.06, 1}
local GREEN    = {0, 104/255, 55/255, 1}   -- piece collected
local RED      = {165/255, 0, 38/255, 1}   -- piece missing
local QUESTION = 134400                    -- inv_misc_questionmark fileID

local COLS  = 9
local STEP  = 32   -- cell size + 2px gap
local CELL  = 30
local PAD   = 6
local GRIDW = COLS * STEP
local MODELH = 640
local WINW   = 640

-- Equipment-slot columns flanking the model (paper-doll style). Slot ids are
-- inventory slots, also the GetSourcesForSlot key. Four per side.
local SLOT     = 44   -- slot button size
local SLOTGAP  = 16   -- vertical gap between slots
local COLINSET = 8    -- column distance from the window edge
local LEFT_SLOTS  = { {1, "Head"},  {3, "Shoulder"}, {15, "Back"}, {5, "Chest"}, {9, "Wrist"} }
local RIGHT_SLOTS = { {10, "Hands"}, {6, "Waist"},   {7, "Legs"},  {8, "Feet"} }

-- A 1px-framed box: an outer border Texture (recolored IDLE↔SELECTED to show
-- selection) over a dark inner panel. Returns the outer border to recolor later.
---@param parent Frame
---@return Texture
local function selBox(parent)
  local border = Texture:new{
    parent = parent, layer = ui.layer.Background,
    position = { All = true }, color = IDLE,
  }
  Texture:new{
    parent = parent, layer = ui.layer.Border, color = PANEL,
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }
  return border
end

-- Build one paper-doll equipment slot: a framed icon that shows the set piece for
-- `slotID` and opens the in-game item tooltip on hover. Registered on room._slots
-- and refreshed per set by UpdateSlots.
---@param room DressingRoom
---@param slotID number  inventory slot id
---@param x number
---@param y number
---@param side string  "left"|"right" — which way the tooltip opens
local function buildSlot(room, slotID, x, y, side)
  local box = Frame:new{
    parent = room,
    position = { TopLeft = {x, y}, Width = SLOT, Height = SLOT },
  }
  local border = selBox(box)
  local icon = Texture:new{
    parent = box, layer = ui.layer.Artwork,
    position = { TopLeft = {2, -2}, BottomRight = {-2, 2}, Hide = true },
  }
  local entry = { slotID = slotID, icon = icon, border = border }

  local anchor = side == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT"
  box._widget:EnableMouse(true)
  box._widget:SetScript("OnEnter", function(f)
    if not entry.itemID then return end
    GameTooltip:SetOwner(f, anchor)
    GameTooltip:SetItemByID(entry.itemID)
    GameTooltip:Show()
  end)
  box._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

  room._slots[#room._slots + 1] = entry
end

-- Lay out one vertically-centered column of slots at column x (each column is
-- centered independently, so the two sides can hold a different number of slots).
---@param room DressingRoom
---@param slots table[]  { {slotID, label}, ... }
---@param x number
---@param side string  "left"|"right"
local function layoutColumn(room, slots, x, side)
  local n = #slots
  local colH = n * SLOT + (n - 1) * SLOTGAP
  local startY = -(30 + PAD) - (MODELH - colH) / 2
  for i, s in ipairs(slots) do
    buildSlot(room, s[1], x, startY - (i - 1) * (SLOT + SLOTGAP), side)
  end
end

---Persistent dress-up window: a Model viewer plus race + gender selectors. One
---instance is shared by both /collected surfaces (see ns.ShowDressingRoom).
---@class DressingRoom: TitleFrame
---@field _model Model  the 3D viewer
---@field _race table<number, { border: Texture }>  selection border per raceID
---@field _gender table<number, Texture>  selection border per sex (2/3)
---@field _raceID number?  selected chrRaceID
---@field _sex number?  selected sex (2 = male, 3 = female)
---@field _set table?  the set entry currently previewed
---@field _undressed boolean?  hide the set to show the bare race body
---@field _undressBorder Texture  undress-toggle border (gold while active)
---@field _slots table[]  paper-doll slot entries ({ slotID, icon, border, itemID? })
---@field _slotTimer table?  cancelable icon-refresh timer
---@field _slotRetries number?  remaining icon-refresh attempts
local ROWH = 22         -- toggle-button height
local TOPGAP = ROWH + PAD

local DressingRoom = Class(TitleFrame, function(self)
  local races = ns.PlayableRaces()
  local rows = ceil(#races / COLS)
  local gridH = rows * STEP
  -- two stacked toggle rows (undress, gender) above the race grid
  local controlsH = 2 * TOPGAP + gridH
  local winW = max(WINW, GRIDW + 12)

  -- Bottom controls strip: toggle rows + wrapped race-icon grid, centered under
  -- the (wider) model.
  local controls = Frame:new{
    parent = self,
    position = {
      BottomLeft  = {self, ui.edge.BottomLeft, (winW - GRIDW) / 2, 6},
      Width = GRIDW, Height = controlsH,
    },
  }

  -- Model sits between the title bar and controls, inset to leave room for the
  -- equipment-slot columns down each side.
  local colW = COLINSET + SLOT + PAD
  self._model = Model:new{
    parent = self,
    position = {
      TopLeft  = {self.titlebar, ui.edge.BottomLeft, colW, -6},
      TopRight = {self.titlebar, ui.edge.BottomRight, -colW, -6},
      Height   = MODELH,
    },
  }

  -- Paper-doll slot columns, each vertically centered alongside the model.
  self._slots = {}
  layoutColumn(self, LEFT_SLOTS, COLINSET, "left")
  layoutColumn(self, RIGHT_SLOTS, winW - COLINSET - SLOT, "right")

  -- Undress toggle, top of the controls strip (full width). Strips the set so a
  -- bare race body is easy to identify; border goes gold while active.
  local undressBox = Frame:new{
    parent = controls,
    position = { TopLeft = {0, 0}, Width = GRIDW, Height = ROWH },
  }
  self._undressBorder = selBox(undressBox)
  Button:new{ parent = undressBox, position = { All = true }, glow = false,
    OnClick = function() self:SetUndressed(not self._undressed) end }
  Label:new{ parent = undressBox, justifyH = ui.justify.Center,
    position = { Left = {6, 0}, Right = {-6, 0} }, text = "Undress" }

  -- Gender toggle (two buttons), second row.
  self._gender = {}
  local half = (GRIDW - PAD) / 2
  for i, info in ipairs({ {2, "Male"}, {3, "Female"} }) do
    local sex, text = info[1], info[2]
    local box = Frame:new{
      parent = controls,
      position = { TopLeft = {(i - 1) * (half + PAD), -TOPGAP}, Width = half, Height = ROWH },
    }
    self._gender[sex] = selBox(box)
    Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:SetSex(sex) end }
    Label:new{ parent = box, justifyH = ui.justify.Center,
      position = { Left = {6, 0}, Right = {-6, 0} }, text = text }
  end

  -- Race grid below the toggle rows.
  self._race = {}
  for idx, race in ipairs(races) do
    local col, row = (idx - 1) % COLS, floor((idx - 1) / COLS)
    local box = Frame:new{
      parent = controls,
      position = { TopLeft = {col * STEP, -(2 * TOPGAP + row * STEP)}, Width = CELL, Height = CELL },
    }
    self._race[race.id] = { border = selBox(box) }

    local atlas = "raceicon-" .. race.file .. "-male"
    if GetAtlasInfo(atlas) then
      Texture:new{ parent = box, layer = ui.layer.Artwork, atlas = atlas, atlasSize = false,
        position = { TopLeft = {2, -2}, BottomRight = {-2, 2} } }
    else
      Label:new{ parent = box, justifyH = ui.justify.Center,
        position = { All = true }, text = race.name:sub(1, 3) }
    end
    Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:SetRace(race.id) end }
  end

  self:Width(winW)
  self:Height(30 + PAD + MODELH + PAD + controlsH + 6)
end, {
  name = "WarbandeerCollectedDressUp",
  title = "Preview",
  special = true,
  strata = "HIGH",
  position = { Center = {} },
})
---@class Warbandeer_Collected
---@field DressingRoom DressingRoom
ns.DressingRoom = DressingRoom

-- Move the gold selection border to raceID, clearing the previous one.
---@param raceID number
function DressingRoom:_highlightRace(raceID)
  if self._raceID and self._race[self._raceID] then self._race[self._raceID].border:Color(IDLE) end
  if self._race[raceID] then self._race[raceID].border:Color(SELECTED) end
end

---@param sex number  2 = male, 3 = female
function DressingRoom:_highlightSex(sex)
  if self._sex and self._gender[self._sex] then self._gender[self._sex]:Color(IDLE) end
  if self._gender[sex] then self._gender[sex]:Color(SELECTED) end
end

---@param raceID number
function DressingRoom:SetRace(raceID)
  if self._raceID == raceID then return end
  self:_highlightRace(raceID)
  self._raceID = raceID
  self:Dress()
end

---@param sex number  2 = male, 3 = female
function DressingRoom:SetSex(sex)
  if self._sex == sex then return end
  self:_highlightSex(sex)
  self._sex = sex
  self:Dress()
end

---@param undressed boolean  true to strip the set off the model
function DressingRoom:SetUndressed(undressed)
  self._undressed = undressed
  self._undressBorder:Color(undressed and SELECTED or IDLE)
  self:Dress()
end

-- Apply the current race/gender to the model, then put on the previewed set.
-- A known race+gender creature display ID is exact (both genders); otherwise we
-- render the race via a customRaceID-overridden player unit — textured and the
-- right race, but the gender follows the logged-in character. Either way no race
-- ever shows white or as the wrong race.
function DressingRoom:Dress()
  if not self._set then return end
  local m = self._model
  local byRace = ns.RaceModels[self._raceID]
  local id = byRace and byRace[self._sex]
  if id then
    m:DisplayInfo(id)           -- creature display starts naked
  else
    m:Unit("player", self._raceID):Undress()
  end
  if self._undressed then return end   -- bare body for race identification
  for _, src in ipairs(GetAllSourceIDs(self._set.id)) do
    m:TryOn(src)
  end
end

-- Fill the paper-doll slots with the current set's pieces: icon + status border
-- (green collected / red missing), and the itemID each slot's tooltip shows.
function DressingRoom:UpdateSlots()
  local set = self._set
  if not set then return end
  local parts = getParts(set.id)
  local primary = {}
  for _, p in ipairs(parts) do primary[p.appearanceID] = true end

  local missing = false
  for _, e in ipairs(self._slots) do
    local sources = GetSourcesForSlot(set.id, e.slotID)
    local _, p = find(sources, function(s) return primary[s.sourceID] end)
    if p then
      local info = GetSourceInfo(p.sourceID)
      e.itemID = info and info.itemID
      local tex = e.itemID and GetItemIcon(e.itemID)
      if e.itemID and not tex then RequestItem(e.itemID); missing = true end
      e.icon:Texture(tex or QUESTION)
      e.icon:Show()
      e.border:Color(any(sources, function(s) return s.isCollected end) and GREEN or RED)
    else
      -- No piece for this slot in the set: show the "unresolved" marker.
      e.itemID = nil
      e.icon:Texture(ui.media.unresolved)
      e.icon:Show()
      e.border:Color(IDLE)
    end
  end

  -- Icons aren't always cached on the first pass; re-run shortly (capped) until
  -- they resolve.
  if self._slotTimer then self._slotTimer:Cancel(); self._slotTimer = nil end
  if missing and (self._slotRetries or 0) < 10 then
    self._slotRetries = (self._slotRetries or 0) + 1
    self._slotTimer = C_Timer.NewTimer(0.2, function()
      self._slotTimer = nil
      self:UpdateSlots()
    end)
  end
end

local _room

---Open the shared dressing room previewing a class set on a selectable race/gender.
---@class Warbandeer_Collected
---@field ShowDressingRoom fun(group: table, set: table)  group/set are entries from ns.Sets
ns.ShowDressingRoom = function(group, set)
  if not _room then _room = DressingRoom:new{} end
  _room._group = group
  _room._set = set
  _room:Title(set.name)
  _room._slotRetries = 0
  _room:UpdateSlots()

  -- Default to the logged-in character on first open; keep the user's choice after.
  if not _room._raceID then
    local _, _, raceID = UnitRace("player")
    _room:_highlightRace(raceID)
    _room._raceID = raceID
    local sex = UnitSex("player")
    _room:_highlightSex(sex)
    _room._sex = sex
  end

  _room:Dress()
  _room:Show()
end

---Hide the shared dressing room (no-op if never opened).
---@class Warbandeer_Collected
---@field HideDressingRoom fun()
ns.HideDressingRoom = function()
  if _room then _room:Hide() end
end
