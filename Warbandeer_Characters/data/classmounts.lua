---@type Warbandeer_Characters
local ns = select(2, ...)

-- Static class-mount catalog: the per-class Legion order-hall mounts (and their spec-gated
-- colour tints) as ACCOUNT-WIDE collectibles. Mount collection is account-wide, so owned state
-- is identical for every character of the class and needs no per-character storage — read live
-- via C_MountJournal, mirroring ns.AppearanceUnlocks (data/glyphinfo.lua). The character's class
-- only selects which roster to show.
--
-- Each entry keys by EITHER a summon `spellID` or a teaching `itemID` (whichever the source
-- gives); api.lua's GetClassMounts resolves it uniformly via C_MountJournal.GetMountFromSpell /
-- GetMountFromItem → GetMountInfoByID (icon, name, isCollected).
--
-- TINT SEMANTICS: where a class's spec tints are SEPARATE collectibles they each get their own
-- entry with a distinct id (Paladin / Rogue / Hunter / Warlock — the source lists a distinct
-- item per tint). The Death Knight mount is the exception: its three spec colours (red Blood /
-- blue Frost / green Unholy) are a SINGLE mount-journal entry whose colour follows the rider's
-- active spec — one collectible, not three (item 142231 → one mountID). So DK gets one entry.
--
-- `source` is an inline "How to obtain" hint, shown in the hover tooltip for an unowned mount.
-- Kept inline (not data/collectiblesources.lua, which keys by itemID) because several tint mounts
-- are quest-granted with no teaching item, so an itemID key doesn't exist for them.
--
-- Item / spell ids are ported from the #504 class-collectibles research (Wowhead's Class-Specific
-- Toys, Mounts and More guide) and verified in-game via `/wbc dump mounts`, which prints each
-- entry's stored label beside its live-resolved mount name (a wrong id reads mismatch / missing).
--
-- Keyed by classId (1 Warrior · 2 Paladin · 3 Hunter · 4 Rogue · 5 Priest · 6 Death Knight ·
-- 7 Shaman · 8 Mage · 9 Warlock · 10 Monk · 11 Druid · 12 Demon Hunter). Evoker (13) is excluded:
-- its Vorquin are racial-vendor mounts, not a class-hall mount.

---@class ClassMountInfo
---@field spellID integer?  summon spell id (resolved via GetMountFromSpell); one of spellID/itemID
---@field itemID integer?   teaching item id (resolved via GetMountFromItem); one of spellID/itemID
---@field label string      mount name (English; the probe verifies it live)
---@field source string?    "How to obtain" hint for an unowned mount (hover tooltip)

