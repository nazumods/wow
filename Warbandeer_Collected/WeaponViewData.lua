---@type Warbandeer_Collected
local ns = select(2, ...)
local floor, max = math.floor, math.max
local ui = ns.ui
local lists = ns.lua.lists
local GameTooltip = GameTooltip

-- Data layer for the Weapons grid (the Armor/Weapons toggle's weapon view). Parallels
-- DataViewData for armor: WeaponRows builds one row per ns.WeaponSources group (name + one
-- cell per weapon TYPE), the cell showing the uncollected-appearance count shaded by
-- completion (green check when every appearance of that type from that source is collected) —
-- the identical renderer as the armor grid. Module functions (not methods) because the base
-- TableFrame calls WeaponRows via GetData during construction, before WeaponView's methods are
-- mixed onto the instance (mirrors CollectedRows).

---@class Warbandeer_Collected
---@field WeaponTypeOrder number[] Enum.TransmogCollectionType grid column order (matches the look-builder + generator)
---@field WeaponTypeAbbr table<number, string> compact column caption per type (full name via the header tooltip)
---@field WeaponTypeName table<number, string> localized full weapon-type name per type
---@field WeaponRows fun(self: WeaponView): table
---@field WeaponVisibleCounts fun(self: WeaponView): number, number, number
---@field WeaponMatches fun(view: WeaponView, grp: table): boolean
---@field ShowWeaponCellTip fun(grp: table, t: number, visuals: number[])
---@field PreviewWeaponCell fun(grp: table, t: number, visuals: number[])

-- Grid column order (main-hand 1H, then 2H, ranged, wand, then off-hands), matching
-- update-sets.ps1 -Weapons and the #596 look-builder.
ns.WeaponTypeOrder = { 13, 14, 15, 16, 17, 20, 21, 22, 24, 23, 28, 25, 27, 26, 12, 18, 19 }
-- Compact 3-char captions so 17 columns stay narrow; the full name is the header tooltip.
ns.WeaponTypeAbbr = { [12] = "Wnd", [13] = "Axe", [14] = "Swd", [15] = "Mce", [16] = "Dgr",
  [17] = "Fst", [18] = "Shd", [19] = "Off", [20] = "2Ax", [21] = "2Sw", [22] = "2Mc",
  [23] = "Stf", [24] = "Plm", [25] = "Bow", [26] = "Gun", [27] = "Xbw", [28] = "Wgl" }
ns.WeaponTypeName = { [12] = "Wand", [13] = "One-Handed Axe", [14] = "One-Handed Sword",
  [15] = "One-Handed Mace", [16] = "Dagger", [17] = "Fist Weapon", [18] = "Shield",
  [19] = "Held In Off-hand", [20] = "Two-Handed Axe", [21] = "Two-Handed Sword",
  [22] = "Two-Handed Mace", [23] = "Staff", [24] = "Polearm", [25] = "Bow", [26] = "Gun",
  [27] = "Crossbow", [28] = "Warglaive" }

-- Same 10-shade red→green completion gradient as the armor grid (DataViewData.shades), so the
-- two views read identically: cell text is the uncollected count tinted by the collected fraction.
local shades = {
  {165/255, 0/255, 38/255, 1}, {215/255, 48/255, 39/255, 1}, {244/255, 109/255, 67/255},
  {253/255, 174/255, 97/255}, {254/255, 224/255, 139/255}, {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255}, {102/255, 189/255, 99/255}, {26/255, 152/255, 80/255},
  {0, 104/255, 55/255},
}
local GreenCheck = { atlas = ns.icons.CheckGreen, atlasSize = false, position = { Center = {}, Size = {13, 13} } }

-- A row's name minus a trailing "(variant)" suffix — the alphabetization key within an expansion.
local function baseName(name) return (name:gsub("%s*%b()%s*$", "")) end

-- A weapon source group passes the active expansion/category filter. Module-level (like armor's
-- `matches`) since WeaponRows runs during base-table construction, before the methods are mixed.
---@param view WeaponView
---@param grp table
---@return boolean
local function matches(view, grp)
  if view._expansion ~= "all" and grp.release ~= view._expansion then return false end
  if view._category ~= "all" and grp.category ~= view._category then return false end
  return true
end
ns.WeaponMatches = matches

---The Weapons grid's row data: one row per ns.WeaponSources group (name + one cell per weapon
---type), sorted by expansion (newest-first by default) then alphabetically. `self` is the
---WeaponView instance (its filter/sort flags drive the output).
---@param self WeaponView
---@return table
function ns.WeaponRows(self)
  local cmap = ns:WeaponCollectedMap()
  local order = {}
  for i = 1, #ns.WeaponSources do
    if matches(self, ns.WeaponSources[i]) then order[#order + 1] = i end
  end
  table.sort(order, function(a, b)
    local ra, rb = ns.WeaponSources[a].release or 0, ns.WeaponSources[b].release or 0
    if ra ~= rb then
      if self._reverse then return ra > rb end
      return ra < rb
    end
    local na, nb = baseName(ns.WeaponSources[a].name), baseName(ns.WeaponSources[b].name)
    if na ~= nb then return na < nb end
    return a < b
  end)
  return lists.map(order, function(srcIdx)
    local grp = ns.WeaponSources[srcIdx]
    local r = {}
    for ci, t in ipairs(ns.WeaponTypeOrder) do
      local visuals = grp.types[t]
      -- A type this source has no weapon of → blank cell.
      if not visuals then
        r[ci] = {}
      else
        local total, coll = #visuals, 0
        for _, v in ipairs(visuals) do if cmap[v] then coll = coll + 1 end end
        local onEnter = function() ns.ShowWeaponCellTip(grp, t, visuals) end
        local onLeave = function() GameTooltip:Hide() end
        local onClick = function() ns.PreviewWeaponCell(grp, t, visuals) end
        -- `_source`/`_type` identify the cell so the dressed-weapon cursor can find it
        -- (the weapon analogue of a cell's setId/classIndex — see WeaponView:HighlightWeaponCell).
        if coll >= total then
          r[ci] = { atlas = GreenCheck.atlas, atlasSize = false, position = GreenCheck.position,
            onEnter = onEnter, onLeave = onLeave, onClick = onClick, _source = grp, _type = t }
        else
          r[ci] = { text = total - coll, justifyH = ui.justify.Center,
            color = shades[max(1, floor(coll / total * 10))], onEnter = onEnter, onLeave = onLeave,
            onClick = onClick, _source = grp, _type = t }
        end
      end
    end
    -- Prepend the name cell (expansion badge + source name), inert — tinsert at 1 shifts the
    -- 17 type cells to columns 2..18, mirroring the armor grid's embedded name column (col 1;
    -- weapons have no lock column since there are no per-character lockouts).
    local icon = ns.ReleaseIcons[grp.release]
    tinsert(r, 1, { text = icon and ("|T%s:0|t %s"):format(icon, grp.name) or grp.name })
    return r
  end)
end

-- Hover tooltip for a weapon cell: the source + type, then each individual appearance in the
-- cell with a collected mark (so the "two daggers" case reads as two named, separately-tracked
-- looks). Cursor-anchored (the cell spans the column; a frame anchor would land off to the side).
-- Weapon item names load async, so a name not yet resolved falls back to the visual id.
---@param grp table
---@param t number
---@param visuals number[]
function ns.ShowWeaponCellTip(grp, t, visuals)
  local cmap = ns:WeaponCollectedMap()
  GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
  GameTooltip:SetText(("%s — %s"):format(grp.name, ns.WeaponTypeName[t] or "?"))
  for i, v in ipairs(visuals) do
    if i > 12 then
      GameTooltip:AddLine(("… and %d more"):format(#visuals - 12), 0.6, 0.6, 0.62)
      break
    end
    local src = ns.WeaponSource(v)
    local name = (src and src.name) or ("Appearance " .. v)
    -- Suffix the boss-drop difficulty (muted gold) so same-named recolours read apart, matching the chooser.
    if src and src.difficulty then name = name .. "  |cffb0a060" .. src.difficulty .. "|r" end
    -- Atlas check/redx (the grid's own icons) render reliably in the tooltip font, unlike a raw
    -- ✓/✗ glyph (which shows as a missing-glyph box).
    local mark = ("|A:%s:12:12|a "):format(cmap[v] and ns.icons.CheckGreen or ns.icons.RedX)
    GameTooltip:AddLine(mark .. name, 1, 1, 1)
  end
  GameTooltip:Show()
end

-- Drill-in: open the shared dressing room previewing a weapon cell's individual looks on the player's
-- character. `set._looks` is the flat list of the cell's looks (each resolved via WeaponSource to its
-- OWN appearance sourceID — what the model renders — plus a representative itemID for the name); the
-- WeaponCellPicker chooser lists them and ↑/↓ steps through them
-- (see _stepWeaponPiece), while ←/→ jumps to the source's adjacent weapon TYPE (see Step) — hence the
-- group carries `_source`/`_type`. A synthetic weapon-cosmetic group (kind="arsenal", weaponCell=true)
-- drives the existing weapon render path. Looks with no resolvable source are skipped.
---@param grp table
---@param t number
---@param visuals number[]
function ns.PreviewWeaponCell(grp, t, visuals)
  local looks = {}
  for _, v in ipairs(visuals) do
    local src = ns.WeaponSource(v)
    if src and src.itemID then
      if not src.name then C_Item.RequestLoadItemDataByID(src.itemID) end   -- name fills in on the chooser/title retry
      looks[#looks + 1] = { visualID = v, itemID = src.itemID, sourceID = src.sourceID,
        difficulty = src.difficulty, isCollected = src.isCollected }
    end
  end
  if #looks == 0 then
    ns.Print("No previewable looks here yet — item data is still loading; hover the cell, then click again.")
    return
  end
  local set = { name = ("%s — %s"):format(grp.name, ns.WeaponTypeName[t] or "Weapon"),
    _looks = looks, _offHand = (t == 18 or t == 19) }   -- Shield / Held-in-off-hand render in the off hand
  local group = { kind = "arsenal", weaponCell = true, name = grp.name, release = grp.release,
    sets = { set }, _source = grp, _type = t }   -- _source/_type let ←/→ step to adjacent weapon types
  ns.ShowDressingRoom(group, set)
end

-- Filter-scoped counts for the header counter: source rows shown, individual weapon appearances
-- across them, and how many of those are collected. Mirrors DataView:VisibleCounts but counts
-- individual appearances (visuals), not type-slots — so it reads "N sources · N appearances · N collected".
---@param self WeaponView
---@return number sources, number appearances, number collected
function ns.WeaponVisibleCounts(self)
  local cmap = ns:WeaponCollectedMap()
  local sources, apps, coll = 0, 0, 0
  for _, grp in ipairs(ns.WeaponSources) do
    if matches(self, grp) then
      sources = sources + 1
      for _, t in ipairs(ns.WeaponTypeOrder) do
        local visuals = grp.types[t]
        if visuals then
          for _, v in ipairs(visuals) do
            apps = apps + 1
            if cmap[v] then coll = coll + 1 end
          end
        end
      end
    end
  end
  return sources, apps, coll
end
