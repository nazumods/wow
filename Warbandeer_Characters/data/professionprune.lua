---@type Warbandeer_Characters
local ns = select(2, ...)

-- `/wbc cleanup professions [preview]` (#1049): drops saved data for professions a character no longer has.
-- The professions / gear / concentration / Moxie / weekly-knowledge fields all copy their stored table
-- forward and only add to it, so a dropped profession keeps every entry (and ShadowsOfUI-Known keeps crediting
-- the character with its recipes). This is an explicit command, never run at login: it deletes data, which the
-- DB-compat rule reserves for a user-invoked cleanup.

-- [broker on the character] = field holding a table keyed by PARENT skill line ID.
local KEYED_BY_SKILL = {
  { "professions", "details" },
  { "professions", "gear" },
  { "concentration", "data" },
  { "artisanCurrency", "data" },
  { "professionKnowledge", "data" },
}

-- Only these parent skill lines are ever pruned: the crafting and gathering professions of
-- data/professioninfo.lua (Alchemy, Blacksmithing, Enchanting, Engineering, Herbalism, Inscription,
-- Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring). Other keys in these stores (Archaeology gear,
-- which the gear scan writes for every Enum.Profession but `basic.professions` never records; Fishing and
-- Cooking, which have no per-slot data to drop; unknown or Forever ids) are left alone, which bounds the
-- damage of any wrong "absent means dropped" assumption.
local PRUNABLE = {
  [171] = true, [164] = true, [333] = true, [202] = true, [182] = true, [773] = true,
  [755] = true, [165] = true, [186] = true, [393] = true, [197] = true,
}

---The skill line IDs a character currently has, from the last `basic.professions` capture.
---@param toon Character
---@return table<integer, true>? ids  nil when the snapshot can't be trusted: no primary/secondary profession
---  with a skill ID (a transient empty read looks like "dropped them all"), or a slot that is a table
---  without one (a half-loaded read)
local function currentSkillIDs(toon)
  local profs = toon.basic and toon.basic.professions
  if not profs then return nil end
  local ids, haveMain = {}, false
  for _, slot in ipairs({ "primary", "secondary", "fishing", "cooking" }) do
    local p = profs[slot]
    if type(p) == "table" then
      if not p.skillID then return nil end
      ids[p.skillID] = true
      if slot == "primary" or slot == "secondary" then haveMain = true end
    end
  end
  return haveMain and ids or nil
end

---Remove (or, with apply=false, just count) stored profession data for crafting/gathering skill lines the
---character no longer has.
---@param toon Character
---@param apply boolean  false = report only
---@param live table<integer, true>?  skill IDs read live from the client for the logged-in character; when
---  given it must show a primary/secondary profession itself, and anything it holds counts as held too
---@return integer removed  entries removed (or that would be)
---@return boolean skipped  true when the character's current professions are unreliable, so nothing was touched
function ns.PruneProfessionData(toon, apply, live)
  local ids = currentSkillIDs(toon)
  if not ids then return 0, true end
  if live then
    local any = false
    for id in pairs(live) do ids[id] = true; any = true end
    if not any then return 0, true end
  end
  local removed = 0
  for _, path in ipairs(KEYED_BY_SKILL) do
    local holder = toon[path[1]]
    local tbl = holder and holder[path[2]]
    if type(tbl) == "table" then
      local stale = {}
      for skillID in pairs(tbl) do
        if PRUNABLE[skillID] and not ids[skillID] then stale[#stale + 1] = skillID end
      end
      for _, skillID in ipairs(stale) do
        if apply then tbl[skillID] = nil end
        removed = removed + 1
      end
    end
  end
  return removed, false
end

---Skill IDs of the logged-in character's professions as the client reports them right now.
---@return table<integer, true>
local function liveSkillIDs()
  local ids = {}
  local professions = ns.wow.Player:GetProfessions()
  for _, slot in ipairs({ "prof1", "prof2" }) do
    local info = professions[slot] and professions[slot]:GetInfo()
    if info and info.skillID then ids[info.skillID] = true end
  end
  return ids
end

ns:registerCommand("cleanup", "professions", function(self, args)
  local mode = args or ""
  if mode ~= "" and mode ~= "preview" and mode ~= "apply" then
    ns.Print("Usage: /wbc cleanup professions [preview|apply]  (no argument = preview)")
    return
  end
  local apply = mode == "apply"
  local total, skippedNames = 0, {}
  for name, toon in pairs(self.db.characters) do
    local removed, skipped = ns.PruneProfessionData(toon, apply, name == self.currentPlayer and liveSkillIDs() or nil)
    if skipped then
      skippedNames[#skippedNames + 1] = name
    elseif removed > 0 then
      ns.Print(("%s: %s %d stale profession entr%s."):format(
        name, apply and "removed" or "would remove", removed, removed == 1 and "y" or "ies"))
      total = total + removed
    end
  end
  if #skippedNames > 0 then
    table.sort(skippedNames)
    ns.Print("Skipped (professions not reliably captured yet, log in once): " .. table.concat(skippedNames, ", "))
  end
  if total == 0 then
    ns.Print("No stale profession data.")
  elseif not apply then
    ns.Print("Nothing deleted. Run /wbc cleanup professions apply to delete it.")
  end
end, "Preview (default) or 'apply' deleting saved data for professions a character no longer has")
