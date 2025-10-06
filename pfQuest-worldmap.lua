local original_UpdateNodes = pfMap.UpdateNodes
local continentPins = {}
local maxContinentPins = 2000 -- guessing here but more is better if possible

-- ============================================================================
-- WorldMapArea.dbc to mapData Conversion Formula
-- ============================================================================
--
-- WorldMapArea Format: LocLeft, LocRight, LocTop, LocBottom
-- mapData Format: {width, height, left, top}
--
-- Conversion: || means absolute value
-- width  = |LocRight - LocLeft|
-- height = |LocTop - LocBottom|
-- left   = LocLeft
-- top    = LocTop
--
-- Example:
-- MPQ: "2938.36","1880.03","10238.3","9532.59"
-- Result: {1058.33, 705.71, 2938.36, 10238.3}
-- ============================================================================

local mapData = {
    -- Eastern Kingdoms zones (instance 0)
    -- Format: {width, height, left, top} in world coordinates
    [1429] = {3470.84, 2314.62, 1535.42, -7939.58},     -- Elwynn Forest
    [1436] = {3500.00, 2333.3, 3016.67, -9400},         -- Westfall
    [1433] = {2170.84, 1447.9, -1570.83, -8575},        -- Redridge Mountains
    [1431] = {2700.00, 1800.03, 833.333, -9716.67},     -- Duskwood
    [1434] = {6381.25, 4254.1, 2220.83, -11168.8},      -- Stranglethorn Vale
    [1453] = {1737.50, 1158.34, 1722.92, -7995.83},     -- Stormwind City
    [1426] = {4925.00, 3283.34, 1802.08, -3877.08},     -- Dun Morogh
    [1455] = {790.63, 527.61, -713.591, -4569.24},      -- Ironforge
    [1432] = {2758.33, 1839.58, -1993.75, -4487.5},     -- Loch Modan
    [1437] = {4135.42, 2756.25, -389.583, -2147.92},    -- Wetlands
    [1424] = {3200.00, 2133.33, 1066.67, 400},          -- Hillsbrad Foothills
    [1416] = {2800.00, 1866.667, 783.333, 1500},        -- Alterac Mountains
    [1417] = {3600.00, 2400.00, -866.667, -133.333},    -- Arathi Highlands
    [1425] = {3850.00, 2566.67, -1575, 1466.67},        -- The Hinterlands
    [1420] = {4518.75, 3012.5, 3033.33, 3837.5},        -- Tirisfal Glades
    [1421] = {4200.00, 2800.00, 3450, 1666.67},         -- Silverpine Forest
    [1458] = {959.38, 640.1, 873.193, 1877.94},         -- Undercity
    [1422] = {4300.00, 2866.67, 416.667, 3366.67},      -- Western Plaguelands
    [1423] = {4031.25, 2687.5, -2287.5, 3704.17},       -- Eastern Plaguelands
    [1418] = {2487.50, 1658.34, -2079.17, -5889.58},    -- Badlands
    [1427] = {2231.253, 1487.5, -322.917, -6100},       -- Searing Gorge
    [1428] = {2929.163, 1952.08, -266.667, -7031.25},   -- Burning Steppes
    [1435] = {2293.75, 1529.17, -2222.92, -9620.83},    -- Swamp of Sorrows
    [1419] = {3350.00, 2233.30, -1241.67, -10566.7},    -- Blasted Lands
    [1430] = {2500.00, 1666.63, -833.333, -9866.67},    -- Deadwind Pass
    -- Kalimdor zones (instance 1)
    -- Format: {width, height, left, top} in world coordinates
    [1438] = {5091.66, 3393.7, 3814.58, 11831.2},       -- Teldrassil (zone 141)
    [1457] = {1058.33, 705.71, 2938.36, 10238.3},       -- Darnassus (zone 1657)
    [1439] = {6550.00, 4366.66, 2941.67, 8333.33},      -- Darkshore (zone 148)
    [1440] = {5766.67, 3843.75, 1700, 4672.92},         -- Ashenvale (zone 331)
    [1442] = {4883.33, 3256.25, 3245.83, 2916.67},      -- Stonetalon Mountains (zone 406)
    [1413] = {10133.34, 6756.25, 2622.92, 1612.5},      -- The Barrens (zone 17)
    [1411] = {5287.5, 3525, -1962.5, 1808.33},          -- Durotar (zone 14)
    [1454] = {1402.61, 935.42, -3680.6, 2273.88},       -- Orgrimmar (zone 1637)
    [1412] = {5137.5, 3425.00, 2047.92, -272.917},      -- Mulgore (zone 215)
    [1456] = {1043.75, 695.83, 516.667, -850},          -- Thunder Bluff (zone 1638)
    [1443] = {4495.83, 2997.91, 4233.33, 452.083},      -- Desolace (zone 405)
    [1444] = {6950.00, 4633.33, 5441.67, -2366.67},     -- Feralas (zone 357)
    [1441] = {4400.00, 2933.33, -433.333, -3966.67},    -- Thousand Needles (zone 400)
    [1446] = {6900.00, 4600.00, -218.75, -5875},        -- Tanaris (zone 440)
    [1449] = {3700.00, 2466.66, 533.333, -5966.67},     -- Un'Goro Crater (zone 490)
    [1451] = {3483.33, 2322.92, 2537.5, -5958.33},      -- Silithus (zone 1377)
    [1445] = {5250.00, 3500.00, -975, -2033.33},        -- Dustwallow Marsh (zone 15)
    [1452] = {7100.00, 4733.33, -316.667, 8533.33},     -- Winterspring (zone 618)
    [1447] = {5070.84, 3381.25, -3277.08, 5341.67},     -- Azshara (zone 16)
    [1448] = {5750.00, 3833.33, 1641.67, 7133.33},      -- Felwood (zone 361)
    [1450] = {2308.33, 1539.59, -1381.25, 8491.67},     -- Moonglade (zone 493)
    -- Eastern Kingdoms
    [1415] = {40741.18, 27149.69, 18171.97, 11176.34},  -- Eastern Kingdoms continent
    -- Kalimdor continent
    [1414] = {36799.81, 24533.20, 17066.60, 12799.90}   -- Kalimdor continent
}

