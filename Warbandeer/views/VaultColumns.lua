---@class Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Icons = ns.icons
local SummaryColumn = ns.SummaryColumn
local Center, Left = ui.justify.Center, ui.justify.Left
local tip = ui.tip
local GetServerTime = GetServerTime
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local floor, insert, concat = math.floor, table.insert, table.concat

-- Great Vault slot pips, rendered inline in a cell's text via |T...|t markup. The colour is baked
-- into the textures (gold disc = unlocked, muted ring = locked), so the plain markup form suffices.
local PIP_FULL  = "Interface\\AddOns\\Warbandeer\\icons\\pip-full"
local PIP_EMPTY = "Interface\\AddOns\\Warbandeer\\icons\\pip-empty"
local PIP_SZ = 11
local function pip(complete)
  return ("|T%s:%d:%d|t"):format(complete and PIP_FULL or PIP_EMPTY, PIP_SZ, PIP_SZ)
end

-- Per-track display label + the noun each slot threshold counts (raid bosses / M+ runs / world
-- activities), used in the pip tooltip.
local TRACK_LABEL = { Raid = "Raid", Dungeons = "Mythic+", World = "World" }
local TRACK_UNIT  = { Raid = "bosses", Dungeons = "runs", World = "activities" }
local KEY_COLOR = { 0.62, 0.80, 1.0, 1 }  -- keystone "+N" (light blue)

-- Short "Nd Nh" (or "Nh Nm" / "Nm") until a lockout resets; nil epoch → nil.
local function resetIn(epoch)
  if not epoch then return nil end
  local s = epoch - GetServerTime()
  if s <= 0 then return "now" end
  local d, h = floor(s / 86400), floor((s % 86400) / 3600)
  if d > 0 then return d .. "d " .. h .. "h" end
  local m = floor((s % 3600) / 60)
  return h > 0 and (h .. "h " .. m .. "m") or (m .. "m")
end

-- Trim a long raid name so the progress + difficulty after it stay visible in the fixed-width cell.
local function trimName(name, maxLen)
  if #name <= maxLen then return name end
  return name:sub(1, maxLen - 1) .. "…"
end

-- Rich per-slot tooltip from vaultSlots: each slot's threshold + reward ilvl (or its locked progress).
local function slotTooltip(self, slots, key)
  tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
  tip:ClearLines()
  tip:AddLine("Great Vault: " .. TRACK_LABEL[key])
  local unit = TRACK_UNIT[key]
  for i, s in ipairs(slots) do
    if s.complete then
      tip:AddLine(("Slot %d  ·  %d %s  ·  ilvl %s"):format(i, s.threshold, unit, s.ilvl and tostring(s.ilvl) or "?"))
    else
      tip:AddLine(("Slot %d  ·  %d %s  ·  locked (%d/%d)"):format(i, s.threshold, unit, s.progress, s.threshold))
    end
  end
  tip:Show()
end

-- Coarser tooltip from the aggregate `vault` field (unlocked count + overall progress; no per-slot ilvl).
local function aggTooltip(self, agg, key)
  tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
  tip:ClearLines()
  tip:AddLine("Great Vault: " .. TRACK_LABEL[key])
  tip:AddLine(("%d of 3 slots unlocked"):format(agg.complete))
  if agg.progress and agg.max then tip:AddLine(("Progress: %d/%d %s"):format(agg.progress, agg.max, TRACK_UNIT[key])) end
  tip:Show()
end

-- One track's pip cell (Raid / Mythic+ / World), `key` = a vault activity-type name. Prefers the
-- per-slot `vaultSlots` detail (pips + per-slot reward ilvl); falls back to the aggregate `vault`
-- field's unlocked count (pips only) for a character seen this week before vaultSlots was captured.
-- Blank only when the character has no vault data at all this reset (e.g. never logged in / below max).
local function trackCell(t, key)
  local w = t.weeklies
  if not w then return "" end
  local slots = w.vaultSlots and w.vaultSlots[key]
  if slots and #slots > 0 then
    local parts = {}
    for _, s in ipairs(slots) do insert(parts, pip(s.complete)) end
    return {
      text = concat(parts, " "), justifyH = Center,
      onEnter = function(self) slotTooltip(self, slots, key) end,
      onLeave = function() tip:Hide() end,
    }
  end
  local agg = w.vault and w.vault.progress and w.vault.progress[key]
  if agg then
    local parts = {}
    for i = 1, 3 do insert(parts, pip(i <= agg.complete)) end  -- the vault is always 3 slots per track
    return {
      text = concat(parts, " "), justifyH = Center,
      onEnter = function(self) aggTooltip(self, agg, key) end,
      onLeave = function() tip:Hide() end,
    }
  end
  return ""
end

