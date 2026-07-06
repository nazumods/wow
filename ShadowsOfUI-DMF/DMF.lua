---@class ShadowsOfUI_DMF: AddOn
local ns = LibNAddOn(...)

---@type table<integer, { questId: integer, questItems: table<integer,integer>? }>
local ProfessionQuestData = {
    [171] = { questId = 29506, questItems = { [1645] = 5,  [19299] = 5  } }, -- Alchemy
    [164] = { questId = 29508 },                                              -- Blacksmithing
    [333] = { questId = 29510 },                                              -- Enchanting
    [202] = { questId = 29511 },                                              -- Engineering
    [182] = { questId = 29514 },                                              -- Herbalism
    [773] = { questId = 29515, questItems = { [39354] = 5  } },              -- Inscription
    [755] = { questId = 29516 },                                              -- Jewelcrafting
    [165] = { questId = 29517, questItems = { [6529] = 10, [2320] = 5, [6260] = 5 } }, -- Leatherworking
    [186] = { questId = 29518 },                                              -- Mining
    [393] = { questId = 29519 },                                              -- Skinning
    [197] = { questId = 29520, questItems = { [2320] = 1,  [6260] = 1, [2604] = 1 } }, -- Tailoring
    [356] = { questId = 29513 },                                              -- Fishing
    [185] = { questId = 29509, questItems = { [30817] = 5  } },              -- Cooking
}

-- Expansion-specific skill line IDs (Classic → TWW) used to compute total skill level
local ProfessionTradeSkillLines = {
    [171] = { 2485, 2484, 2483, 2482, 2481, 2480, 2479, 2478, 2750, 2823, 2871 },
    [164] = { 2477, 2476, 2475, 2474, 2473, 2472, 2454, 2437, 2751, 2822, 2872 },
    [333] = { 2494, 2493, 2492, 2491, 2489, 2488, 2487, 2486, 2753, 2825, 2874 },
    [202] = { 2506, 2505, 2504, 2503, 2502, 2501, 2500, 2499, 2755, 2827, 2875 },
    [182] = { 2556, 2555, 2554, 2553, 2552, 2551, 2550, 2549, 2760, 2832, 2877 },
    [773] = { 2514, 2513, 2512, 2511, 2510, 2509, 2508, 2507, 2756, 2828, 2878 },
    [755] = { 2524, 2523, 2522, 2521, 2520, 2519, 2518, 2517, 2757, 2829, 2879 },
    [165] = { 2532, 2531, 2530, 2529, 2528, 2527, 2526, 2525, 2758, 2830, 2880 },
    [186] = { 2572, 2571, 2570, 2569, 2568, 2567, 2566, 2565, 2761, 2833, 2881 },
    [393] = { 2564, 2563, 2562, 2561, 2560, 2559, 2558, 2557, 2762, 2834, 2882 },
    [197] = { 2540, 2539, 2538, 2537, 2536, 2535, 2534, 2533, 2759, 2831, 2883 },
    [185] = { 2548, 2547, 2546, 2545, 2544, 2543, 2542, 2541, 2752, 2824, 2873 },
    [356] = { 2592, 2591, 2590, 2589, 2588, 2587, 2586, 2585, 2754, 2826, 2876 },
}

-- NPC ID → { questId, ... }. Use /sdmf while mousing over each NPC to find IDs.
-- Creature GUIDs: "Creature-0-serverID-instanceID-zoneUID-npcID-spawnUID" (npcID = segment 6)
local QuestGiverNpcs = {
    [14845] = { 29513, 29509 },             -- Stamp Thunderhorn (Fishing, Cooking)
    [14833] = { 29514, 29516, 29519 },      -- Chronos (Herbalism, Jewelcrafting, Skinning)
    [14844] = { 29506 },                    -- Sylannia (Alchemy)
    [14822] = { 29510, 29515 },             -- Sayge (Enchanting, Inscription)
    [14829] = { 29508 },                    -- Yebb Neblegear (Blacksmithing)
    [10445] = { 29517 },                    -- Selina Dourman (Leatherworking)
    [14841] = { 29518, 29511 },             -- Rinling (Mining, Engineering)
    -- Vendors (Elwynn Forest)
    [66]    = { 29506, 29509, 29515, 29517, 29520 }, -- Tharynn Bouden (Trade Supplies)
    [295]   = { 29506 },                             -- Innkeeper Farley (Moonberry Juice)
}

