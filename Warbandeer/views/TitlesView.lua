---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local min, insert = math.min, table.insert
local Class, Frame, Label = ns.lua.Class, ui.Frame, ui.Label
local theme = ns.theme

-- Warband Titles browser. One scrollable list of every player title the client knows (earned +
-- unearned), filtered by a titlebar status pulldown — All / Earned / Unearned (and Earnable when
-- the optional Epithet addon is installed) — switched with the Left/Right arrow keys, rows picked
-- with Up/Down. "Earned" is the account union: a title any tracked character has, listed with
-- which characters (hover/select shows the breakdown). Epithet, when present, is read live for
-- rarity colour + source and to derive the Earnable list; the view degrades to earned/unearned
-- without it. No bundled data — the title universe comes from the live client scan.
--
-- Layout constants + the impure client/Epithet readers live on ns.titles (views/titles/TitlesData
-- .lua, loaded first); the pure categoriser is ns.ComputeTitles (views/titles/TitlesCompute.lua);
-- the VirtualList row builders + page render live in views/titles/TitlesRender.lua.
local T = ns.titles
local CONTENT_W, SCROLLBAR_W, MAX_H = T.CONTENT_W, T.SCROLLBAR_W, T.MAX_H
local MUTED, END = "|cff9d9d9d", "|r"

-- ─── View ─────────────────────────────────────────────────────────────────────

