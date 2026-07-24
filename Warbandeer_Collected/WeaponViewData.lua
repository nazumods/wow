---@type Warbandeer_Collected
local ns = select(2, ...)
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
---@field WeaponTypeAbbr table<number, string> compact column caption per type (icon fallback / full name via the header tooltip)
---@field WeaponTypeName table<number, string> localized full weapon-type name per type
---@field WeaponTypeIcon table<number, string> column-header icon texture path per type
---@field WeaponUsableTypes fun(): table<number, boolean> logged-in class's usable weapon types (greying hint)
---@field WeaponRows fun(self: WeaponView): table
---@field WeaponVisibleCounts fun(self: WeaponView): number, number, number
---@field WeaponMatches fun(view: WeaponView, grp: table): boolean
---@field ShowWeaponCellTip fun(grp: table, t: number, visuals: number[])
---@field PreviewWeaponCell fun(grp: table, t: number, visuals: number[], host: TitleFrame?)

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
-- Column-header icons: house-style white silhouettes (tools/make_weapon_type_icons.py), one per
-- type. BuildColInfo renders them as a real texture header (`path` + `vertexColor`), so the icon can
-- carry a tint — full white for a usable type, dimmed for one the class can't wield (#690 greying).
local WTEX = [[Interface\AddOns\Warbandeer_Collected\textures\weapons\]]
ns.WeaponTypeIcon = { [12] = WTEX .. "wand", [13] = WTEX .. "axe", [14] = WTEX .. "sword",
  [15] = WTEX .. "mace", [16] = WTEX .. "dagger", [17] = WTEX .. "fist", [18] = WTEX .. "shield",
  [19] = WTEX .. "offhand", [20] = WTEX .. "axe2h", [21] = WTEX .. "sword2h", [22] = WTEX .. "mace2h",
  [23] = WTEX .. "staff", [24] = WTEX .. "polearm", [25] = WTEX .. "bow", [26] = WTEX .. "gun",
  [27] = WTEX .. "crossbow", [28] = WTEX .. "warglaive" }

-- Weapon types the LOGGED-IN character's class can transmog — the same capability the look builder
-- reads (ns.WeaponCategories). The grid greys types this class can't wield as a display HINT (not a
-- filter — the columns stay, their header + cells just dim): a caster's grid showing Two-Handed Axes
-- at full strength is noise. Cached; a character's class is fixed for the session (resets on /reload).
local _usableTypes
function ns.WeaponUsableTypes()
  if _usableTypes then return _usableTypes end
  _usableTypes = {}
  for _, cat in ipairs(ns.WeaponCategories(select(3, UnitClass("player")))) do
    _usableTypes[cat.category] = true
  end
  return _usableTypes
end

-- The completion cell (green check / count + red→green shade), the expansion sort, and the shared
-- gradient live in GridShared.lua (ns.CompletionCell / sortByExpansion) — identical to the armor grid.

-- PTR PREVIEW cell colour: a muted blue reads as "upcoming, no status" (the live client has no
-- collection data for unreleased weapons), mirroring the armor grid's upcoming dot (DataViewData).
local UPCOMING = {0.55, 0.70, 0.95, 1}

