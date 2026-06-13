---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local GetClassInfo = GetClassInfo
local GameTooltip = GameTooltip
local TitleFrame, Frame, Button = ui.TitleFrame, ui.Frame, ui.Button
local Texture, Label, Model, Slider = ui.Texture, ui.Label, ui.Model, ui.Slider
local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs
local GetAtlasInfo = C_Texture.GetAtlasInfo
local floor, ceil, max = math.floor, math.ceil, math.max

-- selection-border colors and panel backing (slot-status colors live in the
-- companion DressingRoomSlots.lua)
local SELECTED = {0.85, 0.65, 0.13, 1}
local IDLE     = {0.20, 0.20, 0.24, 1}
local PANEL    = {0.05, 0.05, 0.06, 1}
local DISABLED = {0.40, 0.40, 0.45, 1}   -- toggle label, locked/inert

local COLS  = 13   -- 25 races wrap to two rows
local CELL  = 40
local STEP  = CELL + 4   -- cell size + gap
local PAD   = 6
local GRIDW = COLS * STEP
local MODELH = 640
local WINW   = 640

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

---Persistent dress-up window: a Model viewer plus race + gender selectors. One
---instance is shared by both /collected surfaces (see ns.ShowDressingRoom).
---@class DressingRoom: TitleFrame
---@field _model Model  the 3D viewer
---@field _race table<number, { border: Texture }>  selection border per raceID
---@field _gender table<number, { border: Texture, label: Label }>  toggle parts per sex (2/3)
---@field _genderLocked boolean?  true when the race renders via the player-gender fallback (toggle inert)
---@field _raceID number?  selected chrRaceID
---@field _sex number?  selected sex (2 = male, 3 = female)
---@field _form number  selected form index for multi-form races (Worgen/Dracthyr); 1 = default
---@field _formButtons table[]  reusable form-toggle button pool ({ box, border, label })
---@field _scaleSlider Slider  model size slider (per-race correction + user resize)
---@field _scaleLabel Label  scale value readout above the slider
---@field _bg Texture  class-themed backdrop behind the model
---@field _bgBorder Texture  Background-toggle border (gold while active)
---@field _bgEnabled boolean  whether the backdrop is shown
---@field _bgClass string?  current class file for the backdrop (remembered for the toggle)
---@field _group table?  the set-group the previewed set belongs to (Step cycles its sets)
---@field _set table?  the set entry currently previewed
---@field _classIcon Texture  title-bar class icon for the current set
---@field _undressed boolean?  hide the set to show the bare race body
---@field _undressBorder Texture  undress-toggle border (gold while active)
---@field _slots table[]  paper-doll slot entries ({ slotID, icon, border, itemID? })
---@field _slotTimer table?  cancelable icon-refresh timer
---@field _slotRetries number?  remaining icon-refresh attempts
local ROWH = 26         -- toggle-button height
local TOPGAP = ROWH + PAD