local zoneToUiMapID = {
    -- Eastern Kingdoms
    [12] = 1429,
    [40] = 1436,
    [44] = 1433,
    [10] = 1431,
    [33] = 1434,
    [1519] = 1453,
    [1] = 1426,
    [1537] = 1455,
    [38] = 1432,
    [11] = 1437,
    [267] = 1424,
    [36] = 1416,
    [45] = 1417,
    [47] = 1425,
    [85] = 1420,
    [130] = 1421,
    [1497] = 1458,
    [28] = 1422,
    [139] = 1423,
    [3] = 1418,
    [51] = 1427,
    [46] = 1428,
    [8] = 1435,
    [4] = 1419,
    [41] = 1430,
    -- Kalimdor
    [141] = 1438,
    [1657] = 1457,
    [148] = 1439,
    [331] = 1440,
    [406] = 1442,
    [17] = 1413,
    [14] = 1411,
    [1637] = 1454,
    [215] = 1412,
    [1638] = 1456,
    [405] = 1443,
    [357] = 1444,
    [400] = 1441,
    [440] = 1446,
    [490] = 1449,
    [1377] = 1451,
    [15] = 1445,
    [618] = 1452,
    [16] = 1447,
    [361] = 1448,
    [493] = 1450
}

-- Get zone data from either main or epoch databases
local function GetZoneData(zoneID)
    local zoneData = pfDB and pfDB["zones"] and pfDB["zones"]["data"] and pfDB["zones"]["data"][zoneID]
    if not zoneData then
        zoneData = pfDB and pfDB["zones"] and pfDB["zones"]["data-epoch"] and pfDB["zones"]["data-epoch"][zoneID]
    end
    return zoneData
end

-- Continent assignments
local zoneContinent = {
    -- Eastern Kingdoms = 2 (continent 0 in game)
    [1] = 2,
    [3] = 2,
    [4] = 2,
    [8] = 2,
    [10] = 2,
    [11] = 2,
    [12] = 2,
    [28] = 2,
    [33] = 2,
    [36] = 2,
    [38] = 2,
    [40] = 2,
    [41] = 2,
    [44] = 2,
    [45] = 2,
    [46] = 2,
    [47] = 2,
    [51] = 2,
    [85] = 2,
    [130] = 2,
    [139] = 2,
    [267] = 2,
    [1497] = 2,
    [1519] = 2,
    [1537] = 2,
    -- Kalimdor = 1 (continent 1 in game)
    [14] = 1,
    [15] = 1,
    [16] = 1,
    [17] = 1,
    [141] = 1,
    [148] = 1,
    [215] = 1,
    [331] = 1,
    [357] = 1,
    [361] = 1,
    [400] = 1,
    [405] = 1,
    [406] = 1,
    [440] = 1,
    [490] = 1,
    [493] = 1,
    [618] = 1,
    [1377] = 1,
    [1637] = 1,
    [1638] = 1,
    [1657] = 1
}

local function GetZoneGroup(zoneID)
    -- Group related zones together to prevent duplicate NPCs
    local zoneGroups = {
        teldrassil = {141, 1657}, -- Teldrassil + Darnassus
        stormwind = {12, 1519}, -- Elwynn + Stormwind City
        ironforge = {1, 1537}, -- Dun Morogh + Ironforge
        orgrimmar = {14, 1637}, -- Durotar + Orgrimmar
        thunderbluff = {215, 1638}, -- Mulgore + Thunder Bluff
        undercity = {85, 1497} -- Tirisfal + Undercity
    }

    for group, zones in pairs(zoneGroups) do
        for _, zID in pairs(zones) do
            if zID == zoneID then
                return group
            end
        end
    end
    return zoneID
end

