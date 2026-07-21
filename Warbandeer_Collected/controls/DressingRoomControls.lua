---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local GameTooltip = GameTooltip
local Frame, Button, Texture, Label = ui.Frame, ui.Button, ui.Texture, ui.Label
local GetAtlasInfo = C_Texture.GetAtlasInfo
local floor, ceil = math.floor, math.ceil
local DressingRoom = ns.DressingRoom

-- The two bottom control rows (Undress/Background + the ratings row) and the
-- three-panel race selector. Reopens the DressingRoom class; called by the constructor.
local k = DressingRoom._k
local selBox, SELECTED = k.selBox, k.SELECTED
local GRIDW, PAD, ROWH, TOPGAP = k.GRIDW, k.PAD, k.ROWH, k.TOPGAP
local CELL, STEP, PANELPAD, RACEICON_CROP = k.CELL, k.STEP, k.PANELPAD, k.RACEICON_CROP
local AHCOLS, PANELGAP, PANELSTOP, PBORDER = k.AHCOLS, k.PANELGAP, k.PANELSTOP, k.PBORDER
local ALLIANCE_COLOR, HORDE_COLOR, NEUTRAL_COLOR = k.ALLIANCE_COLOR, k.HORDE_COLOR, k.NEUTRAL_COLOR

-- Top control row (Undress + Background toggles) + the ratings row (Wanted star,
-- the S/A/B/C/F tier buttons + clear, and the "This race" per-race-override toggle).
---@param controls Frame  the bottom controls strip built by the constructor
function DressingRoom:_buildControls(controls)
  local half = (GRIDW - PAD) / 2

  -- Top control row: Undress (left) + Background toggle (right). Borders go gold
  -- while active.
  local undressBox = Frame:new{
    parent = controls,
    position = { TopLeft = {0, 0}, Width = half, Height = ROWH },
  }
  self._undressBorder = selBox(undressBox)
  Button:new{ parent = undressBox, position = { All = true }, glow = false,
    OnClick = function() self:ToggleUndress() end }
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

  -- ── Ratings row (second control row): Wanted star + tier buttons + per-race
  -- override toggle. All act on the currently-previewed set (self._set); the tier
  -- buttons write the per-race override when "This race" is active, else the
  -- baseline. _refreshRatings (from _load / SetRace) syncs the gold highlights.
  self._raceOnly = false
  self._ratingsBoxes = {}   -- hidden for weapon-cell previews (weapons have no S–F rank row)

  local wantBox = Frame:new{
    parent = controls, position = { TopLeft = {0, -TOPGAP}, Width = 86, Height = ROWH },
  }
  self._wantedBorder = selBox(wantBox)
  self._ratingsBoxes[#self._ratingsBoxes + 1] = wantBox
  Texture:new{ parent = wantBox, layer = ui.layer.Artwork, atlas = ns.WantedIcon, atlasSize = false,
    position = { Left = {6, 0}, Size = {14, 14} } }
  Button:new{ parent = wantBox, position = { All = true }, glow = false,
    OnClick = function() self:ToggleWanted() end }
  Label:new{ parent = wantBox, justifyH = ui.justify.Center,
    position = { Left = {24, 0}, Right = {-4, 0} }, text = "Wanted" }

  -- Tier buttons S A B C F, each tinted its tier color; gold border on the active.
  local TW, tx = 30, 96
  self._rankBtns = {}
  for _, letter in ipairs(ns.Ranks) do
    local box = Frame:new{
      parent = controls, position = { TopLeft = {tx, -TOPGAP}, Width = TW, Height = ROWH },
    }
    self._rankBtns[letter] = { border = selBox(box) }
    self._ratingsBoxes[#self._ratingsBoxes + 1] = box
    Texture:new{ parent = box, layer = ui.layer.Artwork, color = ns.RankColors[letter],
      position = { TopLeft = {2, -2}, BottomRight = {-2, 2} } }
    Button:new{ parent = box, position = { All = true }, glow = false,
      OnClick = function() self:SetRank(letter) end }
    Label:new{ parent = box, justifyH = ui.justify.Center, position = { All = true },
      color = {0.08, 0.08, 0.08}, text = letter }
    tx = tx + TW + 3
  end

  -- Clear tier.
  local clearBox = Frame:new{
    parent = controls, position = { TopLeft = {tx, -TOPGAP}, Width = 24, Height = ROWH },
  }
  selBox(clearBox)
  self._ratingsBoxes[#self._ratingsBoxes + 1] = clearBox
  Button:new{ parent = clearBox, position = { All = true }, glow = false,
    OnClick = function() self:SetRank(nil) end }
  Label:new{ parent = clearBox, justifyH = ui.justify.Center, position = { All = true }, text = "–" }

  -- Per-race override toggle (right-aligned): while gold, tier edits/displays the
  -- override for the selected race instead of the baseline.
  local raceBox = Frame:new{
    parent = controls, position = { TopLeft = {GRIDW - 104, -TOPGAP}, Width = 104, Height = ROWH },
  }
  self._raceOnlyBorder = selBox(raceBox)
  self._ratingsBoxes[#self._ratingsBoxes + 1] = raceBox
  Button:new{ parent = raceBox, position = { All = true }, glow = false,
    OnClick = function() self:SetRaceOnly(not self._raceOnly) end }
  Label:new{ parent = raceBox, justifyH = ui.justify.Center,
    position = { Left = {4, 0}, Right = {-4, 0} }, text = "This race" }
end

-- Race selector: three faction panels (Alliance | Neutral | Horde), centered as a
-- unit below the toggle rows. `d` carries the faction lists + panel dimensions the
-- constructor computed (alliance/neutral/horde, aW/aH/nW/nH/hW/hH, panelsH).
---@param controls Frame
---@param d table
function DressingRoom:_buildRacePanels(controls, d)
  -- Icons match the logged-in character's gender (the body renders in that gender),
  -- with a name-stub fallback for any race lacking a gendered raceicon atlas.
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

  local leftX = (GRIDW - (d.aW + PANELGAP + d.nW + PANELGAP + d.hW)) / 2

  local aPanel = factionPanel(leftX, PANELSTOP + (d.panelsH - d.aH) / 2, d.aW, d.aH, ALLIANCE_COLOR)
  fillGrid(aPanel, d.alliance, AHCOLS)

  -- Neutral: a 2-wide grid with the short final row centered — 3 races render as the
  -- classic 2-over-1 pyramid, 4 as a 2x2 (5+ would keep wrapping). fillGrid handles the
  -- centering, so this stays correct as Blizzard adds both-faction races (Haranir, …).
  local nPanel = factionPanel(leftX + d.aW + PANELGAP, PANELSTOP + (d.panelsH - d.nH) / 2, d.nW, d.nH, NEUTRAL_COLOR)
  fillGrid(nPanel, d.neutral, 2)

  local hPanel = factionPanel(leftX + d.aW + PANELGAP + d.nW + PANELGAP, PANELSTOP + (d.panelsH - d.hH) / 2, d.hW, d.hH, HORDE_COLOR)
  fillGrid(hPanel, d.horde, AHCOLS)
end
