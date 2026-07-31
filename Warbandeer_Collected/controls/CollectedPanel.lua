---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local min, max = math.min, math.max
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local GameTooltip = GameTooltip

-- The whole assembled collection panel: both grids, both filter strips, the Armor/Weapons toggle,
-- the counter + wanted tally, both scroll containers, and the sizing that ties them together.
--
-- **This is the one implementation.** It used to be two — `window.lua` here and
-- `Warbandeer/views/CollectedView.lua` there — which shared the grid CLASSES and nothing else, so
-- every piece of chrome around them existed twice and drifted independently. That is where the two
-- windows' widths came apart: the standalone sized to the active grid with no scrollbar room and no
-- header-chrome floor, the embedded one to the widest grid with both. Neither was wrong on its own
-- terms; they simply weren't the same code. `/collected` is the source of truth and `/wb` consumes
-- it, so the panel lives here and both hosts build it.
--
-- What a host still owns is genuinely host-shaped and nothing else: its own frame (a TitleFrame with
-- a titlebar and a remembered position, or a view inside Warbandeer's window), whether a set name
-- opens the lockout panel, and what to do when the panel resizes. Everything else is here.
--
-- Sizing, since it is the thing that kept diverging:
--   width  = max(widest grid's content + scrollbar room, chrome floor)
--   height = strip + gap + header + capped row area + margin
--
-- The **widest** grid rather than the active one, so an Armor/Weapons swap changes the contents and
-- nothing else; the two grids aren't the same width, and sizing to whichever was up moved the
-- panel's edges on every toggle.
--
-- The chrome floor is the filter strip plus the counter and tally, and it is not optional: those two
-- are FontStrings, and **WoW does not clip a FontString to its parent**. A panel sized to its columns
-- alone doesn't cut them off at its edge, it draws them across whatever is beside it — the model
-- viewer, in the case that surfaced it — which is exactly why it survived review. The floor is
-- derived from `UnboundedWidth` rather than a padding constant so it keeps holding as the counts
-- grow a digit (`5203/12359` is already five).
--
-- Those two labels are anchored to the panel's RIGHT edge, growing leftward, rather than trailing
-- rightward off the filter strip. The floor stops them drawing outside; the anchor stops the floor's
-- extra width reading as dead space beside the last column, by putting the counter in it. Both are
-- needed — the anchor alone would just turn the overflow into an overlap on the dropdowns.

---@class CollectedPanel: Frame
---@field grid DataView  the set-by-class grid (always built)
---@field strip Frame  the armour grid's filter strip
---@field scroll ScrollFrame  scroll container for the armour grid's row area
---@field weaponGrid WeaponView?  the weapon-source grid — nil until the first switch to Weapons
---@field weaponStrip Frame?  the weapon grid's filter strip (built with the grid)
---@field weaponScroll ScrollFrame?  the weapon grid's scroll container (built with the grid)
---@field counter Label  "N sets · N/N collected" (or the PTR "+N upcoming" tally)
---@field wantedCount Label  running "★ N" tally — sets in armor mode, weapon looks in weapons mode
---@field emptyMsg Label  centered "run a scan" message, shown before the first scan
---@field active DataView|WeaponView  the grid currently shown
---@field activeScroll ScrollFrame  the scroll container currently shown
---@field lockouts boolean  enable the lockout name-click on the armour grid (window host only); no longer affects the column layout (#864)
---@field infoTipAnchor fun(cell: Cell): table?  host override for the hover InfoTip anchor; applies to BOTH grids (#856)
---@field onSized fun(self: CollectedPanel)?  fired after the panel resizes, so the host can refit around it
---@field profPrefix string  profiler run-name prefix, so each host's Armor/Weapons swaps are timed apart
---@field scrollbarW number  gutter reserved to the right of the columns for the scroll frame's scrollbar
---@field _top number  grid top offset (filter strip + gap)
---@field _weaponsMode boolean?  true while the weapon grid is the one shown
---@field _modeToggle SegmentedToggle  the persistent Armor|Weapons segmented toggle
---@field _stripX number  filter-strip x offset, clearing the mode toggle; both strips share it
---@field _headerH number  the grid header height, kept for the lazily-built weapon trio
---@field _capH number  the capped row-area height at construction, kept for the same reason
---@field _gridFresh boolean?  one-shot: cells were just built from this data, so the next Render skips its rebuild
---@field _chromeMax number?  widest header chrome measured so far — the floor is monotonic so it can't move with the mode (see _chromeWidth)
local CollectedPanel = Class(Frame, function(self)
  local theme = self:Theme()
  local STRIP_H, GAP = ns.DataView.STRIP_H, 6
  local TOP = STRIP_H + GAP   -- the grid sits below the filter strip
  self._top = TOP

  -- Grids anchor top-LEFT and are padded to the panel's full content width by `_fitToGrid`, so the
  -- slack the header chrome creates lands in the NAME COLUMN — between the row names and the first
  -- data column — rather than as a band at either edge. Anchoring the grid right instead just moves
  -- the same hole from one side to the other; widening the name column is what puts it in the middle,
  -- where it reads as the gutter between a label column and its data.
  self.grid = ns.DataView:new{
    parent = self,
    position = { TopLeft = {0, -TOP} },
    embedded = not self.lockouts,
    -- Viewport virtualisation (#843): build cell frames for the ~25 rows on screen, not all 473. The
    -- grid built 6,622–7,095 cells to show ~5% of them, and that frame count drove the 1.13s build,
    -- ~570ms of engine layout afterwards, and up to 366ms per swap in `UpdateScrollChildRect`.
    virtual = true,
    colInfo = ns.DataView.BuildColInfo(),
    infoTipAnchor = self.infoTipAnchor,
    onWantedToggle = function() self:RefreshWanted() end,
    onFilterChanged = function() self:Render() end,
    onResized = function() self:_fitToGrid() end,
    onEnsureVisible = function(_, rowTop, rowH) ns.EnsureRowVisible(self.scroll, rowTop, rowH) end,
  }

  self.strip = self.grid:BuildFilterStrip(self, function() self:Render() end)
  self.strip:Position({ TopLeft = {0, 0} })
  -- Both dropdowns' option lists walk the whole row source to build themselves, so the strip is a
  -- deferral candidate in its own right rather than a rounding error on the grid (see profile.lua).
  ns.prof:Mark("strip")

  self._headerH = self.grid.headerHeight
  self._capH = min(self.grid.MAX_HEIGHT, self.grid.rowArea:Height())

  self.scroll = ui.ScrollFrame:new{
    parent = self,
    position = { TopLeft = {0, -(TOP + self._headerH)}, Width = self.grid:Width(), Height = self._capH },
  }
  self.scroll:Child(self.grid.rowArea)
  -- Bind AFTER construction, then re-size the pool. The grid builds its data in `onLoad`, inside
  -- `:new{}`, so there is no moment before the data lands at which this scroll frame exists — it needs
  -- the grid's width and row-area height to be created at all. With no viewport bound the first pass
  -- sizes the pool from a zero height and builds `overscan * 2` rows, so the cost of doing it in this
  -- order is ~6 rows rebuilt, against the 473 the eager path built.
  self.grid:BindViewport(self.scroll)
  self.grid:RefreshViewport()
  ns.prof:Mark("scroll")

  -- Counter + tally, anchored to the panel's RIGHT edge and growing leftward (see the header note).
  -- The tally is the rightmost thing in the row, so it is the one pinned to the edge.
  self.wantedCount = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.gold or theme.colors.header,
    position = { TopRight = {self, ui.edge.TopRight, -6, -3} },
    text = "",
  }
  self.counter = Label:new{
    parent = self, fontInfo = theme.fonts.title, color = theme.colors.text,
    position = { TopRight = {self.wantedCount, ui.edge.TopLeft, -16, 0} },
    text = "",
  }

  -- A FontString can't take mouse events, so overlay a transparent frame on each to host its
  -- hover behaviour (anchored to the label, so it tracks the text width).
  local counterHover = Frame:new{
    parent = self,
    position = {
      TopLeft = {self.counter, ui.edge.TopLeft, 0, 0},
      BottomRight = {self.counter, ui.edge.BottomRight, 0, 0},
    },
  }
  counterHover:EnableMouse(true)
  counterHover:SetScript("OnEnter", function(f) self.active:ShowCountTooltip(f) end)
  counterHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- The gold tally toggles WANTED ONLY on click (same as the strip's ★ button), against whichever
  -- grid is up: the two filter different units — sets on one side, individual looks on the other.
  local wantedHover = Frame:new{
    parent = self,
    position = {
      TopLeft = {self.wantedCount, ui.edge.TopLeft, -2, 0},
      BottomRight = {self.wantedCount, ui.edge.BottomRight, 2, 0},
    },
  }
  wantedHover:EnableMouse(true)
  wantedHover:SetScript("OnMouseUp", function() self.active:ToggleWanted() end)
  wantedHover:SetScript("OnEnter", function(f) self.active:ShowWantedTooltip(f) end)
  wantedHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- Shown before the first scan has populated any data. The grid is hidden while it shows, so the
  -- message takes a clear area rather than overlapping the header icons.
  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    justifyH = ui.justify.Center,
    position = { Top = {0, -(TOP + self._headerH + 28)}, Width = self.grid:Width(), Height = 20, Hide = true },
  }

  -- ── Armor / Weapons mode ──────────────────────────────────────────────────
  -- The weapon trio is built on the first switch to Weapons, not here (#770 step 19): it is ~241
  -- rows × 18 columns of Cells that plenty of people never look at. The toggle is eager — it IS the
  -- thing that asks for that grid.
  self.active, self.activeScroll, self._weaponsMode = self.grid, self.scroll, false
  self._modeToggle = ui.SegmentedToggle:new{
    parent = self, height = STRIP_H, selected = "armor",
    options = { { key = "armor", label = "Armor" }, { key = "weapons", label = "Weapons" } },
    position = { TopLeft = {0, 0} },
    onSelect = function(_, key)
      local weapons = key == "weapons"
      self:SetMode(weapons)
      -- Tell the shared dressing room which grid is being browsed, for one rule: a loaded look's
      -- ratings row is hidden, a browsed weapon earns it back, and switching to Armor gives it up
      -- again (#827). From the handler rather than `SetMode`, which early-returns on a repeat click.
      ns.SetGridMode(weapons)
    end,
    -- The toggle can only measure its captions once its fonts are resident and it has been laid
    -- out, so the width read below is a floor rather than the final answer. When it re-measures,
    -- re-place the strips against the real width.
    onResize = function() self:_applyStripX() end,
  }
  self:_applyStripX()
  ns.prof:Mark("chrome")

  self:Render()
  ns.prof:Mark("counter")
  self:_primeChromeFloor()   -- so the first swap to Weapons can't grow the window
  self:_fitToGrid()
  ns.prof:Mark("fit")
  -- The base TableFrame has just built every cell from this data, so the Render that the host's
  -- first show fires would walk all ~6,600 cells to reproduce what is already on them. One-shot:
  -- Render clears it on every path, so only the pass that cannot have new data skips.
  self._gridFresh = true

  self:_registerListeners()
  ns._panels[#ns._panels + 1] = self   -- so `/collected width` can compare the hosts
end, {
  lockouts = false,
  profPrefix = "",
  scrollbarW = 20,   -- gutter reserved for the scroll frame's scrollbar, the same in both hosts
})

---@class Warbandeer_Collected
---@field CollectedPanel CollectedPanel
---@field _panels CollectedPanel[]  every panel built this session, in construction order
ns.CollectedPanel = CollectedPanel
_G.WarbandeerCollectedApi.CollectedPanel = CollectedPanel

-- Every panel built this session, so `/collected width` can dump them side by side. The whole point
-- of the extraction is that the two hosts render the identical panel, and "identical" is a claim
-- worth being able to CHECK rather than infer from a screenshot — the widths came apart twice before
-- anyone could say which term was setting them. Instances only, no classes: at most two exist.
ns._panels = {}

---Where this panel's width comes from, as report lines for `/collected width`.
---
---Every term, not just the answer: knowing the panel is 853 says nothing about which of the two
---candidates to change, and the two want opposite fixes. Both modes are priced whether or not they
---are showing, because the chrome floor moving with the mode is the specific thing in question.
---@return string[]
function CollectedPanel:WidthReport()
  local armor = self.grid.rowArea:Width()
  local weapons = self.weaponGrid and self.weaponGrid.rowArea:Width() or nil
  local content = max(armor, weapons or 0) + self.scrollbarW
  local chrome = self:_chromeWidth()
  local host = ns.GridHost(self.grid)
  local armorChrome = self:_chromeFor(self:_measureCounter(self:_counterText(false)))
  local weaponText = self:_counterText(true)
  local weaponChrome = weaponText and self:_chromeFor(self:_measureCounter(weaponText)) or nil
  local fmt = function(n) return n and ("%.1f"):format(n) or "-" end

  return {
    -- "host" prefix, not the bare host name: this block is meant to be copy-pasted back, and a line
    -- starting with `/` is eaten by the chat client as a slash command ("Unknown command: /wb").
    ("host  %s  [mode %s, lockouts %s]"):format(self.lockouts and "/collected window" or "/wb embedded view",
      self._weaponsMode and "weapons" or "armor", tostring(self.lockouts)),
    ("  content   armor %s | weapons %s | +scrollbar %s"):format(
      fmt(armor), weapons and fmt(weapons) or "not built", fmt(content)),
    ("  chrome    stripX %s | strip %s | counter %s | tally %s"):format(
      fmt(self._stripX), fmt(self.strip:Width()),
      fmt(self.counter:UnboundedWidth()), fmt(self.wantedCount:UnboundedWidth())),
    ("  floor     armor-mode %s | weapons-mode %s | high-water %s"):format(
      fmt(armorChrome), weaponChrome and fmt(weaponChrome) or "weapons grid not built", fmt(chrome)),
    ("  RESULT    bound by %s -> panel %s | host window %s"):format(
      content >= chrome and "CONTENT" or "CHROME", fmt(self:Width()), host and fmt(host:Width()) or "?"),
    -- 34 is the three gaps (12 + 16 + 6); the tally comes off too, since it sits between the
    -- counter and the right edge and the counter cannot borrow its space.
    ("  room for counter after the strip: %s (armor needs %s, weapons %s)"):format(
      fmt(self:Width() - (self._stripX or 0) - self.strip:Width() - 34 - self.wantedCount:UnboundedWidth()),
      fmt(self:_measureCounter(self:_counterText(false))),
      weaponText and fmt(self:_measureCounter(weaponText)) or "-"),
  }
end

-- Live-refresh this panel when a rating changes anywhere (the shared dressing room, the other
-- host's panel, either grid's Shift-click), and follow the dressing room's cell cursor.
--
-- Registered per panel instead of once per file, which is what let each host hand-roll its own
-- version of the same three callbacks. At most two panels ever exist (one per host) and neither is
-- ever rebuilt, so there is nothing to unregister.
function CollectedPanel:_registerListeners()
  ns:OnRatingsChanged(function(setId, visualID)
    -- BOTH grids, not just the shown one: a weapon flagged while Armor is up would otherwise leave
    -- the weapon grid holding a stale wanted-only row set for the next toggle over to it. Each grid
    -- says what the broadcast means for it (#768 L-8) — the two keys are different id spaces, so a
    -- change of one kind skips the other grid entirely rather than walking its cells for nothing.
    for _, grid in ipairs(self:Grids()) do
      local affected, only = grid:_ratingScope(setId, visualID)
      if affected then
        if grid._wantedOnly then grid:_refilter() else grid:_refreshMarks(only) end
      end
    end
    -- Counter + tally only. The loop above already brought every affected grid up to date, and a
    -- rating change can't alter which rows exist unless `_wantedOnly` is on — which is the branch
    -- that just re-filtered. `_gridFresh` is the flag for "the cells are current"; without it Render
    -- would rebuild the active grid a second time on every Shift-click.
    self._gridFresh = true
    self:Render()
  end)
  ns:OnDressedSetChanged(function(setId, classIndex)
    self.grid:HighlightSet(setId, classIndex, true)
  end)
  ns:OnDressedWeaponCellChanged(function(source, weaponType)
    -- Nothing to draw on a grid that was never built. Reaching this at all takes browsing a weapon
    -- cell, which only the Weapons grid offers, so in practice it exists by then.
    if self.weaponGrid then self.weaponGrid:HighlightWeaponCell(source, weaponType, true) end
  end)
end

---Every grid that currently exists, for the callers that refresh "both". The weapon grid is built
---lazily, so before the first switch to Weapons there is only one.
---@return table[]
function CollectedPanel:Grids()
  if self.weaponGrid then return { self.grid, self.weaponGrid } end
  return { self.grid }
end

---Place both filter strips clear of the Armor/Weapons toggle, at the toggle's current width.
---
---Read back rather than declared: the toggle sizes itself to its captions, which is what stopped
---"Weapons" rendering as "Wea…" at a hand-picked 92 (#770 step 12). Re-run from its `onResize`,
---because a caption is only measurable once its font is resident and the panel has been laid out —
---so the width available at construction is a floor, not the answer.
function CollectedPanel:_applyStripX()
  self._stripX = self._modeToggle:Width() + 6
  self.strip:Position({ TopLeft = {self._stripX, 0} })
  if self.weaponStrip then self.weaponStrip:Position({ TopLeft = {self._stripX, 0} }) end
end

---Build the weapon grid + its filter strip and scroll container, once, on the first switch to
---Weapons mode. No-op afterwards, which is why the "refresh both grids" callers go through
---`Grids()` and the dressed-cell listener nil-guards rather than assuming the trio exists.
function CollectedPanel:_ensureWeapons()
  if self.weaponGrid then return end

  self.weaponGrid = ns.WeaponView:new{
    parent = self,
    position = { TopLeft = {0, -self._top} },
    colInfo = ns.WeaponView.BuildColInfo(),
    virtual = true,   -- see the armour grid's note (#843); 244 rows x 18 cols was 4,392 cells
    infoTipAnchor = self.infoTipAnchor,
    onFilterChanged = function() self:Render() end,
    onResized = function() self:_fitToGrid() end,
    -- weaponScroll is assigned just below; the closure only reads it at highlight time.
    onEnsureVisible = function(_, rowTop, rowH) ns.EnsureRowVisible(self.weaponScroll, rowTop, rowH) end,
  }
  self.weaponGrid:Hide()

  self.weaponStrip = self.weaponGrid:BuildFilterStrip(self, function() self:Render() end)
  self.weaponStrip:Position({ TopLeft = {self._stripX, 0} })
  self.weaponStrip:Hide()
  ns.prof:Mark("strip")

  self.weaponScroll = ui.ScrollFrame:new{
    parent = self,
    position = { TopLeft = {0, -(self._top + self._headerH)},
      Width = self.weaponGrid:Width(), Height = self._capH },
  }
  self.weaponScroll:Child(self.weaponGrid.rowArea)
  self.weaponScroll:Hide()
  -- Bind + re-size, same order and for the same reason as the armour grid's in the constructor.
  self.weaponGrid:BindViewport(self.weaponScroll)
  self.weaponGrid:RefreshViewport()
  ns.prof:Mark("scroll")
  -- Same one-shot as the constructor's, at the second site: the grid has just been built from this
  -- data and `SetMode` calls Render a few lines later.
  self._gridFresh = true
end

---Switch between the armor grid and the weapon grid (the Armor/Weapons toggle): swap which
---(grid + strip + scroll) trio is shown, re-point the counter and refit at the active grid, carry
---the PTR mode across, and resize. No-op if already in the requested mode.
---@param weapons boolean
function CollectedPanel:SetMode(weapons)
  if self._weaponsMode == weapons then return end
  -- Timed as its own run, prefixed per host so the same toggle can be compared across the two: the
  -- FIRST switch to Weapons builds a second grid, every later swap builds nothing. If a swap that
  -- builds nothing is still slow, the cost is the render + refit rather than construction.
  ns.prof:Begin(self.profPrefix .. (weapons and "weapons" or "armor"))
  -- First switch to Weapons builds the trio. Switching back can't reach a nil one: the guard above
  -- means SetMode(false) only proceeds when we were already in Weapons mode.
  if weapons then self:_ensureWeapons() end
  self._weaponsMode = weapons
  self.active = weapons and self.weaponGrid or self.grid
  self.activeScroll = weapons and self.weaponScroll or self.scroll
  -- Carry PTR PREVIEW across the swap so it reads as one panel-level mode: the grid being shown
  -- adopts the mode of the one being hidden (SetPtr repaints its own toggle).
  local prevGrid = weapons and self.grid or self.weaponGrid
  if self.active._ptr ~= prevGrid._ptr then
    self.active:SetPtr(prevGrid._ptr)
    -- Drop the freshness claim `_ensureWeapons` just made: PTR preview swaps the row source
    -- entirely, so whatever the cells hold is no longer what GetData() would return.
    self._gridFresh = nil
  end
  self.grid:SetShown(not weapons); self.strip:SetShown(not weapons); self.scroll:SetShown(not weapons)
  self.weaponGrid:SetShown(weapons); self.weaponStrip:SetShown(weapons); self.weaponScroll:SetShown(weapons)
  -- Not the free visibility flip it looks like: SetShown routes through Region:Show → OnBeforeShow
  -- → _fitNameCol on the grid coming up.
  ns.prof:Mark("show")
  self._modeToggle:Select(weapons and "weapons" or "armor")
  self:Render()
  ns.prof:Mark("counter")
  self:_fitToGrid()
  ns.prof:Mark("fit")
  ns.prof:Finish(self.active)
end

---The width the header chrome needs, so the panel can never be sized under it.
---
---Derived from the labels rather than padded by a constant, so it keeps holding when the counts
---grow a digit. `UnboundedWidth` (`GetUnboundedStringWidth`) is layout-order independent — the #718
---lesson — so unlike `Width()` it is safe to call mid-construction.
---
---**Monotonic, and that is the whole point.** Measuring the counter measures the text it is showing
---*right now*, and the two modes' strings are different lengths — `473 sets · 1626/4676 collected`
---against `244 sources · 5203/12359 collected`. `SetMode` renders before it refits, so a floor taken
---at face value is the floor for the mode being entered, and whenever the floor beats the grid
---content the panel comes out wider in Weapons than in Armor. Sizing to the widest GRID fixes the
---content term and leaves this one moving, which is the same complaint wearing a different hat.
---
---So the panel keeps the widest chrome it has ever measured and never sizes below it. The first
---swap to Weapons settles it and nothing moves afterwards; a count gaining a digit raises it once
---and it stays raised. It deliberately does not shrink back when a filter shortens the counter —
---edges that hold still are the point, and a floor that tracked the text downward would give back
---exactly the jitter this removes.
---@return number
function CollectedPanel:_chromeWidth()
  local w = self:_chromeFor(self.counter:UnboundedWidth())
  self._chromeMax = max(self._chromeMax or 0, w)
  return self._chromeMax
end

-- The name column is col 1 in EVERY grid and every host since #864 dropped the lock column, so there
-- is nothing left to resolve — `_nameColOf(grid)` is gone and its one caller passes the constant.

---Pad every grid's name column out to one shared content width, so all of them fill the panel and
---the leftover space lands BETWEEN the row names and the first data column.
---
---There are two independent reasons the columns don't naturally fill the panel, and padding answers
---both with one number. The grids are different widths (armour 800 against weapons 704 as measured),
---so the narrower one falls short; and the panel is at least as wide as the header chrome needs
---(filter strip + counter + tally), which is wider than either grid. Left as-is that surplus sits
---beside the last data column as a hole; anchoring the grid to the right edge instead only moves the
---hole to the other side. Widening the name column puts it in the middle, where it reads as the
---gutter between a label column and its data — and the name text is left-aligned, so it simply gains
---room rather than moving.
---
---Idempotent: after a pass every grid measures `target`, so the next call computes the same target
---and pads by zero. That matters because this runs on the hot `_fitToGrid` path — and it is what
---makes it self-correcting when `ns.FitNameCol`'s deferred second measurement (#718's repair) grows
---the armour column later, or when the weapon grid is finally built.
---@return number target  the shared content width, scrollbar gutter not included
function CollectedPanel:_padGridsToWidth()
  local natural = 0
  for _, g in ipairs(self:Grids()) do natural = max(natural, g.rowArea:Width()) end
  -- The chrome floor is a PANEL width; the grids only get what's left after the scrollbar gutter.
  local target = max(natural, self:_chromeWidth() - self.scrollbarW)
  for _, g in ipairs(self:Grids()) do
    -- Armour reads its own derived index; the weapon grid has a single name column at 1.
    ns.PadNameCol(g, g == self.grid and ns.DataView.NAME_COL or 1, target - g.rowArea:Width())
  end
  return target
end

---Seed the chrome floor with the widest the counter can ever get, before the first fit.
---
---The high-water mark alone stops the floor SHRINKING back, but not the first swap to Weapons
---GROWING it: the weapons counter (`244 sources · 5203/12359 collected`) is ~29px longer than the
---armour one, so a panel that opened priced on armour widened by that much the first time you
---toggled. Which is a window that resizes on the Armor/Weapons swap — the exact thing sizing to the
---widest grid was meant to stop, arriving through the other term.
---
---Priced WITHOUT building the weapon grid and without touching the transmog API. Only the string's
---**width** matters here, and `collected` can never carry more digits than `total`, so `total/total`
---is the widest that string can render — from a pure table walk over `ns.WeaponSources`. No
---`WeaponCollectedMap`, whose per-class API sweep is the expensive part (#859) and the reason the
---weapon grid is deferred in the first place; paying it at construction would hand every user that
---cost on the first `/collected` for a grid many never open.
---
---Unfiltered totals deliberately: filters only ever shorten the counter, so this is an upper bound
---and the floor can rise no further. The live `_chromeWidth()` still prices the armour string on
---every fit, and the high-water takes the max, so armour is covered dynamically.
function CollectedPanel:_primeChromeFloor()
  local sources, apps = 0, 0
  for _, grp in ipairs(ns.WeaponSources) do
    sources = sources + 1
    for _, visuals in pairs(grp.types) do apps = apps + #visuals end
  end
  local widest = ("%d sources · %d/%d collected"):format(sources, apps, apps)
  self._chromeMax = max(self._chromeMax or 0, self:_chromeFor(self:_measureCounter(widest)))
end

---The chrome floor for a counter of `counterW` px — the same sum, with the one term that varies
---lifted out so `/collected width` can price both modes without swapping to them.
---@param counterW number
---@return number
function CollectedPanel:_chromeFor(counterW)
  return (self._stripX or 0) + self.strip:Width() + 12 + counterW
    + 16 + self.wantedCount:UnboundedWidth() + 6
end

---What the counter reads in `weapons` mode (nil when that grid isn't built yet). Split out of
---`Render` so the width report can price the mode that ISN'T showing — the mode-dependence of the
---chrome floor is the thing under investigation, and a single-mode reading cannot show it.
---@param weapons boolean
---@return string?
function CollectedPanel:_counterText(weapons)
  if weapons then
    local g = self.weaponGrid
    if not g then return nil end
    if g._ptr then
      local n, build = g:UpcomingCounts()
      return ("+%d appearances upcoming%s"):format(n, build and (" · PTR " .. build) or "")
    end
    local sources, apps, coll = g:VisibleCounts()
    return ("%d sources · %d/%d collected"):format(sources, coll, apps)
  end
  local g = self.grid
  if g._ptr then
    local n, build = g:UpcomingCounts()
    return ("+%d sets upcoming%s"):format(n, build and (" · PTR " .. build) or "")
  end
  local sets, cells, green = g:VisibleCounts()
  return ("%d sets · %d/%d collected"):format(sets, green, cells)
end

---Width the counter label would need for `text`, measured on a hidden twin rather than by writing
---the live label and putting it back. `Label:Text("")` is the GETTER (an empty string is falsy to
---that method), so a restore of the pre-scan empty counter would silently leave the probe's string
---on screen — and mutating a visible widget to measure it is the kind of thing that works until it
---doesn't.
---@param text string
---@return number
function CollectedPanel:_measureCounter(text)
  if not self._measure then
    local theme = self:Theme()
    self._measure = Label:new{
      parent = self, fontInfo = theme.fonts.title,
      position = { TopLeft = {0, 0}, Hide = true },
    }
    -- Match Render's compact strip font, or the measurement prices a size nothing is drawn at.
    if theme.fonts.title then self._measure:Font({theme.fonts.title[1], 12}) end
  end
  self._measure:Text(text)
  return self._measure:UnboundedWidth()
end

---Size the panel to the grid that is currently shown, capped at the shared `MAX_HEIGHT`, and tell
---the host so it can refit around us. Called at construction and again on every filter / PTR /
---mode change, so the scroll range tracks the visible row count and can't overscroll.
---
---Width is `_padGridsToWidth()` — one shared content width every grid is padded out to, floored by
---the header chrome — plus the scrollbar gutter. So the panel is the same width in both modes (the
---swap changes contents, nothing else), the columns always reach the right edge, and any surplus the
---chrome forces sits in the name column rather than beside the last data column.
---
---`rowArea` is the measurement rather than the grid frame, in both hosts. A host may anchor the grid
---frame on both sides — the `/collected` window used to — and then `grid:Width()` is only the host's
---own width handed straight back, which is how that window crept 16px wider on every refit. `rowArea`
---is single-anchored with an explicit width (the column sum, kept in step by `ns.FitNameCol` and
---`ns.PadNameCol`) whatever the host did, so one measurement is right everywhere.
function CollectedPanel:_fitToGrid()
  local grid, scroll = self.active, self.activeScroll
  self:Width(self:_padGridsToWidth() + self.scrollbarW)
  local capH = min(grid.MAX_HEIGHT, grid.rowArea:Height())
  -- Width as well as height. A ScrollFrame CLIPS its child to its own rect, and the scroll was
  -- sized once at construction — so `ns.FitNameCol`'s deferred second measurement (#718's repair)
  -- widened the grid underneath a scroll frame that stayed narrow, cutting off the rightmost column
  -- with nothing in the window's own width to show for it.
  scroll:Width(grid.rowArea:Width())
  scroll:Height(capH)
  self:Height(self._top + grid.headerHeight + capH + 4)
  -- Split because the phase measured 185ms on a build — far more than a resize should cost — and
  -- which of the three owns it decides whether there is anything cheap to do about it.
  ns.prof:Mark("fit:size")
  -- A virtual grid sizes its resident pool from the viewport's height, and the line above just changed
  -- that height — so tell it. `capH` shrinks whenever a filter leaves fewer rows than fill the view;
  -- without this, clearing that filter would leave the pool sized for the small viewport and a band of
  -- empty space below the data (#843). No-op when the height didn't move, and when not virtual.
  grid:RefreshViewport()
  scroll:Refresh()   -- recompute the scroll range for the new child height
  ns.prof:Mark("fit:scroll")
  if self.onSized then self:onSized() end
  ns.prof:Mark("fit:host")
end

-- Show/hide the grid (header icons + scrolling rows) as a unit, so the empty-state message can take
-- a clear area instead of overlapping the header.
---@param shown boolean
function CollectedPanel:_showGrid(shown)
  self.grid:SetShown(shown)
  self.scroll:SetShown(shown)
end

---Refresh the counter, the wanted tally and the active grid's data. PTR PREVIEW shows only the
---upcoming rows (no scan needed); live mode shows collected/total and needs one.
function CollectedPanel:Render()
  -- Consumed on whatever path this takes, including the early returns, so the flag can never
  -- survive into a later render where the data really could have moved on.
  local fresh = self._gridFresh
  self._gridFresh = nil
  local theme = self:Theme()

  if self._weaponsMode then
    -- No scan gate: WeaponView computes collected state live via ns:WeaponCollectedMap.
    self.emptyMsg:Hide()
    self:RefreshWanted()
    self.counter:Text(self:_counterText(true))
    if theme.fonts.title then self.counter:Font({theme.fonts.title[1], 12}) end
    if not fresh then
      self.weaponGrid.data = self.weaponGrid:GetData()
      self.weaponGrid:update()
    end
    return
  end

  local ptr = self.grid._ptr
  if not ptr and (ns.db.total or 0) <= 0 then
    self.counter:Text("")
    self.wantedCount:Text("")
    self:_showGrid(false)
    self.emptyMsg:Text("Run /collected scan to populate")
    self.emptyMsg:Show()
    return
  end
  self.emptyMsg:Hide()
  self:_showGrid(true)
  self.counter:Text(self:_counterText(false))   -- tracks the active expansion/category filter
  -- The counter sits in the strip row in every mode, so keep it at the compact strip font.
  if theme.fonts.title then self.counter:Font({theme.fonts.title[1], 12}) end
  self:RefreshWanted()
  if not fresh then
    self.grid.data = self.grid:GetData()
    self.grid:update()
  end
end

---Refresh the running wanted tally — flagged SETS in armor mode, flagged weapon APPEARANCES in
---weapons mode, since that is what the grid under it is made of and what its own ★ filter acts on.
---The star is drawn from the shared WantedIcon atlas, not a literal glyph the header font can't render.
function CollectedPanel:RefreshWanted()
  local n = self._weaponsMode and ns:WeaponWantedCount() or ns:WantedCount()
  self.wantedCount:Text(("|A:%s:14:14|a %d"):format(ns.WantedIcon, n))
end