-- NPC map coordinates and display name for waypoint/map pin.
-- { mapId, x, y, label }  —  x/y are 0-1 normalized map fractions.
-- Run /sdmf while standing near each NPC to capture coords.
local NpcPositions = {
    -- Elwynn Forest (mapId 37)
    [66]    = { 37,  0.4189, 0.6709, "Tharynn Bouden"  }, -- Trade Supplies
    [295]   = { 37,  0.4377, 0.6581, "Innkeeper Farley" }, -- Moonberry Juice (Alchemy)
    -- Darkmoon Island (mapId 407)
    [14844] = { 407, 0.5054, 0.6956, "Sylannia"         }, -- Alchemy
    [14822] = { 407, 0.5323, 0.7585, "Sayge"            }, -- Enchanting, Inscription
    [14829] = { 407, 0.5109, 0.8205, "Yebb Neblegear"   }, -- Blacksmithing
    [14833] = { 407, 0.5499, 0.7074, "Chronos"          }, -- Herbalism, Jewelcrafting, Skinning
    [14845] = { 407, 0.5288, 0.6794, "Stamp Thunderhorn" }, -- Fishing, Cooking
    [10445] = { 407, 0.5555, 0.5499, "Selina Dourman"   }, -- Leatherworking
    [14841] = { 407, 0.4924, 0.6078, "Rinling"          }, -- Mining, Engineering
}

-- Ordered visit sequence per zone. First NPC with an incomplete quest gets the waypoint.
local WaypointOrder = {
    [37]  = { 66, 295 },
    [407] = { 14844, 14822, 14829, 10445, 14841, 14833, 14845 },
}

local startTime, endTime = 0, 0
local ProfData = {}
local lockAutoBuy = false
local inDMF = false
local calendarNotified = false

local function checkForDMF()
    local now = C_DateAndTime.GetCurrentCalendarTime()
    now.day = now.monthDay
    local epoch = time(now)
    if startTime > 0 and endTime > 0 then
        if epoch >= startTime and epoch <= endTime then return true end
        startTime, endTime = 0, 0
    end

    local savedMonth, savedYear
    if CalendarFrame and CalendarFrame:IsShown() then
        local info = C_Calendar.GetMonthInfo()
        savedMonth, savedYear = info.month, info.year
    end
    C_Calendar.SetAbsMonth(now.month, now.year)

    for i = 1, C_Calendar.GetNumDayEvents(0, now.monthDay) do
        local holiday = C_Calendar.GetHolidayInfo(0, now.monthDay, i)
        local tex = holiday and holiday.texture or 0
        -- 235448 = DMF begin, 235447 = middle, 235446 = end
        if tex == 235448 or tex == 235447 or tex == 235446 then
            holiday.startTime.day = holiday.startTime.monthDay
            holiday.endTime.day   = holiday.endTime.monthDay
            startTime = time(holiday.startTime)
            endTime   = time(holiday.endTime)
            if savedMonth then C_Calendar.SetAbsMonth(savedMonth, savedYear) end
            -- The calendar still lists the holiday event on its final day after the
            -- faire has actually closed (~3am), so honour the window's end time.
            return epoch >= startTime and epoch <= endTime
        end
    end

    if savedMonth then C_Calendar.SetAbsMonth(savedMonth, savedYear) end
    return false
end

local function updateProfessions()
    wipe(ProfData)
    for index, profIdx in pairs({ GetProfessions() }) do
        if profIdx then
            local _, _, skillLevel, maxSkillLevel, _, _, skillLine = GetProfessionInfo(profIdx)
            if ProfessionQuestData[skillLine] then
                ProfData[index] = { professionId = skillLine, skillLevel = 0, maxSkillLevel = 0 }
                local lines = ProfessionTradeSkillLines[skillLine]
                if lines then
                    for _, lineId in ipairs(lines) do
                        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineId)
                        if info and info.maxSkillLevel and info.maxSkillLevel > 0 then
                            ProfData[index].skillLevel    = ProfData[index].skillLevel    + info.skillLevel
                            ProfData[index].maxSkillLevel = ProfData[index].maxSkillLevel + info.maxSkillLevel
                        end
                    end
                    -- TWW loads trade skill data lazily; fall back to GetProfessionInfo values
                    -- so the profession isn't skipped before the book has been opened
                    if ProfData[index].skillLevel == 0 then
                        ProfData[index].skillLevel    = skillLevel
                        ProfData[index].maxSkillLevel = maxSkillLevel
                    end
                else
                    -- Secondary professions (fishing, cooking) don't have expansion breakdowns
                    ProfData[index].skillLevel    = skillLevel
                    ProfData[index].maxSkillLevel = maxSkillLevel
                end
            end
        end
    end
