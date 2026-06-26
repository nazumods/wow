---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local LabeledBar, FilterDropdown = ns.LabeledBar, ui.FilterDropdown
local theme = ns.theme
local insert = table.insert
local C_TradeSkillUI = C_TradeSkillUI
local D = ns.detail

local DetailView = ns.views.DetailView
local BottomLeft = ui.edge.BottomLeft

-- Grab (or lazily create) a pooled profession panel: icon on the left, a labelled
-- progress bar (skill / max) in the middle, and an intent dropdown on the right
-- whose menu writes through to profIntent for this row's profession / character.
---@return table
function DetailView:_profRow(i)
  local row = self._profRows[i]
  if row then return row end

  local prev = self._profRows[i - 1]
  local panel = Frame:new{
    parent = self,
    background = theme.colors.module,
    position = {
      TopLeft = prev and {prev.panel, BottomLeft, 0, -D.ROW_GAP}
                     or  {self.profHeader, BottomLeft, 0, -8},
      Width  = D.PANEL_W,
      Height = D.ROW_H,
    },
  }
  row = { panel = panel, gearRows = {}, _numGearRows = 0 }

  row.icon = Texture:new{
    parent = panel, layer = ui.layer.Artwork,
    position = { TopLeft = {D.ROW_PAD, -D.ICON_Y}, Width = D.ICON_W, Height = D.ICON_W },
  }
  row.bar = LabeledBar:new{
    parent = panel,
    width = D.BAR_W,
    position = { TopLeft = {D.BAR_X, -D.BAR_Y} },
    -- Click the bar to open that profession's window (no-op for alts you're not on).
    onClick = function()
      if row._skillID then C_TradeSkillUI.OpenTradeSkill(row._skillID) end
    end,
  }
  row.dropdown = FilterDropdown:new{
    parent    = panel,
    options   = D.INTENT_OPTIONS,
    width     = D.DD_W,
    menuWidth = D.DD_W,
    position  = { TopLeft = {D.DD_X, -D.DD_Y} },
    onSelect  = function(_, key)
      ns.data.SetProfIntent(self._char.name, row._skillID, key or nil)
      row.bar:BarColor(D.intentColor(key or nil))
    end,
  }

  self._profRows[i] = row
  return row
end

-- Grab (or lazily create) a pooled profession-gear sub-row for profession block
-- `row`: item name (rarity-coloured, truncated) on the left, the crafted-quality
-- tier icon right-aligned. Parented to the panel, anchored beneath it (or the
-- previous sub-row).
---@return table
function DetailView:_profGearRow(row, j)
  local sub = row.gearRows[j]
  if sub then return sub end

  local c = theme.colors
  local prev = row.gearRows[j - 1]
  local frame = Frame:new{
    parent = row.panel,
    position = {
      TopLeft = prev and {prev.frame, BottomLeft, 0, 0}
                     or  {row.panel, BottomLeft, D.PG_INDENT, -D.PG_TOP_GAP},
      Width  = D.PG_ROW_W,
      Height = D.PG_ROW_H,
    },
  }
  sub = { frame = frame }
  D.attachItemTip(frame)

  -- Crafted-quality tier icon pinned right (vertically centred), name fills the rest.
  sub.tier = Texture:new{
    parent = frame, layer = ui.layer.Artwork,
    position = { Right = {frame, ui.edge.Right, 0, 0}, Width = D.PG_TIER_W, Height = D.PG_TIER_W },
  }
  sub.name = Label:new{
    parent = frame, fontInfo = theme.fonts.body, color = c.muted,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      Left  = {frame, ui.edge.Left, 0, 0},
      Right = {sub.tier, ui.edge.Left, -D.PG_COL_GAP, 0},
    },
  }

  row.gearRows[j] = sub
  return sub
end

-- Populate a visible row for a profession. The panel re-anchors beneath `anchor`
-- (the previous panel or the header — both left-aligned) with `gap` above it; for
-- a panel that follows another, `gap` already includes the previous panel's gear
-- list height, so the panels stay left-aligned while clearing the gear rows that
-- hang below them. Lists this profession's equipped gear beneath the panel.
function DetailView:_showProf(i, prof, anchor, gap)
  local row = self:_profRow(i)
  row._skillID = prof.skillID
  if prof.icon then row.icon:Texture(prof.icon) end

  row.panel:ClearAllPoints()
  row.panel:TopLeft(anchor, BottomLeft, 0, -gap)

  local maxSkill = prof.maxSkill or 0
  local skill = prof.skillLevel or 0
  local value = maxSkill > 0 and (skill .. " / " .. maxSkill) or tostring(skill)
  row.bar:Label(prof.name or ""):Value(value):Fill(maxSkill > 0 and skill / maxSkill or 0)

  local intent = ns.data.GetProfIntent(self._char.name, prof.skillID)
  row.bar:BarColor(D.intentColor(intent))
  row.dropdown:Select(intent or false)
  row.panel:Show()

  -- Profession gear: the tool + accessories equipped in this profession's slots,
  -- listed beneath the panel in inventory-slot order (tool first).
  local profGear = self._char.professions and self._char.professions.gear
                   and self._char.professions.gear[prof.skillID]
  local items = {}
  if profGear and profGear.slots then
    for invSlot, item in pairs(profGear.slots) do
      if item.name or item.link then insert(items, { slot = invSlot, item = item }) end
    end
    table.sort(items, function(a, b) return a.slot < b.slot end)
  end

  local g = 0
  for _, entry in ipairs(items) do
    g = g + 1
    local item = entry.item
    local sub = self:_profGearRow(row, g)
    sub.frame._itemLink = item.link
    sub.name:Text(item.name or "?"):Color(D.rarityColor(item.link))
    if item.tier and item.tier > 0 then
      sub.tier:Atlas(D.tierAtlas(item.tier), false)
      sub.tier:Show()
    else
      sub.tier:Hide()
    end
    sub.frame:Show()
  end
  for j = g + 1, row._numGearRows do row.gearRows[j].frame:Hide() end
  row._numGearRows = g
end
