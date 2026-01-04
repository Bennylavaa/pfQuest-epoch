local questObjectives = {}
local nameplateFrames = {}
local iconFrames = {}
local unusedIconFrames = {}
local frameCount = 0

local ICON_SIZE = 16
local SWORD_ICON = "Interface\\AddOns\\pfQuest-epoch\\img\\slay"
local BAG_ICON = "Interface\\AddOns\\pfQuest-epoch\\img\\loot"
local NAMEPLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"

local function ScanQuestObjectives()
    questObjectives = {}

    if not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"] then
        return
    end

    if not pfDB["quests"]["enUS"] then
        return
    end

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle, _, _, _, _, _, complete = GetQuestLogTitle(qid)
        if questTitle and complete ~= 1 then
            SelectQuestLogEntry(qid)
            activeQuests[questTitle] = {}
            local numObjectives = GetNumQuestLeaderBoards()

            for i = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(i)
                if text and not finished then
                    local objName, current, total = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                    if objName then
                        objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                        table.insert(activeQuests[questTitle], {
                            objective = objName,
                            current = tonumber(current),
                            total = tonumber(total)
                        })
                    end
                end
            end
        end
    end

    for questId, localizedData in pairs(pfDB["quests"]["enUS"]) do
        local questTitle = localizedData["T"]

        if questTitle and activeQuests[questTitle] then
            local questData = pfDB["quests"]["data"][questId]
            if questData and questData["obj"] then
                if questData["obj"]["U"] then
                    for _, unitId in pairs(questData["obj"]["U"]) do
                        if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                            local targetName = pfDB["units"]["enUS"][unitId]

                            for _, activeObj in ipairs(activeQuests[questTitle]) do
                                local objNameBase = activeObj.objective:gsub(" slain$", ""):gsub(" killed$", "")
                                if objNameBase == targetName or activeObj.objective:find(targetName, 1, true) then
                                    if activeObj.current < activeObj.total then
                                        questObjectives[targetName] = SWORD_ICON
                                    end
                                end
                            end
                        end
                    end
                end

                if questData["obj"]["I"] then
                    for _, itemId in pairs(questData["obj"]["I"]) do
                        local itemName = nil
                        if pfDB["items"] and pfDB["items"]["enUS"] and pfDB["items"]["enUS"][itemId] then
                            itemName = pfDB["items"]["enUS"][itemId]
                        end

                        if pfDB["items"] and pfDB["items"]["data"] and pfDB["items"]["data"][itemId] then
                            local itemData = pfDB["items"]["data"][itemId]

                            if itemData["U"] then
                                for unitId, dropRate in pairs(itemData["U"]) do
                                    if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                                        local npcName = pfDB["units"]["enUS"][unitId]

                                        for _, activeObj in ipairs(activeQuests[questTitle]) do
                                            if itemName and activeObj.objective:find(itemName, 1, true) then
                                                if activeObj.current < activeObj.total then
                                                    questObjectives[npcName] = BAG_ICON
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function IsNameplate(frame)
    if not frame then return false end

    local _, borderRegion = frame:GetRegions()
    if borderRegion and borderRegion:GetObjectType() == "Texture" then
        if borderRegion:GetTexture() == NAMEPLATE_BORDER then
            return true
        end
    end

    if frame.UnitFrame or frame.extended or frame.aloftData or frame.kui then
        return true
    end

    return false
end

local cachedScale, cachedX, cachedY = 1, -25, -5

local function UpdateCachedSettings()
    cachedScale = (pfQuest_config and pfQuest_config["nameplateScale"]) and tonumber(pfQuest_config["nameplateScale"]) or 1
    cachedX = (pfQuest_config and pfQuest_config["nameplateX"]) and tonumber(pfQuest_config["nameplateX"]) or -25
    cachedY = (pfQuest_config and pfQuest_config["nameplateY"]) and tonumber(pfQuest_config["nameplateY"]) or -5
end

local function GetIconFrame(nameplateFrame)
    if iconFrames[nameplateFrame] then
        return iconFrames[nameplateFrame]
    end

    if frameCount >= 300 then
        return nil
    end

    local frame = tremove(unusedIconFrames)

    if not frame then
        frame = CreateFrame("Frame")
        frame.Icon = frame:CreateTexture(nil, "ARTWORK")
        frame.Icon:SetAllPoints(frame)
        frameCount = frameCount + 1
    end

    frame:SetParent(nameplateFrame)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(1)
    frame:SetWidth(ICON_SIZE * cachedScale)
    frame:SetHeight(ICON_SIZE * cachedScale)
    frame:SetPoint("LEFT", cachedX, cachedY)
    frame:EnableMouse(false)

    iconFrames[nameplateFrame] = frame
    return frame
end

local function RemoveIconFrame(nameplateFrame)
    local frame = iconFrames[nameplateFrame]
    if not frame then
        return
    end

    frame.Icon:SetTexture(nil)
    frame:Hide()
    frame.lastIcon = nil
    tinsert(unusedIconFrames, frame)
    iconFrames[nameplateFrame] = nil
