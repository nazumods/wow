---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local GameTooltip = GameTooltip
local Frame, Button = ui.Frame, ui.Button
local Texture, Label, Model, Slider = ui.Texture, ui.Label, ui.Model, ui.Slider
local DressingRoom = ns.DressingRoom

-- The 3D model + the on-model overlay widgets (form toggles, scale slider, reset,
-- class/expansion icons, the directional nav pad, arrow-key handling). Reopens the
-- DressingRoom class (defined in DressingRoom.lua); the constructor calls these.
local k = DressingRoom._k
local selBox, MODELH, ROWH = k.selBox, k.MODELH, k.ROWH

-- The model viewer + its class-themed backdrop + the slot-column difficulty bars.
function DressingRoom:_buildModel()
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
end

-- All the widgets that float over the model: the form-toggle row, the scale slider +
-- reset button, the upper-left class icon, the bottom-right expansion badge, the
-- directional nav pad, and the arrow-key handler. All anchor to self._model.
function DressingRoom:_buildOverlays()
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

  -- Scale slider: floats at the bottom-left of the model. A user resize multiplier on
  -- top of the automatic per-race normalization (see Dress); Dress resets it to 1 on
  -- each race change.
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

  -- Reset View: floats just above the scale slider/label at the model's bottom-left.
  -- Restores the camera to its load defaults (facing, zoom, pan) and the scale slider
  -- to 1 — undoing any drag-rotate, pan, wheel-zoom, or resize the user applied.
  local resetBox = Frame:new{
    parent = self,
    position = { BottomLeft = {self._model, ui.edge.BottomLeft, 8, 48}, Width = 100, Height = ROWH },
  }
  selBox(resetBox)
  Button:new{ parent = resetBox, position = { All = true }, glow = false,
    OnClick = function()
      self._model:ResetView()
      self._scaleSlider:Value(1)   -- fires OnChange → resets model scale + label
    end }
  Label:new{ parent = resetBox, justifyH = ui.justify.Center,
    position = { Left = {6, 0}, Right = {-6, 0} }, text = "Reset View" }
  resetBox:Level(self._model:Level() + 10)

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

  -- Expansion badge in the model's bottom-right corner, mirroring the class icon's
  -- upper-left placement and footprint. Boxed at navLvl so it draws above the
  -- ModelScene. Set per set's `release` by _showRelease.
  local expBox = Frame:new{
    parent = self,
    position = { BottomRight = {self._model, ui.edge.BottomRight, -INSET, INSET}, Size = {NAVSPAN, NAVSPAN} },
  }
  expBox:Level(navLvl)
  self._expIcon = Texture:new{
    parent = expBox, layer = ui.layer.Artwork, position = { All = true },
  }
  expBox._widget:EnableMouse(true)
  expBox._widget:SetScript("OnEnter", function(f)
    if not self._expName then return end
    GameTooltip:SetOwner(f, "ANCHOR_LEFT")
    GameTooltip:SetText(self._expName)
    GameTooltip:Show()
  end)
  expBox._widget:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
end
