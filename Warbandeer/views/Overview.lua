---@type Warbandeer
local ns = select(2, ...)
local ui = ns.ui
local Class, Frame, Label, Texture = ns.lua.Class, ui.Frame, ui.Label, ui.Texture
local StatCard = ns.StatCard
local theme = ns.theme
local BreakUpLargeNumbers = BreakUpLargeNumbers
local GetBuildInfo = GetBuildInfo

-- Sub-widgets live in views/overview/ (loaded first) and register on ns.overview:
-- FactionBars (reputation bars), TopAlts (top-character gear table + its marks), and
-- Achievements (per-expansion checklist). RAIDS is the raid-picker config (owned by
-- TopAlts, used here by BuildFilter).
local FactionBars = ns.overview.FactionBars
local Achievements = ns.overview.Achievements
local TopAlts = ns.overview.TopAlts

local P, GAP, STRIP_H, HEAD_H = 12, 8, 64, 16
local TREND_ICON = "Interface\\AddOns\\Warbandeer\\icons\\"
-- inline paragon reward-bag glyph for expansion-picker options that hold a claim
local PARAGON_MARK = "|A:ParagonReputation_Bag:12:12|a"
local BAR_TEX = "Interface\\AddOns\\Warbandeer\\media\\bar-rounded"

-- caps label used for section headers ("REPUTATIONS", "TOP CHARACTERS", ...)
local function capsHeader(parent, text, position)
  return Label:new{
    parent = parent,
    fontInfo = theme.fonts.caps,
    color = theme.colors.muted,
    text = text:upper(),
    position = position,
  }
end

-- Build one expansion's content into `panel`: a Reputations box (left) and an
-- Achievements box (right), each under its own caps header. The two sit a box-gap
-- (GAP*2) apart so each can carry its own module background. Returns the reps and
-- achievements section sizes (width, height) for the caller to size those boxes.
local function buildTab(panel, expansionLevel, extraFactionIDs, achievementIds)
  capsHeader(panel, "Reputations", { TopLeft = {0, 0} })
  local bars = FactionBars:new{
    parent = panel,
    expansionLevel = expansionLevel,
    extraFactionIDs = extraFactionIDs,
    position = { TopLeft = {0, -HEAD_H} },
  }
  panel._bars = bars -- reachable so BuildFilter can total pending paragon rewards
  -- Achievements is moved into its own equal-thirds column by the caller once the
  -- shared column width is known; the X here is a placeholder.
  local achHead = capsHeader(panel, "Achievements", { TopLeft = {0, 0} })
  local ach = Achievements:new{
    parent = panel,
    achievementIds = achievementIds,
    position = { TopLeft = {0, -HEAD_H} },
  }
  panel._ach = ach -- reachable for the cold-session font heal (ns.HealCellFonts)
  return bars:Width(), bars:Height(), ach:Width(), ach:Height(), achHead
end

-- Expansions selectable via the titlebar dropdown. Each builds its own
-- Reputations + Achievements panel; only the selected one is shown.
local EXPANSIONS = {
  { key = "midnight",     label = "Midnight",       expansionLevel = 11, extraFactionIDs = {}, achievementIds = ns.overview.midnightAchievementIds },
  { key = "wwi",          label = "The War Within", expansionLevel = 10, extraFactionIDs = {}, achievementIds = ns.overview.wwiAchievementIds },
  { key = "dragonflight", label = "Dragonflight",   expansionLevel = 9,  extraFactionIDs = {}, achievementIds = ns.overview.dragonflightAchievementIds },
}