end

local function OnNameplateShow(nameplateFrame)
    if not pfQuest_config or pfQuest_config["epochnameplatesEnabled"] ~= "1" then
        return
    end

    local nameText = nameplateFrames[nameplateFrame]
    if not nameText then return end

    local unitName = nameText:GetText()
    if not unitName then return end

    local icon = questObjectives[unitName]

    if not icon then
        for objName, objIcon in pairs(questObjectives) do
            if string.find(string.lower(unitName), string.lower(objName), 1, true) then
                icon = objIcon
                break
            end
        end
    end

    if icon then
        local frame = GetIconFrame(nameplateFrame)
        if frame then
            if frame.lastIcon ~= icon then
                frame.Icon:SetTexture(icon)
                frame.lastIcon = icon
            end
            frame:Show()
        end
    else
        RemoveIconFrame(nameplateFrame)
    end
end

local function OnNameplateHide(nameplateFrame)
    RemoveIconFrame(nameplateFrame)
end

local function ScanWorldFrameChildren(...)
    local numFrames = select('#', ...)

    for i = 1, numFrames do
        local frame = select(i, ...)

        if frame and not nameplateFrames[frame] and IsNameplate(frame) then
            local nameText = select(7, frame:GetRegions())
            if nameText and nameText:GetObjectType() == "FontString" then
                nameplateFrames[frame] = nameText

                frame:HookScript("OnShow", OnNameplateShow)
                frame:HookScript("OnHide", OnNameplateHide)

                if frame:IsShown() then
                    OnNameplateShow(frame)
                end
            end
        end
    end
end

local function UpdateAllNameplates()
    for frame, nameText in pairs(nameplateFrames) do
        if frame:IsShown() then
            OnNameplateShow(frame)
        end
    end
end

local function RedrawAllIcons()
    UpdateCachedSettings()

    for _, iconFrame in pairs(iconFrames) do
        iconFrame:SetWidth(ICON_SIZE * cachedScale)
        iconFrame:SetHeight(ICON_SIZE * cachedScale)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint("LEFT", cachedX, cachedY)
    end
end

local configMonitor = CreateFrame("Frame")
local lastEnabled = "1"

local function StartConfigMonitor()
    configMonitor.elapsed = 0
    configMonitor:SetScript("OnUpdate", function()
        this.elapsed = (this.elapsed or 0) + arg1
        if this.elapsed >= 0.5 then
            if pfQuest_config then
                local currentEnabled = pfQuest_config["epochnameplatesEnabled"] or "1"

                if currentEnabled ~= lastEnabled then
                    lastEnabled = currentEnabled

                    if currentEnabled == "1" then
                        StartNameplateWatcher()
                        UpdateAllNameplates()
                    else
                        StopNameplateWatcher()
                        for frame, _ in pairs(iconFrames) do
                            RemoveIconFrame(frame)
                        end
                    end
                end
            end
            this.elapsed = 0
        end
    end)
end

local function StopConfigMonitor()
    if configMonitor then
        configMonitor:SetScript("OnUpdate", nil)
    end
end

local lastNumChildren = 0
local lastScanTime = 0
local SCAN_INTERVAL = 0.2
local ticker

local function StartNameplateWatcher()
    if ticker then return end

    UpdateCachedSettings()

    ticker = CreateFrame("Frame")
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1

        if this.elapsed >= SCAN_INTERVAL then
            local numChildren = WorldFrame:GetNumChildren()
            if numChildren ~= lastNumChildren then
                lastNumChildren = numChildren
                ScanWorldFrameChildren(WorldFrame:GetChildren())
            end
            this.elapsed = 0
        end
    end)

    StartConfigMonitor()
end

local function StopNameplateWatcher()
    if ticker then
        ticker:SetScript("OnUpdate", nil)
        ticker = nil
    end

    StopConfigMonitor()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event)
    ScanQuestObjectives()

    UpdateAllNameplates()
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "pfQuest-epoch" then
        local timer = 0
        local rebuildRetries = 0
        self:SetScript("OnUpdate", function()
            timer = timer + 1

            if rebuildRetries < 50 and (not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"]) then
                if timer % 5 == 0 then
                    rebuildRetries = rebuildRetries + 1
                    if pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
                        ScanQuestObjectives()
                        if pfQuest_config and pfQuest_config["epochnameplatesEnabled"] == "1" then
                            StartNameplateWatcher()
                        end
                    end
                end
            end

            if timer > 30 then
                ScanQuestObjectives()
                if pfQuest_config and pfQuest_config["epochnameplatesEnabled"] == "1" then
                    StartNameplateWatcher()
                end
                self:SetScript("OnUpdate", nil)
                self:UnregisterAllEvents()
            end
        end)
    end
end)