-- Forward-declared so the constructor closure can read DressingRoom.MODEL_INSET
-- (set by the companion DressingRoomSlots.lua) as an upvalue at instantiation.
local DressingRoom
DressingRoom = Class(TitleFrame, function(self)
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
  -- equipment-slot columns down each side (built by DressingRoomSlots.lua).
  local colW = DressingRoom.MODEL_INSET
  self._model = Model:new{
    parent = self,
    position = {
      TopLeft  = {self.titlebar, ui.edge.BottomLeft, colW, -6},
      TopRight = {self.titlebar, ui.edge.BottomRight, -colW, -6},
      Height   = MODELH,
    },
  }

  -- Class-themed backdrop behind the model. The ModelScene renders transparent, so
  -- a Background-layer texture anchored to the model rect shows through. The atlas
  -- (dressingroom-background-<class>) is chosen per set's class by _showClass and
  -- toggled by the Background button; hidden until both are set.
  self._bgEnabled = true
  self._bg = Texture:new{
    parent = self, layer = ui.layer.Background,
    position = {
      TopLeft = {self._model, ui.edge.TopLeft},
      BottomRight = {self._model, ui.edge.BottomRight},
      Hide = true,
    },
  }

  -- Paper-doll slot columns, each vertically centered alongside the model.
  self:_buildSlots(winW)

  -- Form toggle: a small floating button row at the top-left of the model, shown
  -- only for two-form races (Worgen/Dracthyr). A reusable pool sized to the most
  -- forms any race has; _setupForms relabels + shows the ones the race uses.
  self._form = 1
  self._formButtons = {}
  local FORMW = 80
  for i = 1, 2 do
    local box = Frame:new{
      parent = self,
      position = { TopLeft = {self._model, ui.edge.TopLeft, 8 + (i - 1) * (FORMW + 4), -8},
                   Width = FORMW, Height = ROWH },
    }
    local border = selBox(box)
    Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:SetForm(i) end }
    local label = Label:new{ parent = box, justifyH = ui.justify.Center,
      position = { Left = {4, 0}, Right = {-4, 0} } }
    box:Level(self._model:Level() + 10)   -- above the ModelScene, else hidden behind it
    box:Hide()
    self._formButtons[i] = { box = box, border = border, label = label }
  end

  -- Scale slider: floats at the bottom-left of the model. Corrects the size of
  -- large races (the borrowed scene renders everything player-sized) and lets the
  -- user resize the preview. Drives the live model scale; Dress resets it to the
  -- selected race's configured scale.
  self._scaleLabel = Label:new{
    parent = self, fontObj = "GameFontNormalSmall",
    position = { BottomLeft = {self._model, ui.edge.BottomLeft, 8, 28} },
    text = "Scale  1.00",
  }
  self._scaleSlider = Slider:new{
    parent = self, min = 0.5, max = 3.0, step = 0.05, value = 1,
    position = { BottomLeft = {self._model, ui.edge.BottomLeft, 8, 12}, Width = 150, Height = 14 },
    OnChange = function(_, v)
      self._model:Scale(v)
      self._scaleLabel:Text(("Scale  %.2f"):format(v))
    end,
  }
  -- The slider overlaps the model frame; lift it above the mouse-enabled
  -- ModelScene so the thumb is grabbable instead of rotating the model.
  self._scaleSlider:Level(self._model:Level() + 10)

  local half = (GRIDW - PAD) / 2

  -- Top control row: Undress (left) + Background toggle (right). Borders go gold
  -- while active.
  local undressBox = Frame:new{
    parent = controls,
    position = { TopLeft = {0, 0}, Width = half, Height = ROWH },
  }
  self._undressBorder = selBox(undressBox)
  Button:new{ parent = undressBox, position = { All = true }, glow = false,
    OnClick = function() self:SetUndressed(not self._undressed) end }
  Label:new{ parent = undressBox, justifyH = ui.justify.Center,
    position = { Left = {6, 0}, Right = {-6, 0} }, text = "Undress" }

  local bgBox = Frame:new{
    parent = controls,
    position = { TopLeft = {half + PAD, 0}, Width = half, Height = ROWH },
  }
  self._bgBorder = selBox(bgBox)
  self._bgBorder:Color(SELECTED)   -- backdrop defaults on
  Button:new{ parent = bgBox, position = { All = true }, glow = false,
    OnClick = function() self:SetBackgroundOn(not self._bgEnabled) end }
  Label:new{ parent = bgBox, justifyH = ui.justify.Center,
    position = { Left = {6, 0}, Right = {-6, 0} }, text = "Background" }

  -- Gender toggle (two buttons), second row.
  self._gender = {}
  for i, info in ipairs({ {2, "Male"}, {3, "Female"} }) do
    local sex, text = info[1], info[2]
    local box = Frame:new{
      parent = controls,
      position = { TopLeft = {(i - 1) * (half + PAD), -TOPGAP}, Width = half, Height = ROWH },
    }
    local border = selBox(box)
    Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:SetSex(sex) end }
    local label = Label:new{ parent = box, justifyH = ui.justify.Center,
      position = { Left = {6, 0}, Right = {-6, 0} }, text = text }
    self._gender[sex] = { border = border, label = label }
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
    local btn = Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:SetRace(race.id) end }
    btn._widget:SetScript("OnEnter", function(f)
      GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
      GameTooltip:SetText(race.name)
      GameTooltip:Show()
    end)
    btn._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  -- Set-navigation arrows + class icon in the title bar, left of the close
  -- button. Step() cycles the current group's class sets (skipping empty slots),
  -- so a whole tier can be browsed without reopening from the grid.
  local function navArrow(anchor, dir, glyph)
    local box = Frame:new{
      parent = self.titlebar,
      position = { Right = {anchor, ui.edge.Left, -2, 0}, Width = 22, Height = 20 },
    }
    selBox(box)
    Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:Step(dir) end }
    Label:new{ parent = box, justifyH = ui.justify.Center, fontObj = "GameFontNormalLarge",
      position = { Left = {1, 0}, Right = {-1, 0} }, text = glyph }
    return box
  end
  local nextBox = navArrow(self.closeButton, 1, ">")
  local prevBox = navArrow(nextBox, -1, "<")
  self._classIcon = Texture:new{
    parent = self.titlebar, layer = ui.layer.Artwork,
    position = { Right = {prevBox, ui.edge.Left, -6, 0}, Size = {20, 20} },
  }

  -- Left/Right cycle the class sets (mirroring the title-bar nav arrows); Up/Down
  -- step through the raid's difficulty tiers (StepTier). Every other key is
  -- propagated, so default keybindings (and Escape, via the `special` registration)
  -- keep working.
  self._widget:EnableKeyboard(true)
  self._widget:SetScript("OnKeyDown", function(f, key)
    if key == "LEFT" then
      f:SetPropagateKeyboardInput(false)
      self:Step(-1)
    elseif key == "RIGHT" then
      f:SetPropagateKeyboardInput(false)
      self:Step(1)
    elseif key == "UP" then
      f:SetPropagateKeyboardInput(false)
      self:StepTier(-1)
    elseif key == "DOWN" then
      f:SetPropagateKeyboardInput(false)
      self:StepTier(1)
    else
      f:SetPropagateKeyboardInput(true)
    end
  end)

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

