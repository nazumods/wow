---@type Warbandeer_Characters
local ns = select(2, ...)
local insert = table.insert
local C_StableInfo = C_StableInfo
local GetServerTime = GetServerTime
local date = date
local HUNTER = 3 -- classId; only Hunters have a stable

---@class PetRecord
---@field name string        the pet's (renameable) name
---@field family string      localized family name (Cat, Spirit Beast, …)
---@field level integer      raw PetInfo.level — a stored last-active level, stale for un-summoned stabled pets (pets scale to the hunter's level, so the UI shows the character's level instead; kept for the /wbc dump probe)
---@field spec string        pet specialization (Ferocity / Tenacity / Cunning)
---@field icon integer       family icon fileID
---@field creatureID integer stable creature id — locale-independent, the Challenge-Tames matching key
---@field displayID integer  display id — recolor granularity (Sabertron colours, Deth'tilac recolors, …)
---@field exotic boolean     an exotic family (Beast Mastery only)

---@class PetsData
---@field scannedAt integer server time of the last scan (captured at a stable master)
---@field active PetRecord[] the currently-loaded Call Pet slots
---@field stable PetRecord[] the stabled pets

---@class Character
---@field pets PetsData?

-- A Hunter's pets — active (Call Pet slots) + stabled — are only reliably readable while a stable
-- master's frame is open: the Blizzard stable UI drives everything off PET_STABLE_SHOW and calls
-- C_StableInfo.ClosePetStables() on close, tearing the lists down. So this is a last-seen cache
-- captured on the stable events, mirroring the bank/mail/auction scanners — not a login broker.
-- Both PetInfo lists carry a stable creatureID + displayID, which a future Challenge-Tames checklist
-- keys off (a pet's name is user-renameable, so it can't be matched on).
---@param info PetInfo
---@return PetRecord
local function record(info)
  return {
    name = info.name,
    family = info.familyName,
    level = info.level,
    spec = info.specialization,
    icon = info.icon,
    creatureID = info.creatureID,
    displayID = info.displayID,
    exotic = info.isExotic,
  }
end

---@param list PetInfo[]
---@return PetRecord[]
local function records(list)
  local out = {}
  for _, info in ipairs(list) do insert(out, record(info)) end
  return out
end

local function scan()
  local toon = ns.currentData
  if not toon or toon.classId ~= HUNTER then return end
  toon.pets = {
    scannedAt = GetServerTime(),
    active = records(C_StableInfo.GetActivePetList()),
    stable = records(C_StableInfo.GetStabledPetList()),
  }
end

-- The stable frame opens (SHOW) then streams its contents in (UPDATE); scan on both so the cache
-- reflects the fully-populated lists. Cheap enough to run per event — a Hunter has at most a few
-- hundred pets — so no debounce (mirrors the auction scanner).
ns:registerEvent("PET_STABLE_SHOW", scan)
ns:registerEvent("PET_STABLE_UPDATE", scan)

-- A Hunter's active (Call Pet) roster is configured at a stable, but its pets keep LEVELING — and can
-- be renamed — out in the world, where PET_INFO_UPDATE fires. Refresh just the active list from it so
-- those levels/names stay current between stable visits. Guarded two ways: only for a Hunter that
-- already has a stable-captured roster (the stable scan owns the full active+stable capture and the
-- "stable pets" missing flag; scannedAt stays the last full-scan time), and only when the API returns
-- pets — away from a stable GetActivePetList may read empty, which must not clobber the last-seen list.
local function refreshActive()
  local toon = ns.currentData
  if not toon or toon.classId ~= HUNTER or not toon.pets then return end
  local active = C_StableInfo.GetActivePetList()
  if #active > 0 then toon.pets.active = records(active) end
end
ns:registerEvent("PET_INFO_UPDATE", refreshActive)

-- `/wbc dump pets` (+ `wdump pets`): verify the captured roster + the stable ids the future
-- Challenge-Tames checklist will match on. toWindow=true — a full stable is too large for chat, so
-- even the `dump` variant opens the copy window.
ns:registerDump("pets", "Hunter Pets",
  "Active + stabled pets for the current Hunter (visit a stable master to capture)",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    if toon.classId ~= HUNTER then out:line("Not a Hunter."); return end
    local pets = toon.pets
    if not pets then out:line("No pets captured — visit a stable master."); return end
    out:line("Scanned " .. date("%Y-%m-%d %H:%M", pets.scannedAt))
    local function section(title, list)
      out:line(("%s (%d):"):format(title, #list))
      for _, p in ipairs(list) do
        out:line(("  %s — Lv %d %s %s%s  [creature %d / display %d]"):format(
          p.name, p.level, p.family, p.spec, p.exotic and " (Exotic)" or "",
          p.creatureID, p.displayID))
      end
    end
    section("Active", pets.active)
    section("Stable", pets.stable)
  end, true)

-- `/wbc dump tames` (+ `wdump tames`): verify the Challenge-Tames catalog (data/challengetames.lua)
-- against the current Hunter's captured roster — each entry's label, creatureID (+ displayID for a
-- recolor entry) and OWNED (naming the matched pet) / missing, grouped by category. The in-game loop
-- that confirms a seed creatureID/displayID actually matches a stored pet before it's locked in; pair
-- with `dump pets` (which prints each owned pet's creature/display) to source a recolor's displayID.
-- toWindow=true — the catalog is longer than a chat dump wants.
ns:registerDump("tames", "Challenge Tames",
  "Owned/missing rare 'secret' tames for the current Hunter, matched by creatureID/displayID",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    if toon.classId ~= HUNTER then out:line("Not a Hunter."); return end
    local tames = ns.api:GetChallengeTames()
    if not tames then out:line("No challenge-tames catalog."); return end
    local owned = 0
    for _, t in ipairs(tames) do if t.owned then owned = owned + 1 end end
    out:line(("Challenge Tames — %d / %d owned:"):format(owned, #tames))
    local cat
    for _, t in ipairs(tames) do
      if t.category ~= cat then cat = t.category; out:line(cat .. ":") end
      local key = t.displayID and ("creature %d / display %d"):format(t.creatureID, t.displayID)
        or ("creature %d"):format(t.creatureID)
      out:line(("  %s  [%s]%s"):format(t.label, key,
        t.owned and ("  <OWNED as %s>"):format(t.petName or "?") or ""))
    end
  end, true)

-- Missing report: a Hunter's roster is only readable at a stable master, so a Hunter with no
-- `pets` cache hasn't visited one since the field was added. Non-Hunters have no stable.
ns:RegisterMissing{
  order = 130,
  check = function(toon) if toon.classId == HUNTER and not toon.pets then return "stable pets" end end,
}
