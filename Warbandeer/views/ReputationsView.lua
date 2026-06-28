---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local min, insert, sort, unpack = math.min, table.insert, table.sort, unpack
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local theme = ns.theme

-- Paged cross-alt reputation browser. One page per expansion (plus a trailing "Other"
-- page for guild / uncategorized factions), switched via a titlebar pulldown labelled
-- with the Collected addon's expansion badges and via the Left/Right arrow keys. Each row
-- is one faction — its icon, name, an Alliance/Horde marker when the rep is side-locked,
-- and the highest standing reached across the warband; hovering (or selecting with the
-- Up/Down arrows) shows every character's standing. Data comes from the reputations
-- broker via WarbandeerApi (per-faction `categoryId` is the locale-proof expansion key).
--
-- Layout constants + cell helpers live in views/reps/ReputationsData.lua (on ns.reps,
-- loaded first); the row pool + page rendering in views/reps/ReputationsRender.lua.
local R = ns.reps
local CONTENT_W, SCROLLBAR_W, MAX_H = R.CONTENT_W, R.SCROLLBAR_W, R.MAX_H
local REL, EXP_NAMES, END, MUTED = R.REL, R.EXP_NAMES, R.END, R.MUTED
local standingText, classCode = R.standingText, R.classCode

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class ReputationsView: Frame
---@field scroll ScrollFrame
---@field list Frame                 scroll child holding the faction rows
---@field emptyMsg Label
---@field _rows table[]              pooled faction rows
---@field _pages table[]             ordered pages { key, rel?, label, icon?, factions[] }
---@field _pageIdx integer           current page index
---@field _sel integer?              selected row index on the current page
---@field _viewH number              current viewport height (for scroll-into-view)
---@field _filter FilterDropdown?    titlebar expansion picker
local ReputationsView = Class(Frame, function(self)
  self.scroll = ui.ScrollFrame:new{
    parent = self,
    position = { TopLeft = {0, 0}, Width = CONTENT_W, Height = MAX_H },
  }
  self.list = Frame:new{
    parent = self.scroll,
    position = { TopLeft = {0, 0}, Width = CONTENT_W, Height = MAX_H },
  }
  self.scroll:Child(self.list)
  self._rows = {}
  self._pageIdx = 1
  self._viewH = MAX_H

  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {2, -6}, Width = 280, Height = 20, Hide = true },
    text = "No reputation data yet — log in on a character.",
  }

  -- Arrow-key navigation, scoped to while the view is shown so it never eats the
  -- player's movement keys.  SetPropagateKeyboardInput lets every non-arrow key fall
  -- through to its default binding (Escape closes the window, etc.).
  local w = self._widget
  w:EnableKeyboard(false)
  w:SetScript("OnKeyDown", function(_, key) self:_onKey(key) end)
  w:HookScript("OnShow", function() w:EnableKeyboard(true); w:SetPropagateKeyboardInput(true) end)
  w:HookScript("OnHide", function() w:EnableKeyboard(false); ui.tip:Hide() end)

  self:Width(CONTENT_W + SCROLLBAR_W)
  self:Height(MAX_H)
end, {
  name = "reputations",
  background = theme.colors.window,
})
ReputationsView.name = "reputations"
ReputationsView._title = "Reputations"
ns.views.ReputationsView = ReputationsView

-- ─── Data ─────────────────────────────────────────────────────────────────────

