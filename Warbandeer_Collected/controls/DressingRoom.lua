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
local RACEICON_CROP = 0.04   -- fraction cropped off each raceicon edge to hide its baked ring
local STEP  = CELL + 4   -- cell size + gap
local PAD   = 6
local GRIDW = COLS * STEP
local MODELH = 640

-- Race-selector faction panels: Alliance | Neutral | Horde, each in a colored
-- border. Alliance/Horde wrap at AHCOLS columns; Neutral is an inverted pyramid.
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
---@field _scaleSlider Slider  model size slider (per-race correction + user resize)
---@field _scaleLabel Label  scale value readout above the slider
---@field _bg Texture  class-themed backdrop behind the model
---@field _tierBarL Texture  left slot-column difficulty-color gradient bar
---@field _tierBarR Texture  right slot-column difficulty-color gradient bar
---@field _bgBorder Texture  Background-toggle border (gold while active)
---@field _bgEnabled boolean  whether the backdrop is shown
---@field _bgClass string?  current class file for the backdrop (remembered for the toggle)
---@field _bgRetries number?  remaining backdrop-atlas load retries
---@field _group table?  the set-group the previewed set belongs to (Step cycles its sets)
---@field _set table?  the set entry currently previewed
---@field _reverse boolean  grid sort direction at open: true = newest-first, so Up/Down tier nav matches the on-screen order
---@field _classIcon Texture  class icon in the model's upper-left (mirrors the nav pad)
---@field _className string?  localized class name for the icon's hover tooltip
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
  -- Split the playable races into the three faction panels (built far below).
  local alliance, neutral, horde = {}, {}, {}
  for _, r in ipairs(ns.PlayableRaces()) do
    local t = (r.faction == "alliance" and alliance) or (r.faction == "horde" and horde) or neutral
    t[#t + 1] = r
  end
  -- Panel content + border footprint. Alliance/Horde wrap at AHCOLS; Neutral is a
  -- fixed 2-wide inverted pyramid (2 over 1).
  local function panelDims(n, cols)
    local rws = ceil(n / cols)
    return (cols - 1) * STEP + CELL + 2 * PANELPAD, (rws - 1) * STEP + CELL + 2 * PANELPAD
  end
  local aW, aH = panelDims(#alliance, AHCOLS)
  local hW, hH = panelDims(#horde, AHCOLS)
  local nW, nH = STEP + CELL + 2 * PANELPAD, STEP + CELL + 2 * PANELPAD
  local panelsH = max(aH, hH, nH)
  -- one toggle row (Undress / Background) above the faction panels
  local controlsH = TOPGAP + panelsH + 4
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

  -- Tier-color backdrop bars down each slot column: a quality-colored gradient
  -- (reusing the ilvl palette) fading from BARALPHA at the window edge to 0 at the
  -- model edge, keyed to the raid's difficulty. Hosted on their own frame lifted
  -- above the window backdrop (a plain Background texture on self gets buried under
  -- it) but built before the slot columns and held at their frame level, so it draws
  -- beneath the slots — the bars sit behind the slot icons. The white fill is the
  -- base the gradient tints; gradient set per set by _setTierBars. The top anchors to
  -- the title bar (not the model, which sits 6px lower) and the bottom to the frame
  -- bottom, so the bar fills the whole column edge-to-edge with no corner gaps. inset
  -- == one slot column's width, so the inner edge meets the model edge.
  local inset = DressingRoom.MODEL_INSET
  local barLayer = Frame:new{ parent = self, position = { All = true } }
  barLayer:Level(self._model:Level())
  self._tierBarL = Texture:new{
    parent = barLayer, layer = ui.layer.Background, color = {1, 1, 1, 1},
    position = {
      TopRight = {self.titlebar, ui.edge.BottomLeft, inset, 0},
      BottomRight = {self, ui.edge.BottomLeft, inset, 0},
      Width = inset, Hide = true,
    },
  }
  self._tierBarR = Texture:new{
    parent = barLayer, layer = ui.layer.Background, color = {1, 1, 1, 1},
    position = {
      TopLeft = {self.titlebar, ui.edge.BottomRight, -inset, 0},
      BottomLeft = {self, ui.edge.BottomRight, -inset, 0},
      Width = inset, Hide = true,
    },
  }

  -- Paper-doll slot columns, each vertically centered alongside the model.
  self:_buildSlots(winW)

  -- Shared on-model overlay geometry: the directional nav pad (upper-right) is a
  -- PADB cross; the class icon (upper-left) mirrors its NAVSPAN footprint, and both
  -- sit at navLvl so the mouse-enabled ModelScene doesn't hide/eat them. The form
  -- buttons tuck just under the class icon.
  local PADB, PADGAP = 24, 2
  local NAVSPAN = 3 * PADB + 2 * PADGAP   -- nav-cross bounding box (mirrored by the class icon)
  local INSET = 8                          -- corner inset from the model edge
  local navLvl = self._model:Level() + 10

  -- Form toggle: a small floating button row under the class icon, shown only for
  -- two-form races (Worgen/Dracthyr). A reusable pool sized to the most forms any
  -- race has; _setupForms relabels + shows the ones the race uses.
  self._form = 1
  self._formButtons = {}
  local FORMW = 80
  for i = 1, 2 do
    local box = Frame:new{
      parent = self,
      position = { TopLeft = {self._model, ui.edge.TopLeft,
                     INSET + (i - 1) * (FORMW + 4), -(INSET + NAVSPAN + 4)},
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

  -- Race selector: three faction panels (Alliance | Neutral | Horde), each in a
  -- 5px colored border, centered as a unit below the toggle row. Icons match the
  -- logged-in character's gender (the body renders in that gender), with a name-stub
  -- fallback for any race lacking a gendered raceicon atlas.
  local iconSex = UnitSex("player") == 3 and "female" or "male"
  self._race = {}

  -- One race icon at panel-relative (xoff, yoff).
  local function raceIcon(panel, race, xoff, yoff)
    local box = Frame:new{
      parent = panel, position = { TopLeft = {xoff, -yoff}, Width = CELL, Height = CELL },
    }
    self._race[race.id] = { border = selBox(box) }
    -- Prefer the higher-fidelity raceicon128 atlas, falling back to the standard
    -- raceicon, then a name stub. Both bake in a white/metal ring, so crop the outer
    -- RACEICON_CROP fraction off each edge (a texcoord inset) to show only the face
    -- inside our own selBox border — no ring (issue #114).
    local atlas = "raceicon128-" .. race.file .. "-" .. iconSex
    if not GetAtlasInfo(atlas) then
      atlas = "raceicon-" .. race.file .. "-" .. iconSex
    end
    local info = GetAtlasInfo(atlas)
    if info then
      -- Draw the atlas's sheet region directly (SetTexture + SetTexCoord) rather than
      -- SetAtlas — SetTexCoord after SetAtlas doesn't crop reliably. Then inset the
      -- coords by RACEICON_CROP to drop the baked ring.
      local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
      local cx, cy = (r - l) * RACEICON_CROP, (b - t) * RACEICON_CROP
      local tex = Texture:new{ parent = box, layer = ui.layer.Artwork,
        position = { TopLeft = {1, -1}, BottomRight = {-1, 1} } }
      tex:Texture(info.file or info.filename)
      tex:Coords(l + cx, r - cx, t + cy, b - cy)
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

  -- A faction panel: a frame with a PBORDER-thick colored outline (four edge
  -- textures) at (x, y) in `controls`.
  local function factionPanel(x, y, w, h, color)
    local panel = Frame:new{
      parent = controls, position = { TopLeft = {x, -y}, Width = w, Height = h },
    }
    local function edge(pos) Texture:new{ parent = panel, layer = ui.layer.Border, color = color, position = pos } end
    edge{ TopLeft = {0, 0}, TopRight = {0, 0}, Height = PBORDER }
    edge{ BottomLeft = {0, 0}, BottomRight = {0, 0}, Height = PBORDER }
    edge{ TopLeft = {0, 0}, BottomLeft = {0, 0}, Width = PBORDER }
    edge{ TopRight = {0, 0}, BottomRight = {0, 0}, Width = PBORDER }
    return panel
  end

  local function fillGrid(panel, list, cols)
    local rem = #list % cols                 -- icons in a short final row (0 = full)
    local lastRow = ceil(#list / cols) - 1
    for i, race in ipairs(list) do
      local col, row = (i - 1) % cols, floor((i - 1) / cols)
      -- Center the final row when it doesn't fill all columns.
      local xshift = (rem > 0 and row == lastRow) and (cols - rem) * STEP / 2 or 0
      raceIcon(panel, race, PANELPAD + col * STEP + xshift, PANELPAD + row * STEP)
    end
  end

  local leftX = (GRIDW - (aW + PANELGAP + nW + PANELGAP + hW)) / 2

  local aPanel = factionPanel(leftX, TOPGAP + (panelsH - aH) / 2, aW, aH, ALLIANCE_COLOR)
  fillGrid(aPanel, alliance, AHCOLS)

  -- Neutral: inverted pyramid — 2 on top, 1 centered below.
  local nPanel = factionPanel(leftX + aW + PANELGAP, TOPGAP + (panelsH - nH) / 2, nW, nH, NEUTRAL_COLOR)
  local pyramid = { {0, 0}, {1, 0}, {0.5, 1} }
  for i, race in ipairs(neutral) do
    local p = pyramid[i] or {i - 1, 0}
    raceIcon(nPanel, race, PANELPAD + p[1] * STEP, PANELPAD + p[2] * STEP)
  end

  local hPanel = factionPanel(leftX + aW + PANELGAP + nW + PANELGAP, TOPGAP + (panelsH - hH) / 2, hW, hH, HORDE_COLOR)
  fillGrid(hPanel, horde, AHCOLS)

  -- Class icon in the model's upper-left, mirroring the directional nav pad's
  -- upper-right placement and overall size. Boxed in a frame at navLvl so it draws
  -- above the ModelScene (a bare titlebar/self texture would sit behind it).
  local classBox = Frame:new{
    parent = self,
    position = { TopLeft = {self._model, ui.edge.TopLeft, INSET, -INSET}, Size = {NAVSPAN, NAVSPAN} },
  }
  classBox:Level(navLvl)
  self._classIcon = Texture:new{
    parent = classBox, layer = ui.layer.Artwork,
    position = { All = true },
  }
  -- Hover tooltip naming the class (matches the race icons). _className is set by
  -- _showClass; skip when there's no class icon to describe.
  classBox._widget:EnableMouse(true)
  classBox._widget:SetScript("OnEnter", function(f)
    if not self._className then return end
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    GameTooltip:SetText(self._className)
    GameTooltip:Show()
  end)
  classBox._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Directional nav pad in the model's upper-right corner: Left/Right cycle the
  -- group's class sets (skipping empty slots), Up/Down cycle the raid's difficulty
  -- tiers — same as the arrow keys. Parented to self and lifted above the
  -- mouse-enabled ModelScene (which would otherwise eat the clicks) so the buttons
  -- are clickable, matching the form buttons / scale slider.
  local function navButton(col, row, glyph, onClick)
    local box = Frame:new{
      parent = self,
      position = {
        TopRight = {self._model, ui.edge.TopRight,
          -((2 - col) * (PADB + PADGAP) + INSET), -(row * (PADB + PADGAP) + INSET)},
        Width = PADB, Height = PADB,
      },
    }
    selBox(box)
    Button:new{ parent = box, position = { All = true }, glow = false, OnClick = onClick }
    Label:new{ parent = box, justifyH = ui.justify.Center, fontObj = "GameFontNormalLarge",
      position = { Left = {1, 0}, Right = {-1, 0} }, text = glyph }
    box:Level(navLvl)
    return box
  end
  navButton(1, 0, "^", function() self:StepTierVisual(-1) end)  -- up = tier above in the grid
  navButton(0, 1, "<", function() self:Step(-1) end)
  navButton(2, 1, ">", function() self:Step(1) end)
  navButton(1, 2, "v", function() self:StepTierVisual(1) end)   -- down = tier below in the grid

  -- Left/Right cycle the class sets, Up/Down cycle difficulty tiers (mirroring the
  -- on-model nav pad); Up/Down call StepTier. Every other key is
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
      self:StepTierVisual(-1)
    elseif key == "DOWN" then
      f:SetPropagateKeyboardInput(false)
      self:StepTierVisual(1)
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
  _reverse = true,   -- matches DataView's newest-first default until ShowDressingRoom says otherwise
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

-- The race's resolved RaceModels entry for the current form (multi-form races
-- read through the selected form; single-form races are the entry itself).
---@return table?
function DressingRoom:_resolvedForm()
  local entry = ns.RaceModels[self._raceID]
  return entry and (entry.forms and entry.forms[self._form] or entry)
end

---@param raceID number
function DressingRoom:SetRace(raceID)
  if self._raceID == raceID then return end
  self:_highlightRace(raceID)
  self._raceID = raceID
  self:_setupForms(ns.RaceModels[raceID])
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
  -- The body always renders as the logged-in character's gender (it can't be
  -- overridden), and the race defaults to theirs until one is picked. Seed both
  -- here so a per-sex / per-race `scale` always resolves, regardless of how Dress
  -- was reached (the open path doesn't always run _defaultToPlayer).
  if not self._raceID then self._raceID = select(3, UnitRace("player")) end
  self._sex = UnitSex("player")
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

  -- Set the scale BEFORE the re-skin: `Model:Unit` arms the re-apply machinery
  -- (load callback + backstop) right then, and a synchronous load (e.g. the
  -- logged-in character's own race on first open, already in memory) re-applies
  -- immediately — so `_scale` must already be correct or the model renders at the
  -- previous/default size until the next race change. `scale` may be a number (both
  -- genders) or a per-sex table { [2]=, [3]= }.
  local scale = form and form.scale
  if type(scale) == "table" then scale = scale[self._sex] end
  scale = scale or 1
  m:Scale(scale)                  -- per-race size correction; re-applied post re-skin
  self._scaleSlider:Value(scale)  -- reflect the race's scale in the slider/readout

  -- A form may override the render race (Worgen's "Human" form → race 1, rendered
  -- as a plain Human); otherwise render the selected race.
  m:Unit("player", (form and form.race) or self._raceID)
end

-- Point the title-bar class icon at the class in column `classId` (hidden if the
-- id is missing or has no class icon). `group.sets` is positional — the array
-- index is the classId — so callers pass the set's index, not `set.classId`
-- (which is only populated for the earliest groups).
---@param classId number?
function DressingRoom:_showClass(classId)
  local name, file
  if classId then name, file = GetClassInfo(classId) end
  self._className = name   -- localized class name for the icon's hover tooltip
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

-- Point the model backdrop at the class's dressing-room background (hidden when the
-- toggle is off). Setting the atlas once on a class change is hit-or-miss — it
-- renders blank while the texture streams in (and `GetAtlasInfo` can briefly read
-- nil) — so `_applyBackground` re-asserts it on a short timer across a ~0.6s window
-- (each `Atlas` call forces a render refresh), catching it whenever it resolves.
---@param classFile string?  lowercased class file (e.g. "warrior")
function DressingRoom:_setBackground(classFile)
  self._bgClass = classFile
  if self._bgEnabled and classFile then
    self._bgRetries = 12               -- ~0.6s of re-asserts while the texture loads
    self:_applyBackground(classFile)
  else
    self._bg:Hide()
  end
end

-- Re-assert the class backdrop, re-running on a 50ms timer across the retry window
-- (not stopping at the first success — the texture can still render blank for a
-- frame or two after the atlas resolves). Bails if the class changed underneath us
-- or the toggle went off, so a stale tick can't reveal the wrong/old backdrop.
---@param classFile string  lowercased class file
function DressingRoom:_applyBackground(classFile)
  if self._bgClass ~= classFile or not self._bgEnabled then return end
  local atlas = "dressingroom-background-" .. classFile
  if GetAtlasInfo(atlas) then
    self._bg:Atlas(atlas, false)   -- false = stretch to the model rect; re-assert forces a refresh
    self._bg:Show()
  end
  if self._bgRetries > 0 then
    self._bgRetries = self._bgRetries - 1
    self:delay(50, function() self:_applyBackground(classFile) end)
  end
end

-- Color the slot-column backdrop bars for the raid's difficulty tier (parsed from
-- the group name). Each bar fades from BARALPHA at its outer window edge to 0 at the
-- inner model edge.
---@param groupName string?  the set-group's name (carries the "(Difficulty)" suffix)
function DressingRoom:_setTierBars(groupName)
  local c, outerA, innerA = tierBar(groupName)
  local outer = CreateColor(c.r, c.g, c.b, outerA)
  local inner = CreateColor(c.r, c.g, c.b, innerA)
  self._tierBarL:Gradient("HORIZONTAL", outer, inner)   -- window edge → model edge
  self._tierBarR:Gradient("HORIZONTAL", inner, outer)   -- model edge → window edge
  self._tierBarL:Show()
  self._tierBarR:Show()
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
  self:_setTierBars(group.name)
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

-- Step tiers by on-screen direction (-1 = the row above, +1 = below). The grid
-- can render newest-first (ns.Sets order reversed), so a visual "up" is a forward
-- data step there; mirror DataView's current `_reverse` so the arrows track what
-- the user sees.
---@param vdir number  -1 = move to the tier shown above, +1 = below
function DressingRoom:StepTierVisual(vdir)
  self:StepTier(self._reverse and -vdir or vdir)
end

-- Select the logged-in character's race + gender. Called when the window opens
-- from a closed state, so each fresh open starts on the current character (while
-- it's open, the user's race picks stick). Set before _load so its Dress() renders
-- the right race/gender immediately.
function DressingRoom:_defaultToPlayer()
  local _, _, raceID = UnitRace("player")
  self:_highlightRace(raceID)
  self._raceID = raceID
  self._sex = UnitSex("player")   -- body gender is locked to the char; used for per-sex scale
  self:_setupForms(ns.RaceModels[raceID])
end

local _room

---Open the shared dressing room previewing a class set on a selectable race/gender.
---@class Warbandeer_Collected
---@field ShowDressingRoom fun(group: table, set: table, reverse: boolean?)  group/set are entries from ns.Sets; reverse mirrors the grid sort so Up/Down tier nav matches the on-screen order
ns.ShowDressingRoom = function(group, set, reverse)
  if not _room then _room = DressingRoom:new{} end

  -- Track the grid's sort direction so the tier arrows match what the user sees.
  _room._reverse = reverse ~= false

  -- Reset to the current character's race on a fresh open — the first ever (no race
  -- picked yet) or a reopen after closing; clicking another cell while it's already
  -- open keeps the chosen race. The IsShown check alone misses the first open (the
  -- frame is shown on creation), so also seed when `_raceID` is still unset.
  if not _room._raceID or not _room._widget:IsShown() then _room:_defaultToPlayer() end

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

---Dev: dump the open preview's scale state, to tell a wrong value from a wrong
---application (`/collected scale` with no arg).
---@class Warbandeer_Collected
---@field DebugDressScale fun()
ns.DebugDressScale = function()
  if not _room then ns.Print("dressing room not opened yet"); return end
  local form = _room:_resolvedForm()
  ns.Print(("raceID=%s sex=%s form.scale=%s | model:Scale()=%s | slider=%s | shown=%s"):format(
    tostring(_room._raceID), tostring(_room._sex), tostring(form and form.scale),
    tostring(_room._model:Scale()), tostring(_room._scaleSlider:Value()),
    tostring(_room._widget:IsShown())))
end
