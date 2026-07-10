---@type Warbandeer_Collected
local ns = select(2, ...)
local floor, max = math.floor, math.max
local ui, api = ns.ui, ns.api
local lists = ns.lua.lists
local Texture = ui.Texture
local GameTooltip = GameTooltip
local DataView = ns.DataView

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  -- Centered, ~one character wide so it lines up with the numeric count cells.
  position = { Center = {}, Size = {13, 13} },
}

-- PTR mode marks every existing set "upcoming" rather than counting collected
-- pieces (the live client has no collection data for sets that aren't out yet).
-- A muted blue dot reads as "available to preview, no status" without borrowing
-- the red→green completion gradient.
local UPCOMING = {0.55, 0.70, 0.95, 1}
local UPCOMING_GLYPH = "•"

-- A class set counts as fully collected when the scan flagged the base set (true)
-- or every appearance is owned (remaining <= 0). The `or` short-circuits before
-- indexing `status`, so passing the boolean `true` is safe.
local function isComplete(status)
  return status == true or status.collected >= status.total
end

-- A row's name without its trailing "(variant)" suffix — the key the grid alphabetizes
-- on within an expansion, so a set's difficulty/variant rows stay grouped (and in their
-- authored order, e.g. Raid Finder→Mythic) rather than scattering by suffix.
local function baseName(name)
  return (name:gsub("%s*%b()%s*$", ""))
end

-- A group passes the active filters. A module-level function (not a method) because
-- CollectedRows runs during the base TableFrame construction — before the subclass's
-- methods are mixed onto the instance. PTR preview is never filtered (small
-- upcoming-only list, no category), so the dropdowns apply to the live grid only.
---@param view DataView
---@param grp table
---@return boolean
local function matches(view, grp)
  if view._ptr then return true end
  if view._expansion ~= "all" and grp.release ~= view._expansion then return false end
  if view._category ~= "all" and grp.category ~= view._category then return false end
  return true
end

-- True if any of the group's class sets is flagged wanted. Row-level test for the
-- "wanted only" filter, which hides whole rows that hold no wanted set (within a
-- shown row, the non-wanted class cells still blank — see the cell builder below).
---@param grp table
---@return boolean
local function groupWanted(grp)
  for _, set in ipairs(grp.sets) do
    if set.id and ns:IsWanted(set.id) then return true end
  end
  return false
end

local shades = {
  {165/255,   0/255,  38/255, 1},
  {215/255,  48/255,  39/255, 1},
  {244/255, 109/255,  67/255},
  {253/255, 174/255,  97/255},
  {254/255, 224/255, 139/255},
  {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255},
  {102/255, 189/255,  99/255},
  { 26/255, 152/255,  80/255},
  {      0, 104/255,  55/255},
}