local function GetZoneContinent(zoneID)
    if zoneContinent[zoneID] then
        return zoneContinent[zoneID]
    end

    local zoneData = GetZoneData(zoneID)
    if zoneData and zoneData[1] then
        local continent = zoneData[1]
        if continent == 0 then
            continent = 2
        elseif continent == 1 then
            continent = 1
        else
            return nil
        end

        zoneContinent[zoneID] = continent
        return continent
    end

    return nil
end

local function ZoneToWorld(x, y, zoneID)
    local uiMapID = zoneToUiMapID[zoneID]
    if not uiMapID then
        return nil, nil
    end
    local data = mapData[uiMapID]
    if not data then
        return nil, nil
    end

    local worldX = data[3] - data[1] * (x / 100)
    local worldY = data[4] - data[2] * (y / 100)

    return worldX, worldY
end

local function WorldToContinent(worldX, worldY, continent)
    local contData = mapData[continent == 1 and 1414 or 1415]
    if not contData then
        return nil, nil
    end

    local x = (contData[3] - worldX) / contData[1]
    local y = (contData[4] - worldY) / contData[2]

    return x, y
end

local function NodeAnimate(self, max)
    return
end

local inverseMapScale = 1.0
local function ResizeContinentNode(frame)
    if not frame.icon then
        -- Use config value for regular nodes, fallback to 12 if not set
        frame.defsize = tonumber(pfQuest_config["continentNodeSize"]) or 12
        frame.defsize = frame.defsize * inverseMapScale
    else
        -- Use config value for utility NPCs, fallback to 14 if not set
        frame.defsize = tonumber(pfQuest_config["continentUtilityNodeSize"]) or 14
        -- Compensate for icon's 1 pixel padding so it doesn't shrink down to nothing
        frame.defsize = (frame.defsize - 2) * inverseMapScale + 2
    end
    frame:SetWidth(frame.defsize)
    frame:SetHeight(frame.defsize)
    frame.hl:SetWidth(frame.defsize)
    frame.hl:SetHeight(frame.defsize)
end

local function ResizeContinentNodes()
    local i = 1
    if continentPins then
        while continentPins[i] and continentPins[i]:IsShown() do
            ResizeContinentNode(continentPins[i])
            i = i + 1
        end
    end
end

-- Resize icons on map zoom change
local function OnMapScaleChanged(frame, scale, originalfunction)
    originalfunction(frame, scale)

    local newInverseScale = 1.0 / WorldMapButton:GetEffectiveScale()
    if (inverseMapScale ~= newInverseScale) then
        inverseMapScale = newInverseScale
        ResizeContinentNodes()
    end
end
-- Listen for WorldMapFrame scale changes
local originalWorldMapFrame_SetScale = WorldMapFrame.SetScale
WorldMapFrame.SetScale = function(frame, scale)
    OnMapScaleChanged(frame, scale, originalWorldMapFrame_SetScale)
end
-- Listen for WorldMapDetailFrame scale changes
local originalWorldMapDetailFrame_SetScale = WorldMapDetailFrame.SetScale
WorldMapDetailFrame.SetScale = function(frame, scale)
    OnMapScaleChanged(frame, scale, originalWorldMapDetailFrame_SetScale)
end
-- Listen for WorldMapButton scale changes
local originalWorldMapButton_SetScale = WorldMapButton.SetScale
WorldMapButton.SetScale = function(frame, scale)
    OnMapScaleChanged(frame, scale, originalWorldMapButton_SetScale)
end

