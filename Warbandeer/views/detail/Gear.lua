---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Texture = ui.Frame, ui.Label, ui.Texture
local unpack = unpack
local theme = ns.theme
local D = ns.detail

local DetailView = ns.views.DetailView
local BottomLeft, BottomRight = ui.edge.BottomLeft, ui.edge.BottomRight

-- The suggested upgrade and each issue-note (missing enchant, empty socket) render on
-- their own stacked sub-line (joined with "\n"), so a slot with several never truncates.
-- Every line is fully inline-coloured — the shared sub-line label keeps one base colour,
-- so the upgrade line carries its own green (held) / gold (warband) code and the notes
-- their orange. NOTE_ARROW is the "→ <recommendation>" tail.
local colorCode = ns.Colors.code
local GREEN_CODE, GOLD_CODE = colorCode(theme.colors.green), colorCode(theme.colors.gold)
-- Distinct colours so the issue-notes don't blur together: missing enchant = orange,
-- wrong enchant = yellow (a milder "consider swapping"), empty socket = cyan (a gem slot).
local NO_ENCHANT = "|cffff8000Missing enchant|r"
local WRONG_ENCHANT = "|cffffe066Wrong enchant|r"
local SOCKET_CODE = "|cff4fc3f7"
local NOTE_ARROW = "|cff808080\226\134\146|r |cffb0b0b0%s|r"

-- Trim the "Enchant <Slot> - " prefix for a compact note (recipe names carry it; spellthread
-- / kit names don't have the " - " and pass through unchanged).
local function shortEnchant(name) return (name:gsub("^.- %- ", "")) end
-- Red "[UP] →" tag prepended to the suggested-upgrade line, mirroring the enchant /
-- socket note prefixes (\226\134\146 is the → arrow).
local UP_PREFIX = "|cffff4040[UP] \226\134\146|r "
local GEAR_MAX_SUBS = 3   -- most sub-lines a row can show: upgrade + missing-enchant + empty-socket

-- A transparent mouse-catcher overlaid on one issue-note sub-line (missing enchant / empty
-- socket). Hovering it shows that recommendation's own tooltip (`show(hover, suggestion)`,
-- via the suggestion stashed on it each render) in place of the row's equipped-item tooltip;
-- leaving it hides the shared tooltip. Pooled with the row, repositioned by `parkHover`.
local function noteHover(parent, show)
  local h = Frame:new{ parent = parent, position = { Hide = true } }
  h:EnableMouse(true)
  h:SetScript("OnEnter", function() if h._suggestion then show(h, h._suggestion) end end)
  h:SetScript("OnLeave", function() ns.HideItemTooltip() end)
  return h
end

-- Park a note-hover overlay exactly over its sub-line label (when both the line and a
-- suggestion to detail are present), else hide it. ClearAllPoints first so a pooled row
-- re-anchors cleanly when the note moves to a different sub-line between renders.
local function parkHover(hover, sub, suggestion)
  if sub and suggestion then
    hover._suggestion = suggestion
    hover:ClearAllPoints()
    hover:SetPoint(ui.edge.TopLeft, sub, ui.edge.TopLeft, 0, 0)
    hover:SetPoint(ui.edge.BottomRight, sub, ui.edge.BottomRight, 0, 0)
    hover:Show()
  else
    hover._suggestion = nil
    hover:Hide()
  end
end

