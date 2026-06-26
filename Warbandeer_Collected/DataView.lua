---@type Warbandeer_Collected
local ns = select(2, ...)
local floor, max = math.floor, math.max
local ui, api, Colors = ns.ui, ns.api, ns.Colors
local lists, prepend = ns.lua.lists, ns.lua.lists.prepend
local Class = ns.lua.Class
local TableFrame, Texture, Label = ui.TableFrame, ui.Texture, ui.Label

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

local _arrow = nil
local _selectedRow = nil

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

-- Build the column layout: a zero-width auto-sized name column then one icon column
-- per class. The windowed grid prepends a narrow lock column (the lockout glyph);
-- `embedded` hosts omit it entirely, so the name column is col 1 there and col 2 in
-- the window. Passed in at construction by each host (defaults can't branch on the
-- per-instance `embedded` flag, since the base table consumes colInfo first).
---@param embedded boolean?  true → no lock column (host owns lockouts)
---@return table
local function buildColInfo(embedded)
  local cols = lists.map(ns.icons.classes, function(icon)
    return {
      atlas = icon,
      atlasSize = false,
      width = 28,
      padding = 2,
      justifyH = ui.justify.Center,
      backdrop = {color = Colors.TransparentBlack},
    }
  end)
  if embedded then
    return prepend(cols, { width = 0, backdrop = {color = Colors.TransparentBlack} })
  end
  return prepend(cols,
    { width = 15, backdrop = {color = Colors.TransparentBlack} },  -- lock
    { width =  0, backdrop = {color = Colors.TransparentBlack} })  -- name
end