---@type SummaryColumn[]  columns for the Great Vault view (a separate registry from ns.SummaryColumns)
ns.VaultColumns = {
  -- faction crest
  SummaryColumn:new{
    name = "", width = 22,
    getData = function(t) return ns.SummaryIconCell(ns.factionIcon[t.isAlliance]) end,
  },
  -- character (class-coloured) + an unclaimed-vault marker
  SummaryColumn:new{
    name = "Character", width = 128, justifyH = Left,
    getData = function(t)
      local c = t.classKey and RAID_CLASS_COLORS[t.classKey:upper()]
      local name = c and c:WrapTextInColorCode(t.name) or t.name
      if t.weeklies and t.weeklies.hasUnclaimedVault then
        name = name .. "  |A:" .. Icons.Vault .. ":13:13|a"
      end
      return { text = name, justifyH = Left }
    end,
  },
  -- level
  SummaryColumn:new{
    name = "Lvl", width = 30, justifyH = Left,
    getData = function(t) return { text = t.basic and t.basic.level or "", justifyH = Left } end,
  },
  -- Great Vault tracks — three slot pips each
  SummaryColumn:new{
    name = "Raid", key = "vaultRaid", label = "Raid", width = 60, justifyH = Center,
    getData = function(t) return trackCell(t, "Raid") end,
  },
  SummaryColumn:new{
    name = "M+", key = "vaultMPlus", label = "Mythic+", width = 60, justifyH = Center,
    getData = function(t) return trackCell(t, "Dungeons") end,
  },
  SummaryColumn:new{
    name = "World", key = "vaultWorld", label = "World", width = 60, justifyH = Center,
    getData = function(t) return trackCell(t, "World") end,
  },
  -- owned keystone (+level)
  SummaryColumn:new{
    name = "Key", key = "vaultKeystone", label = "Key", width = 42, justifyH = Center,
    getData = function(t)
      local w = t.weeklies
      if not w then return "" end
      local ks, dg = w.keystone, w.dungeons
      if not ks then
        return (w.vaultSlots or dg) and ns.ZeroDashC or ""  -- max-level with no key vs. below-max
      end
      return {
        text = "+" .. ks, justifyH = Center, color = KEY_COLOR,
        onEnter = function(self)
          tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
          tip:ClearLines()
          tip:AddLine("Owned keystone: +" .. ks)
          if dg then tip:AddLine(("Mythic+ this week: %d run%s"):format(dg.done, dg.done == 1 and "" or "s")) end
          tip:AddLine("Great Vault unlocks at 1 / 4 / 8 runs")
          tip:Show()
        end,
        onLeave = function() tip:Hide() end,
      }
    end,
  },
  -- primary raid lockout (tooltip lists them all)
  SummaryColumn:new{
    name = "Raid Lock", key = "vaultRaidLock", label = "Raid Lock", width = 118, justifyH = Left,
    getData = function(t)
      local locks = ns.api:GetRaidLocks(t.name)
      if #locks == 0 then return "" end
      local p = locks[1]
      return {
        justifyH = Left,
        text = ("%s |cffbfbfbf%d/%d|r |cffe6c35c%s|r"):format(trimName(p.name, 12), p.progress, p.total, p.label),
        onEnter = function(self)
          tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
          tip:ClearLines()
          tip:AddLine("Raid lockouts")
          for _, l in ipairs(locks) do
            local r = resetIn(l.reset)
            tip:AddLine(("%s — %s %d/%d%s"):format(l.name, l.label, l.progress, l.total, r and ("   (resets " .. r .. ")") or ""))
          end
          tip:Show()
        end,
        onLeave = function() tip:Hide() end,
      }
    end,
  },
  -- Delver's Bounty (weekly)
  SummaryColumn:new{
    name = "D-Bounty", key = "vaultDelversBounty", label = "D-Bounty", width = 74, justifyH = Center,
    getData = function(t)
      local w = t.weeklies
      if not w then return "" end
      if w.delversBounty then return ns.GreenCheck end
      return (w.vaultSlots or w.keystone or w.dungeons) and ns.ZeroDashC or ""
    end,
  },
}

-- The visible columns in display order: every always-on identity column (no `key`) plus each
-- toggleable column the user hasn't hidden. Visibility lives in db.settings.vaultColumns[key]
-- (missing/true = shown, false = hidden). Built fresh each Vault (re)build so a settings toggle
-- takes effect on the next render. The Vault twin of ns.VisibleSummaryColumns.
---@class Warbandeer
---@field VisibleVaultColumns fun(): SummaryColumn[]
function ns.VisibleVaultColumns()
  local shown = ns.db.settings.vaultColumns or {}
  local out = {}
  for _, c in ipairs(ns.VaultColumns) do
    if not c.key or shown[c.key] ~= false then
      out[#out + 1] = c
    end
  end
  return out
end