-- Grab (or lazily create) a pooled gear row: item name (truncated) on the left,
-- with the item level and upgrade-track badge right-aligned.
---@return table
function DetailView:_gearRow(i)
  local row = self._gearRows[i]
  if row then return row end

  local c = theme.colors
  local prev = self._gearRows[i - 1]
  local frame = Frame:new{
    parent = self.gearPanel,
    position = {
      TopLeft = prev and {prev.frame, BottomLeft, 0, 0}
                     or  {self.gearHeader, BottomLeft, 0, -D.GEAR_HEADER_GAP},
      Width  = D.gearInnerW(D.GEAR_NAME_MIN),  -- resized to fit content in OnBeforeShow
      Height = D.GEAR_ROW_H,
    },
  }
  row = { frame = frame }
  D.attachItemTip(frame)

  -- Head-line elements are centred on the top GEAR_ROW_H band of the frame, so a
  -- row that grows taller for its upgrade sub-line keeps the item line at the top.
  local headY = -D.GEAR_ROW_H / 2
  -- Slot icon pinned to the left (Warbandeer gear atlas; see _showGear).
  row.icon = Texture:new{
    parent = frame, layer = ui.layer.Artwork,
    position = { Left = {frame, ui.edge.TopLeft, 0, headY}, Width = D.GEAR_ICON_W, Height = D.GEAR_ICON_W },
  }
  -- Track badge pinned to the right, ilvl left of it, name fills the remaining space.
  row.track = Label:new{
    parent = frame, fontInfo = theme.fonts.stat, color = c.gold,
    justifyH = ui.justify.Right,
    position = { Right = {frame, ui.edge.TopRight, 0, headY}, Width = D.GEAR_TRACK_W },
  }
  row.ilvl = Label:new{
    parent = frame, fontInfo = theme.fonts.stat,
    justifyH = ui.justify.Right,
    position = { Right = {row.track, ui.edge.Left, -D.GEAR_COL_GAP, 0}, Width = D.GEAR_ILVL_W },
  }
  row.name = Label:new{
    parent = frame, fontInfo = theme.fonts.body,
    justifyH = ui.justify.Left, wordWrap = false,
    position = {
      Left  = {row.icon, ui.edge.Right, D.GEAR_ICON_GAP, 0},
      Right = {row.ilvl, ui.edge.Left, -D.GEAR_COL_GAP, 0},
    },
  }
  -- Stacked sub-lines beneath the item name (the suggested upgrade, a missing-enchant
  -- note, an empty-socket note). One label per line — a single multi-line label doesn't
  -- work here (`wordWrap = false` collapses "\n" to one truncated line). Each spans the
  -- name column out to the frame's right edge (name right + the ilvl/track extras) and
  -- sits GEAR_UP_H lower than the one above; hidden until `_showGear` fills it.
  row.subs = {}
  for s = 1, GEAR_MAX_SUBS do
    local y = -2 - (s - 1) * D.GEAR_UP_H
    row.subs[s] = Label:new{
      parent = frame, fontInfo = theme.fonts.bodySmall,
      justifyH = ui.justify.Left, wordWrap = false, color = theme.colors.muted,
      position = {
        TopLeft  = {row.name, BottomLeft, 0, y},
        TopRight = {row.name, BottomRight, D.GEAR_EXTRAS_W, y},
        Hide     = true,
      },
    }
  end

  -- Mouse-catchers parked over the missing-enchant / empty-socket sub-lines (repositioned
  -- each render in _showGear). Hovering one shows that recommendation's own tooltip — the
  -- enchant's effect / the gem's stat — in place of the row's equipped-item tooltip. A slot
  -- can carry both notes at once (e.g. a ring), so each gets its own overlay.
  row.enchHover = noteHover(frame, ns.ShowEnchantTooltip)
  row.gemHover = noteHover(frame, ns.ShowGemTooltip)

  self._gearRows[i] = row
  return row
end

