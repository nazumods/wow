local _, ns = ...
-- luacheck: no max line length

ns.icons = {
  -- common
  CheckGreen = "common-icon-checkmark",
  RedX = "auctionhouse-ui-filter-redx",
  Vault = "greatVault-whole-normal",
  Theatre = "UI-EventPoi-TheatreTroupe",
  Treasure = "Crosshair_lootall_32",
  BackArrow = "common-icon-backarrow-disable", -- 45x45
-- preMidnight
  preMidnight = "UI-EventPoi-twilightascension",
  -- reputations
  Nightfall = "renown-nightfall",

  -- faction
  Alliance = "Interface/Icons/ui_allianceicon",
  Horde = "Interface/Icons/ui_hordeicon",
  AllianceLight = {path= "interface/glues/characterselect/uicharacterselectglues2x", coords = {0.24365234375, 0.27880859375, 0.79541015625, 0.84033203125}, vertexColor = {0.400, 0.733, 1.000}},
  HordeLight = {path= "interface/glues/characterselect/uicharacterselectglues2x", coords = {0.24365234375, 0.27880859375, 0.88720703125, 0.93212890625}, vertexColor = {1.000, 0.125, 0.125}},

  -- classes

  -- roles
  DAMAGER = {path = "interface/lfgframe/uilfgprompts", coords = {0.00048828125, 0.12548828125, 0.25146484375, 0.37646484375}},
  HEALER = {path = "interface/lfgframe/uilfgprompts", coords = {0.00048828125, 0.12548828125, 0.75537109375, 0.88037109375}},
  TANK = {path = "interface/lfgframe/uilfgprompts", coords = {0.63037109375, 0.75537109375, 0.25146484375, 0.37646484375}},

  -- specializations
  Arcane = {path = "interface/talentframe/specializationclassthumbnails", coords = {0.30126953125, 0.45068359375, 0.18408203125, 0.27490234375}}, --"spec-thumbnail-mage-arcane",
  Fury = {path = "interface/talentframe/specializationclassthumbnails", coords = {0.30126953125, 0.45068359375, 0.45947265625, 0.55029296875}}, --"spec-thumbnail-warrior-fury",
  Holy = {path = "interface/talentframe/specializationclassthumbnails", coords = {0.00048828125, 0.14990234375, 0.36767578125, 0.45849609375}}, --"spec-thumbnail-priest-holy",
  Preservation = {path = "interface/talentframe/specializationclassthumbnails", coords = {0.60205078125, 0.75146484375, 0.09228515625, 0.18310546875}}, --"spec-thumbnail-evoker-preservation",
  Shadow = {path = "interface/talentframe/specializationclassthumbnails", coords = {0.15087890625, 0.30029296875, 0.36767578125, 0.45849609375}}, --"spec-thumbnail-priest-shadow",
  Vengeance = {path = "interface/talentframe/specializationclassthumbnails", coords = {0.60205078125, 0.75146484375, 0.00048828125, 0.09130859375}}, --"spec-thumbnail-demonhunter-vengeance",

  Bag = "bag-main",
  Backpack = "hud-backpack",
}

ns.icons.classes = {
  'classicon-warrior',
  'classicon-paladin',
  'classicon-hunter',
  'classicon-rogue',
  'classicon-priest',
  'classicon-deathknight',
  'classicon-shaman',
  'classicon-mage',
  'classicon-warlock',
  'classicon-monk',
  'classicon-druid',
  'classicon-demonhunter',
  'classicon-evoker',
}