-- A weapon source group passes the active expansion/category filter. Module-level (like armor's
-- `matches`) since WeaponRows runs during base-table construction, before the methods are mixed. PTR
-- preview is never filtered (small upcoming-only list), so the dropdowns apply to the live grid only.
---@param view WeaponView
---@param grp table
---@return boolean
local function matches(view, grp)
  if view._ptr then return true end
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
  local ptr = self._ptr
  local source = ptr and ns.WeaponPtrSources or ns.WeaponSources   -- PTR preview swaps the whole source
  local cmap = (not ptr) and ns:WeaponCollectedMap() or nil         -- upcoming weapons aren't obtainable yet, so no collected state to track
  local usable = ns.WeaponUsableTypes()   -- greying hint: types this class can't wield are muted
  local GREYED = {0.42, 0.42, 0.45, 1}    -- one shared muted colour for every unusable-type cell
  local order = {}
  for i = 1, #source do
    if matches(self, source[i]) then order[#order + 1] = i end
  end
  ns.sortByExpansion(order, source, self._reverse)
  return lists.map(order, function(srcIdx)
    local grp = source[srcIdx]
    local r = {}
    for ci, t in ipairs(ns.WeaponTypeOrder) do
      local visuals = grp.types[t]
      -- A type this source has no weapon of → blank cell.
      if not visuals then
        r[ci] = {}
      elseif ptr then
        -- PTR PREVIEW: on a PTR client (where these are live) show how many UPCOMING appearances of
        -- this type are coming; on a live client show a muted dot — they aren't obtainable until the
        -- patch lands, so there's no collected/remaining state to shade. PTR blue either way, no class
        -- greying. Clickable: on the PTR the looks resolve and open the dressing room; on live it notes.
        r[ci] = { text = ns.OnPtr(ns.WeaponPtrBuild and ns.WeaponPtrBuild.ptr) and #visuals or "•", justifyH = ui.justify.Center, color = UPCOMING,
          onEnter = function() ns.ShowWeaponCellTip(grp, t, visuals) end,
          onLeave = function() GameTooltip:Hide() end,
          onClick = function() ns.PreviewWeaponCell(grp, t, visuals, ns.GridHost(self), true) end,
          _source = grp, _type = t }
      else
        local total, coll = #visuals, 0
        for _, v in ipairs(visuals) do if cmap[v] then coll = coll + 1 end end
        local onEnter = function() ns.ShowWeaponCellTip(grp, t, visuals) end
        local onLeave = function() GameTooltip:Hide() end
        local onClick = function() ns.PreviewWeaponCell(grp, t, visuals, ns.GridHost(self)) end   -- dock onto this grid's window (#708)
        -- `_source`/`_type` identify the cell so the dressed-weapon cursor can find it
        -- (the weapon analogue of a cell's setId/classIndex — see WeaponView:HighlightWeaponCell).
        local cell = ns.CompletionCell(coll, total, {
          onEnter = onEnter, onLeave = onLeave, onClick = onClick, _source = grp, _type = t,
        })
        -- Display hint: a class that can't wield this weapon type gets a muted cell so the whole
        -- column recedes — the red→green count shade (and the green check, if the renderer tints it)
        -- flattens to grey. Only the paint changes; the count/collected data is untouched.
        if not usable[t] then cell.color = GREYED end
        r[ci] = cell
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
  -- A curated "where from" line, carried only by the arsenal rows (data/arsenals.lua). The
  -- generated rows are named for their source already — "Black Temple" says where it drops — but an
  -- arsenal is named for the bundle, so without this the move out of the armour grid would lose the
  -- one thing that row was telling you (#653).
  if grp.obtain then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("How to obtain", 1, 0.82, 0)
    GameTooltip:AddLine(grp.obtain, 0.7, 0.7, 0.7, true)
  end
  GameTooltip:Show()
end

-- Drill-in: browse a weapon cell's individual looks on the shared dressing room's paper doll — the
-- same one armour is previewed on, with the browsed weapon live in a hand of the composed look
-- (#673). `set._looks` is the flat list of the cell's looks (each resolved via WeaponSource to its
-- OWN appearance sourceID — what the model renders — plus a representative itemID for the name); the
-- WeaponCellPicker chooser lists them and ↑/↓ steps through them (see _stepWeaponPiece), while ←/→
-- jumps to the source's adjacent weapon TYPE (see _stepWeaponType) — hence the group carries
-- `_source`/`_type`, and `_type` is also the category the hand rules read. `weaponCell` is what
-- routes the load to `_loadCell` instead of the armour path. Looks with no resolvable source are
-- skipped.
---@param grp table
---@param t number
---@param visuals number[]
---@param host TitleFrame?  the collection window to dock onto (nil = keep the current dock host)
---@param ptr boolean?  true for a PTR-preview cell — on a live client its appearances don't resolve, so
---                     degrade to the "log into the PTR" note (matching the armor dressing-room fallback)
function ns.PreviewWeaponCell(grp, t, visuals, host, ptr)
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
    -- On the PTR these resolve and preview like any weapon; on a live client the appearance isn't out
    -- yet, so match the armor grid's dressing-room fallback instead of the generic "still loading" note.
    ns.Print(ptr and ('"%s" is upcoming on the PTR — log into the PTR to preview it in 3D.'):format(grp.name)
      or "No previewable looks here yet — item data is still loading; hover the cell, then click again.")
    return
  end
  -- No hand recorded on the set: which one a browsed weapon lands in is `ns.DefaultWeaponHand`'s
  -- answer, derived from `_type` below, so the shield/holdable rule lives in one place with the
  -- rest of the hand rules instead of as a second hard-coded pair of category ids here (#673).
  local set = { name = ("%s — %s"):format(grp.name, ns.WeaponTypeName[t] or "Weapon"), _looks = looks }
  local group = { weaponCell = true, name = grp.name, release = grp.release,
    sets = { set }, _source = grp, _type = t }   -- _source/_type let ←/→ step to adjacent weapon types
  ns.ShowDressingRoom(group, set, host)
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