---Main grid: one row per set group (lock icon + name), one column per class,
---cells show missing-piece counts color-shaded by completion.
---
---Shared by both the standalone /collected window and Warbandeer's embedded
---collected view (single source of truth). `embedded` trims the chrome the host
---window owns: the lock column is dropped (so the name column is col 1, not col 2)
---and the lockout-panel name-click is removed (Warbandeer keeps lockouts in
---/collected's own window). Each host passes its `colInfo` via `BuildColInfo`.
---@class DataView: TableFrame
---@field _reverse boolean? render newest set-group first (defaults true; see ToggleOrder)
---@field _wantedOnly boolean? blank cells for sets that aren't flagged wanted (see ToggleWantedOnly)
---@field _ptr boolean? show the PTR-only "upcoming" sets (ns.PtrSets) instead of live (see SetPtr)
---@field _playerRace number? cached canonical race id the rank pips resolve against
---@field embedded boolean? render trimmed for a host view (no lock column / lockout name-click)
---@field infoTipAnchor fun(cell: Cell): table?  host override for the hover InfoTip anchor (defaults to "above the cell")
---@field onWantedToggle fun(self: DataView)?  host callback fired after a Shift-click wanted toggle (refresh the host's header)
local DataView = Class(TableFrame, function(self)
  -- autoadjust name width (col 1 embedded, col 2 in the window — lock takes col 1)
  local nameCol = self.embedded and 1 or 2
  local w = 0
  for _,r in ipairs(self.cells) do
    if #r > nameCol then
      w = max(w, r[nameCol].label:Width())
    end
  end
  self.cols[nameCol]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
  self:_refreshMarks()   -- the constructor-time update() ran before our override was mixed in
end, {
  headerHeight = 28,
  _reverse = true,   -- default to newest set-group first
  _wantedOnly = false,
  _ptr = false,
  embedded = false,
  GetData = function(self)
    -- Lockouts are window-only chrome; the embedded host omits the lock column.
    local toon = not self.embedded and api:GetCharacterData(api:GetCurrentCharacter())
    -- PTR PREVIEW shows ONLY the upcoming-only delta (ns.PtrSets); off, the live ns.Sets.
    local source = self._ptr and ns.PtrSets or ns.Sets
    -- Display order: source oldest-first by default; _reverse → newest-first. `srcIdx`
    -- indexes `source` (a live group's index is also its ns.Sets index, which the lockout
    -- panel keys off); `dispIdx` is the on-screen row position (row/cell highlight + arrow).
    local order = {}
    for i = 1, #source do order[i] = self._reverse and (#source - i + 1) or i end
    return lists.map(order, function(srcIdx, dispIdx)
      local grp = source[srcIdx]
      local isPtr = self._ptr
      local lock = toon and toon.instances.locks and toon.instances.locks[grp.instance] and toon.instances.locks[grp.instance][grp.difficulty]
      local gsets = ns.db.sets[grp.id]
      -- Always emit a positional cell per class (blank {} where there's no set, e.g.
      -- Evoker in pre-Dragonflight raids). Returning nil would make table.insert drop
      -- the slot, shifting later classes left and leaving stale cells on re-sort.
      local r = lists.map(grp.sets, function(set)
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
              self:_applyCellMarks(cell, set.id)
            end
            if self.onWantedToggle then self:onWantedToggle() end
            ns.RefreshInfoTip()
          else
            ns.ShowDressingRoom(grp, set, self._reverse)
          end
        end
        -- Upcoming (PTR): a muted dot, no count/completion shade.
        if isPtr then
          return {
            setId = set.id,
            text = UPCOMING_GLYPH,
            justifyH = ui.justify.Center,
            color = UPCOMING,
            onEnter = onEnter, onLeave = onLeave, onClick = onClick,
          }
        end
        if isComplete(status) then
          return {
            setId = set.id,
            atlas = GreenCheck.atlas, atlasSize = GreenCheck.atlasSize,
            position = GreenCheck.position,
            onEnter = onEnter, onLeave = onLeave, onClick = onClick,
          }
        end
        return {
            setId = set.id,
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
      -- (badge + name) shows the expansion name via the shared themed tooltip.
      local icon = ns.ReleaseIcons[grp.release]
      local expName = ns.Releases[grp.release]
      local nameText = icon and ("|T%s:0|t %s"):format(icon, grp.name) or grp.name
      local onNameEnter = expName and function(cell)
        ui.tip:ClearLines()
        ui.tip:AddLine(expName)
        ui.tip:AnchorTo(cell, "ANCHOR_RIGHT")
        ui.tip:Show()
      end or nil
      local onNameLeave = expName and function() ui.tip:Hide() end or nil
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
          if _selectedRow == dispIdx then
            self:_clearSelection()
            return
          end
          ns.ShowLockoutView(srcIdx, ns.window, {
            TopRight = {ns.window, ui.edge.TopLeft, -25, 0},
            BottomRight = {ns.window, ui.edge.BottomLeft, -25, 0},
          })
          local row = self.rows[dispIdx]
          if _selectedRow ~= nil then
            self.cells[_selectedRow][2].label:Color(WHITE_FONT_COLOR)
          end
          _selectedRow = dispIdx
          self.cells[dispIdx][2].label:Color(NORMAL_FONT_COLOR:GetRGBA())
          if not _arrow then
            _arrow = Texture:new{
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
          _arrow._widget:SetSize(14, 16)
          _arrow:TopRight(row, ui.edge.TopLeft, -3, -2)
        end,
      })
      return r
    end)
  end,
})

---Flip the raid (row) order between oldest-first (ns.Sets order) and newest-first.
---Clears any active lockout selection first — its row index moves on re-sort — then
---rebuilds the grid in place.
---@return boolean reversed  the new order state
function DataView:ToggleOrder()
  self._reverse = not self._reverse
  if not self.embedded then self:_clearSelection() end
  self.data = self:GetData()
  self:update()
  return self._reverse
end

---Toggle the "wanted only" filter, rebuilding the grid so non-wanted cells blank out.
---@return boolean wantedOnly  the new filter state
function DataView:ToggleWantedOnly()
  self._wantedOnly = not self._wantedOnly
  self.data = self:GetData()
  self:update()
  return self._wantedOnly
end

---Switch between live and PTR ("upcoming") data, rebuilding the grid. Clears any
---active lockout selection first — its row index moves between datasets.
---@param on boolean  true → show ns.PtrSets (upcoming), false → live ns.Sets
---@return boolean ptr  the new mode
function DataView:SetPtr(on)
  self._ptr = on
  if not self.embedded then self:_clearSelection() end
  self.data = self:GetData()
  self:update()
  return self._ptr
end

-- Drop any active lockout-panel row selection (its row index moves on re-sort / a
-- dataset swap): un-highlight the name, hide the arrow, close the panel. Window-only
-- — embedded hosts have no lockout selection (and share these module locals).
function DataView:_clearSelection()
  if _selectedRow and self.cells[_selectedRow] and self.cells[_selectedRow][2] then
    self.cells[_selectedRow][2].label:Color(WHITE_FONT_COLOR)
  end
  _selectedRow = nil
  if _arrow then _arrow:Hide() end
  ns.HideLockoutView()
end

-- Per-cell rating overlays: a gold "wanted" star (top-left) and the tier letter
-- in its tier color (top-right), both lazily created on the cell and reused.
-- Driven entirely by live DB state, so re-applying after any toggle / re-sort is
-- enough — the cell data carries only the setId to look them up by.
local STAR = 11

---@param cell Cell
---@param setId number?
function DataView:_applyCellMarks(cell, setId)
  if setId and ns:IsWanted(setId) then
    if not cell._wantStar then
      cell._wantStar = Texture:new{
        parent = cell, layer = ui.layer.Overlay,
        atlas = ns.WantedIcon, atlasSize = false,
        position = { TopLeft = {1, -1}, Size = {STAR, STAR} },
      }
    end
    cell._wantStar:Show()
  elseif cell._wantStar then
    cell._wantStar:Hide()
  end

  local rank = setId and ns:EffectiveRank(setId, self._playerRace)
  if rank then
    if not cell._rankPip then
      cell._rankPip = Label:new{
        parent = cell, layer = ui.layer.Overlay, fontObj = "GameFontNormalSmall",
        position = { TopRight = {-1, 0} },
      }
    end
    cell._rankPip:Text(rank)
    cell._rankPip:Color(ns.RankColors[rank])
    cell._rankPip:Show()
  elseif cell._rankPip then
    cell._rankPip:Hide()
  end
end

-- Re-apply every cell's overlays from current DB state. Cheap enough to run on
-- every update()/re-sort; cells persist across re-sorts so their overlays do too.
function DataView:_refreshMarks()
  self._playerRace = ns:PlayerRace()
  for r = 1, #self.cells do
    local row = self.cells[r]
    for c = 1, #self.cols do
      local cell = row[c]
      if cell then
        local data = cell.data
        self:_applyCellMarks(cell, type(data) == "table" and data.setId or nil)
      end
    end
  end
end

-- Refresh overlays after the base table (re)builds its cells. The row count varies
-- (PTR PREVIEW swaps the ~live-raid list for the small upcoming list), so follow the
-- variable-height pattern: grow the row pool for any new rows, pad the data out to the
-- pool with blank-string cells so update() overwrites cells left from a larger previous
-- render (PTR's few rows leave the live rows behind), then ResizeRows to hide the dead
-- space below the active rows.
function DataView:update()
  local real = #self.data
  for _ = #self.rows + 1, real do self:addRow{} end
  if real < #self.rows then
    local blank = {}
    for c = 1, #self.cols do blank[c] = "" end
    for i = real + 1, #self.rows do self.data[i] = blank end
  end
  TableFrame.update(self)
  self:ResizeRows(real)
  self:_refreshMarks()
end

-- Column-layout builder, exposed so each host passes its own `colInfo` at
-- construction (windowed = with lock column, embedded = without).
---@param embedded boolean?
---@return table
DataView.BuildColInfo = buildColInfo

-- Max scrollable row-area height (px) before the grid scrolls — shared so the embedded
-- view and the standalone window cap the grid to the same height (same window size).
DataView.MAX_HEIGHT = 460

---@class Warbandeer_Collected
---@field DataView DataView
ns.DataView = DataView

-- Share the grid class with sibling addons (Warbandeer's embedded collected view)
-- via the API global, so the grid is maintained in this one place. api.lua loads
-- first, so the table already exists; consumers build it with `embedded = true`.
_G.WarbandeerCollectedApi.DataView = DataView
