---@type Warbandeer_Characters
local ns = select(2, ...)

-- Per-character *learned* class unlocks — items/skills that permanently grant an ability to the
-- character (a "Use: Teaches you …" tome, a crafted matrix, a looted knowledge), so the state is
-- PER CHARACTER, detected via C_SpellBook.IsSpellKnown on the granted spell. Most classes have a
-- book set — the Legion class-order-hall cosmetic/utility tomes (Corpse Exploder, Contemplation,
-- Detection, the Tomes of Hex, the Mystical / Polymorph tomes, Zen Flight, Fireworks / Play Dead) —
-- plus the two sets that predate this catalog:
--   * Druid "Tome of the Wilds" (Treant Form + Mount Form are the modern successors to the
--     removed Glyph of the Treant / Glyph of the Stag).
--   * Hunter "Tomes & Tames" — two kinds: Skill Tames (special pet families that need an unlock
--     before taming — Blood Beasts, Feathermanes, Direhorns, Mechanicals, Gargon, Cloud Serpents,
--     Undead, Dragonkin, Nah'qi, Florafaun) and utility ability tomes (Aspect of the Chameleon,
--     Fetch, Fireworks, Play Dead).
-- Abilities with no collectible item are excluded, since every entry needs a real item to show:
-- Hunter Eyes of the Beast (baseline at 29) + Ottuk Taming (Renown-granted), and Mage Polymorph:
-- Pig (learned directly from the wandering NPC The Amazing Zanzo in Dalaran for gold).
-- Keyed by classId → { itemID, spell, label, races? }. `spell` = the granted spell (IsSpellKnown
-- target); `races` (Mechanicals) = race file tokens that grant it innately (Goblin/Gnome hunters
-- tame Mechanicals without the matrix). `ns.LearnedUnlockTitle` names the per-class card section.
-- Ids from Wowhead; verified in-game via `/wbc dump glyphs`.
---@class UnlockLearn
---@field itemID integer   the unlock item
---@field spell integer    the granted spell (the IsSpellKnown target)
---@field label string     display name (pet family / form / ability; the probe verifies the item live)
---@field races table<string, boolean>?  race file tokens that grant it innately (no item needed)

---@type table<integer, UnlockLearn[]>
ns.LearnedUnlocks = {
  [2] = { -- Paladin — Divine Tome
    { itemID = 136801, spell = 121183, label = "Contemplation" },
  },
  [3] = { -- Hunter — Skill Tames + utility ability tomes (title "Tomes & Tames")
    -- Skill Tames — special pet families that require an unlock before taming.
    { itemID = 166502, spell = 288956,  label = "Blood Beasts" },
    { itemID = 147580, spell = 242155,  label = "Feathermanes" },   -- Hybrid Kinship (BM-only exotic)
    { itemID = 94232,  spell = 138430,  label = "Direhorns" },      -- Ancient Zandalari Knowledge
    -- Mecha-Bond Imprint Matrix; Goblin/Gnome hunters tame Mechanicals innately. (Spell id may be
    -- 209646 on 12.0.5+ — the probe confirms which resolves live.)
    { itemID = 134125, spell = 205154,  label = "Mechanicals", races = { Goblin = true, Gnome = true } },
    { itemID = 180705, spell = 334850,  label = "Gargon" },         -- Gargon Training Manual
    { itemID = 183123, spell = 340826,  label = "Cloud Serpents" }, -- How to School Your Serpent
    { itemID = 183124, spell = 340825,  label = "Undead" },         -- Simple Tome of Bone-Binding
    { itemID = 201791, spell = 394788,  label = "Dragonkin" },      -- How to Train a Dragonkin
    { itemID = 211314, spell = 428736,  label = "Nah'qi" },         -- Cinder of Companionship
    { itemID = 264895, spell = 1272785, label = "Florafaun" },      -- Trials of the Florafaun Hunter
    -- Utility ability tomes — teach a hunter/pet skill (not a tame); sold by the Nesingwary /
    -- Trueshot Lodge vendors.
    { itemID = 136783, spell = 61648,   label = "Aspect of the Chameleon" }, -- The Art of Concealment
    { itemID = 136781, spell = 125050,  label = "Fetch" },                   -- Pet Training Manual: Fetch
    { itemID = 136782, spell = 127933,  label = "Fireworks" },               -- Fireworks Instruction Manual
    { itemID = 136780, spell = 209997,  label = "Play Dead" },               -- Pet Training Manual: Play Dead
  },
  [4] = { -- Rogue — Dirty Tricks
    { itemID = 136803, spell = 210108, label = "Detection" },
  },
  [6] = { -- Death Knight — Necrophile Tome
    { itemID = 136796, spell = 127344, label = "Corpse Exploder" },
  },
  [7] = { -- Shaman — Tomes of Hex
    { itemID = 136972, spell = 211015, label = "Hex: Cockroach" },
    { itemID = 136938, spell = 210873, label = "Hex: Compy" },
    { itemID = 136969, spell = 211004, label = "Hex: Spider" },
  },
  [8] = { -- Mage — Mystical Tomes (Arcane Linguist / Illusion + Polymorph variants)
    { itemID = 136797, spell = 210086, label = "Arcane Linguist" },
    { itemID = 136799, spell = 131784, label = "Illusion" },
    { itemID = 44709,  spell = 61305,  label = "Polymorph: Black Cat" },
    { itemID = 120138, spell = 161354, label = "Polymorph: Monkey" },
    { itemID = 44793,  spell = 61721,  label = "Polymorph: Rabbit" },
    { itemID = 120137, spell = 161353, label = "Polymorph: Polar Bear Cub" },
    { itemID = 120140, spell = 126819, label = "Polymorph: Porcupine" },
    { itemID = 22739,  spell = 28271,  label = "Polymorph: Turtle" },
  },
  [10] = { -- Monk — Meditation Manual
    { itemID = 136800, spell = 125883, label = "Zen Flight" },
  },
  [11] = { -- Druid — Tome of the Wilds
    { itemID = 136787, spell = 114282, label = "Treant Form" },
    { itemID = 136789, spell = 210053, label = "Mount Form" },
    { itemID = 136794, spell = 164862, label = "Flap" },
    { itemID = 136795, spell = 127757, label = "Charm Woodland Creature" },
    { itemID = 136790, spell = 210065, label = "Track Beasts" },
  },
}

-- Per-class section title for the learned-unlock catalog (the Detail card header).
---@type table<integer, string>
ns.LearnedUnlockTitle = {
  [2]  = "Divine Tome",
  [3]  = "Tomes & Tames",
  [4]  = "Dirty Tricks",
  [6]  = "Necrophile Tome",
  [7]  = "Tomes of Hex",
  [8]  = "Mystical Tomes",
  [10] = "Meditation Manual",
  [11] = "Tome of the Wilds",
}

-- Merge a class's learned-unlock catalog with a character's known-spell set into a status list,
-- preserving order. Pure — no WoW API — so it's unit-tested (spec/glyphs_spec.lua). The known set
-- already folds in any race-innate unlocks (the broker stamps those), so this only reads it.
---@param list UnlockLearn[]?              the class's learned-unlock catalog
---@param known table<integer, boolean>?   the character's known unlock spell ids (nil = none scanned)
---@return { itemID: integer, label: string, spell: integer, known: boolean }[]
function ns.MergeLearnedStatus(list, known)
  local out = {}
  for _, e in ipairs(list or {}) do
    out[#out + 1] = {
      itemID = e.itemID,
      label = e.label,
      spell = e.spell,
      known = known ~= nil and known[e.spell] == true or false,
    }
  end
  return out
end
