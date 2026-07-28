---@type Warbandeer_Collected
local ns = select(2, ...)
local ui, api = ns.ui, ns.api
local lists = ns.lua.lists
local Texture = ui.Texture
local GameTooltip = GameTooltip
local DataView = ns.DataView

-- PTR mode marks every existing set "upcoming" rather than counting collected
-- pieces (the live client has no collection data for sets that aren't out yet).
-- A muted blue dot reads as "available to preview, no status" without borrowing
-- the red→green completion gradient.
local UPCOMING = {0.55, 0.70, 0.95, 1}
local UPCOMING_GLYPH = "•"

-- The number of equipment slots a set fills (its "pieces") — the same 9-slot enumeration InfoTip
-- lists — for the PTR count. Only meaningful where the client has the set's data (a PTR/beta client
-- for an upcoming set); on a live client an upcoming set has no sources, so this returns 0 (and the
-- caller shows a dot instead). Raid + PvP sets both resolve via the per-slot source lookup.
---@param setId number
---@return number
function ns.SetPieceCount(setId)
  local n = 0
  for _, slot in ipairs({1, 3, 15, 5, 6, 7, 8, 9, 10}) do
    if #(C_TransmogSets.GetSourcesForSlot(setId, slot) or {}) > 0 then n = n + 1 end
  end
  return n
end

-- A class set counts as fully collected when the scan flagged the base set (true)
-- or every appearance is owned (remaining <= 0). The `or` short-circuits before
-- indexing `status`, so passing the boolean `true` is safe.
local function isComplete(status)
  return status == true or status.collected >= status.total
end

-- Row filtering is `ns.GridMatches` in GridShared.lua — this was a byte-identical copy of the
-- weapon grid's (#770 step 1). Aliased to a local because CollectedRows calls it per group.
local matches = ns.GridMatches

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
  -- Filter + sort is `ns.GridRowOrder` (GridShared.lua, #770 step 13), shared with the weapons grid
  -- and spec-covered — it is the only part of this file that can silently change which rows appear.
  local order = ns.GridRowOrder(self, source, groupWanted)
  return lists.map(order, function(srcIdx, dispIdx)
    local grp = source[srcIdx]
    local isPtr = self._ptr
    local lock = toon and ns.LockedFor(toon, grp)
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
          ns:ToggleWanted(set.id)
          -- Broadcast rather than refresh this grid by hand (#765). The ratings listener
          -- (window.lua) does everything the old local branch did — `_refilter` when wanted-only
          -- so the lockout selection goes with the rows it indexed (#762) and the host refits
          -- (#768 L-7), else scoped marks — and additionally recomputes the filter-scoped counter
          -- (#776) and covers the OTHER grid, the other host, and the dressing room, none of which
          -- a local refresh can reach. Scoped to this set so the click stays cheap.
          ns:NotifyRatingsChanged(set.id)
          -- Still fired: `onWantedToggle` is part of DataView's public hook contract. Both in-repo
          -- hosts are already covered by the broadcast above, so this is for consumers, not them.
          if self.onWantedToggle then self:onWantedToggle() end
          ns.RefreshInfoTip()
        else
          ns.ShowDressingRoom(grp, set, ns.GridHost(self))   -- dock onto this grid's window (#708)
        end
      end
      -- Upcoming (PTR): on a PTR client (where the set is live) the piece count still to come; on a
      -- live client a muted dot — the set has no data there. PTR blue, no completion shade either way.
      -- classIndex (the set's slot in the positional grp.sets) disambiguates the dressed-set cursor:
      -- PvP sets share one base setId across every class of an armour type, so setId alone can't tell
      -- those columns apart (see HighlightSet).
      if isPtr then
        return {
          setId = set.id, classIndex = classIndex,
          text = ns.OnPtr(ns.PtrBuild and ns.PtrBuild.ptr) and ns.SetPieceCount(set.id) or UPCOMING_GLYPH,
          justifyH = ui.justify.Center,
          color = UPCOMING,
          onEnter = onEnter, onLeave = onLeave, onClick = onClick,
        }
      end
      -- A completed set (scan flagged the base set = boolean `true`, or every appearance owned)
      -- shows the green check; otherwise the uncollected count shaded by the collected fraction.
      local collected = status == true and 1 or status.collected
      local total = status == true and 1 or status.total
      return ns.CompletionCell(collected, total, {
        setId = set.id, classIndex = classIndex,
        onEnter = onEnter, onLeave = onLeave, onClick = onClick,
      })
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
            -- rowArea, not the grid (#768 L-9): parented to the grid it wasn't clipped by the
            -- scroll frame, so scrolling the selected row out of view left the arrow drawn over
            -- the column header. `ns.EnsureDressedCursor` parents to rowArea for the same reason —
            -- "so it scrolls with the cells". The anchor still targets the row itself, which is a
            -- child of rowArea, so the positioning is unchanged.
            parent = self.rowArea,
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
---
---Counts what the grid SHOWS in either mode, PTR preview included (#769 L-10) — it reads the same
---`_ptr and ns.PtrSets or ns.Sets` source the row builder does. It used to walk `ns.Sets`
---unconditionally while `matches` returns true for everything under `_ptr`, so a PTR-mode caller got
---the whole live table back, unfiltered. Both in-repo hosts branch to `UpcomingCounts` before
---reaching here, which is why nothing showed it — but this class is exported to Warbandeer, and a
---consumer taking the doc at its word had no warning.
---
---Under PTR the greens are always 0, matching the grid: an upcoming cell renders a piece count (or a
---muted dot on live), never a completion shade, and it renders for every set id — there is no
---collection status to gate it on, so `cells` counts the slots rather than the scanned ones.
---@return number sets, number cells, number green
function DataView:VisibleCounts()
  local sets, cells, green = 0, 0, 0
  local wantedOnly, isPtr = self._wantedOnly, self._ptr
  for _, grp in ipairs(isPtr and ns.PtrSets or ns.Sets) do
    if matches(self, grp) and (not wantedOnly or groupWanted(grp)) then
      sets = sets + 1
      local gsets = ns.db.sets[grp.id]
      for _, set in ipairs(grp.sets) do
        if set.id and (not wantedOnly or ns:IsWanted(set.id)) then
          local s = gsets and gsets[set.id]
          if isPtr then
            cells = cells + 1
          elseif s ~= nil then
            cells = cells + 1
            if isComplete(s) then green = green + 1 end
          end
        end
      end
    end
  end
  return sets, cells, green
end
