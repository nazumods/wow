local _, ns = ...
local Set = ns.lua.sets.Set

local wow = {
  maxLevel = GetMaxLevelForPlayerExpansion(),
}
ns.wow = wow

local Cloth, Leather, Mail, Plate = "Cloth", "Leather", "Mail", "Plate"
ns.wow.Armor = {
  Cloth = Cloth,
  Leather = Leather,
  Mail = Mail,
  Plate = Plate,

  byClass = {
    Druid = Leather,
    DeathKnight = Plate,
    DemonHunter = Leather,
    Evoker = Mail,
    Hunter = Mail,
    Mage = Cloth,
    Monk = Leather,
    Paladin = Plate,
    Priest = Cloth,
    Rogue = Leather,
    Shaman = Mail,
    Warlock = Cloth,
    Warrior = Plate,
  },
}
ns.wow.Armor.types = {Cloth, Leather, Mail, Plate}

ns.wow.ClassKeys = Set{"DeathKnight", "DemonHunter", "Druid", "Evoker", "Hunter", "Mage", "Monk", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"}
ns.wow.ClassByKey = {
  DeathKnight = "Death Knight",
  DemonHunter = "Demon Hunter",
  Druid = "Druid",
  Evoker = "Evoker",
  Hunter = "Hunter",
  Mage = "Mage",
  Monk = "Monk",
  Paladin = "Paladin",
  Priest = "Priest",
  Rogue = "Rogue",
  Shaman = "Shaman",
  Warlock = "Warlock",
  Warrior = "Warrior",
}

ns.wow.Specializations = {
  DeathKnight = {"Blood", "Frost", "Unholy"},
  DemonHunter = {"Vengeance", "Havoc"},
  Druid = {"Restoration", "Feral", "Guardian", "Balance"},
  Evoker = {"Augmentation", "Devastation", "Preservation"},
  Hunter = {"Marksmanship", "Beast Mastery", "Survival"},
  Mage = {"Arcane", "Frost", "Fire"},
  Monk = {"Brewmaster", "Mistweaver", "Windwalker"},
  Paladin = {"Protection", "Retribution", "Holy"},
  Priest = {"Discipline", "Holy", "Shadow"},
  Rogue = {"Assassination", "Outlaw", "Subtlety"},
  Shaman = {"Elemental", "Enhancement","Restoration"},
  Warlock = {"Affliction", "Demonology", "Destruction"},
  Warrior = {"Arms", "Fury", "Protection"},
}
