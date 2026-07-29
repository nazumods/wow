---@type Warbandeer_Collected
local ns = select(2, ...)
local ui, api = ns.ui, ns.api
local lists = ns.lua.lists
local Texture = ui.Texture
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

---Progress lines for an armour row's name tooltip: how many of the row's class sets are finished, how
---many individual appearances are owned across all of them, and how many are flagged wanted.
---
---Counted over the sets the SCAN knows about (`db.sets[grp.id]`), which is the same gate the cells
---render on — so "7/13 class sets" agrees with the seven cells you can see rather than with how many
---classes the group nominally lists. A set the client can't resolve draws no cell and is counted in
---neither figure.
---
---Wanted is counted over every set id in the group, scanned or not: the flag is keyed by the globally
---unique setId and survives the set being unresolvable on this client, so hiding it here would
---under-report a target list the ★ filter would still act on.
---
---Yields no progress lines at all for a PTR-preview row, and does so by construction rather than by a
---mode check: an upcoming group has no `db.sets` entry, so `classes` stays 0 and the guard below skips
---both figures. That is the right outcome — 0/0 would read as "you own none of this" rather than "this
---isn't out yet" — and the title and expansion · category lines still carry the useful part.
---@param grp table
---@return string[]
function ns.SetGroupInfo(grp)
  local gsets = ns.db.sets[grp.id]
  local classes, complete, coll, total, wanted = 0, 0, 0, 0, 0
  for _, set in ipairs(grp.sets) do
    if set.id then
      if ns:IsWanted(set.id) then wanted = wanted + 1 end
      local status = gsets and gsets[set.id]
      if status then
        classes = classes + 1
        -- `true` is the scan's shorthand for "base set collected", carrying no piece counts — so it
        -- contributes one owned appearance out of one rather than being skipped, which would make a
        -- fully-collected row read 0/0.
        if status == true then
          complete, coll, total = complete + 1, coll + 1, total + 1
        else
          coll, total = coll + status.collected, total + status.total
          if status.collected >= status.total then complete = complete + 1 end
        end
      end
    end
  end
  local out = {}
  if classes > 0 then
    out[#out + 1] = ("%d/%d class sets complete"):format(complete, classes)
    out[#out + 1] = ("%d/%d appearances collected"):format(coll, total)
  end
  if wanted > 0 then
    out[#out + 1] = ("|A:%s:14:14|a %d wanted"):format(ns.WantedIcon, wanted)
  end
  return out
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
      -- aren't flagged, so the grid shows just the target list in context. Off under PTR preview
      -- (ns.WantedOnlyActive) — the upcoming list is a few rows and the dropdowns are bypassed there
      -- too, so the star gutting it was the odd one out.
      if ns.WantedOnlyActive(self) and not ns:IsWanted(set.id) then return {} end
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
    -- The expansion-badged name cell — `ns.GridNameCell`, shared with the weapons grid. Embedded
    -- hosts have no lock column or lockout panel, so it is the leading (col 1) cell there and
    -- click-inert; "inert" is about the CLICK only, and both hover tooltips still apply, which is
    -- what this host is mostly looked at through.
    if self.embedded then
      tinsert(r, 1, ns.GridNameCell(grp, ns.SetGroupInfo))
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
    local nameCell = ns.GridNameCell(grp, ns.SetGroupInfo)
    nameCell.onClick = isPtr and function() end or function()
      -- Toggle: clicking the row whose lockouts are already open closes the panel.
      if self._selectedRow == dispIdx then
        self:_clearSelection()
        return
      end
      ns.ShowLockoutView(srcIdx, ns.window, {
        TopRight = {ns.window, ui.edge.TopLeft, -25, 0},
        BottomRight = {ns.window, ui.edge.BottomLeft, -25, 0},
      })
      -- `dispIdx` and `_selectedRow` are DATA indices, and `cells`/`rows` are keyed by viewport slot
      -- once the grid is virtual — so both lookups go through ns.ResidentCell / ns.ResidentRow. The
      -- previously-selected row may have scrolled out since it was picked, in which case there is
      -- nothing on screen to un-highlight.
      local row = ns.ResidentRow(self, dispIdx)
      local prev = ns.ResidentCell(self, self._selectedRow, 2)
      if prev then prev.label:Color(WHITE_FONT_COLOR) end
      self._selectedRow = dispIdx
      local picked = ns.ResidentCell(self, dispIdx, 2)
      if picked then picked.label:Color(NORMAL_FONT_COLOR:GetRGBA()) end
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
    end
    tinsert(r, 2, nameCell)
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
  local isPtr = self._ptr
  local wantedOnly = ns.WantedOnlyActive(self)   -- never in force under PTR preview
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