local function ExtendPfQuestConfig()
    -- Check if already added (prevents duplicates)
    local found = false
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "epochnameplatesEnabled" then
            found = true
            break
        end
    end

    if found then
        return
    end

    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccNameplates|r",
            type = "header"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Show Quest Icons on Nameplates",
            default = "1",
            type = "checkbox",
            config = "epochnameplatesEnabled"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Icon Scale",
            default = "1",
            type = "text",
            config = "nameplateScale"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Icon X Position",
            default = "-25",
            type = "text",
            config = "nameplateX"
        }
    )
    table.insert(
        pfQuest_defconfig,
        {
            text = "Icon Y Position",
            default = "-5",
            type = "text",
            config = "nameplateY"
        }
    )

    pfQuest_config["epochnameplatesEnabled"] = pfQuest_config["epochnameplatesEnabled"] or "1"
    pfQuest_config["nameplateScale"] = pfQuest_config["nameplateScale"] or "1"
    pfQuest_config["nameplateX"] = pfQuest_config["nameplateX"] or "-25"
    pfQuest_config["nameplateY"] = pfQuest_config["nameplateY"] or "-5"

    -- UI rebuild is handled by pfQuest-config.lua
end

local function HookConfigWindow()
    if pfQuestConfig then
        local originalOnHide = pfQuestConfig:GetScript("OnHide")
        pfQuestConfig:SetScript("OnHide", function()
            if originalOnHide then
                originalOnHide()
            end
            RedrawAllIcons()
        end)
    end
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
    HookConfigWindow()
end)

SLASH_PFQUESTNP1 = "/pfqnp"
SlashCmdList["PFQUESTNP"] = function(msg)
    if msg == "debug" then
        print("|cff33ffccpfQuest-epoch Nameplates Debug:|r")
        print("=== Status ===")
        print("Enabled: " .. tostring(pfQuest_config and pfQuest_config["epochnameplatesEnabled"] == "1"))
        print("Watcher running: " .. tostring(ticker ~= nil))
        print("pfDB exists: " .. tostring(pfDB ~= nil))

        if pfDB then
            print("  pfDB.quests exists: " .. tostring(pfDB.quests ~= nil))
            if pfDB.quests then
                print("  pfDB.quests.data exists: " .. tostring(pfDB.quests.data ~= nil))
            end
        end

        print("=== Settings ===")
        print("Scale: " .. tostring(pfQuest_config["nameplateScale"] or "1"))
        print("X Position: " .. tostring(pfQuest_config["nameplateX"] or "0"))
        print("Y Position: " .. tostring(pfQuest_config["nameplateY"] or "0"))

        print("=== Quest Objectives ===")
        local count = 0
        for npcName, icon in pairs(questObjectives) do
            count = count + 1
            local iconType = (icon == SWORD_ICON) and "KILL" or "LOOT"
            print("  " .. npcName .. " - " .. iconType)
        end
        print("Total objectives tracked: " .. count)

        print("=== Nameplates ===")
        local npCount = 0
        for frame, nameText in pairs(nameplateFrames) do
            npCount = npCount + 1
        end
        print("Total nameplates tracked: " .. npCount)

        local iconCount = 0
        for frame, iconFrame in pairs(iconFrames) do
            iconCount = iconCount + 1
            local nameText = nameplateFrames[frame]
            if nameText then
                local name = nameText:GetText()
                print("  Icon " .. iconCount .. ": " .. tostring(name) .. " (visible: " .. tostring(iconFrame:IsVisible()) .. ")")
            end
        end
        print("Active nameplate icons: " .. iconCount)
        print("Total icon frames created: " .. frameCount)

        if count == 0 then
            print("|cffff0000No quest objectives found!|r")
            print("Try running |cffffcc00/pfqrebuild|r to rebuild quest mappings")
        end
    elseif msg == "scan" then
        print("|cff33ffccpfQuest-epoch:|r Manually scanning quest objectives...")
        ScanQuestObjectives()
        UpdateAllNameplates()
        print("Done! Run |cffffcc00/pfqnp debug|r to see results")
    elseif msg == "on" then
        if not pfQuest_config then pfQuest_config = {} end
        pfQuest_config["epochnameplatesEnabled"] = "1"
        StartNameplateWatcher()
        UpdateAllNameplates()
        print("|cff33ffccpfQuest-epoch:|r Nameplate icons enabled")
    elseif msg == "off" then
        if not pfQuest_config then pfQuest_config = {} end
        pfQuest_config["epochnameplatesEnabled"] = "0"
        StopNameplateWatcher()
        for frame, _ in pairs(iconFrames) do
            RemoveIconFrame(frame)
        end
        print("|cff33ffccpfQuest-epoch:|r Nameplate icons disabled")
    else
        print("|cff33ffccpfQuest-epoch Nameplates:|r")
        print("Commands:")
        print("  |cffffcc00/pfqnp debug|r - Show debug information")
        print("  |cffffcc00/pfqnp scan|r - Manually rescan quest objectives")
        print("  |cffffcc00/pfqnp on|r - Enable nameplate icons")
        print("  |cffffcc00/pfqnp off|r - Disable nameplate icons")
        print("")
        print("To adjust icon size/position:")
        print("Open |cffffcc00/pfquest config|r → Nameplates section")
        print("Changes apply when you click Save & Close")
    end
end