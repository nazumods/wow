---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local unpack = unpack
local StatCard = ns.StatCard
local SuggestedBox = ns.SuggestedBox
local ConsumablesBox = ns.ConsumablesBox
local GlyphBox = ns.GlyphBox
local theme = ns.theme
local Colors = ns.Colors
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight
local BreakUpLargeNumbers = BreakUpLargeNumbers
local D = ns.detail
local HUNTER = 3        -- classId; a stable of pets
local WARLOCK = 9       -- classId; the other pet class — summoned demons instead of a stable
local PETS_BTN_H = 28   -- Detail's "Pets"/"Demons" button (toggles the docked roster panel)

-- Header geometry: a faction/role icon column, then a race icon, then the class
-- portrait, then the identity text — all derived from the shared layout metrics.
local FR_X = D.P
local RACE_X = FR_X + D.FR_W + D.HEADER_GAP
local PORTRAIT_X = RACE_X + D.RACE_W + D.HEADER_GAP
local TEXT_X = PORTRAIT_X + D.PORTRAIT + 14
local RACE_Y = D.P + (D.PORTRAIT - D.RACE_W) / 2          -- race icon centred in the portrait band
local ROLE_Y = D.P + D.PORTRAIT - D.FR_W                  -- role icon at the bottom of the band

-- Apply a `{path, coords, vertexColor?}` icon spec (as used by ns.factionIcon /
-- ns.icons role entries) to a plain header Texture, clearing any prior tint.
local function applyIcon(tex, spec)
  tex:Texture(spec.path)
  tex:Coords(unpack(spec.coords))
  if spec.vertexColor then tex:SetVertexColor(unpack(spec.vertexColor)) else tex:SetVertexColor(1, 1, 1) end
  tex:Show()