---The grid's row data: one row per set group (lock + name + one cell per class),
---sorted by expansion (newest-first by default) then alphabetically within an
---expansion. Module function (not a method) because the base TableFrame calls it via
---`GetData` during construction, before the subclass methods are mixed on. `self` is
---the DataView instance (its filter/sort/PTR/embedded flags drive the output).
---@param self DataView
---@return table
function ns.CollectedRows(self)
  -- Lockouts are window-only chrome; the embedded host omits the lock column.
  local toon = not self.embedded and api:GetCharacterData(api:GetCurrentCharacter())
  -- PTR PREVIEW shows ONLY the upcoming-only delta (ns.PtrSets); off, the live ns.Sets.
  local source = self._ptr and ns.PtrSets or ns.Sets
  -- Display order is keyed on **expansion** (`release`), not array position: sets are
  -- appended out of expansion order, so position no longer tracks recency. _reverse
  -- (newest-first, the default) sorts release 12→1, else 1→12; ties break on the source
  -- index so order within an expansion stays stable. `srcIdx` indexes `source` (a live
  -- group's index is also its ns.Sets index, which the lockout panel keys off); `dispIdx`
  -- is the on-screen row position. Groups filtered out by expansion/category are dropped.
  local order = {}
  for i = 1, #source do
    -- Expansion/category filter, plus (when "wanted only" is on) drop whole rows with
    -- no wanted set so the grid shows just the target list, not blanked filler rows.
    if matches(self, source[i]) and (not self._wantedOnly or groupWanted(source[i])) then
      order[#order + 1] = i
    end
  end
  table.sort(order, function(a, b)
    local ra, rb = source[a].release or 0, source[b].release or 0
    if ra ~= rb then
      if self._reverse then return ra > rb end
      return ra < rb
    end
    -- Within an expansion: alphabetical by base name (A→Z regardless of sort direction);
    -- same base name (a set's variant/difficulty rows) falls back to authored order.
    local na, nb = baseName(source[a].name), baseName(source[b].name)
    if na ~= nb then return na < nb end
    return a < b
  end)
  return lists.map(order, function(srcIdx, dispIdx)
    local grp = source[srcIdx]
    local isPtr = self._ptr
    local lock = toon and toon.instances.locks and toon.instances.locks[grp.instance] and toon.instances.locks[grp.instance][grp.difficulty]
    local gsets = ns.db.sets[grp.id]
    -- Always emit a positional cell per class (blank {} where there's no set, e.g.
    -- Evoker in pre-Dragonflight raids). Returning nil would make table.insert drop
    -- the slot, shifting later classes left and leaving stale cells on re-sort.
    local r = lists.map(grp.sets, function(set, classIndex)
      -- Blank class slot (no set for this class in the group).
      if not set.id then return {} end
      -- Live row: only show sets the scan knows about. PTR (upcoming) row: every
      -- entry is "upcoming" (no collection data on this client), so skip the gate.
      local status = gsets and gsets[set.id]
      if not isPtr and not status then return {} end
      -- "Wanted only" blanks the cell (no content/click/marks) for sets that
      -- aren't flagged, so the grid shows just the target list in context.
      if self._wantedOnly and not ns:IsWanted(set.id) then return {} end
      -- Same per-slot source tooltip on every cell, complete or partial — for a
      -- fully-collected set every slot shows green.
      local onEnter = function(cell)
        ns.ShowInfoTip(grp, set, cell, self.infoTipAnchor and self.infoTipAnchor(cell) or {
          BottomRight = {cell, ui.edge.Top, -2, 2},
        })
      end
      local onLeave = function() ns.HideInfoTip() end
      -- Left-click previews the set; Shift-click flags/unflags it as wanted.
      -- Both work for PTR-only sets: wanted is keyed by the globally-unique setId
      -- (the flag survives the set later shipping to live), and the dressing room
      -- resolves the appearance on a PTR client. On live it has no data for an
      -- upcoming set, so ShowDressingRoom prints a "preview on the PTR" hint instead
      -- of opening an empty viewer (see DressingRoom.lua).
      local onClick = function(cell)
        if IsShiftKeyDown() then
          local nowWanted = ns:ToggleWanted(set.id)
          if self._wantedOnly and not nowWanted then
            self.data = self:GetData(); self:update()   -- it left the filtered view
          else
            -- refresh every cell sharing this setId, not just the clicked one, so
            -- sibling class columns of a shared set update their star/pip too
            self:_refreshMarks(set.id)
          end
          if self.onWantedToggle then self:onWantedToggle() end
          ns.RefreshInfoTip()
        else
          ns.ShowDressingRoom(grp, set)
        end
      end
      -- Upcoming (PTR): a muted dot, no count/completion shade.
      -- classIndex (the set's slot in the positional grp.sets) disambiguates the
      -- dressed-set cursor: PvP sets share one base setId across every class of an
      -- armour type, so setId alone can't tell those columns apart (see HighlightSet).
      if isPtr then
        return {
          setId = set.id, classIndex = classIndex,
          text = UPCOMING_GLYPH,
          justifyH = ui.justify.Center,
          color = UPCOMING,
          onEnter = onEnter, onLeave = onLeave, onClick = onClick,
        }
      end
      if isComplete(status) then
        return {
          setId = set.id, classIndex = classIndex,
          atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
          position = GreenCheck.position,
          onEnter = onEnter, onLeave = onLeave, onClick = onClick,
        }
      end
      return {
          setId = set.id, classIndex = classIndex,
          text = status.total - status.collected,
          justifyH = ui.justify.Center,
          color = shades[max(1,floor(status.collected / status.total * 10))],
          onEnter = onEnter,
          onLeave = onLeave,
          onClick = onClick,
        }
    end)
    -- grp.sets can stop short of the newest classes (e.g. no Demon Hunter/Evoker
    -- entry in a Vanilla raid), leaving those columns without a cell. Pad to the
    -- full class count so they get a blank cell and don't keep another row's value
    -- on re-sort.
    for i = #r + 1, #ns.icons.classes do r[i] = {} end
    -- Prefix the name with its expansion badge (inline texture escape, auto-sized to
    -- the font height via :0); the name column auto-sizes to fit it. ReleaseIcons is
    -- parallel to Releases, indexed by the group's release. Hovering the name cell
    -- shows the expansion name in a cursor-anchored tooltip (the cell spans the whole
    -- name, so a frame-anchored tip would land far off to the side).
    local icon = ns.ReleaseIcons[grp.release]
    local expName = ns.Releases[grp.release]
    local nameText = icon and ("|T%s:0|t %s"):format(icon, grp.name) or grp.name
    local onNameEnter = expName and function()
      GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
      GameTooltip:SetText(expName)
      GameTooltip:Show()
    end or nil
    local onNameLeave = expName and function() GameTooltip:Hide() end or nil
    -- Embedded hosts have no lock column or lockout panel — just the group name as
    -- the leading (col 1) cell, inert.
    if self.embedded then
      tinsert(r, 1, { text = nameText, onEnter = onNameEnter, onLeave = onNameLeave })
      return r
    end
    -- Windowed grid: a lock-icon column then the name. The name click opens the
    -- lockout panel, except in PTR mode (srcIdx indexes ns.PtrSets, not ns.Sets, so
    -- there are no lockouts to show), where it's inert.
    -- Render the lock as a real texture, not a `|T…|t` font-escape in a Label — that
    -- escape doesn't fit/measure reliably in the narrow column under a custom font
    -- (it truncated to "|…"); a Texture cell is immune to font + ellipsis truncation.
    tinsert(r, 1, lock and {
      path = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK",
      coords = {0, 0.875, 0, 0.875},
      position = { Center = {}, Size = {12, 12} },
    } or {})
    tinsert(r, 2, {
      text = nameText,
      onEnter = onNameEnter,
      onLeave = onNameLeave,
      onClick = isPtr and function() end or function()
        -- Toggle: clicking the row whose lockouts are already open closes the panel.
        if self._selectedRow == dispIdx then
          self:_clearSelection()
          return
        end
        ns.ShowLockoutView(srcIdx, ns.window, {
          TopRight = {ns.window, ui.edge.TopLeft, -25, 0},
          BottomRight = {ns.window, ui.edge.BottomLeft, -25, 0},
        })
        local row = self.rows[dispIdx]
        if self._selectedRow ~= nil then
          self.cells[self._selectedRow][2].label:Color(WHITE_FONT_COLOR)
        end
        self._selectedRow = dispIdx
        self.cells[dispIdx][2].label:Color(NORMAL_FONT_COLOR:GetRGBA())
        if not self._arrow then
          self._arrow = Texture:new{
            parent = self,
            path = "interface/common/commonicons",
            coords = {
              0.02654,
              0.10273,
              0.2529296875,
              0.5029296875
            },
          }
        end
        self._arrow._widget:SetSize(14, 16)
        self._arrow:TopRight(row, ui.edge.TopLeft, -3, -2)
        self._arrow:Show()  -- re-show: _clearSelection hides it, and SetPoint alone won't
      end,
    })
    return r
  end)
end

---Counts over the currently filtered (matching) groups, so the counter tracks the active
---expansion/category filter: the number of set **rows** shown, the total grid **cells**
---that hold a resolvable set (every green check or red number), and how many of those
---render a **green** check — a fully collected set (`isComplete`, however it got there).
---When "wanted only" is active it mirrors the grid: whole rows with no wanted set are
---skipped, and within a shown row only the wanted class cells count.
---@return number sets, number cells, number green
function DataView:VisibleCounts()
  local sets, cells, green = 0, 0, 0
  local wantedOnly = self._wantedOnly
  for _, grp in ipairs(ns.Sets) do
    if matches(self, grp) and (not wantedOnly or groupWanted(grp)) then
      sets = sets + 1
      local gsets = ns.db.sets[grp.id]
      if gsets then
        for _, set in ipairs(grp.sets) do
          if set.id and (not wantedOnly or ns:IsWanted(set.id)) then
            local s = gsets[set.id]
            if s ~= nil then
              cells = cells + 1
              if isComplete(s) then green = green + 1 end
            end
          end
        end
      end
    end
  end
  return sets, cells, green
end
