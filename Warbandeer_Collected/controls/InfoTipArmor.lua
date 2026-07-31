---@type Warbandeer_Collected
local ns = select(2, ...)
local find, any = ns.lua.lists.find, ns.lua.maps.any
local getParts = C_TransmogSets.GetSetPrimaryAppearances
local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs

-- The armour grid's body for the shared hover panel (controls/InfoTip.lua): the hovered set's piece
-- per armour slot, coloured by collected status, under a wanted/rank status line. Lifted out of
-- InfoTip.lua unchanged when the panel grew a second body (#856) — the file was at the size limit
-- and this is the battle-tested half, so it moved rather than being rewritten around the split.

---Fill the panel's nine-slot table for one set. Registered as the "armor" body renderer.
---@param tip InfoTip
---@param desc InfoTipDesc  carries `group` and `set`, entries from ns.Sets
---@return Frame body, number bodyW, boolean incomplete
ns.InfoTipBodies.armor = function(tip, desc)
  local group, set = desc.group, desc.set
  tip.name:Text(set.name)

  -- Wanted/rank line. Inline color codes let one Label carry the gold star and a
  -- tier-colored letter; falls back to the shift-click hint when unrated.
  local race = ns:PlayerRace()
  local rank = ns:EffectiveRank(set.id, race)
  local bits = {}
  -- Inline atlas escape for the gold star (the status Label's font has no U+2605
  -- glyph, so a literal ★ renders as a missing-glyph box); same atlas as the cell mark.
  if ns:IsWanted(set.id) then bits[#bits + 1] = "|A:" .. ns.WantedIcon .. ":14:14|a |cffffd100Wanted|r" end
  if rank then
    local tag = ns:RaceRank(set.id, race) and ("Tier " .. rank .. " (race)") or ("Tier " .. rank)
    bits[#bits + 1] = "|cff" .. ns.RankHex(rank) .. tag .. "|r"
  end

  -- GetSetPrimaryAppearances returns nil (not an empty table) for a set id the client
  -- doesn't know — so coalesce before #parts. NOTE: primary appearances are a raid-tier
  -- concept; PvP sets have sources but ZERO primary appearances, so they can't be the
  -- "has data" signal (that's GetAllSourceIDs below).
  local parts = getParts(set.id) or {}
  local allSources = GetAllSourceIDs(set.id) or {}
  local scanned = ns.db.sets[group.id] and ns.db.sets[group.id][set.id]
  -- "Upcoming / no data on this client" = the set has NO appearance sources at all
  -- (a PTR-only set on a live client). A set with sources but no primary appearances
  -- (a PvP set) is NOT upcoming — it renders via the GetAllSourceIDs slot fallback below.
  local upcoming = not scanned and #allSources == 0
  if upcoming then bits[#bits + 1] = "|cff8cc8ffNot yet on live (PTR)|r" end
  tip.status:Text(#bits > 0 and table.concat(bits, "   ") or "|cff808080Shift-click to mark wanted|r")

  local incomplete = false
  if upcoming then
    for i = 1, 9 do tip.items.data[i][1] = "" end
  else
    local primary = {}
    for _,p in ipairs(parts) do primary[p.appearanceID] = true end

    local fallback   -- built lazily when a slot's per-slot source lookup is empty
    for i,slot in ipairs({1,3,15,5,6,7,8,9,10}) do
      local sources = C_TransmogSets.GetSourcesForSlot(set.id, slot)
      local _, p = find(sources, function(s) return primary[s.sourceID] end)
      local name, isCollected
      if p then
        isCollected = any(sources, function(s) return s.isCollected end)
        name = p.name
        if not name or name == "" then
          -- Name not cached yet: nudge the item to load and flag a re-render.
          incomplete = true
          local info = C_TransmogCollection.GetSourceInfo(p.sourceID)
          if info and info.itemID then C_Item.RequestLoadItemDataByID(info.itemID) end
        end
      else
        -- Per-slot API gave nothing (Trading Post / variant set): bucket the set's
        -- pieces by equip location, matching the dressing-room slots.
        fallback = fallback or ns.SetSlotPieces(set.id)
        local fb = fallback[slot]
        if fb then
          isCollected = fb.isCollected
          name = C_Item.GetItemNameByID(fb.itemID)
          if not name or name == "" then incomplete = true; C_Item.RequestLoadItemDataByID(fb.itemID) end
        end
      end
      tip.items.data[i][1] = name and {
        text = name,
        color = isCollected and ns.slotOK or ns.slotMissing,
       } or ""
    end
  end
  tip.items:update()

  -- find the widest one and resize the column
  local w = 0
  for _,r in ipairs(tip.items.cells) do
    w = max(w, r[1].label:UnboundedWidth())
  end
  tip.items.cols[1]:Width(w)
  tip.items:Width(4 + tip.items.headerWidth + w)

  return tip.items, 4 + tip.items.headerWidth + w, incomplete
end

---Show the shared InfoTip for a transmog set, positioned relative to a cell.
---@class Warbandeer_Collected
---@field ShowInfoTip fun(group: table, set: table, parent: Frame, position: table) group/set are entries from ns.Sets; position is a LibNUI position spec
ns.ShowInfoTip = function(group, set, parent, position)
  ns.ShowInfoTipFor{ kind = "armor", group = group, set = set, parent = parent, position = position }
end