-- Layout primitives shared with the companion controls/DressingRoomSlots.lua,
-- which reopens this class to add :_buildSlots / :UpdateSlots and reads these
-- back. MODEL_INSET is set there in return (model edge inset = slot column width).
DressingRoom._selBox = selBox
DressingRoom._IDLE   = IDLE
DressingRoom._PAD    = PAD
DressingRoom._MODELH = MODELH

-- Move the gold selection border to raceID, clearing the previous one.
---@param raceID number
function DressingRoom:_highlightRace(raceID)
  if self._raceID and self._race[self._raceID] then self._race[self._raceID].border:Color(IDLE) end
  if self._race[raceID] then self._race[raceID].border:Color(SELECTED) end
end

---@param sex number  2 = male, 3 = female
function DressingRoom:_highlightSex(sex)
  if self._sex and self._gender[self._sex] then self._gender[self._sex].border:Color(IDLE) end
  if self._gender[sex] then self._gender[sex].border:Color(SELECTED) end
end

-- The race's resolved RaceModels entry for the current form (multi-form races
-- read through the selected form; single-form races are the entry itself).
---@return table?
function DressingRoom:_resolvedForm()
  local entry = ns.RaceModels[self._raceID]
  return entry and (entry.forms and entry.forms[self._form] or entry)
end

-- The Male/Female toggle is always inert: a dressable body (needed to show the set
-- and to undress) renders through the player-unit path, whose gender follows the
-- logged-in character — and WoW exposes no gender override for it. So the toggle is
-- pinned to the char's gender and greyed to show it. Kept (greyed) rather than
-- removed so the constraint is visible. Call on open / race / form change.
function DressingRoom:_syncGenderToggle()
  self._genderLocked = true
  self:_highlightSex(UnitSex("player"))
  self._sex = UnitSex("player")
  for _, g in pairs(self._gender) do g.label:Color(DISABLED) end
end

---@param raceID number
function DressingRoom:SetRace(raceID)
  if self._raceID == raceID then return end
  self:_highlightRace(raceID)
  self._raceID = raceID
  self:_setupForms(ns.RaceModels[raceID])
  self:_syncGenderToggle()
  self:Dress()
end

-- Highlight the active form button (gold), the rest idle.
---@param i number
function DressingRoom:_highlightForm(i)
  for j, b in ipairs(self._formButtons) do b.border:Color(j == i and SELECTED or IDLE) end
end