-- Overview
---@class Overview: Frame
---@field topAlts TopAlts
---@field _panels table<string, Frame>   expansion key -> reps+achievements panel
---@field _repsH table<string, number>   expansion key -> reputations section height
---@field _achH table<string, number>    expansion key -> achievements section height
---@field _altH number                   Top Characters section height
---@field _contentW number               total content width (excl. outer padding)
---@field _contentTop number             Y offset where the panels start
---@field _modReps Texture               reputations module background
---@field _modAch Texture                achievements module background
---@field _expansion string?             currently selected expansion key
---@field _filter FilterDropdown?        titlebar expansion picker
-- The live view instance, captured so the ratings-changed listener (registered once,
-- below) refreshes whichever Top Characters table currently exists.
local _view
local Overview = Class(Frame, function(self)
  _view = self
  local c = theme.colors
  local BLEED = 6                        -- module/strip outer bleed (matches module bg padding)

  -- Account-wide Traveler's Log strip sits between the stat strip and the grid; when
  -- shown it pushes the grid (panels, Top Characters, all module backgrounds) down by
  -- its height. `tl` is the snapshot; nil or no-thresholds-yet means no strip, no offset.
  local tl = ns.api.GetTravelersLog and ns.api.GetTravelersLog()
  local showTL = tl and tl.max and tl.max > 0
  local TL_NAME_H = (theme.fonts.body[2] or 13) + 6   -- LabeledBar name-row height
  local TL_BAR_TH = 10                                 -- LabeledBar bar thickness
  local TL_ROW_H  = (theme.fonts.body[2] or 13) + 6    -- rewards-waiting line height
  local TL_H = HEAD_H + TL_NAME_H + TL_BAR_TH + 6 + TL_ROW_H
  local stripTop = P + STRIP_H + GAP
  -- GAP + BLEED*2: a plain GAP is swallowed by a strip's and the grid's 6px module bleeds (which
  -- meet in the middle), leaving them touching; the extra BLEED*2 restores a visible GAP-sized gutter.
  local tlBlock = showTL and (TL_H + GAP + BLEED * 2) or 0

  -- Houses (endeavors) strip — account-wide house level/favor + current endeavor, stacked below the
  -- Traveler's Log strip. Two faction-house blocks (Alliance | Horde) side by side, each a
  -- name/level/favor line over an endeavor progress bar. `houses` is nil until a house is captured.
  local houses = ns.api.GetHouses and ns.api.GetHouses()
  local showHouses = (houses and (houses.alliance or houses.horde)) and true or false
  local HOUSE_LB_H = (theme.fonts.body[2] or 13) + 6 + 8   -- LabeledBar: name row + 8px bar
  local HOUSE_HEAD_H = (theme.fonts.body[2] or 13) + 6     -- the house name/level/favor line
  local HOUSES_H = HEAD_H + HOUSE_HEAD_H + 2 + HOUSE_LB_H  -- caps header + one house block
  local housesTop = stripTop + tlBlock
  local contentTop = housesTop + (showHouses and (HOUSES_H + GAP + BLEED * 2) or 0)
  self._contentTop = contentTop

  -- Reputations + Achievements, one panel per expansion. Each panel holds a reps
  -- box (left) and an achievements box (right); panels share the same anchor and
  -- only the selected one is shown. The two module backgrounds are siblings of the
  -- panels and resize to the active expansion's section heights.
  self._panels, self._repsH, self._achH = {}, {}, {}
  local repsW, achW = 0, 0
  local achHeads = {}                    -- expansion key -> achievements caps header
  for _, e in ipairs(EXPANSIONS) do
    local panel = Frame:new{
      parent = self,
      position = { TopLeft = {P, -contentTop}, Hide = true },
    }
    local bw, bh, aw, ah, achHead = buildTab(panel, e.expansionLevel, e.extraFactionIDs, e.achievementIds)
    panel:Height(HEAD_H + math.max(bh, ah))
    self._panels[e.key] = panel
    self._repsH[e.key] = HEAD_H + bh
    self._achH[e.key]  = HEAD_H + ah
    repsW = math.max(repsW, bw)
    achW  = math.max(achW, aw)
    achHeads[e.key] = achHead
  end

  -- Top Characters header + table — built at a placeholder X, moved to its column below.
  local topHead = capsHeader(self, "Top Characters", { TopLeft = {P, -contentTop} })
  self.topAlts = TopAlts:new{
    parent = self,
    position = { TopLeft = {P, -(contentTop + HEAD_H)} },
  }
  self._altH = HEAD_H + self.topAlts:Height()

  -- Equal thirds: every section gets the same box width — the widest natural column —
  -- laid out left→right with a box-gap between, so the three sections line up as a clean
  -- grid (each content frame left-aligned in its column) instead of staggering to its
  -- own content width.
  local colW = math.max(repsW, achW, self.topAlts:Width())
  local col0, col1, col2 = P, P + colW + GAP * 2, P + 2 * (colW + GAP * 2)

  -- shift each expansion's achievements box into column 1 (local X relative to the
  -- panel, which is anchored at col0); the panel spans columns 0–1 (reps + ach).
  for key, panel in pairs(self._panels) do
    local achHead = achHeads[key]
    achHead:ClearAllPoints();    achHead:TopLeft(col1 - P, 0)
    panel._ach:ClearAllPoints(); panel._ach:TopLeft(col1 - P, -HEAD_H)
    panel:Width(2 * colW + GAP * 2)
  end

  -- move Top Characters into column 2.
  topHead:ClearAllPoints();      topHead:TopLeft(col2, -contentTop)
  self.topAlts:ClearAllPoints(); self.topAlts:TopLeft(col2, -(contentTop + HEAD_H))

  self._contentW = (col2 - P) + colW

  -- module backgrounds (parent textures render behind the child content frames); each
  -- section gets an equal-width box. Reps + ach are resized per selection (height only).
  self._modReps = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col0 - 6, -(contentTop - 6)}, Width = colW + 12, Height = 12 },
  }
  self._modAch = Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col1 - 6, -(contentTop - 6)}, Width = colW + 12, Height = 12 },
  }
  Texture:new{
    parent = self, layer = ui.layer.Artwork, color = c.module,
    position = { TopLeft = {col2 - 6, -(contentTop - 6)}, Width = colW + 12, Height = self._altH + 12 },
  }

  -- Traveler's Log — account-wide monthly Trading Post progress. A caps-headed strip
  -- above the grid: a % bar (raw earned/max on hover) with the current Tender balance
  -- and reset countdown on the right, and a rewards-waiting line beneath.
  if showTL then
    Texture:new{
      parent = self, layer = ui.layer.Artwork, color = c.module,
      position = { TopLeft = {P - 6, -(stripTop - 6)}, Width = self._contentW + 12, Height = TL_H + 12 },
    }
    capsHeader(self, "Traveler's Log", { TopLeft = {P, -stripTop} })
    local days = math.max(0, math.floor(((tl.resetAt or 0) - GetServerTime()) / 86400))
    Label:new{
      parent = self, fontInfo = theme.fonts.stat, color = c.muted,
      text = BreakUpLargeNumbers(tl.tender or 0) .. " Trader's Tender   ·   resets in " .. days .. "d",
      justifyH = ui.justify.Right,
      position = { TopRight = {-P, -stripTop} },
    }
    ns.LabeledBar:new{
      parent = self,
      width = self._contentW,
      barHeight = TL_BAR_TH,
      label = "Traveler's Log — " .. (tl.monthName or "?"),
      value = math.floor((tl.pct or 0) * 100 + 0.5) .. "%",
      hoverValue = (tl.earned or 0) .. " / " .. (tl.max or 0),
      pct = tl.pct or 0,
      valueColor = c.gold,
      hoverColor = c.muted,
      position = { TopLeft = {P, -(stripTop + HEAD_H)} },
    }
    -- rewards line: a gold call-to-collect (bag glyph, pending Tender, reward item
    -- icons) when a chest is waiting, else a muted "all collected".
    local r = tl.rewards or {}
    local rewardText, rewardColor
    if (r.count or 0) > 0 then
      local s = "|A:ParagonReputation_Bag:14:14|a Rewards waiting — collect at the Trading Post"
      if (r.pendingTender or 0) > 0 then
        s = s .. "   ·   " .. BreakUpLargeNumbers(r.pendingTender) .. " Trader's Tender"
      end
      -- Prefer the scan-time capture; the live lookup is the fallback for snapshots
      -- taken before the field existed.
      for _, id in ipairs(r.items or {}) do
        local stored = r.itemInfo and r.itemInfo[id]
        local icon = (stored and stored.icon) or C_Item.GetItemIconByID(id)
        if icon then s = s .. "  |T" .. icon .. ":16|t" end
      end
      rewardText, rewardColor = s, c.gold
    else
      rewardText, rewardColor = "All rewards collected", c.muted
    end
    Label:new{
      parent = self, fontInfo = theme.fonts.body, color = rewardColor,
      text = rewardText,
      position = { TopLeft = {P, -(stripTop + HEAD_H + TL_NAME_H + TL_BAR_TH + 6)} },
    }
  end

  -- Houses (endeavors) — account-wide per-house level/favor (the house's lifetime XP) over its
  -- current endeavor's progress bar (counts up toward the goal; reset on hover). Two blocks
  -- (Alliance | Horde) side by side; the crest is a pre-coloured endeavor TGA.
  if showHouses then
    local ALLIANCE_BAR, HORDE_BAR = {0.40, 0.733, 1.0, 1}, {1.0, 0.20, 0.20, 1}
    local CREST = "Interface\\AddOns\\Warbandeer\\icons\\endeavor-"
    Texture:new{
      parent = self, layer = ui.layer.Artwork, color = c.module,
      position = { TopLeft = {P - 6, -(housesTop - 6)}, Width = self._contentW + 12, Height = HOUSES_H + 12 },
    }
    capsHeader(self, "Houses", { TopLeft = {P, -housesTop} })
    local half = (self._contentW - GAP) / 2
    local blockTop = housesTop + HEAD_H
    local function houseBlock(x, view, faction)
      if not view then return end
      local crest = Texture:new{
        parent = self, layer = ui.layer.Artwork,
        position = { TopLeft = {x, -blockTop}, Size = {14, 14} },
      }
      crest:Texture(CREST .. faction)
      local head = view.name or (faction == "alliance" and "Alliance House" or "Horde House")
      if view.level then head = head .. "  ·  Lvl " .. view.level end
      if view.favor then head = head .. "  ·  " .. BreakUpLargeNumbers(view.favor) .. " XP" end
      Label:new{
        parent = self, fontInfo = theme.fonts.body, color = c.text, text = head,
        position = { TopLeft = {x + 18, -blockTop} },
      }
      local pct = (view.progress and view.required and view.required > 0) and (view.progress / view.required) or 0
      local val = (view.progress and view.required)
        and (BreakUpLargeNumbers(math.floor(view.progress + 0.5)) .. " / " .. BreakUpLargeNumbers(view.required)) or ""
      local resetTxt = view.resetAt
        and ("resets in " .. math.max(0, math.floor((view.resetAt - GetServerTime()) / 86400)) .. "d") or nil
      ns.LabeledBar:new{
        parent = self, width = half, barHeight = 8,
        label = view.title or "No active endeavor",
        value = val, pct = pct,
        barColor = faction == "alliance" and ALLIANCE_BAR or HORDE_BAR,
        valueColor = c.muted,
        -- endeavor tooltip: the still-earnable House XP (the "Available" countdown) + progress + reset
        onEnter = function(bar)
          ns.AnchorTip(bar)
          ui.tip:ClearLines()
          ui.tip:AddLine(view.title or "Endeavor")
          if view.xp then
            ui.tip:AddLine(("You can still earn |cffffffff%s|r House XP"):format(BreakUpLargeNumbers(view.xp)))
          end
          if view.progress and view.required then
            ui.tip:AddLine(("Neighborhood progress: %s / %s"):format(
              BreakUpLargeNumbers(math.floor(view.progress + 0.5)), BreakUpLargeNumbers(view.required)))
          end
          if resetTxt then ui.tip:AddLine(resetTxt) end
          ui.tip:Show()
        end,
        onLeave = function() ui.tip:Hide() end,
        position = { TopLeft = {x, -(blockTop + HOUSE_HEAD_H + 2)} },
      }
    end
    houseBlock(P, houses.alliance, "alliance")
    houseBlock(P + half + GAP, houses.horde, "horde")
  end

  -- Stat strip — one card per content column, each overlaying its column's box.
  local cardX = {col0, col1, col2}

  -- this-patch played time = each char's total minus its /played snapshot taken at
  -- first login on the current patch (PlaytimeBroker.byPatch); chars that never logged
  -- in this patch have no snapshot and contribute nothing.
  local patch = GetBuildInfo()
  local playSecs, patchSecs, topIlvl, count = 0, 0, 0, 0
  for _, toon in ipairs(ns.api.GetAllCharacters()) do
    count = count + 1
    local pt = toon.playtime
    if pt and pt.total then
      playSecs = playSecs + pt.total
      local snap = pt.byPatch and pt.byPatch[patch]
      if snap then patchSecs = patchSecs + (pt.total - snap) end
    end
    if toon.equipment and toon.equipment.ilvl and toon.equipment.ilvl > topIlvl then
      topIlvl = toon.equipment.ilvl
    end
  end

  local function card(i, caption, amount, amountColor, sub, subIcon, subColor)
    return StatCard:new{
      parent = self,
      caption = caption,
      amount = amount,
      amountColor = amountColor,
      sub = sub,
      subIcon = subIcon,
      subColor = subColor,
      subIconColor = subColor,
      position = { TopLeft = {cardX[i] - BLEED, -BLEED}, Width = colW + BLEED * 2, Height = STRIP_H },
    }
  end
  -- wealth includes the warband (account) bank, not just per-character gold
  local wealth = ns.api.GetWarbandWealth()
  local madeCopper = ns.api.GetWeeklyGoldMade()
  local madeGold = math.floor(madeCopper / 10000)
  local madeSub, trendIcon, trendColor
  if madeGold ~= 0 then
    madeSub = (madeGold > 0 and "+" or "") .. ns.wow.GoldString(madeCopper) .. "g this week"
    trendIcon = TREND_ICON .. (madeGold > 0 and "trending_up.tga" or "trending_down.tga")
    trendColor = madeGold > 0 and c.green or c.red
  end
  card(1, "Total Warband Wealth", ns.wow.CoinString(wealth), c.gold,
       madeSub, trendIcon, trendColor)
  card(2, "Total Playtime", BreakUpLargeNumbers(math.floor(playSecs / 3600)) .. " hrs", c.text,
       BreakUpLargeNumbers(math.floor(patchSecs / 3600)) .. " hrs this patch · " .. count .. " chars")
  card(3, "Top Item Level", tostring(topIlvl), ns.IlvlColorObj(topIlvl))

  self:selectExpansion(EXPANSIONS[1].key)

  -- Cold-session render glitch: cell FontStrings in the two TableFrames above can
  -- rasterize blank on the first UI load of a client session, even though text,
  -- size, visibility, and font all report correct (and the rest of the view
  -- renders fine). A *real* font change forces the client to re-rasterize them —
  -- a same-params SetFont is a no-op — so one tick after construction every cell
  -- label's font is swapped away and back. Invisible and idempotent.
  ns:after(50, function()
    ns.HealCellFonts(self.topAlts)
    for _, panel in pairs(self._panels) do ns.HealCellFonts(panel._ach) end
  end)
end, {
  name = "overview",
  background = theme.colors.window,
})
Overview.name = "overview"
Overview._title = "Overview"
ns.views.Overview = Overview