end

local function autoBuyItems()
    local numMerchantItems = GetMerchantNumItems()
    for _, prof in pairs(ProfData) do
        if prof.professionId and prof.skillLevel >= 1 then
            local questData = ProfessionQuestData[prof.professionId]
            if not C_QuestLog.IsQuestFlaggedCompleted(questData.questId) and questData.questItems then
                for itemId, needed in pairs(questData.questItems) do
                    local buyCount = needed - C_Item.GetItemCount(itemId)
                    if buyCount > 0 then
                        for j = 1, numMerchantItems do
                            if GetMerchantItemID(j) == itemId then
                                local maxStack = GetMerchantItemMaxStack(j)
                                local info = C_MerchantFrame and C_MerchantFrame.GetItemInfo and C_MerchantFrame.GetItemInfo(j)
                                local price = info and info.price       or select(3, GetMerchantItemInfo(j))
                                local qty   = info and info.stackCount  or select(4, GetMerchantItemInfo(j))
                                local avail = info and info.numAvailable or select(5, GetMerchantItemInfo(j))
                                -- Spend-safety: a 0/nil maxStack makes the stack loop below spin
                                -- forever (BuyMerchantItem(j, 0) never reduces buyCount); an
                                -- extended-cost item's `price` is only the gold portion, so the
                                -- gold check can't gauge affordability. Skip the item in both cases.
                                if not maxStack or maxStack <= 0 or (info and info.hasExtendedCost) then break end
                                if avail ~= -1 then buyCount = math.min(buyCount, avail) end
                                while buyCount >= maxStack
                                        and (avail >= maxStack or avail == -1)
                                        and GetMoney() >= (maxStack / qty * price) do
                                    BuyMerchantItem(j, maxStack)
                                    buyCount = buyCount - maxStack
                                end
                                if buyCount > 0
                                        and (avail >= buyCount or avail == -1)
                                        and GetMoney() >= (buyCount / qty * price) then
                                    BuyMerchantItem(j, buyCount)
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Waypoint guidance (Elwynn only — C_Map.SetUserWaypoint unsupported on DMF island) -----

local function npcNeeded(npcId)
    local questIds = QuestGiverNpcs[npcId]
    if not questIds then return false end
    for _, questId in ipairs(questIds) do
        if not C_QuestLog.IsQuestFlaggedCompleted(questId) then return true end
    end
    return false
end

local function updateWaypoint()
    if not inDMF then
        C_Map.ClearUserWaypoint()
        return
    end
    local mapId = C_Map.GetBestMapForUnit("player")
    local order = WaypointOrder[mapId]
    if not order then
        C_Map.ClearUserWaypoint()
        return
    end
    for _, npcId in ipairs(order) do
        if npcNeeded(npcId) then
            local pos = NpcPositions[npcId]
            if pos and (pos[2] ~= 0 or pos[3] ~= 0) then
                C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(pos[1], pos[2], pos[3]))
                return
            end
        end
    end
    C_Map.ClearUserWaypoint()
end

-- World map pins (DMF island) -----------------------------------------------------

local mapPins = {}
local PIN_SIZE = 16
local PIN_ICON = "Interface\\MINIMAP\\TRACKING\\QuestGiver"

local function clearMapPins()
    for _, pin in ipairs(mapPins) do
        pin:Hide()
        pin:SetParent(nil)
    end
    wipe(mapPins)
end