-- Show form-toggle buttons for the selected race's alternate forms (Worgen,
-- Dracthyr); hide the row for single-form races. Resets to the first form.
---@param entry table?  the race's RaceModels entry
function DressingRoom:_setupForms(entry)
  local forms = entry and entry.forms
  for i, b in ipairs(self._formButtons) do
    local f = forms and forms[i]
    if f then b.label:Text(f.name); b.box:Show() else b.box:Hide() end
  end
  self._form = 1
  if forms then self:_highlightForm(1) end
end

---@param i number  index into the selected race's forms array
function DressingRoom:SetForm(i)
  if self._form == i then return end
  self._form = i
  self:_highlightForm(i)
  self:_syncGenderToggle()
  self:Dress()
end

---@param sex number  2 = male, 3 = female
function DressingRoom:SetSex(sex)
  if self._genderLocked or self._sex == sex then return end
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

-- Render the selected race on a DRESSABLE actor, then put on the previewed set.
-- We always use the customRaceID-overridden player unit: it renders any race
-- textured AND can wear transmog / undress. The exact-gender creature-display path
-- (Model:DisplayInfo) is a static NPC whose baked gear can't be removed or dressed
-- over, so it can't show a set — hence the gender follows the logged-in character
-- (see _syncGenderToggle). The race's `scale` still corrects sizing.
function DressingRoom:Dress()
  if not self._set then return end
  local m = self._model
  -- Multi-form races resolve through the selected form (for its `scale`); others
  -- are the entry itself.
  local form = self:_resolvedForm()

  -- Decide the outfit BEFORE (re)loading the model. The re-skin loads async and
  -- resets the actor to its default body once the load finishes, so the model
  -- re-applies this on its load callback (Model:Outfit). Empty = undressed.
  local sources = {}
  if not self._undressed then
    for _, src in ipairs(GetAllSourceIDs(self._set.id)) do sources[#sources + 1] = src end
  end
  m:Outfit(sources)

  -- A form may override the render race (Worgen's "Human" form → race 1, rendered
  -- as a plain Human); otherwise render the selected race.
  m:Unit("player", (form and form.race) or self._raceID)

  -- `scale` may be a number (both genders) or a per-sex table { [2]=, [3]= }.
  local scale = form and form.scale
  if type(scale) == "table" then scale = scale[self._sex] end
  scale = scale or 1
  m:Scale(scale)                  -- per-race size correction; re-apply post re-skin
  self._scaleSlider:Value(scale)  -- reflect the race's scale in the slider/readout
end

-- Point the title-bar class icon at the class in column `classId` (hidden if the
-- id is missing or has no class icon). `group.sets` is positional — the array
-- index is the classId — so callers pass the set's index, not `set.classId`
-- (which is only populated for the earliest groups).
---@param classId number?
function DressingRoom:_showClass(classId)
  local file
  if classId then file = select(2, GetClassInfo(classId)) end
  local lower = file and file:lower()
  local atlas = lower and ("classicon-" .. lower)
  if atlas and GetAtlasInfo(atlas) then
    self._classIcon:Atlas(atlas)
    self._classIcon:Show()
  else
    self._classIcon:Hide()
  end
  self:_setBackground(lower)   -- class-themed model backdrop
end

-- Point the model backdrop at the class's dressing-room background (hidden when
-- the toggle is off or the class/atlas is unknown). Remembers the class so the
-- Background toggle can re-show it.
---@param classFile string?  lowercased class file (e.g. "warrior")
function DressingRoom:_setBackground(classFile)
  self._bgClass = classFile
  local atlas = classFile and ("dressingroom-background-" .. classFile)
  if self._bgEnabled and atlas and GetAtlasInfo(atlas) then
    self._bg:Atlas(atlas, false)   -- false = stretch to the model rect
    self._bg:Show()
  else
    self._bg:Hide()
  end
end

---@param on boolean  show the class-themed model backdrop
function DressingRoom:SetBackgroundOn(on)
  self._bgEnabled = on
  self._bgBorder:Color(on and SELECTED or IDLE)
  self:_setBackground(self._bgClass)
end