local function CreateContinentPin(index)
    if not continentPins[index] then
        local pin = CreateFrame("Button", "pfQuestContinentPin" .. index, WorldMapButton)
        pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 10)
        pin:SetFrameStrata("DIALOG")

        pin.tex = pin:CreateTexture(nil, "BACKGROUND")
        pin.tex:SetAllPoints(pin)

        pin.pic = pin:CreateTexture(nil, "BORDER")
        pin.pic:SetPoint("TOPLEFT", pin, "TOPLEFT", 1, -1)
        pin.pic:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -1, 1)

        pin.hl = pin:CreateTexture(nil, "OVERLAY")
        pin.hl:SetTexture(pfQuestConfig.path .. "\\img\\track")
        pin.hl:SetPoint("TOPLEFT", pin, "TOPLEFT", -5, 5)
        pin.hl:Hide()

        pin.defalpha = 1
        pin.Animate = NodeAnimate
        pin.dt = 0

        if pfQuest_config["continentClickThrough"] == "1" then
            pin.tooltipTimer = 0
            pin.wasMouseOver = false

            local function CheckTooltip(self, elapsed)
                if not self:IsVisible() then return end

                local x, y = GetCursorPosition()
                local scale = self:GetEffectiveScale()
                x = x / scale
                y = y / scale

                local left = self:GetLeft()
                local right = self:GetRight()
                local top = self:GetTop()
                local bottom = self:GetBottom()

                local isMouseOver = false
                if left and right and top and bottom then
                    isMouseOver = (x >= left and x <= right and y >= bottom and y <= top)
                end

                if isMouseOver and not self.wasMouseOver then
                    if self.node then
                        pfMap.NodeEnter(self)
                    end
                    self.wasMouseOver = true
                elseif not isMouseOver and self.wasMouseOver then
                    self.pulse = 1
                    self.mod = 1
                    self:SetWidth(self.defsize)
                    self:SetHeight(self.defsize)
                    pfMap.NodeLeave(self)
                    self.wasMouseOver = false
                end
            end

            pin:SetScript("OnUpdate", function(self, elapsed)
                if IsControlKeyDown() then
                    -- Enable full mouse interaction when Ctrl is held
                    if not self.mouseEnabled then
                        self:EnableMouse(true)
                        self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        self.mouseEnabled = true
                    end
                else
                    -- Disable mouse interaction when Ctrl is not held, but keep tooltips
                    if self.mouseEnabled ~= false then
                        self:EnableMouse(false)
                        self:RegisterForClicks()
                        self.mouseEnabled = false
                    end
                end

                CheckTooltip(self, elapsed)
            end)

            pin:SetScript(
                "OnClick",
                function(self, button)
                    if IsControlKeyDown() and self.node then
                        if pfMap.NodeClick then
                            pfMap.NodeClick(self, button)
                        end
                    end
                end
            )
        else
            pin:EnableMouse(true)
            pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            pin:SetScript(
                "OnEnter",
                function(self)
                    if self.node then
                        pfMap.NodeEnter(self)
                    end
                end
            )

            pin:SetScript(
                "OnLeave",
                function(self)
                    self.pulse = 1
                    self.mod = 1
                    self:SetWidth(self.defsize)
                    self:SetHeight(self.defsize)
                    pfMap.NodeLeave(self)
                end
            )

            pin:SetScript(
                "OnClick",
                function(self, button)
                    if self.node then
                        if pfMap.NodeClick then
                            pfMap.NodeClick(self, button)
                        end
                    end
                end
            )
        end

        continentPins[index] = pin
    end
    return continentPins[index]
end