---@class TitlesView: Frame
---@field list VirtualList         pooled title-row list (owns its own scrolling viewport)
---@field emptyMsg Label
---@field _all TitleEntry[]        the full categorised universe (all statuses)
---@field _statuses table[]        ordered filter pages { key, label, list[] }
---@field _statusIdx integer       current status index
---@field _sel integer?            selected row index in the current list
---@field _classByName table<string,string?>  character name → classKey (owner tooltip colour)
---@field _filter FilterDropdown?  titlebar status picker
local TitlesView = Class(Frame, function(self)
  self.list = ui.VirtualList:new{
    parent = self,
    position = { TopLeft = {0, 0}, Width = CONTENT_W + SCROLLBAR_W, Height = MAX_H },
    scrollbar = true,
    spacing = 0,
    padding = 0,
    rowHeight = T.ROW_H,
    createRow = function(l) return self:_createRow(l) end,
    updateRow = function(_, row, e, i) return self:_updateRow(row, e, i) end,
  }
  self._statusIdx = 1

  self.emptyMsg = Label:new{
    parent = self, fontInfo = theme.fonts.body, color = theme.colors.muted,
    position = { TopLeft = {2, -6}, Width = 300, Height = 20, Hide = true },
    text = "No titles in this list.",
  }

  -- Arrow-key navigation, live only while shown so it never eats movement keys;
  -- SetPropagateKeyboardInput lets every non-arrow key fall through to its default binding.
  -- Capture goes through _setKeyCapture so combat takes it away (#736); the regen pair hands
  -- it back. ReputationsView and Warbandeer_Collected's DressingRoomBuild carry the same
  -- shape -- slated to become a shared LibNUI Frame:CaptureKeys.
  local w = self._widget
  w:EnableKeyboard(false)
  w:SetScript("OnKeyDown", function(_, key) self:_onKey(key) end)
  w:HookScript("OnShow", function() self:_setKeyCapture(true) end)
  w:HookScript("OnHide", function() self:_setKeyCapture(false); ui.tip:Hide() end)
  self:listenForEvents()
  self:registerEvent("PLAYER_REGEN_DISABLED")
  self:registerEvent("PLAYER_REGEN_ENABLED")

  self:Width(CONTENT_W + SCROLLBAR_W)
  self:Height(MAX_H)
end, {
  name = "titles",
  background = theme.colors.window,
})
TitlesView.name = "titles"
TitlesView._title = "Titles"
ns.views.TitlesView = TitlesView

-- ─── Data ─────────────────────────────────────────────────────────────────────

-- Live-scan the universe, gather each character's earned list, read Epithet (when installed), then
-- categorise via the pure ns.ComputeTitles. Pre-bin the result into the status filter lists the
-- pulldown pages through, and cache name→classKey for the owner tooltip.
function TitlesView:_refreshData()
  local universe = T.scanUniverse()
  local chars = T.gatherCharacters()
  local epById = T.epithetById()
  local result = ns.ComputeTitles(universe, chars, epById)

  self._all = result.list
  self._classByName = {}
  for _, c in ipairs(chars) do self._classByName[c.name] = c.classKey end

  local earned, unearned, earnable, unearnable = {}, {}, {}, {}
  for _, e in ipairs(self._all) do
    if e.earned then
      insert(earned, e)
    else
      insert(unearned, e)
      if e.earnable then insert(earnable, e)
      elseif e.unearnable then insert(unearnable, e) end
    end
  end

  local counts = result.counts
  local statuses = {
    { key = "all",      label = ("All (%d)"):format(counts.total),         list = self._all },
    { key = "earned",   label = ("Earned (%d)"):format(counts.earned),     list = earned },
    { key = "unearned", label = ("Unearned (%d)"):format(counts.unearned), list = unearned },
  }
  -- Earnable/Unearnable split the unearned titles by Epithet's obtainability, so they only carry
  -- meaning with Epithet loaded.
  if epById then
    insert(statuses, { key = "earnable",   label = ("Earnable (%d)"):format(counts.earnable),     list = earnable })
    insert(statuses, { key = "unearnable", label = ("Unearnable (%d)"):format(counts.unearnable), list = unearnable })
  end
  self._statuses = statuses
  if self._statusIdx > #statuses then self._statusIdx = 1 end
end

function TitlesView:_statusOptions()
  local opts = {}
  for _, s in ipairs(self._statuses) do insert(opts, { key = s.key, label = s.label }) end
  return opts
end

function TitlesView:_currentList()
  local s = self._statuses[self._statusIdx]
  return s and s.list or {}
end

-- ─── Selection + navigation ───────────────────────────────────────────────────
-- Row builders + page render (_createRow / _updateRow / _renderPage / _highlight) live in
-- views/titles/TitlesRender.lua.

-- Highlight a row and show its detail: Epithet source (when present) + the warband characters
-- that have earned it.
function TitlesView:_select(idx)
  self:_highlight(idx)
  if not self._sel then return end
  local e = self:_currentList()[self._sel]
  if not e then return end
  local row = self.list:Row(self._sel)
  ns.AnchorTip(row)
  ui.tip:ClearLines()

  local rc = T.rarityCode(e.epithet)
  ui.tip:AddLine(rc and (rc .. e.name .. END) or e.name)
  local ep = e.epithet
  if ep then
    if ep.cat then ui.tip:AddLine(MUTED .. "Category: " .. END .. tostring(ep.cat)) end
    local source = ep.obtainability_reason or ep.achievement or ep.kind
    if source then ui.tip:AddLine(MUTED .. "Source: " .. END .. tostring(source)) end
  end

  if e.earnable then
    ui.tip:AddLine("|cffffd200Earnable now|r")
  elseif e.unearnable then
    ui.tip:AddLine("|cffdb6666Not currently obtainable|r")
  end

  if not e.earned then
    ui.tip:AddLine(MUTED .. "Not earned by any character" .. END)
  elseif e.accountWide then
    -- Account-wide (available to every character) — an owner roster would just be noise.
    ui.tip:AddLine("|cff40bf40Earned by Warband|r")
  else
    -- Character-specific (e.g. a PvP season title) — show exactly which characters hold it.
    local o = e.owners
    local shown = min(#o, 12)
    ui.tip:AddLine("Earned by:")
    for i = 1, shown do
      ui.tip:AddLine("  " .. ns.Colors.className(o[i], self._classByName[o[i]]))
    end
    if #o > shown then ui.tip:AddLine(MUTED .. ("  +%d more"):format(#o - shown) .. END) end
  end
  ui.tip:Show()
end

-- Flip to a sibling status page (Left/Right arrows + dropdown both route here).
function TitlesView:_flipStatus(d)
  local n = #self._statuses
  if n == 0 then return end
  local i = (self._statusIdx or 1) + d
  i = i < 1 and 1 or (i > n and n or i)
  if i == self._statusIdx then return end
  self._statusIdx = i
  if self._filter then self._filter:Select(self._statuses[i].key) end
  self:_renderPage()
  if ns.MainWindow then ns.MainWindow:Fit() end
end

-- Holding the keyboard and steering propagation are one decision, so they are taken and given
-- up together. SetPropagateKeyboardInput is restricted in combat lockdown and LibNUI skips it
-- there, so a view that kept the keyboard in combat would consume the player's movement and
-- action-bar keys with no way to pass them on (#736). Releasing capture instead costs arrow
-- navigation for the fight, which is the right trade. Re-asserting propagation on regain also
-- clears the `false` the last arrow press left behind.
---@param on boolean  capture keys -- only honoured out of combat
function TitlesView:_setKeyCapture(on)
  on = on and not InCombatLockdown()
  self:EnableKeyboard(on)
  if on then self:SetPropagateKeyboardInput(true) end
end

function TitlesView:PLAYER_REGEN_DISABLED() self:_setKeyCapture(false) end
function TitlesView:PLAYER_REGEN_ENABLED() self:_setKeyCapture(self._widget:IsShown()) end

function TitlesView:_onKey(key)
  -- Route through the LibNUI Frame wrapper (self, not the raw widget) so the propagation
  -- toggle is skipped in combat lockdown instead of firing a taint error.
  if key == "UP" then self:SetPropagateKeyboardInput(false); self:_select((self._sel or 1) - 1)
  elseif key == "DOWN" then self:SetPropagateKeyboardInput(false); self:_select((self._sel or 1) + 1)
  elseif key == "LEFT" then self:SetPropagateKeyboardInput(false); self:_flipStatus(-1)
  elseif key == "RIGHT" then self:SetPropagateKeyboardInput(false); self:_flipStatus(1)
  else self:SetPropagateKeyboardInput(true) end
end

-- ─── Filter + lifecycle ─────────────────────────────────────────────────────────

function TitlesView:BuildFilter(parent)
  self:_refreshData()
  local box = ui.FilterDropdown:new{
    parent = parent,
    bordered = true,
    width = 150, menuWidth = 170,
    options = self:_statusOptions(),
    selected = self._statuses[self._statusIdx] and self._statuses[self._statusIdx].key,
    onSelect = function(_, key)
      for i, s in ipairs(self._statuses) do
        if s.key == key then self._statusIdx = i; break end
      end
      self:_renderPage()
      if ns.MainWindow then ns.MainWindow:Fit() end
    end,
  }
  self._filter = box
  return box
end

function TitlesView:OnBeforeShow()
  self:_refreshData()
  -- The dropdown's options (labels + the Earnable entry) are fixed at first build like the
  -- Reputations picker; re-select to keep the shown status in sync. The row lists themselves are
  -- refreshed above, so the list content is always current even if a count label is a snapshot.
  if self._filter then
    self._filter:Select(self._statuses[self._statusIdx] and self._statuses[self._statusIdx].key)
  end
  self:_renderPage()
end