-- Live-refresh the Top Characters rating overlays when a rating changes in the shared
-- dressing room (registered once at load; Collected loads first via the OptionalDep
-- order). Mirrors CollectedView's own ratings-changed refresher. The Overview has no
-- wanted-only filter, so a mark re-apply is always enough.
if WarbandeerCollectedApi and WarbandeerCollectedApi.OnRatingsChanged then
  WarbandeerCollectedApi:OnRatingsChanged(function()
    local t = _view and _view.topAlts
    if t then t:_refreshMarks() end
  end)
end

-- Show the panel for `key`, size the reps + achievements boxes and the view to it,
-- and refit the window so the shorter expansion doesn't leave dead space below.
---@param key string
function Overview:selectExpansion(key)
  for k, panel in pairs(self._panels) do
    panel:SetShown(k == key)
  end
  self._expansion = key
  local repsH, achH = self._repsH[key], self._achH[key]
  self._modReps:Height(repsH + 12)
  self._modAch:Height(achH + 12)
  self:Width(P + self._contentW + P)
  self:Height(self._contentTop + math.max(repsH, achH, self._altH) + P)
  if self.parent and self.parent.Fit then self.parent:Fit() end
end

-- Refresh the Top Characters gear columns each time the view shows, so a
-- /collected scan run after the view was built is reflected on next open.
function Overview:OnBeforeShow()
  if self.topAlts then self.topAlts:Refresh() end
  -- Recolour achievement checklists so a mid-session earn shows without a /reload.
  for _, panel in pairs(self._panels) do
    if panel._ach then panel._ach:Refresh() end
  end