end

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class DetailView: Frame
---@field _char Character        currently displayed character
---@field _missingEnch table<string, boolean>  slots missing a permanent enchant (per-render)
---@field _enchMismatch table<string, {applied:string, recommended:string, itemID:integer?, enchantID:integer}>  slots with a wrong (non-recommended) enchant, raw incl. accepted (per-render)
---@field _emptySockets table<string, integer>  slots → empty-socket count (per-render)
---@field _gemPrimary string?  recommended unique diamond name (per-render; one socket only)
---@field _gemSecondary string?  recommended fill-gem name (per-render; the other sockets)
---@field _gemPrimaryInfo table?  raw diamond suggestion for the hover tooltip (per-render)
---@field _gemSecondaryInfo table?  raw fill-gem suggestion for the hover tooltip (per-render)
---@field _gemPlaced boolean  whether the one diamond has been recommended yet this render
---@field _profRows table[]      pooled profession rows (each owns a `gearRows` sub-pool)
---@field _numRows integer       number of rows currently visible
---@field _gearRows table[]      pooled equipped-gear rows (right column)
---@field _numGearRows integer   number of equipped-gear rows currently visible
---@field portraitBorder Texture
---@field portrait Texture
---@field badge Texture
---@field level Label
---@field raceIcon Texture
---@field factionIcon Texture
---@field roleIcon Texture
---@field heading Label
---@field subtitle Label
---@field realm Label
---@field ilvlCard StatCard
---@field playCard StatCard
---@field _statCells table[]?  secondary-stat grid cells (lazily built; { key, name, pct, rating })
---@field profHeader Label
---@field gearPanel Frame
---@field gearHeader Label
---@field suggestBox SuggestedBox
---@field consumeBox ConsumablesBox
---@field glyphBox GlyphBox
---@field petsButton Button  Hunter/Warlock; toggles the docked pet/demon roster panel (+ Challenge Tames for Hunters)
---@field petsPanel PetsPanel?  lazily-created docked pet/demon roster (right of the window)
---@field tamesPanel ChallengeTamesPanel?  lazily-created Hunter Challenge-Tames checklist (right of the pets panel)
local DetailView = Class(Frame, function(self)
  local c = theme.colors
  self._char = ns.api:GetCharacterData()
  self._profRows = {}
  self._numRows = 0
  self._gearRows = {}
  self._numGearRows = 0

  -- Faction icon stacked over a role icon, left of the race icon.
  self.factionIcon = Texture:new{
    parent = self, layer = ui.layer.Artwork,
    position = { TopLeft = {FR_X, -D.P}, Width = D.FR_W, Height = D.FR_W },
  }
  self.roleIcon = Texture:new{
    parent = self, layer = ui.layer.Artwork,
    position = { TopLeft = {FR_X, -ROLE_Y}, Width = D.FR_W, Height = D.FR_W },
  }

  -- Race icon, left of the class portrait.
  self.raceIcon = Texture:new{
    parent = self, layer = ui.layer.Artwork,
    position = { TopLeft = {RACE_X, -RACE_Y}, Width = D.RACE_W, Height = D.RACE_W },
  }

  -- Portrait: class icon framed by a class-coloured border, with a level badge.
  self.portraitBorder = Texture:new{
    parent = self, layer = ui.layer.Background,
    position = { TopLeft = {PORTRAIT_X, -D.P}, Width = D.PORTRAIT, Height = D.PORTRAIT },
  }
  self.portrait = Texture:new{
    parent = self, layer = ui.layer.Artwork,
    position = { TopLeft = {PORTRAIT_X + 2, -(D.P + 2)}, Width = D.PORTRAIT - 4, Height = D.PORTRAIT - 4 },
  }
  self.badge = Texture:new{
    parent = self, layer = ui.layer.Overlay, color = {0, 0, 0, 0.65},
    position = {
      BottomLeft  = {self.portrait, BottomLeft, 0, 0},
      BottomRight = {self.portrait, BottomRight, 0, 0},
      Height = 16,
    },
  }
  self.level = Label:new{
    parent = self, layer = ui.layer.Overlay, fontInfo = theme.fonts.caps, color = c.text,
    position = { Center = {self.badge, ui.edge.Center, 0, 0} },
  }

  -- Identity block to the right of the portrait.
  self.heading = Label:new{
    parent = self, fontInfo = theme.fonts.headline,
    position = { TopLeft = {TEXT_X, -(D.P + 6)} },
  }
  self.subtitle = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = c.muted,
    position = { TopLeft = {self.heading, BottomLeft, 0, -4} },
  }
  self.realm = Label:new{
    parent = self, fontInfo = theme.fonts.subcaps, color = c.muted,
    position = { TopLeft = {self.subtitle, BottomLeft, 0, -4} },
  }

  -- Stat strip: Item Level + Playtime (no per-character M+ rating is tracked).
  local cardW = (D.PANEL_W - D.GAP) / 2
  self.ilvlCard = StatCard:new{
    parent = self, caption = "Item Level",
    position = { TopLeft = {D.P, -D.CONTENT_TOP}, Width = cardW, Height = D.STRIP_H },
  }
  self.playCard = StatCard:new{
    parent = self, caption = "Playtime",
    position = { TopLeft = {D.P + cardW + D.GAP, -D.CONTENT_TOP}, Width = cardW, Height = D.STRIP_H },
  }

  self.profHeader = Label:new{
    parent = self, fontInfo = theme.fonts.caps, color = c.muted,
    text = "PROFESSIONS",
    position = { TopLeft = {D.P, -D.PROF_HEADER_Y} },
  }

  -- Gear list down the middle column: one row per equipped slot.
  self.gearPanel = Frame:new{
    parent = self, background = c.module,
    position = { TopLeft = {D.GEAR_X, -D.CONTENT_TOP}, Width = D.gearPanelW(D.GEAR_NAME_MIN), Height = D.STRIP_H },
  }
  self.gearHeader = Label:new{
    parent = self.gearPanel, fontInfo = theme.fonts.caps, color = c.muted,
    text = "GEAR",
    position = { TopLeft = {D.GEAR_PAD, -D.GEAR_PAD} },
  }

  -- Suggested actions, anchored beneath the professions block in OnBeforeShow.
  self.suggestBox = SuggestedBox:new{
    parent = self,
    position = { TopLeft = {D.P, -D.PROF_HEADER_Y}, Width = D.PANEL_W, Height = D.STRIP_H },
  }

  -- Recommended consumables, anchored beneath the gear panel in OnBeforeShow (middle column).
  self.consumeBox = ConsumablesBox:new{
    parent = self,
    position = { TopLeft = {D.GEAR_X, -D.CONTENT_TOP}, Width = D.gearPanelW(D.GEAR_NAME_MIN), Height = D.STRIP_H },
  }

  -- Appearance box (applied glyphs + account barbershop unlocks) — heads the third column,
  -- positioned right of the gear panel in OnBeforeShow.
  self.glyphBox = GlyphBox:new{
    parent = self,
    position = { TopLeft = {D.GEAR_X, -D.CONTENT_TOP}, Width = D.gearPanelW(D.GEAR_NAME_MIN), Height = D.STRIP_H },
  }
  -- The glyph box's spec picker changes its height, so re-run the layout when it switches spec.
  self.glyphBox.onSpecChange = function()
    self:OnBeforeShow()
    if ns.MainWindow then ns.MainWindow:Fit() end
  end

  -- Hunter/Warlock: a button beneath the appearance box that toggles the docked pet/demon roster
  -- panel (self.petsPanel) — a big stable is far too much to inline. Positioned + labelled per
  -- character in OnBeforeShow; hidden for classes with no pet roster.
  self.petsButton = ui.Button:new{
    parent     = self,
    glow       = true,
    background  = theme.colors.module,
    position    = { TopLeft = {D.GEAR_X, -D.CONTENT_TOP}, Width = D.gearPanelW(D.GEAR_NAME_MIN), Height = PETS_BTN_H, Hide = true },
    OnClick     = function()
      local char = self._char
      if not char then return end
      local pp = self:_getPetsPanel()
      pp:Toggle(char)
      -- Keep the Challenge-Tames sibling (Hunter-only) in the same open/closed state as the pets panel.
      if char.classId == HUNTER then
        local tp = self:_getTamesPanel()
        if pp:IsOpen() then tp:Set(char) else tp:Hide() end
      end
    end,
  }
  self.petsButton:TextAlign("CENTER")

  self:Width(D.VIEW_WIDTH)
  self:Height(D.PROF_HEADER_Y + 40)