-- Preview a specific set within a group: refresh the title, class icon, slots and
-- model. Shared by ShowDressingRoom (initial open) and Step (navigation).
---@param group table  a group entry from ns.Sets
---@param set table    a set entry within that group
function DressingRoom:_load(group, set)
  self._group = group
  self._set = set
  self:Title(set.name)
  -- Class = the set's position in the (positional) group.sets array.
  local classId
  for i = 1, #group.sets do if group.sets[i] == set then classId = i; break end end
  self:_showClass(classId)
  self._slotRetries = 0
  self:UpdateSlots()
  self:Dress()
end

-- Move to the next/previous class set in the current group, wrapping and skipping
-- empty class slots (the data has gaps for classes absent from a tier).
---@param dir number  +1 = next, -1 = previous
function DressingRoom:Step(dir)
  local sets = self._group and self._group.sets
  if not sets then return end
  local n = #sets
  local cur
  for i = 1, n do if sets[i] == self._set then cur = i; break end end
  if not cur then return end
  for _ = 1, n do
    cur = (cur - 1 + dir) % n + 1
    local s = sets[cur]
    if s and s.id then return self:_load(self._group, s) end
  end
end

-- Switch to the same class set in a sibling difficulty tier of the current raid,
-- keeping the class column. Sibling tiers are the ns.Sets groups that share this
-- group's base id (e.g. Hellfire Citadel Normal/Heroic/Mythic all id 28); they sit
-- in difficulty order in the data. Wraps; no-op for a single-tier raid. Falls back
-- to the tier's first real set if it lacks the current class column.
---@param dir number  +1 = next tier, -1 = previous tier
function DressingRoom:StepTier(dir)
  if not self._group then return end
  local sibs, cur = {}, nil
  for _, g in ipairs(ns.Sets) do
    if g.id == self._group.id then
      sibs[#sibs + 1] = g
      if g == self._group then cur = #sibs end
    end
  end
  if not cur or #sibs < 2 then return end

  -- Current class column = the set's index within its group's positional sets.
  local col
  for i = 1, #self._group.sets do if self._group.sets[i] == self._set then col = i; break end end

  for _ = 1, #sibs do
    cur = (cur - 1 + dir) % #sibs + 1
    local g = sibs[cur]
    local s = col and g.sets[col]
    if not (s and s.id) then
      for i = 1, #g.sets do if g.sets[i] and g.sets[i].id then s = g.sets[i]; break end end
    end
    if s and s.id then return self:_load(g, s) end
  end
end

local _room

---Open the shared dressing room previewing a class set on a selectable race/gender.
---@class Warbandeer_Collected
---@field ShowDressingRoom fun(group: table, set: table)  group/set are entries from ns.Sets
ns.ShowDressingRoom = function(group, set)
  if not _room then _room = DressingRoom:new{} end

  -- Default to the logged-in character on first open; keep the user's choice after.
  -- Set before _load so its Dress() renders the right race/gender immediately.
  if not _room._raceID then
    local _, _, raceID = UnitRace("player")
    _room:_highlightRace(raceID)
    _room._raceID = raceID
    local sex = UnitSex("player")
    _room:_highlightSex(sex)
    _room._sex = sex
    _room:_setupForms(ns.RaceModels[raceID])
    _room:_syncGenderToggle()
  end

  _room:_load(group, set)
  _room:Show()
end

---Hide the shared dressing room (no-op if never opened).
---@class Warbandeer_Collected
---@field HideDressingRoom fun()
ns.HideDressingRoom = function()
  if _room then _room:Hide() end
end

---Dev/verify helper: force a raw creature display id into the open dressing room
---model so a candidate RaceModels id can be eyeballed (no-op if not open). The
---next race/gender/form change reverts to the configured model. Used by
---`/collected model <id>`.
---@class Warbandeer_Collected
---@field PreviewModelID fun(id: number, useCustomizations: boolean?)
ns.PreviewModelID = function(id, useCustomizations)
  if _room and _room._widget:IsShown() then _room._model:DisplayInfo(id, useCustomizations) end
end

---Dev/verify helper: live-set the open preview model's scale, to tune a race's
---`scale` correction (reverts on the next race/gender/form change). `/collected scale`.
---@class Warbandeer_Collected
---@field PreviewModelScale fun(scale: number)
ns.PreviewModelScale = function(scale)
  if _room and _room._widget:IsShown() then _room._scaleSlider:Value(scale) end
end