end

-- Titlebar pickers (shown only while the Overview is active): a raid picker for the
-- Top Characters gear columns (left) and the reps/achievements expansion picker
-- (right). Both sit in one container anchored by its right edge to the close button.
---@param parent Frame
---@return Frame
function Overview:BuildFilter(parent)
  local box = Frame:new{ parent = parent, position = { Height = 20 } }

  -- Pending paragon claims per expansion (tallied when the panels were built; a claim
  -- turned in mid-session clears on the next open, like the row indicators themselves).
  local counts, total = {}, 0
  for _, e in ipairs(EXPANSIONS) do
    local n = self._panels[e.key]._bars.rewardCount or 0
    counts[e.key] = n
    total = total + n
  end

  -- Expansion options carry a leading reward-bag glyph when that expansion holds a claim.
  local expOptions = {}
  for _, e in ipairs(EXPANSIONS) do
    expOptions[#expOptions + 1] = {
      key = e.key,
      label = (counts[e.key] > 0 and PARAGON_MARK .. " " or "") .. e.label,
    }
  end

  -- Titlebar "N to claim" badge — an at-a-glance signal visible on any expansion tab,
  -- shown only when at least one paragon reward is waiting.
  local badge
  if total > 0 then
    badge = Frame:new{ parent = box, position = { TopLeft = {0, 0}, Height = 20 } }
    local bg = Texture:new{ parent = badge, layer = ui.layer.Background, position = { All = true } }
    bg:Texture(BAR_TEX); bg:SliceMargins(6, 6, 6, 6); bg:SliceMode(0)
    bg:SetVertexColor(0.95, 0.75, 0.1, 0.16)
    local icon = ns.overview.ParagonBag(badge, 14)
    icon:Left(badge, ui.edge.Left, 7, 0)
    local text = total .. " to claim"
    Label:new{
      parent = badge, fontInfo = theme.fonts.stat, color = theme.colors.gold,
      text = text, position = { Left = {icon, ui.edge.Right, 5, 0} },
    }
    badge:Width(7 + 14 + 5 + #text * 6.2 + 8)
  end

  local raid = ui.FilterDropdown:new{
    parent    = box,
    bordered  = true,
    options   = ns.overview.RAIDS,
    selected  = self.topAlts._raidId,
    width     = 110,
    menuWidth = 120,
    onSelect  = function(_, key) self.topAlts:SetRaid(key) end,
    position  = badge and { TopLeft = {badge, ui.edge.TopRight, GAP, 0} } or { TopLeft = {0, 0} },
  }
  local exp = ui.FilterDropdown:new{
    parent    = box,
    bordered  = true,
    options   = expOptions,
    selected  = self._expansion,
    width     = 112,
    menuWidth = 130,
    onSelect  = function(_, key) self:selectExpansion(key) end,
    position  = { TopLeft = {raid, ui.edge.TopRight, GAP, 0} },
  }

  local w = raid:Width() + GAP + exp:Width()
  if badge then w = badge:Width() + GAP + w end
  box:Width(w)
  self._filter = box
  return box
end
