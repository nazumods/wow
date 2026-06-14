---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local unpack = unpack
local StatCard = ns.StatCard
local SuggestedBox = ns.SuggestedBox
local theme = ns.theme
local Colors = ns.Colors
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight
local BreakUpLargeNumbers = BreakUpLargeNumbers
local D = ns.detail

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
---@field profHeader Label
---@field gearPanel Frame
---@field gearHeader Label
---@field suggestBox SuggestedBox
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

  -- Gear list down the right column: one row per equipped slot.
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
  self.subtitle:Text((raceList[char.raceIdx] or char.race) .. " " .. char.className)
  self.realm:Text(char.realm)

  local ilvl = (char.equipment and char.equipment.ilvl) or 0
  self.ilvlCard:Amount(string.format("%.1f", ilvl), ns.IlvlColorObj(ilvl))
  local hrs = (char.playtime and char.playtime.total and math.floor(char.playtime.total / 3600)) or 0
  self.playCard:Amount(BreakUpLargeNumbers(hrs) .. " hrs", c.text)

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
  local g, maxNameW, gearRowsH = 0, 0, 0
  for _, slotKey in ipairs(ns.gearSlots) do
    local item = slots[slotKey]
    if item then
      g = g + 1
      gearRowsH = gearRowsH + self:_showGear(g, item, slotKey)
      local w = self._gearRows[g].name:StringWidth()
      if w > maxNameW then maxNameW = w end
      -- The upgrade sub-line starts under the name but may run into the ilvl/track
      -- columns; widen the name column so it isn't truncated.
      local uw = self._gearRows[g].upgrade:StringWidth() - D.GEAR_EXTRAS_W
      if uw > maxNameW then maxNameW = uw end
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

  -- Right column height (gear panel).
  local gearH = D.GEAR_PAD + self.gearHeader:Height()
  if g > 0 then gearH = gearH + D.GEAR_HEADER_GAP + gearRowsH end
  gearH = gearH + D.GEAR_PAD
  self.gearPanel:Height(gearH)
  local rightH = D.CONTENT_TOP + gearH + D.P

  self:Width(D.GEAR_X + D.gearPanelW(nameW) + D.P)
  self:Height(math.max(leftH, rightH))
end

function DetailView:update() end