local function refreshMapPins()
    clearMapPins()
    if not inDMF or not WorldMapFrame:IsShown() then return end
    local mapId = WorldMapFrame:GetMapID()
    local order = WaypointOrder[mapId]
    if not order then return end

    local canvas = WorldMapFrame:GetCanvas()
    local w, h   = canvas:GetWidth(), canvas:GetHeight()

    for _, npcId in ipairs(order) do
        if npcNeeded(npcId) then
            local pos = NpcPositions[npcId]
            if pos and pos[1] == mapId then
                local pin = CreateFrame("Frame", nil, canvas)
                pin:SetSize(PIN_SIZE, PIN_SIZE)
                pin:SetPoint("CENTER", canvas, "TOPLEFT", pos[2] * w, -pos[3] * h)
                pin:SetFrameLevel(canvas:GetFrameLevel() + 10)

                local tex = pin:CreateTexture(nil, "OVERLAY")
                tex:SetAllPoints(pin)
                tex:SetTexture(PIN_ICON)

                local label = pos[4]
                pin:EnableMouse(true)
                pin:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(label, 1, 1, 1)
                    GameTooltip:Show()
                end)
                pin:SetScript("OnLeave", function() GameTooltip:Hide() end)

                pin:Show()
                table.insert(mapPins, pin)
            end
        end
    end
end

-- Event handlers ----------------------------------------------------------

local function onMerchantShow(self, interactionType)
    if interactionType ~= Enum.PlayerInteractionType.Merchant then return end
    if not lockAutoBuy then
        lockAutoBuy = true
        C_Timer.After(0, autoBuyItems)
    end
end

local function onBagUpdate(self)
    C_Timer.After(0, function() lockAutoBuy = false end)
end

local function onQuestAccepted(self, questId)
    updateWaypoint()
    refreshMapPins()
end

local function onQuestTurnedIn(self, questId)
    updateWaypoint()
    refreshMapPins()
end

local function enterDMF()
    ns:registerEvent("BAG_UPDATE_DELAYED",                    onBagUpdate)
    ns:registerEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", onMerchantShow)
    ns:registerEvent("QUEST_ACCEPTED",                        onQuestAccepted)
    ns:registerEvent("QUEST_TURNED_IN",                       onQuestTurnedIn)
end

local function leaveDMF()
    ns:unregisterEvent("BAG_UPDATE_DELAYED",                    onBagUpdate)
    ns:unregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", onMerchantShow)
    ns:unregisterEvent("QUEST_ACCEPTED",                        onQuestAccepted)
    ns:unregisterEvent("QUEST_TURNED_IN",                       onQuestTurnedIn)
    lockAutoBuy = false
    C_Map.ClearUserWaypoint()
    clearMapPins()
end

local function checkDMFStatus()
    local active = checkForDMF()
    if active and not inDMF then
        inDMF = true
        enterDMF()
    elseif not active and inDMF then
        inDMF = false
        leaveDMF()
    end
    updateWaypoint()
    refreshMapPins()
end

ns:registerEvent("PLAYER_ENTERING_WORLD",      function(self) checkDMFStatus() end)
ns:registerEvent("ZONE_CHANGED_NEW_AREA",      function(self) checkDMFStatus() end)
ns:registerEvent("SKILL_LINES_CHANGED",        function(self) updateProfessions() end)
ns:registerEvent("TRADE_SKILL_LIST_UPDATE",    function(self) updateProfessions() end)
ns:registerEvent("CALENDAR_UPDATE_EVENT_LIST", function(self)
    if calendarNotified then return end
    calendarNotified = true
    checkDMFStatus()
    if inDMF then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00ShadowsOfUI-DMF:|r Darkmoon Faire is open!") end
end)

-- Refresh pins whenever the world map opens or changes to a different map
WorldMapFrame:HookScript("OnShow", refreshMapPins)
WorldMapFrame:RegisterCallback("MapChanged", function() refreshMapPins() end)

function ns:onLogin()
    updateProfessions()
    C_Calendar.OpenCalendar()
end

-- /sdmf: print NPC ID and player map position to populate QuestGiverNpcs/NpcPositions
SLASH_SUI_DMF1 = "/sdmf"
SlashCmdList["SUI_DMF"] = function()
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos    = mapId and C_Map.GetPlayerMapPosition(mapId, "player")
    local posStr = pos and string.format("mapId=%d  x=%.4f  y=%.4f", mapId, pos.x, pos.y) or "position unknown"

    local unit = UnitExists("mouseover") and "mouseover" or UnitExists("target") and "target" or nil
    if not unit then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00ShadowsOfUI-DMF:|r " .. posStr)
        return
    end
    local guid  = UnitGUID(unit)
    local npcId = tonumber((select(6, strsplit("-", guid))))
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cffffcc00ShadowsOfUI-DMF:|r " .. (UnitName(unit) or "?") ..
        "  npcId=" .. tostring(npcId) ..
        "  " .. posStr
    )
end