function pfMap:UpdateNodes()
    local continent = GetCurrentMapContinent()
    local zone = GetCurrentMapZone()

    original_UpdateNodes(self)

    local mapName = GetMapInfo()
    local isContinent =
        (mapName == "Kalimdor" and zone == 0) or (mapName == "Azeroth" and zone == 0) or
        (mapName == nil and continent == 0 and zone == 0)

    -- Function to calculate gray level (no XP level) based on WoW's system
    local function GetGrayLevel(charLevel)
        if charLevel <= 5 then
            return 0 -- all mobs give XP
        elseif charLevel <= 49 then
            return charLevel - math.floor(charLevel / 10) - 5
        elseif charLevel == 50 then
            return 40 -- charLevel - 10
        elseif charLevel <= 59 then
            return charLevel - math.floor(charLevel / 5) - 1
        else -- level 60-70
            return charLevel - 9
        end
    end

    for i = 1, maxContinentPins do
        if continentPins[i] then
            continentPins[i]:Hide()
            continentPins[i].node = nil
            continentPins[i].sourceContinent = nil
        end
    end

    if pfQuest_config["epochContinentPins"] == "0" then
        return
    end

    if zone > 0 and not isContinent then
        return
    end

    for _, pin in pairs(pfMap.pins) do
        if pin then
            pin:Hide()
        end
    end

    if continent == 0 then
        local pinCount = 0
        local playerLevel = UnitLevel("player")
        local processedZones = {}
        local processedQuests = {}

        for targetContinent = 1, 2 do
            for addon, addonData in pairs(pfMap.nodes) do
                for zID, zoneNodes in pairs(addonData) do
                    local zoneCont = GetZoneContinent(zID)

                    if zoneCont == targetContinent then
                        processedZones[zID] = true
                        local uiMapID = zoneToUiMapID[zID]
                        if uiMapID and mapData[uiMapID] then
                            for coords, node in pairs(zoneNodes) do
                                local skipNode = false
                                local questKey = nil

                                for title, data in pairs(node) do
                                    local needsDeduplication = false
                                    local isUtilityNPC = false

                                    if data.addon == "PFDB" then
                                        local utilityTypes = {
                                            "flight",
                                            "auctioneer",
                                            "banker",
                                            "battlemaster",
                                            "innkeeper",
                                            "mailbox",
                                            "stablemaster",
                                            "spirithealer",
                                            "meetingstone"
                                        }

                                        for _, utilityType in pairs(utilityTypes) do
                                            if pfDB["meta-epoch"] and pfDB["meta-epoch"][utilityType] then
                                                for objectId, faction in pairs(pfDB["meta-epoch"][utilityType]) do
                                                    if data.id and tonumber(data.id) == objectId then
                                                        isUtilityNPC = true
                                                        break
                                                    end
                                                end
                                                if isUtilityNPC then
                                                    break
                                                end
                                            end
                                        end

                                        -- Block unwanted PFDB trackables (herbs, mines, chests, etc.)
                                        if not isUtilityNPC then
                                            local blockedTypes = {"herbs", "mines", "chests", "fish", "rares"}
                                            for _, blockedType in pairs(blockedTypes) do
                                                if pfDB["meta-epoch"] and pfDB["meta-epoch"][blockedType] then
                                                    for objectId, faction in pairs(pfDB["meta-epoch"][blockedType]) do
                                                        if data.id and tonumber(data.id) == objectId then
                                                            skipNode = true
                                                            break
                                                        end
                                                    end
                                                    if skipNode then
                                                        break
                                                    end
                                                end
                                            end
                                        end
                                    elseif data.addon and string.find(data.addon, "TRACK_") then
                                        local allowedTracks = {
                                            "TRACK_FLIGHT",
                                            "TRACK_AUCTIONEER",
                                            "TRACK_BANKER",
                                            "TRACK_BATTLEMASTER",
                                            "TRACK_INNKEEPER",
                                            "TRACK_MAILBOX",
                                            "TRACK_STABLEMASTER",
                                            "TRACK_SPIRITHEALER",
                                            "TRACK_MEETINGSTONE"
                                        }

                                        local isAllowed = false
                                        for _, track in pairs(allowedTracks) do
                                            if string.find(data.addon, track) then
                                                isAllowed = true
                                                break
                                            end
                                        end

                                        if isAllowed then
                                            isUtilityNPC = true
                                        else
                                            skipNode = true
                                        end
                                    end

                                    if
                                        (zID == 141 or zID == 1657) or (zID == 12 or zID == 1519) or
                                            (zID == 1 or zID == 1537) or
                                            (zID == 14 or zID == 1637) or
                                            (zID == 215 or zID == 1638) or
                                            (zID == 85 or zID == 1497)
                                     then
                                        needsDeduplication = true

                                        if zID == 141 or zID == 1657 then
                                            questKey = title .. "_teldrassil"
                                        elseif zID == 12 or zID == 1519 then
                                            questKey = title .. "_stormwind"
                                        elseif zID == 1 or zID == 1537 then
                                            questKey = title .. "_ironforge"
                                        elseif zID == 14 or zID == 1637 then
                                            questKey = title .. "_orgrimmar"
                                        elseif zID == 215 or zID == 1638 then
                                            questKey = title .. "_thunderbluff"
                                        elseif zID == 85 or zID == 1497 then
                                            questKey = title .. "_undercity"
                                        end
                                    end

                                    if needsDeduplication and questKey and processedQuests[questKey] then
                                        skipNode = true
                                        break
                                    end

                                    -- Skip chicken quests (if enabled in config)
                                    if pfQuest_config["epochHideChickenQuests"] == "1" then
                                        if title == "CLUCK!" or title == "Cluck!" or string.find(title, "CLUCK") then
                                            skipNode = true
                                            break
                                        end
                                    end

                                    -- Skip felwood flowers (if enabled in config)
                                    if pfQuest_config["epochHideFelwoodFlowers"] == "1" then
                                        if
                                            title == "Corrupted Windblossom" or title == "Corrupted Whipper Root" or
                                                title == "Corrupted Songflower" or
                                                title == "Corrupted Night Dragon"
                                         then
                                            skipNode = true
                                            break
                                        end
                                    end

                                    -- Skip PvP quests (if enabled in config)
                                    if pfQuest_config["epochHidePvPQuests"] == "1" then
                                        if
                                            string.find(title, "Warsong") or string.find(title, "Arathi") or
                                                string.find(title, "Alterac") or
                                                string.find(title, "Battleground") or
                                                string.find(title, "Call to Skirmish")
                                         then
                                            skipNode = true
                                            break
                                        end
                                    end

                                    -- Skip Commission quests (if enabled in config)
                                    if pfQuest_config["epochHideCommissionQuests"] == "1" then
                                        if
                                            string.find(title, "Commission for")
                                         then
                                            skipNode = true
                                            break
                                        end
                                    end

                                    local questLevel = tonumber(data.qlvl) or tonumber(data.lvl) or 0
                                    local minLevel = tonumber(data.min) or 0

                                    if not isUtilityNPC then
                                        if pfQuest_config["showlowlevel"] == "0" then
                                            if questLevel > 0 and questLevel <= GetGrayLevel(playerLevel) then
                                                if not (data.texture and string.find(data.texture, "complete")) then
                                                    skipNode = true
                                                    break
                                                end
                                            end
                                        end
                                    end

                                    -- Skip quests that are way too high level (red quests) - only if high level display is disabled
                                    if not isUtilityNPC then
                                        if minLevel > playerLevel + (pfQuest_config["showhighlevel"] == "1" and 3 or 0) then
                                            if not (data.texture and string.find(data.texture, "complete")) then
                                                skipNode = true
                                                break
                                            end
                                        end
                                    end

                                    -- Special filter for quests with suspiciously low min level - only if low level display is disabled
                                    if not isUtilityNPC then
                                        if pfQuest_config["showlowlevel"] == "0" then
                                            if minLevel <= 1 and questLevel <= GetGrayLevel(playerLevel) then
                                                if not (data.texture and string.find(data.texture, "complete")) then
                                                    skipNode = true
                                                    break
                                                end
                                            end
                                        end
                                    end

                                    if needsDeduplication and questKey and not skipNode then
                                        processedQuests[questKey] = true
                                    end
                                end

                                if not skipNode then
                                    local _, _, strx, stry = strfind(coords, "(.*)|(.*)")
                                    local zoneX = tonumber(strx)
                                    local zoneY = tonumber(stry)

                                    if zoneX and zoneY then
                                        local worldX, worldY = ZoneToWorld(zoneX, zoneY, zID)

                                        if worldX and worldY then
                                            local contX, contY = WorldToContinent(worldX, worldY, targetContinent)

                                            if
                                                contX and contY and contX >= 0 and contX <= 1 and contY >= 0 and
                                                    contY <= 1
                                             then
                                                local worldMapX, worldMapY

                                                if targetContinent == 1 then
                                                    worldMapX = contX * 0.90 - 0.22
                                                    worldMapY = contY * 0.85 + 0.05
                                                else
                                                    worldMapX = 0.33 + (contX * 0.90)
                                                    worldMapY = contY * 0.90 - 0.04
                                                end

                                                if
                                                    worldMapX >= 0 and worldMapX <= 1 and worldMapY >= 0 and
                                                        worldMapY <= 1
                                                 then
                                                    pinCount = pinCount + 1
                                                    if pinCount > maxContinentPins then
                                                        break
                                                    end

                                                    local pin = CreateContinentPin(pinCount)
                                                    pin.node = node
                                                    pin.sourceContinent = targetContinent

                                                    pfMap:UpdateNode(pin, node, nil, nil, nil)

                                                    ResizeContinentNode(pin)

                                                    pin:ClearAllPoints()
                                                    pin:SetPoint(
                                                        "CENTER",
                                                        WorldMapButton,
                                                        "TOPLEFT",
                                                        worldMapX * WorldMapButton:GetWidth(),
                                                        -worldMapY * WorldMapButton:GetHeight()
                                                    )
                                                    pin:Show()
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            if pinCount >= maxContinentPins then
                                break
                            end
                        end
                    end
                end
                if pinCount >= maxContinentPins then
                    break
                end
            end
            if pinCount >= maxContinentPins then
                break
            end
        end

        for i = pinCount + 1, maxContinentPins do
            if continentPins[i] then
                continentPins[i]:Hide()
            end
        end
        return
    end

    if continent > 2 or continent < 1 then
        return
    end

    local pinCount = 0
    local playerLevel = UnitLevel("player")
    local processedZones = {}
    local processedQuests = {}

    local function GetGrayLevel(charLevel)
        if charLevel <= 5 then
            return 0
        elseif charLevel <= 49 then
            return charLevel - math.floor(charLevel / 10) - 5
        elseif charLevel == 50 then
            return 40
        elseif charLevel <= 59 then
            return charLevel - math.floor(charLevel / 5) - 1
        else
            return charLevel - 9
        end
    end

    for addon, addonData in pairs(pfMap.nodes) do
        for zID, zoneNodes in pairs(addonData) do
            local zoneCont = GetZoneContinent(zID)
            if not zoneCont or zoneCont ~= continent then
            else
                processedZones[zID] = true
                local uiMapID = zoneToUiMapID[zID]
                if uiMapID and mapData[uiMapID] then
                    for coords, node in pairs(zoneNodes) do
                        local skipNode = false
                        local questKey = nil

                        for title, data in pairs(node) do
                            local needsDeduplication = false
                            local isUtilityNPC = false

                            if data.addon == "PFDB" then
                                local utilityTypes = {
                                    "flight",
                                    "auctioneer",
                                    "banker",
                                    "battlemaster",
                                    "innkeeper",
                                    "mailbox",
                                    "stablemaster",
                                    "spirithealer",
                                    "meetingstone"
                                }

                                for _, utilityType in pairs(utilityTypes) do
                                    if pfDB["meta-epoch"] and pfDB["meta-epoch"][utilityType] then
                                        for objectId, faction in pairs(pfDB["meta-epoch"][utilityType]) do
                                            if data.id and tonumber(data.id) == objectId then
                                                isUtilityNPC = true
                                                break
                                            end
                                        end
                                        if isUtilityNPC then
                                            break
                                        end
                                    end
                                end

                                -- Block unwanted PFDB trackables (herbs, mines, chests, etc.)
                                if not isUtilityNPC then
                                    local blockedTypes = {"herbs", "mines", "chests", "fish", "rares"}
                                    for _, blockedType in pairs(blockedTypes) do
                                        if pfDB["meta-epoch"] and pfDB["meta-epoch"][blockedType] then
                                            for objectId, faction in pairs(pfDB["meta-epoch"][blockedType]) do
                                                if data.id and tonumber(data.id) == objectId then
                                                    skipNode = true
                                                    break
                                                end
                                            end
                                            if skipNode then
                                                break
                                            end
                                        end
                                    end
                                end
                            elseif data.addon and string.find(data.addon, "TRACK_") then
                                local allowedTracks = {
                                    "TRACK_FLIGHT",
                                    "TRACK_AUCTIONEER",
                                    "TRACK_BANKER",
                                    "TRACK_BATTLEMASTER",
                                    "TRACK_INNKEEPER",
                                    "TRACK_MAILBOX",
                                    "TRACK_STABLEMASTER",
                                    "TRACK_SPIRITHEALER",
                                    "TRACK_MEETINGSTONE"
                                }

                                local isAllowed = false
                                for _, track in pairs(allowedTracks) do
                                    if string.find(data.addon, track) then
                                        isAllowed = true
                                        break
                                    end
                                end

                                if isAllowed then
                                    isUtilityNPC = true
                                else
                                    skipNode = true
                                end
                            end

                            -- Only apply deduplication to specific problem zones
                            if
                                (zID == 141 or zID == 1657) or     -- Teldrassil/Darnassus
                                    (zID == 12 or zID == 1519) or  -- Elwynn/Stormwind
                                    (zID == 1 or zID == 1537) or   -- Dun Morogh/Ironforge
                                    (zID == 14 or zID == 1637) or  -- Durotar/Orgrimmar
                                    (zID == 215 or zID == 1638) or -- Mulgore/Thunder Bluff
                                    (zID == 85 or zID == 1497)     -- Tirisfal/Undercity
                             then
                                needsDeduplication = true

                                -- Create zone-pair specific keys
                                if zID == 141 or zID == 1657 then
                                    questKey = title .. "_teldrassil"
                                elseif zID == 12 or zID == 1519 then
                                    questKey = title .. "_stormwind"
                                elseif zID == 1 or zID == 1537 then
                                    questKey = title .. "_ironforge"
                                elseif zID == 14 or zID == 1637 then
                                    questKey = title .. "_orgrimmar"
                                elseif zID == 215 or zID == 1638 then
                                    questKey = title .. "_thunderbluff"
                                elseif zID == 85 or zID == 1497 then
                                    questKey = title .. "_undercity"
                                end
                            end

                            -- Only check for duplicates in problem zones
                            if needsDeduplication and questKey and processedQuests[questKey] then
                                skipNode = true
                                break
                            end

                            -- Skip chicken quests (if enabled in config)
                            if pfQuest_config["epochHideChickenQuests"] == "1" then
                                if title == "CLUCK!" or title == "Cluck!" or string.find(title, "CLUCK") then
                                    skipNode = true
                                    break
                                end
                            end

                            -- Skip felwood flowers (if enabled in config)
                            if pfQuest_config["epochHideFelwoodFlowers"] == "1" then
                                if
                                    title == "Corrupted Windblossom" or title == "Corrupted Whipper Root" or
                                        title == "Corrupted Songflower" or
                                        title == "Corrupted Night Dragon"
                                 then
                                    skipNode = true
                                    break
                                end
                            end

                            -- Skip PvP quests (if enabled in config)
                            if pfQuest_config["epochHidePvPQuests"] == "1" then
                                if
                                    string.find(title, "Warsong") or string.find(title, "Arathi") or
                                        string.find(title, "Alterac") or
                                        string.find(title, "Battleground") or
                                        string.find(title, "Call to Skirmish")
                                 then
                                    skipNode = true
                                    break
                                end
                            end

                            -- Skip Commission quests (if enabled in config)
                            if pfQuest_config["epochHideCommissionQuests"] == "1" then
                                if
                                    string.find(title, "Commission for")
                                 then
                                    skipNode = true
                                    break
                                end
                            end

                            local questLevel = tonumber(data.qlvl) or tonumber(data.lvl) or 0
                            local minLevel = tonumber(data.min) or 0

                            if not isUtilityNPC then
                                if pfQuest_config["showlowlevel"] == "0" then
                                    if questLevel > 0 and questLevel <= GetGrayLevel(playerLevel) then
                                        if not (data.texture and string.find(data.texture, "complete")) then
                                            skipNode = true
                                            break
                                        end
                                    end
                                end
                            end

                            -- Skip quests that are way too high level (red quests) - only if high level display is disabled
                            if not isUtilityNPC then
                                if minLevel > playerLevel + (pfQuest_config["showhighlevel"] == "1" and 3 or 0) then
                                    if not (data.texture and string.find(data.texture, "complete")) then
                                        skipNode = true
                                        break
                                    end
                                end
                            end

                            -- Special filter for quests with suspiciously low min level - only if low level display is disabled
                            if not isUtilityNPC then
                                if pfQuest_config["showlowlevel"] == "0" then
                                    if minLevel <= 1 and questLevel <= GetGrayLevel(playerLevel) then
                                        if not (data.texture and string.find(data.texture, "complete")) then
                                            skipNode = true
                                            break
                                        end
                                    end
                                end
                            end

                            if needsDeduplication and questKey and not skipNode then
                                processedQuests[questKey] = true
                            end
                        end

                        if not skipNode then
                            local _, _, strx, stry = strfind(coords, "(.*)|(.*)")
                            local zoneX = tonumber(strx)
                            local zoneY = tonumber(stry)

                            if zoneX and zoneY then
                                local worldX, worldY = ZoneToWorld(zoneX, zoneY, zID)
                                if worldX and worldY then
                                    local contX, contY = WorldToContinent(worldX, worldY, continent)
                                    if contX and contY and contX >= 0 and contX <= 1 and contY >= 0 and contY <= 1 then
                                        pinCount = pinCount + 1
                                        if pinCount > maxContinentPins then
                                            break
                                        end

                                        local pin = CreateContinentPin(pinCount)
                                        pin.node = node
                                        pin.sourceContinent = continent

                                        pfMap:UpdateNode(pin, node, nil, nil, nil)

                                        ResizeContinentNode(pin)

                                        pin:ClearAllPoints()
                                        pin:SetPoint(
                                            "CENTER",
                                            WorldMapButton,
                                            "TOPLEFT",
                                            contX * WorldMapButton:GetWidth(),
                                            -contY * WorldMapButton:GetHeight()
                                        )
                                        pin:Show()
                                    end
                                end
                            end
                        end
                    end
                    if pinCount >= maxContinentPins then
                        break
                    end
                end
            end
        end
        if pinCount >= maxContinentPins then
            break
        end
    end

    for i = pinCount + 1, maxContinentPins do
        if continentPins[i] then
            continentPins[i]:Hide()
        end
    end