end, {
  name   = "detail",
  background = theme.colors.window,
})
DetailView.name = "detail"
DetailView._title = "Detail"
ns.views.DetailView = DetailView

-- Select a character to display. Used by the titlebar picker and by clicking a
-- character on the Overview. Updates the picker label, rebuilds the body, and
-- refits the window. No-op if the character is already shown.
---@param toon Character
function DetailView:Select(toon)
  if not toon or self._char == toon then return end
  self._char = toon
  if self._filter and self._filter.label then
    self._filter.label:Text(toon.name .. D.CHEVRON)
  end
  self:OnBeforeShow()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Direct navigation (the rail's Detail glyph or `/wb detail`) always shows the
-- logged-in character with fresh data; a character picked via Select sticks only
-- until the user navigates here directly again.
function DetailView:OnNavigate()
  self._char = ns.api:GetCharacterData()
  if self._filter and self._filter.label then
    self._filter.label:Text(self._char.name .. D.CHEVRON)
  end
end

-- ─── Lifecycle ────────────────────────────────────────────────────────────────

-- Lazily create the docked Pets companion panel: parented to the view (so it hides when Detail is
-- left or the window closes) and anchored to the main window's right edge, mirroring the Bars
-- view's preview/apply companions. Toggled by the Hunter-only "Pets" button.
---@return PetsPanel
function DetailView:_getPetsPanel()
  if not self.petsPanel then
    -- Span the window's right edge top-to-bottom (docked, tracks window height), width set in Set().
    local win = ns.MainWindow or self
    self.petsPanel = ns.PetsPanel:new{
      parent   = self,
      position = {
        TopLeft    = {win, ui.edge.TopRight, 8, 0},
        BottomLeft = {win, ui.edge.BottomRight, 8, 0},
      },
    }
  end
  return self.petsPanel
end

-- Lazily create the Challenge-Tames companion panel, docked to the right of the pets panel (Hunter-
-- only), top-to-bottom so it tracks the window height. Kept in step with the pets panel by the Pets
-- button + OnBeforeShow, so the checklist lives beside the roster instead of buried beneath a big stable.
---@return ChallengeTamesPanel
function DetailView:_getTamesPanel()
  if not self.tamesPanel then
    local anchor = self:_getPetsPanel()
    self.tamesPanel = ns.ChallengeTamesPanel:new{
      parent   = self,
      position = {
        TopLeft    = {anchor, ui.edge.TopRight, 8, 0},
        BottomLeft = {anchor, ui.edge.BottomRight, 8, 0},
      },
    }
  end
  return self.tamesPanel
end

function DetailView:OnBeforeShow()
  local char = self._char
  local c = theme.colors
  local color = Colors[char.classKey] or { 1, 1, 1 }

  local atlas = ns.icons.classes[char.classId]
  if atlas then self.portrait:Atlas(atlas, false) end
  self.portraitBorder:Color(color[1], color[2], color[3], 1)
  self.level:Text(char.basic.level)

  -- Header identity icons: race (gender-aware atlas), faction, and role.
  self.raceIcon:Atlas(D.raceAtlas(char), false)
  applyIcon(self.factionIcon, ns.factionIcon[char.isAlliance])
  local role = char.basic.specialization and char.basic.specialization.role
  local roleSpec = role and ns.icons[role]
  if roleSpec then applyIcon(self.roleIcon, roleSpec) else self.roleIcon:Hide() end

  local h = self.heading:Text(char.name)
  ---@cast h Label
  h:Color(color)
  local raceList = char.isAlliance and ns.api.ALLIANCE_RACES or ns.api.HORDE_RACES
  -- "Human Shadow Priest": race + active spec (when stored) + class. Falls back to
  -- "Human Priest" for an alt scanned before the spec was captured.
  local spec = char.basic.specialization and char.basic.specialization.active
  self.subtitle:Text(("%s %s%s"):format(
    raceList[char.raceIdx] or char.race, spec and (spec .. " ") or "", char.className))
  self.realm:Text(char.realm)

  local ilvl = (char.equipment and char.equipment.ilvl) or 0
  self.ilvlCard:Amount(string.format("%.1f", ilvl), ns.IlvlColorObj(ilvl))
  local hrs = (char.playtime and char.playtime.total and math.floor(char.playtime.total / 3600)) or 0
  self.playCard:Amount(BreakUpLargeNumbers(hrs) .. " hrs", c.text)

  self:_showStats()  -- secondary-stat grid under the cards

  -- The two flexible slots plus Fishing/Cooking, so a main cook/fisher can be set too.
  -- Each panel re-anchors beneath the previous block (panel + its gear list), so the
  -- running Y below tracks the left column's content height for sizing.
  local profs = char.basic.professions or {}
  local i = 0
  local anchor = self.profHeader
  local pendingGap = 8                            -- gap above the next panel
  local profsBottomY = D.PROF_HEADER_Y + self.profHeader:Height()
  for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
    local p = profs[slot]
    if p and p.skillID then
      i = i + 1
      self:_showProf(i, p, anchor, pendingGap)
      profsBottomY = profsBottomY + pendingGap + D.ROW_H
      -- The gear list hangs below the panel; fold its height into the next gap so
      -- the following panel stays left-aligned with this one yet clears the rows.
      local g = self._profRows[i]._numGearRows
      local gearExtent = g > 0 and (D.PG_TOP_GAP + g * D.PG_ROW_H) or 0
      profsBottomY = profsBottomY + gearExtent
      anchor = self._profRows[i].panel
      pendingGap = D.ROW_GAP + gearExtent
    end
  end
  self.profHeader:Text(i == 0 and "NO PROFESSIONS" or "PROFESSIONS")
  for j = i + 1, self._numRows do
    self._profRows[j].panel:Hide()  -- hiding the panel cascades to its gear sub-rows
  end
  self._numRows = i

  -- Gear list (right column): one row per equipped slot, in slot order. The name
  -- column autosizes to the longest equipped item name (clamped to a min/max).
  local slots = (char.equipment and char.equipment.slots) or {}
  self._missingEnch = ns.MissingEnchantSlots(char.name)
  self._emptySockets = ns.EmptySocketSlots(char.name)
  -- Slots whose applied enchant ≠ the recommendation (raw — includes accepted ones); the
  -- gear row shows the note only when not on the accept list, but keeps the right-click
  -- toggle on accepted rows too so an accept can be undone.
  self._enchMismatch = ns.EnchantMismatchSlots(char.name)
  -- The unique-equipped diamond (primary) goes on the *first* empty socket only; every other
  -- socket gets the repeatable secondary gem. `_gemPlaced` tracks the one-diamond placement
  -- across the gear loop below.
  self._gemPrimary, self._gemSecondary = ns.RecommendedGems(char.name)
  self._gemPrimaryInfo, self._gemSecondaryInfo = ns.RecommendedGemsInfo(char.name)
  self._gemPlaced = false
  local g, maxNameW, gearRowsH = 0, 0, 0
  for _, slotKey in ipairs(ns.gearSlots) do
    local item = slots[slotKey]
    if item then
      g = g + 1
      gearRowsH = gearRowsH + self:_showGear(g, item, slotKey)
      local w = self._gearRows[g].name:StringWidth()
      if w > maxNameW then maxNameW = w end
      -- Each sub-line (upgrade / enchant / socket note) starts under the name but runs
      -- toward the ilvl/track columns; widen the name column to the widest so none truncate.
      for _, sub in ipairs(self._gearRows[g].subs) do
        local uw = sub:StringWidth() - D.GEAR_EXTRAS_W
        if uw > maxNameW then maxNameW = uw end
      end
    end
  end
  for j = g + 1, self._numGearRows do
    self._gearRows[j].frame:Hide()
  end
  self._numGearRows = g

  -- Size the name column to content, then the rows / panel / view to match.
  local nameW = math.max(D.GEAR_NAME_MIN, math.min(D.GEAR_NAME_MAX, math.ceil(maxNameW)))
  local innerW = D.gearInnerW(nameW)
  for j = 1, g do self._gearRows[j].frame:Width(innerW) end
  self.gearPanel:Width(D.gearPanelW(nameW))

  -- Suggested box at the bottom of the left column: actionable gear upgrades the
  -- character can equip right now (held / warband bank), priority-ordered. It re-
  -- anchors where the next profession panel would go (`anchor`/`pendingGap`); its
  -- visible gap above the professions content is ROW_GAP (or 8 with no professions).
  self.suggestBox:ClearAllPoints()
  self.suggestBox:TopLeft(anchor, BottomLeft, 0, -pendingGap)
  self.suggestBox:Width(D.PANEL_W)
  local suggH = self.suggestBox:Populate(char)
  local suggExtent = suggH > 0 and ((i > 0 and D.ROW_GAP or 8) + suggH) or 0

  -- Left column height (identity + stats + professions, including each profession's
  -- gear list, plus the suggested box). `profsBottomY` accumulated the professions'
  -- content bottom while laying out rows.
  local leftH = profsBottomY + suggExtent + D.P

  -- Middle column: gear panel height (consumables fold in below).
  local gearH = D.GEAR_PAD + self.gearHeader:Height()
  if g > 0 then gearH = gearH + D.GEAR_HEADER_GAP + gearRowsH end
  gearH = gearH + D.GEAR_PAD
  self.gearPanel:Height(gearH)

  -- Consumables box beneath the gear panel: the spec's recommended flask/potion/food/etc
  -- from ClassCodex (via ShadowsOfUI-Upgrade), each category toggleable in settings. Hidden
  -- (zero height) when that data isn't available or every category is off.
  self.consumeBox:ClearAllPoints()
  self.consumeBox:TopLeft(self.gearPanel, BottomLeft, 0, -D.GAP)
  self.consumeBox:Width(D.gearPanelW(nameW))
  local consH = self.consumeBox:Populate(char)
  local consExtent = consH > 0 and (D.GAP + consH) or 0

  -- ─── Third column (appearance & collections) ───────────────────────────────
  -- The middle column (gear + consumables) can run long, and the appearance box
  -- (class mounts / tomes / applied glyphs) is the tallest block of all — stacked
  -- beneath it, the window grew off the bottom while the left column sat half-empty.
  -- So the appearance box and the pet-roster button move into a third column to the
  -- right of the gear panel, spreading the view across the screen. Col 3 starts at
  -- the gear panel's right edge (the panel autosizes, so its width is only known now).
  local col3X = D.GEAR_X + D.gearPanelW(nameW) + D.GAP

  -- Appearance box at the top of col 3, aligned with the gear panel / stat-card band.
  self.glyphBox:ClearAllPoints()
  self.glyphBox:TopLeft(self, ui.edge.TopLeft, col3X, -D.CONTENT_TOP)
  self.glyphBox:Width(D.APPEAR_W)
  local glyphH = self.glyphBox:Populate(char)

  -- Pet/demon roster: a button (opening the dedicated docked panel) beneath the appearance
  -- box in col 3. The roster itself is too large to inline, so only the button lives here.
  -- Hunters get "Pets — N" (active + stable), Warlocks "Demons — N"; no roster otherwise.
  -- (A pet class always has an appearance box; the no-glyph branch is defensive.)
  local petsExtent = 0
  if char.classId == HUNTER or char.classId == WARLOCK then
    local n, label
    if char.classId == WARLOCK then
      local demons = ns.api:GetDemons(char.name)
      n = demons and #demons.list or 0
      label = n > 0 and ("Demons — " .. n) or "Demons"
    else
      local pets = ns.api:GetPets(char.name)
      n = pets and (#pets.active + #pets.stable) or 0
      label = n > 0 and ("Pets — " .. n) or "Pets"
    end
    self.petsButton:Text(label)
    self.petsButton:ClearAllPoints()
    if glyphH > 0 then
      self.petsButton:TopLeft(self.glyphBox, BottomLeft, 0, -D.GAP)
      petsExtent = D.GAP + PETS_BTN_H
    else
      self.petsButton:TopLeft(self, ui.edge.TopLeft, col3X, -D.CONTENT_TOP)
      petsExtent = PETS_BTN_H
    end
    self.petsButton:Width(D.APPEAR_W)
    self.petsButton:Show()
    if self.petsPanel then self.petsPanel:Refresh(char) end  -- re-point an open panel at the new subject
    -- Keep the Challenge-Tames sibling in step: re-point it for a Hunter, hide it for a Warlock (no tames).
    if self.tamesPanel then
      if char.classId == HUNTER then self.tamesPanel:Refresh(char) else self.tamesPanel:Hide() end
    end
  else
    self.petsButton:Hide()
    if self.petsPanel then self.petsPanel:Hide() end
    if self.tamesPanel then self.tamesPanel:Hide() end
  end

  -- Column heights → the window fits the tallest of the three.
  local col2H = D.CONTENT_TOP + gearH + consExtent + D.P
  local hasCol3 = glyphH > 0 or petsExtent > 0
  local col3H = hasCol3 and (D.CONTENT_TOP + glyphH + petsExtent + D.P) or 0

  -- Reserve the third column's width only when it has content: a class with neither an
  -- appearance box nor a pet roster (e.g. Evoker) keeps the two-column width (gear rightmost).
  local viewW = hasCol3 and (col3X + D.APPEAR_W + D.P)
    or (D.GEAR_X + D.gearPanelW(nameW) + D.P)

  self:Width(viewW)
  self:Height(math.max(leftH, col2H, col3H))
end

function DetailView:update() end