---@type table<integer, ClassMountInfo[]>
ns.ClassMounts = {
  [1] = { -- Warrior (Skyhold)
    { itemID = 142232, label = "Bloodthirsty War Wyrm",
      source = "Warrior order hall (Skyhold): class-mount campaign reward." },
  },
  [2] = { -- Paladin (Sanctum of Light) — Highlord's Charger + spec tints (separate collectibles)
    { itemID = 143502, label = "Highlord's Golden Charger",
      source = "Paladin order hall (Sanctum of Light): class-mount campaign reward." },
    { itemID = 143505, label = "Highlord's Valorous Charger",
      source = "Paladin order hall: class-mount spec tint, unlocked alongside the Golden Charger." },
    { itemID = 143503, label = "Highlord's Vengeful Charger",
      source = "Paladin order hall: class-mount spec tint, unlocked alongside the Golden Charger." },
    { itemID = 143504, label = "Highlord's Vigilant Charger",
      source = "Paladin order hall: class-mount spec tint, unlocked alongside the Golden Charger." },
    { itemID = 47179, label = "Reins of the Argent Charger",
      source = "Argent Tournament quartermaster (Paladin only), as a Champion of the Argent Crusade." },
  },
  [3] = { -- Hunter (Trueshot Lodge) — Wolfhawk tints (separate collectibles)
    { itemID = 142227, label = "Loyal Wolfhawk",
      source = "Hunter order hall (Trueshot Lodge): class-mount campaign reward." },
    { itemID = 142226, label = "Fierce Wolfhawk",
      source = "Hunter order hall: class-mount tint, unlocked alongside the Loyal Wolfhawk." },
    { itemID = 142228, label = "Dire Wolfhawk",
      source = "Hunter order hall: class-mount tint, unlocked alongside the Loyal Wolfhawk." },
  },
  [4] = { -- Rogue (Hall of Shadows) — Shadowblade's Omen steeds (4 separate tints)
    { itemID = 143493, label = "Shadowblade's Murderous Omen",
      source = "Rogue order hall (Hall of Shadows): class-mount campaign reward." },
    { itemID = 143491, label = "Shadowblade's Baneful Omen",
      source = "Rogue order hall: class-mount tint, unlocked alongside the Murderous Omen." },
    { itemID = 143490, label = "Shadowblade's Lethal Omen",
      source = "Rogue order hall: class-mount tint, unlocked alongside the Murderous Omen." },
    { itemID = 143492, label = "Shadowblade's Ruthless Omen",
      source = "Rogue order hall: class-mount tint, unlocked alongside the Murderous Omen." },
  },
  [5] = { -- Priest (Netherlight Temple)
    { itemID = 142224, label = "High Priest's Lightsworn Seeker",
      source = "Priest order hall (Netherlight Temple): class-mount campaign reward." },
  },
  [6] = { -- Death Knight (Acherus) — the class mount is ONE entry; its colour follows the spec
    { itemID = 142231, label = "Deathlord's Vilebrood Vanquisher",
      source = "Death Knight order hall (Acherus): class-mount campaign reward. One mount; its "
        .. "colour follows your active spec (red Blood / blue Frost / green Unholy)." },
    { itemID = 40775, label = "Winged Steed of the Ebon Blade",
      source = "Dread Commander Thalanor in Acherus: The Ebon Hold (cost scales with Knights of "
        .. "the Ebon Blade reputation)." },
    { spellID = 48778, label = "Acherus Deathcharger",
      source = "Automatically learned by every Death Knight." },
  },
  [7] = { -- Shaman (The Maelstrom / Heart of Azeroth)
    { itemID = 143489, label = "Raging Tempest",
      source = "Shaman order hall (The Maelstrom): class-mount campaign reward." },
  },
  [8] = { -- Mage (Hall of the Guardian)
    { spellID = 229376, label = "Archmage's Prismatic Disc",
      source = "Mage order hall (Hall of the Guardian): class-mount campaign reward." },
  },
  [9] = { -- Warlock (Dreadscar Rift) — Wrathsteed + tints (separate collectibles)
    { spellID = 232412, label = "Netherlord's Chaotic Wrathsteed",
      source = "Warlock order hall (Dreadscar Rift): class-mount campaign reward." },
    { itemID = 143637, label = "Netherlord's Brimstone Wrathsteed",
      source = "Warlock order hall: class-mount tint, unlocked alongside the Chaotic Wrathsteed." },
    { itemID = 142233, label = "Netherlord's Accursed Wrathsteed",
      source = "Warlock order hall: class-mount tint, unlocked alongside the Chaotic Wrathsteed." },
  },
  [10] = { -- Monk (Peak of Serenity)
    { itemID = 142225, label = "Ban-Lu, Grandmaster's Companion",
      source = "Monk order hall (Peak of Serenity): class-mount campaign reward." },
  },
  [11] = { -- Druid (The Dreamgrove)
    { itemID = 143638, label = "Lunarwing",
      source = "Druid order hall (The Dreamgrove): class-mount campaign reward (Moon-Kissed Feather)." },
  },
  [12] = { -- Demon Hunter (Fel Hammer)
    { spellID = 200175, label = "Felsaber",
      source = "Demon Hunter starting mount (Fel Hammer / Mardum)." },
    { spellID = 241856, label = "Slayer's Felbroken Shrieker",
      source = "Demon Hunter order hall (Fel Hammer): class-mount campaign reward." },
  },
}

-- `/wbc dump mounts` (+ `wdump mounts`): the in-game verification probe. Prints each catalog
-- entry's stored label beside its live-resolved mountID + mount name and collected state — a
-- wrong or duplicate id reads "<unresolved>"/mismatch/shared mountID, never a false owned.
ns:registerDump("mounts", "Class Mounts",
  "Owned/missing class mounts + spec tints for the current character's class",
  function(_, out)
    local toon = ns.currentData
    if not toon then out:line("No current character."); return end
    local list = ns.ClassMounts[toon.classId]
    if not list then out:line(("Class %d has no class-mount catalog."):format(toon.classId)); return end
    local mounts = ns.api:GetClassMounts()
    local owned = 0
    for _, m in ipairs(mounts) do if m.owned then owned = owned + 1 end end
    out:line(("Class Mounts — %d / %d owned:"):format(owned, #mounts))
    for i, e in ipairs(list) do
      local key = e.spellID and ("spell %d"):format(e.spellID) or ("item %d"):format(e.itemID)
      local mountID = (e.spellID and C_MountJournal.GetMountFromSpell(e.spellID))
        or (e.itemID and C_MountJournal.GetMountFromItem(e.itemID))
      local liveName = (mountID and C_MountJournal.GetMountInfoByID(mountID)) or "<unresolved>"
      local m = mounts[i]
      out:line(("  %s  [%s -> mount %s]  live=%q%s"):format(
        e.label, key, tostring(mountID), liveName, (m and m.owned) and "  <COLLECTED>" or ""))
    end
  end, true)