end

local originalWorldMapButton_OnUpdate = WorldMapButton:GetScript("OnUpdate")
WorldMapButton:SetScript(
    "OnUpdate",
    function(self, elapsed)
        if originalWorldMapButton_OnUpdate then
            originalWorldMapButton_OnUpdate(self, elapsed)
        end

        local currentContinent = GetCurrentMapContinent()
        local currentZone = GetCurrentMapZone()

        if self.lastContinent ~= currentContinent or self.lastZone ~= currentZone then
            self.lastContinent = currentContinent
            self.lastZone = currentZone

            if currentZone == 0 then
                pfMap:UpdateNodes()
            end
        end
    end
)

local function ExtendPfQuestConfig()
    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccContinent Map|r",
            type = "header"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Display Continent Pins",
            default = "1",
            type = "checkbox",
            config = "epochContinentPins"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Require Ctrl+Click for Pin Interaction",
            default = "0",
            type = "checkbox",
            config = "continentClickThrough"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Continent Node Size",
            default = "12",
            type = "text",
            config = "continentNodeSize"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Continent Utility Node Size",
            default = "14",
            type = "text",
            config = "continentUtilityNodeSize"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Hide Chicken Quests (CLUCK!)",
            default = "1",
            type = "checkbox",
            config = "epochHideChickenQuests"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Hide Felwood Corrupted Flowers",
            default = "1",
            type = "checkbox",
            config = "epochHideFelwoodFlowers"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Hide PvP/Battleground Quests",
            default = "1",
            type = "checkbox",
            config = "epochHidePvPQuests"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Hide Commission Quests",
            default = "0",
            type = "checkbox",
            config = "epochHideCommissionQuests"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccQuest Tracker Style|r",
            type = "header"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Show Zone Groups (Modern Style)",
            default = "0",
            type = "checkbox",
            config = "trackershowzones"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccQuest Tracker Dimensions|r",
            type = "header"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Use Fixed Height",
            default = "0",
            type = "checkbox",
            config = "trackerfixedheight"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Tracker Height (pixels)",
            default = "400",
            type = "text",
            config = "trackerheight"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Use Fixed Width",
            default = "0",
            type = "checkbox",
            config = "trackerfixedwidth"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Tracker Width (pixels)",
            default = "250",
            type = "text",
            config = "trackerwidth"
        }
    )
    
    -- Initialize the config values with defaults
    pfQuest_config["epochContinentPins"] = pfQuest_config["epochContinentPins"] or "1"
    pfQuest_config["continentClickThrough"] = pfQuest_config["continentClickThrough"] or "0"
    pfQuest_config["continentNodeSize"] = pfQuest_config["continentNodeSize"] or "12"
    pfQuest_config["continentUtilityNodeSize"] = pfQuest_config["continentUtilityNodeSize"] or "14"
    pfQuest_config["epochHideChickenQuests"] = pfQuest_config["epochHideChickenQuests"] or "1"
    pfQuest_config["epochHideFelwoodFlowers"] = pfQuest_config["epochHideFelwoodFlowers"] or "1"
    pfQuest_config["epochHidePvPQuests"] = pfQuest_config["epochHidePvPQuests"] or "1"
    pfQuest_config["epochHideCommissionQuests"] = pfQuest_config["epochHideCommissionQuests"] or "0"
    pfQuest_config["trackershowzones"] = pfQuest_config["trackershowzones"] or "0"
    pfQuest_config["trackerfixedheight"] = pfQuest_config["trackerfixedheight"] or "0"
    pfQuest_config["trackerheight"] = pfQuest_config["trackerheight"] or "400"
    pfQuest_config["trackerfixedwidth"] = pfQuest_config["trackerfixedwidth"] or "0"
    pfQuest_config["trackerwidth"] = pfQuest_config["trackerwidth"] or "250"
end

local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript(
    "OnEvent",
    function()
        ExtendPfQuestConfig()
    end
)
