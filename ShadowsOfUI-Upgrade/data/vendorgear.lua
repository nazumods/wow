---@class ShadowsOfUI_Upgrade
local ns = select(2, ...)

-- Faction-quartermaster gear: a small, hand-maintained list of the current
-- expansion's quartermaster gear pieces that can be *bought* (for a currency),
-- so the Suggested box can point a character at "go buy the <slot> piece from
-- <quartermaster>".  Unlike the held/warband/world-quest sources this isn't read
-- from the data layer — quartermaster stock is fixed game data with a handful of
-- entries, so it's cheaper to bundle than to scan and cache merchant inventory.
--
-- Each entry is one slot at one quartermaster.  `options` lists the purchasable
-- items for that slot: the four armour-type variants (cloth/leather/mail/plate)
-- for body armour, or the genuine alternatives for an armour-type-less slot (a
-- neck has two stat variants).  The evaluator (upgrade.lua VendorUpgrades) keeps
-- only the options the viewing character can equip — `CanEquip` selects the right
-- armour type for body slots and passes every option for necks/rings — then picks
-- the best-fitting one by stat tag, so one row surfaces per slot.
--
-- ilvl/cost are fixed per piece, captured here so no item load is needed to gate
-- the upgrade.  **Regenerate this table each season** when the quartermaster gear
-- changes (mirrors data/statpriority.lua's refresh note); the links pin the ilvl
-- via their bonus IDs, so a piece renders at its true level on any character.

---@class VendorGearOption
---@field itemID integer
---@field subClassID integer Enum.ItemArmorSubclass (1 cloth, 2 leather, 3 mail, 4 plate; 0 = no armour type)
---@field link string item link (bonus-ID-pinned to the purchasable ilvl)

---@class VendorGearEntry
---@field quartermaster string vendor NPC name ("Buy from <quartermaster>")
---@field zone string zone the quartermaster is in
---@field mapID integer zone uiMapID (opens the world map to the quartermaster)
---@field cost string human-readable price ("25 Voidlight Marl")
---@field ilvl integer item level every option in this entry is
---@field equipLoc string INVTYPE_* the slot the pieces fill
---@field classID integer Enum.ItemClass (Armor for all current pieces)
---@field options VendorGearOption[] purchasable variants (armour types / stat alternatives)

---@type VendorGearEntry[]
ns.VendorGear = {
  { -- Eversong head — Caeris Fairdawn
    quartermaster = "Caeris Fairdawn", zone = "Eversong", mapID = 2395,
    cost = "25 Voidlight Marl", ilvl = 180, equipLoc = "INVTYPE_HEAD", classID = 4,
    options = {
      { itemID = 267638, subClassID = 1, -- cloth
        link = "|cnIQ3:|Hitem:267638::::::::82:265::25:3:13578:13649:12667:1:28:3085:::::|h[Tarnished Silvermoon Sunspire]|h|r" },
      { itemID = 267639, subClassID = 2, -- leather
        link = "|cnIQ3:|Hitem:267639::::::::84:259::25:3:13578:13649:12667:1:28:3085:::::|h[Tarnished Silvermoon Sunguard]|h|r" },
      { itemID = 267640, subClassID = 3, -- mail
        link = "|cnIQ3:|Hitem:267640::::::::83:253::25:3:13578:13649:12667:1:28:3085:::::|h[Tarnished Silvermoon Sunveil]|h|r" },
      { itemID = 267641, subClassID = 4, -- plate
        link = "|cnIQ3:|Hitem:267641::::::::84:70::25:3:13578:13649:12667:1:28:3085:::::|h[Tarnished Silvermoon Suncrest]|h|r" },
    },
  },
  { -- Harandar waist — Naynar
    quartermaster = "Naynar", zone = "Harandar", mapID = 2413,
    cost = "25 Voidlight Marl", ilvl = 180, equipLoc = "INVTYPE_WAIST", classID = 4,
    options = {
      { itemID = 267479, subClassID = 1, -- cloth
        link = "|cnIQ3:|Hitem:267479::::::::85:258::25:3:13578:13649:12667:1:28:3087:::::|h[Aspiring Hara'ti Defender's Sash]|h|r" },
      { itemID = 267480, subClassID = 2, -- leather
        link = "|cnIQ3:|Hitem:267480::::::::84:259::25:3:13578:13649:12667:1:28:3087:::::|h[Aspiring Hara'ti Defender's Cord]|h|r" },
      { itemID = 267481, subClassID = 3, -- mail
        link = "|cnIQ3:|Hitem:267481::::::::83:253::25:3:13578:13649:12667:1:28:3087:::::|h[Aspiring Hara'ti Defender's Belt]|h|r" },
      { itemID = 267482, subClassID = 4, -- plate
        link = "|cnIQ3:|Hitem:267482::::::::84:70::25:3:13578:13649:12667:1:28:3087:::::|h[Aspiring Hara'ti Defender's Greatbelt]|h|r" },
    },
  },
  { -- Voidstorm hands — Void Researcher Anomander
    quartermaster = "Void Researcher Anomander", zone = "Voidstorm", mapID = 2405,
    cost = "25 Voidlight Marl", ilvl = 180, equipLoc = "INVTYPE_HAND", classID = 4,
    options = {
      { itemID = 267607, subClassID = 1, -- cloth
        link = "|cnIQ3:|Hitem:267607::::::::85:258::25:2:13578:13649:1:28:3084:::::|h[Hazy Penumbral Handwraps]|h|r" },
      { itemID = 267606, subClassID = 2, -- leather
        link = "|cnIQ3:|Hitem:267606::::::::84:259::25:2:13578:13649:1:28:3084:::::|h[Gloves of Infinite Gravity]|h|r" },
      { itemID = 267605, subClassID = 3, -- mail
        link = "|cnIQ3:|Hitem:267605::::::::83:253::25:2:13578:13649:1:28:3084:::::|h[Neverending Vortex Grasps]|h|r" },
      { itemID = 267604, subClassID = 4, -- plate
        link = "|cnIQ3:|Hitem:267604::::::::84:70::25:2:13578:13649:1:28:3084:::::|h[Clutches of the Colossal Behemoths]|h|r" },
    },
  },
  { -- Zul'aman neck — Magovu (two stat variants; necks have no armour type)
    quartermaster = "Magovu", zone = "Zul'aman", mapID = 2437,
    cost = "25 Voidlight Marl", ilvl = 180, equipLoc = "INVTYPE_NECK", classID = 4,
    options = {
      { itemID = 267642, subClassID = 0,
        link = "|cnIQ3:|Hitem:267642::::::::84:70::25:2:13649:13668:1:28:3086:::::|h[Worn Amani Heartstring Pendant]|h|r" },
      { itemID = 267643, subClassID = 0,
        link = "|cnIQ3:|Hitem:267643::::::::85:104::25:2:13649:13668:1:28:3086:::::|h[Worn Amani Totemstring]|h|r" },
    },
  },
}
