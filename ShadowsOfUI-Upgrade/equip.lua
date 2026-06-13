---@type ShadowsOfUI_Upgrade
local ns = select(2, ...)
local Armor = Enum.ItemClass.Armor
local Weapon = Enum.ItemClass.Weapon

-- Maps an item's INVTYPE to the equipment slot(s) it competes with, and decides
-- whether a class can actually equip it (armour type, shield, weapon proficiency).

-- Enum.ItemArmorSubclass IDs for the four wearable armour types.
local ARMOR_TYPE_ID = { Cloth = 1, Leather = 2, Mail = 3, Plate = 4 }

-- Equipment-slot names (matching equipment.slots keys) an item type can fill.
-- A loose one-hander/2H/ranged is compared against the main hand; only true
-- off-hand items (off-hand weapon, shield, frill) contest the off-hand — this
-- avoids comparing a weapon's ilvl against a shield's.
local SLOTS_FOR = {
  INVTYPE_HEAD           = { "Head" },
  INVTYPE_NECK           = { "Neck" },
  INVTYPE_SHOULDER       = { "Shoulder" },
  INVTYPE_CLOAK          = { "Back" },
  INVTYPE_CHEST          = { "Chest" },
  INVTYPE_ROBE           = { "Chest" },
  INVTYPE_WAIST          = { "Waist" },
  INVTYPE_LEGS           = { "Legs" },
  INVTYPE_FEET           = { "Feet" },
  INVTYPE_WRIST          = { "Wrist" },
  INVTYPE_HAND           = { "Hands" },
  INVTYPE_FINGER         = { "Finger1", "Finger2" },
  INVTYPE_TRINKET        = { "Trinket1", "Trinket2" },
  INVTYPE_WEAPON         = { "MainHand" },
  INVTYPE_2HWEAPON       = { "MainHand" },
  INVTYPE_WEAPONMAINHAND = { "MainHand" },
  INVTYPE_RANGED         = { "MainHand" },
  INVTYPE_RANGEDRIGHT    = { "MainHand" },
  INVTYPE_WEAPONOFFHAND  = { "OffHand" },
  INVTYPE_SHIELD         = { "OffHand" },
  INVTYPE_HOLDABLE       = { "OffHand" },
}

-- Body armour slots where the item's armour type must match the class's.
local BODY_ARMOR = {
  INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
  INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true,
  INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

---Equipment slot names a candidate item contests, or nil if its type maps to no
---tracked slot.
---@param equipLoc string
---@return string[]?
function ns.CompetingSlots(equipLoc)
  return SLOTS_FOR[equipLoc]
end

---Whether a class can equip an item, from its static class/subclass.  Armour-type
---is enforced only on body slots (cloaks, rings, necks, trinkets, frills are
---all-class); shields and weapons gate on the bundled proficiency matrix.
---@param classKey string PascalCase class key
---@param equipLoc string INVTYPE_*
---@param classID integer Enum.ItemClass
---@param subClassID integer
---@return boolean
function ns.CanEquip(classKey, equipLoc, classID, subClassID)
  if classID == Armor then
    if BODY_ARMOR[equipLoc] then
      return subClassID == ARMOR_TYPE_ID[ns.wow.Armor.byClass[classKey]]
    elseif equipLoc == "INVTYPE_SHIELD" then
      local p = ns.ClassGear[classKey]
      return (p and p.shield) or false
    end
    return true -- cloak / neck / finger / trinket / holdable / misc: any class
  elseif classID == Weapon then
    local p = ns.ClassGear[classKey]
    return (p and p.weapons[subClassID]) or false
  end
  return false
end