-- Aggregate every tracked character's standings into ordered pages.  Side-restriction is
-- inferred from which sides hold the rep (only flagged when the opposite side has a
-- scanned character, so a neutral faction only one side happens to hold isn't mislabelled).
function ReputationsView:_refreshData()
  local api = ns.api
  local chars = api.GetAllCharacters()
  local haveA, haveH = false, false
  for _, c in ipairs(chars) do
    if c.isAlliance then haveA = true else haveH = true end
  end

  local byFid = {}
  for _, c in ipairs(chars) do
    local reps = api:GetReputations(c.name)
    if reps then
      for fid, f in pairs(reps) do
        local e = byFid[fid]
        if not e then
          e = { fid = fid, name = f.name, categoryId = f.categoryId or 0, accountWide = f.accountWide }
          byFid[fid] = e
        elseif e.categoryId == 0 and f.categoryId and f.categoryId ~= 0 then
          -- a faction several characters share: prefer any known category, so one
          -- re-scanned (v24) character fixes its page even if other alts are stale.
          e.categoryId = f.categoryId
        end
        if c.isAlliance then e.ally = true else e.horde = true end
      end
    end
  end

  local groups = {}
  for fid, e in pairs(byFid) do
    local list = api:GetFactionStandings(fid)
    if list then
      e.standings, e.highest = list, list[1]
      if not e.accountWide then
        if e.ally and not e.horde and haveH then e.side = true
        elseif e.horde and not e.ally and haveA then e.side = false end
      end
      local rel = REL[e.categoryId]
      local key = rel or "other"
      local g = groups[key]
      if not g then g = { key = key, rel = rel, factions = {} }; groups[key] = g end
      insert(g.factions, e)
    end
  end

  local pages = {}
  for _, g in pairs(groups) do insert(pages, g) end
  sort(pages, function(a, b) return (a.rel or 99) < (b.rel or 99) end)

  local capi = WarbandeerCollectedApi
  for _, g in ipairs(pages) do
    sort(g.factions, function(x, y)
      local rx, ry = (x.highest and x.highest.rank) or 0, (y.highest and y.highest.rank) or 0
      if rx ~= ry then return rx > ry end
      return (x.name or "") < (y.name or "")
    end)
    if g.rel then
      g.label = (capi and capi.Releases and capi.Releases[g.rel]) or EXP_NAMES[g.rel] or ("Release " .. g.rel)
      g.icon = capi and capi.ReleaseIcons and capi.ReleaseIcons[g.rel]
    else
      g.label = "Other"
    end
  end

  self._pages = pages
  if self._pageIdx > #pages then self._pageIdx = 1 end
end

-- Dropdown option specs from the current pages (expansion badge inlined when available).
function ReputationsView:_pageOptions()
  local opts = {}
  for _, g in ipairs(self._pages) do
    local label = g.icon and ("|T%s:14:14|t %s"):format(g.icon, g.label) or g.label
    insert(opts, { key = g.key, label = label })
  end
  return opts
end

-- ─── Selection + navigation ───────────────────────────────────────────────────
-- Row pool + page rendering (_acquireRow / _renderPage / _highlight) live in
-- views/reps/ReputationsRender.lua.

-- Highlight a row and show its warband-wide standing breakdown.
function ReputationsView:_select(idx)
  self:_highlight(idx)
  if not self._sel then return end
  local e = self._pages[self._pageIdx].factions[self._sel]
  local row = self._rows[self._sel]
  ns.AnchorTip(row)
  ui.tip:ClearLines()
  ui.tip:AddLine(e.name)
  if e.side ~= nil then
    ui.tip:AddLine(e.side and "Alliance only" or "Horde only", unpack(ns.factionIcon[e.side].vertexColor))
  end
  local list = e.standings
  if list[1].accountWide then
    ui.tip:AddLine("Warband Wide: " .. standingText(list[1]))
  else
    local shown = min(#list, 8)
    for i = 1, shown do
      local s = list[i]
      ui.tip:AddLine(classCode(s.classKey) .. s.name .. END .. "   " .. standingText(s))
    end
    if #list > shown then
      ui.tip:AddLine(MUTED .. ("+%d more — /sreps %s"):format(#list - shown, e.name) .. END)
    end
  end
  ui.tip:Show()
end

-- Flip to a sibling expansion page (Left/Right arrows + dropdown both route here).
function ReputationsView:_flipPage(d)
  local n = #self._pages
  if n == 0 then return end
  local i = (self._pageIdx or 1) + d
  i = i < 1 and 1 or (i > n and n or i)
  if i == self._pageIdx then return end
  self._pageIdx = i
  if self._filter then self._filter:Select(self._pages[i].key) end
  self:_renderPage()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

function ReputationsView:_onKey(key)
  local w = self._widget
  if key == "UP" then w:SetPropagateKeyboardInput(false); self:_select((self._sel or 1) - 1)
  elseif key == "DOWN" then w:SetPropagateKeyboardInput(false); self:_select((self._sel or 1) + 1)
  elseif key == "LEFT" then w:SetPropagateKeyboardInput(false); self:_flipPage(-1)
  elseif key == "RIGHT" then w:SetPropagateKeyboardInput(false); self:_flipPage(1)
  else w:SetPropagateKeyboardInput(true) end
end

-- ─── Filter + lifecycle ─────────────────────────────────────────────────────────

function ReputationsView:BuildFilter(parent)
  self:_refreshData()
  local box = ui.FilterDropdown:new{
    parent = parent,
    width = 160, menuWidth = 180,
    options = self:_pageOptions(),
    selected = self._pages[self._pageIdx] and self._pages[self._pageIdx].key,
    onSelect = function(_, key)
      for i, g in ipairs(self._pages) do
        if g.key == key then self._pageIdx = i; break end
      end
      self:_renderPage()
      if ns.MainWindow then ns.MainWindow:Fit() end
    end,
  }
  self._filter = box
  return box
end

function ReputationsView:OnBeforeShow()
  self:_refreshData()
  if self._filter then self._filter:Select(self._pages[self._pageIdx] and self._pages[self._pageIdx].key) end
  self:_renderPage()
end

-- ─── Dev: dump uncategorized ("Other") reps ─────────────────────────────────────
-- `/wb reps0` — copy-window list of every warband faction that lands on the "Other"
-- page (its captured categoryId isn't a mapped expansion header), with the resolved
-- header name. cat=0 means the faction hasn't been re-scanned on a v24 client yet (log
-- into a character that has it); a non-zero header not in REL is a mapping gap to add.
ns:registerCommand("reps0", "", function(self)
  local api = self.api
  local byFid = {}
  for _, c in ipairs(api.GetAllCharacters()) do
    local reps = api:GetReputations(c.name)
    if reps then
      for fid, f in pairs(reps) do
        local e = byFid[fid]
        if not e then
          e = { fid = fid, name = f.name, categoryId = f.categoryId or 0, n = 0 }
          byFid[fid] = e
        elseif e.categoryId == 0 and f.categoryId and f.categoryId ~= 0 then
          e.categoryId = f.categoryId
        end
        e.n = e.n + 1
      end
    end
  end

  local rows = {}
  for _, e in pairs(byFid) do
    if not REL[e.categoryId] then insert(rows, e) end
  end
  sort(rows, function(a, b)
    if a.categoryId ~= b.categoryId then return a.categoryId < b.categoryId end
    return (a.name or "") < (b.name or "")
  end)

  local lines = { ("Uncategorized (\"Other\") reputations: %d"):format(#rows), "" }
  for _, e in ipairs(rows) do
    local hdr = e.categoryId > 0 and C_Reputation.GetFactionDataByID(e.categoryId)
    local cat = e.categoryId == 0 and "0 (uncategorized)"
      or (e.categoryId .. (hdr and hdr.name and (" " .. hdr.name) or " (unknown header)"))
    insert(lines, ("%s\t[fid %d]\tcat=%s\t(%d chars)"):format(e.name or "?", e.fid, cat, e.n))
  end
  ui.ShowCopyWindow("Warbandeer — Other reputations", table.concat(lines, "\n"))
end, "Dump uncategorized reputations to a copy window")
