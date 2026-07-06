---@type ShadowsOfUI_Reputations
local ns = select(2, ...)
local concat = table.concat

-- Append the cross-alt standing block to an item tooltip when the item is tied to a tracked
-- faction. There's no item->faction API, so match a cached faction name appearing anywhere in
-- the tooltip text (a rep token's "increases your reputation with X", a tabard's name, etc.) —
-- locale-consistent since the cached names and the live tooltip share the client locale.
--
-- Item tooltips re-fire constantly (mouseover refreshes, comparison toggles) for the same item,
-- so memoize the resolved faction per itemID (false = "no faction", a negative result worth
-- caching too) and wipe the whole memo whenever the name index is rebuilt.
local memo = {}
local memoGen
ns:OnItemTooltip(function(tooltip, data)
  if not data.lines then return end
  -- A loading/empty item tooltip (or some hyperlink-routed ones) fires with a nil id;
  -- memo[nil] = fid would raise 'table index is nil'. Guard like the sibling consumers
  -- (ShadowsOfUI-Known, ShadowsOfUI-WarbandInventory) do.
  if not data.id then return end
  if memoGen ~= ns._factionIndexGen then
    wipe(memo)
  end
  local fid = memo[data.id]
  if fid == nil then
    local buf = {}
    for i = 1, #data.lines do
      local t = data.lines[i].leftText
      if t then buf[#buf + 1] = t:lower() end
    end
    fid = ns.FactionIDByName(concat(buf, "\n")) or false
    memo[data.id] = fid
  end
  -- Sync AFTER the resolve: FactionIDByName can lazily build the index (bumping the
  -- gen), so syncing at the top would leave memoGen one behind and force a spurious
  -- wipe on the next tooltip.
  memoGen = ns._factionIndexGen
  if not fid then return end
  ns.AppendStandings(tooltip, fid) -- item tooltips auto-show after post-calls; no Show() needed
end)

-- /sreps <factionID | faction name> — print the cross-alt standings for a faction (testing
-- aid + a quick "who's exalted with X?" lookup, since tooltip text can't be copied).
SLASH_SUI_REPS1 = "/sreps"
SlashCmdList["SUI_REPS"] = function(msg)
  msg = msg and msg:match("^%s*(.-)%s*$") or ""
  local fid = tonumber(msg:match("^%d+$"))
  if not fid and msg ~= "" then fid = ns.FactionIDByQuery(msg:lower()) end
  if not fid then ns.Print("Usage: /sreps <factionID or faction name>") return end
  local list = ns.api:GetFactionStandings(fid)
  if not list then ns.Print("No tracked standings for faction", fid, "(log alts in to populate).") return end
  if list[1].accountWide then
    ns.Print(("Faction %d (warband-wide): %s%s"):format(fid, list[1].label, list[1].paragon and " (Paragon)" or ""))
    return
  end
  ns.Print(("Standings for faction %d:"):format(fid))
  for _, e in ipairs(list) do
    ns.Print(("  %s: %s%s"):format(e.name, e.label, e.paragon and " (Paragon)" or ""))
  end
end