-- Populate a visible gear row for an equipped item. `slotKey` selects the slot icon.
-- Returns the row's content height (taller when a suggested-upgrade sub-line shows).
---@return number
function DetailView:_showGear(i, item, slotKey)
  local row = self:_gearRow(i)
  -- Slot art from Warbandeer's gear atlas (one cell per slot, all slots covered).
  local spec = ns.gearSlotIcon[slotKey]
  row.icon:Texture(spec.path)
  row.icon:Coords(unpack(spec.coords))
  row.icon:Show()
  row.frame._itemLink = item.link
  row.name:Text(item.name or ""):Color(D.rarityColor(item.link))
  local ilvl = item.ilvl or 0
  row.ilvl:Text(tostring(ilvl)):Color(ns.IlvlColorObj(ilvl))
  if item.track and item.trackLevel and item.trackLevel > 0 then
    row.track:Text(item.track:sub(1, 1) .. item.trackLevel)
  else
    row.track:Text("")
  end

  -- Suggested upgrade for this slot, on a smaller line beneath the item name,
  -- mirroring the tooltip: the item link's own appearance ([Name] in rarity colour)
  -- + the ilvl gain (tinted green held / gold warband-bank) + "@ lvl N" in red when
  -- the item needs a level this character hasn't reached yet. The link is stashed on
  -- the frame so the hover tooltip can show it beside the equipped item.
  local upLink, upGain, upWarband = ns.UpgradeSuggestion(self._char.name, slotKey)
  row.frame._upgradeLink = upLink
  -- One stacked sub-line each: the suggested upgrade, then a missing-enchant note, then
  -- an empty-socket note — each with its recommendation appended ("→ Enchant Ring – …" /
  -- "→ <gem>"). The upgrade line is inline-coloured (green held / gold warband); the
  -- notes carry their own orange. The row grows one GEAR_UP_H per line present.
  local lines = {}
  if upLink then
    local req = D.reqLevel(upLink)
    local reqTail = (req and req > (self._char.basic.level or 0))
      and ("  |cffff4040@ lvl %d|r"):format(req) or ""
    lines[#lines + 1] = UP_PREFIX .. upLink
      .. (upWarband and GOLD_CODE or GREEN_CODE) .. ("  +%d ilvl"):format(upGain or 0) .. "|r" .. reqTail
  end
  local enchSub, enchInfo
  if self._missingEnch[slotKey] then
    local rec = ns.RecommendedEnchant(self._char.name, slotKey)
    lines[#lines + 1] = NO_ENCHANT .. (rec and ("  " .. NOTE_ARROW:format(rec)) or "")
    -- Remember which sub-line this note lands on + its raw suggestion, so the hover
    -- overlay (below) can sit over it and show the enchant's own tooltip.
    enchSub, enchInfo = #lines, rec and ns.RecommendedEnchantInfo(self._char.name, slotKey) or nil
  end
  -- Wrong (non-recommended) enchant: distinct from "missing" (the slot IS enchanted, just
  -- not with the recommended one). Mutually exclusive with the missing-enchant note. Hidden
  -- when the user has accepted this item's enchant; the right-click toggle (wired below) is
  -- armed for any slot with a raw mismatch so an accept can be undone.
  local mis = self._enchMismatch[slotKey]
  row.frame._enchMismatch = mis   -- {itemID, enchantID} for the right-click accept toggle
  if mis and not ns.IsEnchantIgnored(mis.itemID, mis.enchantID) then
    lines[#lines + 1] = WRONG_ENCHANT
      .. ("  |cff808080(%s)|r"):format(shortEnchant(mis.applied))
      .. "  " .. NOTE_ARROW:format(shortEnchant(mis.recommended))
  end
  local gemSub, gemInfo
  local sockets = self._emptySockets[slotKey]
  if sockets then
    local label = sockets > 1 and ("Empty sockets ×%d"):format(sockets) or "Empty socket"
    -- The unique diamond goes on the first empty socket; every other socket gets the
    -- secondary fill gem. Take the matching raw suggestion alongside the name for the hover.
    local rec, info
    if not self._gemPlaced and self._gemPrimary then
      rec, info, self._gemPlaced = self._gemPrimary, self._gemPrimaryInfo, true
    else
      rec, info = self._gemSecondary, self._gemSecondaryInfo
    end
    lines[#lines + 1] = SOCKET_CODE .. label .. "|r"
      .. (rec and ("  " .. NOTE_ARROW:format(rec)) or "")
    gemSub, gemInfo = #lines, rec and info or nil
  end

  local h = D.GEAR_ROW_H
  for s, sub in ipairs(row.subs) do
    if lines[s] then
      sub:Text(lines[s]):Show()       -- lines are inline-coloured; label base stays muted
      h = h + D.GEAR_UP_H
    else
      sub:Text(""):Hide()             -- clear so a pooled row's stale width doesn't skew autosize
    end
  end
  -- Park each note-detail hover over its sub-line (missing-enchant / empty-socket), or hide
  -- it when that note isn't shown this render. A slot may have both at once.
  parkHover(row.enchHover, enchSub and lines[enchSub] and row.subs[enchSub], enchInfo)
  parkHover(row.gemHover, gemSub and lines[gemSub] and row.subs[gemSub], gemInfo)

  row.frame:Height(h)
  row.frame:Show()
  return h
end
