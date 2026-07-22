---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class = ns.lua.Class
local GameTooltip = GameTooltip
local TitleFrame, Frame, Label, Texture = ui.TitleFrame, ui.Frame, ui.Label, ui.Texture
local ceil, max = math.ceil, math.max

-- The class is assembled across five files (all reopening this one): DressingRoom.lua
-- (constants/helpers + constructor scaffolding), DressingRoomBuild.lua (the model +
-- on-model overlays), DressingRoomControls.lua (the toggle/ratings rows + race-selector
-- panels), DressingRoomActions.lua (race/form/rating/navigation methods), and
-- DressingRoomModel.lua (Dress + class/expansion/backdrop/tier-bar rendering + the shared
-- ShowDressingRoom entry points). Layout constants + helpers are shared via DressingRoom._k.

-- selection-border colors and panel backing (slot-status colors live in the
-- companion DressingRoomSlots.lua)
local SELECTED = {0.85, 0.65, 0.13, 1}
local IDLE     = {0.20, 0.20, 0.24, 1}
local PANEL    = {0.05, 0.05, 0.06, 1}

-- Raid difficulty → ilvl/quality color + alpha range for the slot-column backdrop
-- bars, so the bar reads like gear quality: LFR green, Normal blue, Heroic purple,
-- Mythic gold. Returns the color and the outer/inner edge alphas (the bar fades from
-- outer at the window edge to inner at the model edge). All tiers fade BARALPHA→0.
-- The difficulty is encoded in the group name's parenthetical suffix (e.g. "Hellfire
-- Citadel (Mythic)"); pre-LFR/no-difficulty raids fall back to purple.
local BARALPHA = 0.2    -- default alpha at the outer (window) edge; fades to 0 inward
-- Custom Mythic gold: ITEM_ARTIFACT_COLOR (e6cc80 = 0.902, 0.800, 0.502) blended
-- toward pure yellow (1, 1, 0) in two 10% steps (~19% total) so it reads warmer/
-- less brown at low alpha.
local MYTHIC_GOLD = CreateColor(0.921, 0.838, 0.407)
local function tierBar(groupName)
  if groupName then
    if groupName:find("Raid Finder") then return ITEM_GOOD_COLOR,     BARALPHA, 0   -- LFR
    elseif groupName:find("Mythic")    then return MYTHIC_GOLD,         BARALPHA, 0
    elseif groupName:find("Heroic")    then return ITEM_EPIC_COLOR,     BARALPHA, 0
    elseif groupName:find("Normal")    then return ITEM_SUPERIOR_COLOR, BARALPHA, 0
    end
  end
  return ITEM_EPIC_COLOR, BARALPHA, 0   -- default: no parsed difficulty
end

local COLS  = 13   -- overall controls width is still keyed to this
local CELL  = 40
local RACEICON_CROP = 0.08   -- fraction cropped off each raceicon edge to hide its baked ring
local STEP  = CELL + 4   -- cell size + gap
local PAD   = 6
local GRIDW = COLS * STEP
local MODELH = 640

-- Race-selector faction panels: Alliance | Neutral | Horde, each in a colored
-- border. Alliance/Horde wrap at AHCOLS columns; Neutral wraps at 2 (2-over-1 for 3
-- races, 2x2 for 4).
local AHCOLS   = 4          -- columns in the Alliance / Horde panels
local PBORDER  = 1          -- faction-panel border thickness (px)
local PINPAD   = 5          -- gap between the border and the icons
local PANELPAD = PBORDER + PINPAD
local PANELGAP = 12         -- gap between the three panels
local ALLIANCE_COLOR = {0.08, 0.40, 0.83, 1}   -- Alliance blue
local HORDE_COLOR    = {0.74, 0.12, 0.18, 1}   -- Horde red
local NEUTRAL_COLOR  = {0.20, 0.68, 0.58, 1}   -- jade/teal (distinct from the gold selection border)
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
---@field _raceID number?  selected chrRaceID
---@field _sex number?  the logged-in character's sex (2 = male, 3 = female); the body can't be re-gendered
---@field _form number  selected form index for multi-form races (Worgen/Dracthyr); 1 = default
---@field _formButtons table[]  reusable form-toggle button pool ({ box, border, label })
---@field _scaleSlider Slider  user resize slider (multiplier on top of the normalized size); its own `label`/`valueFormat` render the "Scale" caption + value readout
---@field _bg Texture  class-themed backdrop behind the model
---@field _tierBarL Texture  left slot-column difficulty-color gradient bar
---@field _tierBarR Texture  right slot-column difficulty-color gradient bar
---@field _bgBorder Texture  Background-toggle border (gold while active)
---@field _bgEnabled boolean  whether the backdrop is shown
---@field _bgClass string?  current class file for the backdrop (remembered for the toggle)
---@field _group table?  the set-group the previewed set belongs to (Step cycles its sets)
---@field _set table?  the set entry currently previewed
---@field _classIndex number?  the previewed set's class column (its slot in group.sets), broadcast for the grid cursor
---@field _classIcon Texture  class icon in the model's upper-left (mirrors the nav pad)
---@field _className string?  localized class name for the icon's hover tooltip
---@field _expIcon Texture  expansion badge in the model's bottom-right (mirrors the class icon)
---@field _expName string?  expansion name for the badge's hover tooltip
---@field _idLabel Label  set-id text in the title bar (left of the close button)
---@field _masterName string?  master-grid group name for the id label's hover tooltip
---@field _undressBorder Texture  undress-toggle border (gold while every slot is toggled off)
---@field _wantedBorder Texture  wanted-toggle border (gold while the set is wanted)
---@field _rankBtns table<string, { border: Texture }>  tier buttons keyed by letter
---@field _raceOnly boolean  edit/show the per-race override instead of the baseline
---@field _raceOnlyBorder Texture  per-race-override toggle border (gold while active)
---@field _slots table[]  paper-doll slot entries ({ slotID, icon, border, itemID?, cosmetic? }) — cosmetic ones are picker-driven, not set pieces
---@field _cosmeticSlots table[]  the shirt/tabard subset of _slots ({ slotID, label, target, look, empty, ... }) (DressingRoomCosmeticSlots.lua)
---@field _hiddenSlots table<number, true>  inventory slot ids toggled off the model (reset per set)
---@field _undressed boolean?  the master Undress toggle's state — greys the composed-look slots, which have no _hiddenSlots entry (reset per set)
---@field _weaponSlots table[]  bottom-center weapon-slot entries ({ hand, label, icon, border, box, itemID? }) (DressingRoomWeaponSlots.lua)
---@field _weaponPiece number?  index of the previewed piece within a weapon-cosmetic cell (up/down nav cycles it)
---@field _weaponTitleTimer table?  cancelable retitle timer (arsenal item names load async)
---@field _weaponTitleTries number?  remaining retitle attempts
---@field _slotTimer table?  cancelable icon-refresh timer
---@field _slotRetries number?  remaining icon-refresh attempts
---@field _weaponSlotTimer table?  cancelable weapon-slot icon-refresh timer
---@field _weaponSlotRetries number?  remaining weapon-slot icon-refresh attempts
---@field _cosmeticSlotTimer table?  cancelable cosmetic-slot icon-refresh timer
---@field _cosmeticSlotRetries number?  remaining cosmetic-slot icon-refresh attempts
---@field _buildModel fun(self: DressingRoom)  build the model + backdrop + tier bars (DressingRoomBuild.lua)
---@field _buildOverlays fun(self: DressingRoom)  build the on-model overlays (DressingRoomBuild.lua)
---@field _buildControls fun(self: DressingRoom, controls: Frame)  build the toggle + ratings rows (DressingRoomControls.lua)
---@field _buildRacePanels fun(self: DressingRoom, controls: Frame, d: table)  build the race selector (DressingRoomControls.lua)
---@field _buildSlots fun(self: DressingRoom, winW: number)  build the paper-doll slot columns (DressingRoomSlots.lua)
---@field _picker Frame?  the docked appearance picker pane, lazily built on first open (AppearancePicker.lua)
---@field _pickerTitle Label  the pane's header caption, retitled per target
---@field _pickerCats WeaponCategory[]  the previewed set's class's usable weapon categories (dropdown source)
---@field _pickerClass number?  chrClassID the picker is currently scoped to (weapons + illusions); rescoped on class change
---@field _pickerCatByID table<number, WeaponCategory>  category id → descriptor (main/off-hand slot routing)
---@field _pickerCat FilterDropdown  the category selector (weapon types; hidden for a cosmetic target)
---@field _pickerList VirtualList  the appearance / illusion list
---@field _pickerCategory number?  the active weapon category (Enum.TransmogCollectionType)
---@field _pickerMode string  the active pane mode ("weapons" | "illusions") — weapon targets only
---@field _pickerTabs Frame  the Weapons|Illusions tab row (hidden for a cosmetic target)
---@field _modeTab table<string, Texture>  mode-tab borders (gold on the active mode)
---@field _pickerTabBox table<string, Frame>  mode-tab boxes (the Illusions tab is hidden for the off-hand)
---@field _pickerTarget string  which slot the picker targets ("main" | "off" | "shirt" | "tabard") — shapes the pane + routes picks
---@field _lookMH number?  the composed look's main-hand weapon appearance sourceID
---@field _lookMH2H boolean?  whether the main-hand pick is two-handed (occupies both hands) — greys the off-hand slot (#618)
---@field _lookOH number?  the composed look's off-hand weapon appearance sourceID
---@field _lookIllusion number?  the composed look's enchant illusion sourceID (rides the main-hand)
---@field _lookShirt number?  the composed look's shirt appearance sourceID (INVSLOT_BODY; picked in the cosmetic slots)
---@field _lookTabard number?  the composed look's tabard appearance sourceID (INVSLOT_TABARD)
---@field _pickerNameTimer table?  cancelable async item-name refresh timer
---@field _buildWeaponSlots fun(self: DressingRoom)  build the bottom-center weapon-slot pair (DressingRoomWeaponSlots.lua)
---@field _showWeaponSlots fun(self: DressingRoom, show: boolean)  show/hide the weapon-slot pair (DressingRoomWeaponSlots.lua)
---@field UpdateWeaponSlots fun(self: DressingRoom, retry: boolean?)  fill the weapon slots from the composed look (DressingRoomWeaponSlots.lua)
---@field _clearWeaponSlot fun(self: DressingRoom, hand: string)  clear a hand's picked weapon — the right-click gesture (DressingRoomWeaponSlots.lua)
---@field _buildCosmeticSlot fun(self: DressingRoom, spec: table, x: number, y: number, side: string)  build one shirt/tabard column slot (DressingRoomCosmeticSlots.lua)
---@field UpdateCosmeticSlots fun(self: DressingRoom, retry: boolean?)  fill the shirt/tabard slots from the composed look (DressingRoomCosmeticSlots.lua)
---@field _clearCosmeticSlot fun(self: DressingRoom, target: string)  clear a cosmetic slot's pick — the right-click gesture (DressingRoomCosmeticSlots.lua)
---@field _buildPicker fun(self: DressingRoom)  build the docked picker pane (AppearancePicker.lua)
---@field TogglePicker fun(self: DressingRoom, force: boolean?, target: string?)  show/hide the picker pane, targeting a slot (AppearancePicker.lua)
---@field _applyPickerTarget fun(self: DressingRoom)  re-shape the pane for the current target + repopulate (AppearancePicker.lua)
---@field _anchorPickerList fun(self: DressingRoom, anchor: Frame)  re-anchor the list under the pane's current furniture (AppearancePicker.lua)
---@field _targetLook fun(self: DressingRoom): number?  the sourceID picked into the targeted slot (AppearancePicker.lua)
---@field _toggleRowWanted fun(self: DressingRoom, item: table?)  shift-click gesture: flag a shirt/tabard appearance wanted (AppearancePicker.lua)
---@field _applyLook fun(self: DressingRoom)  re-assert the whole composed look on the model (AppearancePicker.lua)
---@field _bareSlot fun(self: DressingRoom, slot: number)  strip one composed-look slot off the model in place (AppearancePicker.lua)
---@field _rescopeWeapons fun(self: DressingRoom)  re-derive the previewed class's weapon categories (WeaponPicker.lua)
---@field _rescopePicker fun(self: DressingRoom)  re-scope the picker (weapon types + illusions) to the previewed set's class (WeaponPicker.lua)
---@field _applyWeaponTarget fun(self: DressingRoom)  shape the pane for a weapon target + repopulate the list (WeaponPicker.lua)
---@field _applyCosmeticTarget fun(self: DressingRoom)  shape the pane for a shirt/tabard target + repopulate (CosmeticPicker.lua)
local ROWH = 26         -- toggle-button height
local TOPGAP = ROWH + PAD
local PANELSTOP = TOPGAP + ROWH + PAD   -- faction panels sit below TWO control rows (toggles + ratings)

-- Forward-declared so the constructor closure can read DressingRoom.MODEL_INSET
-- (set by the companion DressingRoomSlots.lua) as an upvalue at instantiation.
local DressingRoom
DressingRoom = Class(TitleFrame, function(self)
  -- Split the playable races into the three faction panels (built by _buildRacePanels).
  local alliance, neutral, horde = {}, {}, {}
  for _, r in ipairs(ns.PlayableRaces()) do
    local t = (r.faction == "alliance" and alliance) or (r.faction == "horde" and horde) or neutral
    t[#t + 1] = r
  end
  -- Panel content + border footprint. Alliance/Horde wrap at AHCOLS; Neutral wraps at
  -- 2 columns (3 races → 2-over-1 pyramid, 4 → 2x2), sized to its row count so it grows
  -- as both-faction races are added.
  local function panelDims(n, cols)
    local rws = ceil(n / cols)
    return (cols - 1) * STEP + CELL + 2 * PANELPAD, (rws - 1) * STEP + CELL + 2 * PANELPAD
  end
  local aW, aH = panelDims(#alliance, AHCOLS)
  local hW, hH = panelDims(#horde, AHCOLS)
  local nW, nH = panelDims(#neutral, 2)
  local panelsH = max(aH, hH, nH)
  -- two control rows (Undress/Background + ratings) above the faction panels
  local controlsH = PANELSTOP + panelsH + 4
  local winW = max(WINW, GRIDW + 12)

  -- Bottom controls strip: toggle row + the three faction race panels, centered
  -- under the (wider) model.
  local controls = Frame:new{
    parent = self,
    position = {
      BottomLeft  = {self, ui.edge.BottomLeft, (winW - GRIDW) / 2, 6},
      Width = GRIDW, Height = controlsH,
    },
  }

  -- Set id on the right of the title bar (left of the close button), hovering it shows
  -- the master-grid group name this set belongs to — a curation aid for mapping a
  -- previewed set back to its row. Text + tooltip name are set per set in _load. The id
  -- sits clear of the center title text so that strip stays draggable.
  self._idLabel = Label:new{
    parent = self.titlebar,
    fontObj = "GameFontDisableSmall",
    position = { Right = {self.closeButton, ui.edge.Left, -4, 0} },
    text = "",
  }
  self._idLabel._widget:EnableMouse(true)
  self._idLabel._widget:SetScript("OnEnter", function(f)
    if not self._masterName then return end
    GameTooltip:SetOwner(f, "ANCHOR_LEFT")
    GameTooltip:SetText(self._masterName)
    GameTooltip:Show()
  end)
  self._idLabel._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Build the model + slot columns, the on-model overlays, the two control rows, and
  -- the race-selector panels (methods reopened in the companion files). Order matters:
  -- the overlays/slots anchor to self._model, so _buildModel runs first.
  self:_buildModel()
  self:_buildSlots(winW)
  self:_buildOverlays()
  self:_buildWeaponSlots()
  self:_buildControls(controls)
  self:_buildRacePanels(controls, {
    alliance = alliance, neutral = neutral, horde = horde,
    aW = aW, aH = aH, nW = nW, nH = nH, hW = hW, hH = hH, panelsH = panelsH,
  })

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

-- Constants + helpers shared with the build/controls/actions/model companion files.
DressingRoom._k = {
  SELECTED = SELECTED, IDLE = IDLE, selBox = selBox, tierBar = tierBar,
  GRIDW = GRIDW, PAD = PAD, ROWH = ROWH, TOPGAP = TOPGAP, MODELH = MODELH,
  CELL = CELL, STEP = STEP, PANELPAD = PANELPAD, RACEICON_CROP = RACEICON_CROP,
  AHCOLS = AHCOLS, PANELGAP = PANELGAP, PANELSTOP = PANELSTOP, PBORDER = PBORDER,
  ALLIANCE_COLOR = ALLIANCE_COLOR, HORDE_COLOR = HORDE_COLOR, NEUTRAL_COLOR = NEUTRAL_COLOR,
}
