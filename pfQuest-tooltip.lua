local partyQuestData = {}
local myQuestMappings = {}
local lastBroadcastState = {}
local previousQuestList = {}
local debugMode = false

local function InitializeConfig()
    if not pfQuest_config then
        pfQuest_config = {}
    end

    if pfQuest_config["epochShowPartyProgress"] == nil then
        pfQuest_config["epochShowPartyProgress"] = "1"
    end
end

local function CleanupPartyData()
    local validPlayers = {}

    validPlayers[UnitName("player")] = true

    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name then
            validPlayers[name] = true
        end
    end

    for i = 1, GetNumRaidMembers() do
        local name = UnitName("raid" .. i)
        if name then
            validPlayers[name] = true
        end
    end

    for playerName in pairs(partyQuestData) do
        if not validPlayers[playerName] then
            partyQuestData[playerName] = nil
        end
    end
end

local myQuestMappings = {}

local function RebuildQuestMappings()
    if not pfDatabase or not pfDatabase["quests"] or not pfDatabase["quests"]["data"] then
        return
    end

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle, _, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle then
            activeQuests[questTitle] = {}
            local numObjectives = GetNumQuestLeaderBoards(qid)

            for i = 1, numObjectives do
                local text, objType, finished = GetQuestLogLeaderBoard(i, qid)
                if text then
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

    for questId, questData in pairs(pfDatabase["quests"]["data"]) do
        local questTitle = questData["T"]

        if questTitle and activeQuests[questTitle] then
            if questData["objectives"] then
                for _, objective in pairs(questData["objectives"]) do
                    local objType = objective["type"]

                    if objType == "slay" or objType == "loot" then
                        local targetName = objective["targetName"]
                        local objectiveName = objective["questText"]

                        if targetName and objectiveName then
                            for _, activeObj in ipairs(activeQuests[questTitle]) do
                                if activeObj.objective == objectiveName then
                                    if not myQuestMappings[targetName] then
                                        myQuestMappings[targetName] = {}
                                    end

                                    local found = false
                                    for _, data in ipairs(myQuestMappings[targetName]) do
                                        if data.quest == questTitle and data.objective == objectiveName then
                                            data.current = activeObj.current
                                            data.total = activeObj.total
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(myQuestMappings[targetName], {
                                            quest = questTitle,
                                            objective = objectiveName,
                                            current = activeObj.current,
                                            total = activeObj.total
                                        })
                                    end

                                    if debugMode then
                                        print("|cff33ffccpfQuest-epoch:|r REBUILD - Added " .. targetName .. " -> " .. questTitle .. " (" .. objectiveName .. ": " .. activeObj.current .. "/" .. activeObj.total .. ")")
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

local function CaptureMyQuestData(targetKey, questTitle, objectiveText, current, total)
    if debugMode then
        print("|cff33ffccpfQuest-epoch:|r CAPTURE - Key: " .. tostring(targetKey) .. ", Quest: " .. tostring(questTitle) .. ", Obj: " .. tostring(objectiveText) .. ", Progress: " .. current .. "/" .. total)
    end

    if not myQuestMappings[targetKey] then
        myQuestMappings[targetKey] = {}
    end

    local found = false
    for _, data in ipairs(myQuestMappings[targetKey]) do
        if data.quest == questTitle and data.objective == objectiveText then
            data.current = current
            data.total = total
            found = true
            break
        end
    end

    if not found then
        table.insert(myQuestMappings[targetKey], {
            quest = questTitle,
            objective = objectiveText,
            current = current,
            total = total
        })
    end
end

local function ShareQuestData()
    if GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 then
        return
    end

    local channel = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
    local myName = UnitName("player")

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle then
            activeQuests[questTitle] = true
        end
    end

    for questTitle in pairs(previousQuestList) do
        if not activeQuests[questTitle] then
            for targetKey, quests in pairs(myQuestMappings) do
                for _, questData in ipairs(quests) do
                    if questData.quest == questTitle then
                        local msg = string.format("REMOVE:%s:%s", targetKey, questTitle)
                        SendAddonMessage("pfqe", msg, channel)

                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r REMOVE broadcast - " .. targetKey .. ": " .. questTitle)
                        end
                    end
                end
            end
        end
    end

    previousQuestList = activeQuests

    for targetKey, quests in pairs(myQuestMappings) do
        local i = 1
        while i <= table.getn(quests) do
            if not activeQuests[quests[i].quest] then
                table.remove(quests, i)
            else
                i = i + 1
            end
        end

        if table.getn(quests) == 0 then
            myQuestMappings[targetKey] = nil
        end
    end

    for targetKey, quests in pairs(myQuestMappings) do
        for _, questData in ipairs(quests) do
            for qid = 1, GetNumQuestLogEntries() do
                local questTitle, _, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)

                if questTitle == questData.quest then
                    local numObjectives = GetNumQuestLeaderBoards(qid)

                    for i = 1, numObjectives do
                        local text, objType, finished = GetQuestLogLeaderBoard(i, qid)

                        if text then
                            local objName, current, total = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                            if objName then
                                objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")

                                if objName == questData.objective then
                                    questData.current = tonumber(current)
                                    questData.total = tonumber(total)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if debugMode then
        local count = 0
        for _ in pairs(myQuestMappings) do count = count + 1 end
        print("|cff33ffccpfQuest-epoch:|r BROADCAST (quest update) - Sending " .. count .. " target mappings to " .. channel)
    end

    for targetKey, quests in pairs(myQuestMappings) do
        for _, data in ipairs(quests) do
            local msg = string.format("QUEST:%s:%s:%s:%d:%d",
                targetKey,
                data.quest,
                data.objective,
                data.current,
                data.total)
            SendAddonMessage("pfqe", msg, channel)

            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r   -> " .. targetKey .. ": " .. data.quest .. " (" .. data.current .. "/" .. data.total .. ")")
            end

            if not partyQuestData[myName] then
                partyQuestData[myName] = {}
            end
            if not partyQuestData[myName][targetKey] then
                partyQuestData[myName][targetKey] = {}
            end

            local found = false
            for i, existing in ipairs(partyQuestData[myName][targetKey]) do
                if existing.quest == data.quest and existing.objective == data.objective then
                    partyQuestData[myName][targetKey][i].current = data.current
                    partyQuestData[myName][targetKey][i].total = data.total
                    partyQuestData[myName][targetKey][i].lastUpdate = GetTime()
                    found = true
                    break
                end
            end

            if not found then
                table.insert(partyQuestData[myName][targetKey], {
                    quest = data.quest,
                    objective = data.objective,
                    current = data.current,
                    total = data.total,
                    lastUpdate = GetTime()
                })
            end
        end
    end
end

local function ProcessQuestData(sender, message)
    local removeTarget, removeQuest = string.match(message, "^REMOVE:([^:]+):(.+)$")
    if removeTarget and removeQuest then
        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r REMOVE from " .. sender .. " - Key: " .. removeTarget .. ", Quest: " .. removeQuest)
        end

        if partyQuestData[sender] and partyQuestData[sender][removeTarget] then
            local i = 1
            while i <= table.getn(partyQuestData[sender][removeTarget]) do
                if partyQuestData[sender][removeTarget][i].quest == removeQuest then
                    table.remove(partyQuestData[sender][removeTarget], i)
                else
                    i = i + 1
                end
            end

            if table.getn(partyQuestData[sender][removeTarget]) == 0 then
                partyQuestData[sender][removeTarget] = nil
            end
        end

        return
    end

    local targetName, questTitle, objective, current, total = string.match(message, "^QUEST:([^:]+):([^:]+):([^:]+):(%d+):(%d+)$")

    if targetName and questTitle and objective and current and total then
        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r RECEIVE from " .. sender .. " - Key: " .. targetName .. ", Quest: " .. questTitle .. ", Progress: " .. current .. "/" .. total)
        end

        if not partyQuestData[sender] then
            partyQuestData[sender] = {}
        end

        if not partyQuestData[sender][targetName] then
            partyQuestData[sender][targetName] = {}
        end

        local found = false
        for i, data in ipairs(partyQuestData[sender][targetName]) do
            if data.quest == questTitle and data.objective == objective then
                partyQuestData[sender][targetName][i].current = tonumber(current)
                partyQuestData[sender][targetName][i].total = tonumber(total)
                partyQuestData[sender][targetName][i].lastUpdate = GetTime()
                found = true
                break
            end
        end

        if not found then
            table.insert(partyQuestData[sender][targetName], {
                quest = questTitle,
                objective = objective,
                current = tonumber(current),
                total = tonumber(total),
                lastUpdate = GetTime()
            })
        end
    end
end

local function GetClassColor(playerName)
    if playerName == UnitName("player") then
        local _, class = UnitClass("player")
        if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
            local classColor = RAID_CLASS_COLORS[class]
            return {classColor.r, classColor.g, classColor.b}
        end
    end

    for i = 1, GetNumPartyMembers() do
        local name = UnitName("party" .. i)
        if name == playerName then
            local _, class = UnitClass("party" .. i)
            if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
                local classColor = RAID_CLASS_COLORS[class]
                return {classColor.r, classColor.g, classColor.b}
            end
            break
        end
    end

    for i = 1, GetNumRaidMembers() do
        local name = UnitName("raid" .. i)
        if name == playerName then
            local _, class = UnitClass("raid" .. i)
            if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
                local classColor = RAID_CLASS_COLORS[class]
                return {classColor.r, classColor.g, classColor.b}
            end
            break
        end
    end

    return {1.0, 1.0, 1.0}
end

local function HookGameTooltip()
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local unitName, unit = self:GetUnit()
        if not unitName or not unit then return end
        if UnitIsPlayer(unit) then return end

        local inParty = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
        local featureEnabled = pfQuest_config and pfQuest_config["epochShowPartyProgress"] == "1"

        if not inParty or not featureEnabled then return end

        local matchedKey = nil
        local questGroups = {}

        for playerName, targets in pairs(partyQuestData) do
            if targets[unitName] then
                matchedKey = unitName
                for _, data in ipairs(targets[unitName]) do
                    if not questGroups[data.quest] then
                        questGroups[data.quest] = {}
                    end

                    local isDuplicate = false
                    for _, existing in ipairs(questGroups[data.quest]) do
                        if existing.player == playerName and existing.objective == data.objective then
                            existing.current = data.current
                            existing.total = data.total
                            isDuplicate = true
                            break
                        end
                    end

                    if not isDuplicate then
                        table.insert(questGroups[data.quest], {
                            player = playerName,
                            objective = data.objective,
                            current = data.current,
                            total = data.total
                        })
                    end
                end
            end
        end

        if not matchedKey then return end

        self:AddLine(" ")

        for questName, lines in pairs(questGroups) do
            local symbol = "|cff555555[|cffffcc00!|cff555555]|r "
            self:AddLine(symbol .. questName, 1, 1, 0)

            for _, line in ipairs(lines) do
                local classColor = GetClassColor(line.player)
                local perc = line.current / line.total
                local r, g, b

                if perc <= 0.5 then
                    perc = perc * 2
                    r = 1
                    g = perc
                    b = 0
                else
                    perc = perc * 2 - 1
                    r = 1 - perc
                    g = 1
                    b = 0
                end

                local cr, cg, cb = classColor[1] * 255, classColor[2] * 255, classColor[3] * 255
                local coloredName = string.format("|cFF%02x%02x%02x%s|r", cr, cg, cb, line.player)
                local displayText = string.format("|cffaaaaaa- |r%s: %s (%d/%d)", coloredName, line.objective, line.current, line.total)
                self:AddLine(displayText, r, g, b)
            end
        end

        self:AddLine(" ")
        self:Show()
    end)

    return true
end

local function HookPfQuestTooltip()
    if not pfMap or not pfMap.ShowTooltip then
        return false
    end

    if not pfQuestCompat then
        return false
    end

    local orig_ShowTooltip = pfMap.ShowTooltip

    pfMap.ShowTooltip = function(self, meta, tooltip)
        tooltip = tooltip or GameTooltip

        local targetKey = meta.spawn or meta.title

        local tooltipName = nil
        local tooltipText = _G["GameTooltipTextLeft1"]
        if tooltipText and tooltipText:GetText() then
            tooltipName = tooltipText:GetText()
        end

        local inParty = (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0)
        local featureEnabled = pfQuest_config and pfQuest_config["epochShowPartyProgress"] == "1"

        if meta["quest"] and inParty and featureEnabled and targetKey then
            for qid=1, GetNumQuestLogEntries() do
                local qtitle, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)

                if meta["quest"] == qtitle then
                    local objectives = GetNumQuestLeaderBoards(qid)

                    if objectives then
                        for i=1, objectives do
                            local text, type, finished = GetQuestLogLeaderBoard(i, qid)

                            if text then
                                local objName, current, total = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                                if objName and current and total then
                                    objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                                    if string.len(objName) > 0 then
                                        CaptureMyQuestData(targetKey, qtitle, objName, tonumber(current), tonumber(total))
                                        if tooltipName and tooltipName ~= targetKey then
                                            CaptureMyQuestData(tooltipName, qtitle, objName, tonumber(current), tonumber(total))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local hasPartyData = false
        local matchedKey = nil

        if inParty and featureEnabled then
            if targetKey then
                for playerName, targets in pairs(partyQuestData) do
                    if targets[targetKey] then
                        hasPartyData = true
                        matchedKey = targetKey
                        break
                    end
                end
            end

            if not hasPartyData and tooltipName then
                for playerName, targets in pairs(partyQuestData) do
                    if targets[tooltipName] then
                        hasPartyData = true
                        matchedKey = tooltipName
                        break
                    end
                end
            end
        end

        if hasPartyData and matchedKey then
            local oldquest = meta["quest"]
            meta["quest"] = nil
            orig_ShowTooltip(self, meta, tooltip)
            meta["quest"] = oldquest

            local unitName, unit = tooltip:GetUnit()
            if not unit then
                local questGroups = {}

                for playerName, targets in pairs(partyQuestData) do
                    if targets[matchedKey] then
                        for _, data in ipairs(targets[matchedKey]) do
                            if not questGroups[data.quest] then
                                questGroups[data.quest] = {}
                            end

                            local isDuplicate = false
                            for _, existing in ipairs(questGroups[data.quest]) do
                                if existing.player == playerName and existing.objective == data.objective then
                                    existing.current = data.current
                                    existing.total = data.total
                                    isDuplicate = true
                                    break
                                end
                            end

                            if not isDuplicate then
                                table.insert(questGroups[data.quest], {
                                    player = playerName,
                                    objective = data.objective,
                                    current = data.current,
                                    total = data.total
                                })
                            end
                        end
                    end
                end

                tooltip:AddLine(" ")

                for questName, lines in pairs(questGroups) do
                    local symbol = "|cff555555[|cffffcc00!|cff555555]|r "
                    tooltip:AddLine(symbol .. questName, 1, 1, 0)

                    for _, line in ipairs(lines) do
                        local classColor = GetClassColor(line.player)
                        local perc = line.current / line.total
                        local r, g, b

                        if perc <= 0.5 then
                            perc = perc * 2
                            r = 1
                            g = perc
                            b = 0
                        else
                            perc = perc * 2 - 1
                            r = 1 - perc
                            g = 1
                            b = 0
                        end

                        local cr, cg, cb = classColor[1] * 255, classColor[2] * 255, classColor[3] * 255
                        local coloredName = string.format("|cFF%02x%02x%02x%s|r", cr, cg, cb, line.player)
                        local displayText = string.format("|cffaaaaaa- |r%s: %s (%d/%d)", coloredName, line.objective, line.current, line.total)
                        tooltip:AddLine(displayText, r, g, b)
                    end
                end

                tooltip:AddLine(" ")
            end

            tooltip:Show()
        else
            orig_ShowTooltip(self, meta, tooltip)
        end
    end

    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTER_COMBAT")
eventFrame:RegisterEvent("PLAYER_LEAVE_COMBAT")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = arg1, arg2, arg3, arg4
        if prefix == "pfqe" then
            ProcessQuestData(sender, message)
        elseif prefix == "PFQUEST_SYNC_REQUEST" then
            if (GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0) and sender ~= UnitName("player") then
                if debugMode then
                    print("|cff33ffccpfQuest-epoch:|r Received sync request from " .. sender .. ", rebuilding and broadcasting current data")
                end
                RebuildQuestMappings()
                ShareQuestData()
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        CleanupPartyData()
        if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
            RebuildQuestMappings()
            ShareQuestData()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        CleanupPartyData()
        if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
            RebuildQuestMappings()
            local channel = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r Requesting sync from " .. channel)
            end
            SendAddonMessage("PFQUEST_SYNC_REQUEST", "1", channel)
            ShareQuestData()
        end
    elseif event == "QUEST_LOG_UPDATE" then
        if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
            RebuildQuestMappings()
            ShareQuestData()
        end
    elseif event == "PLAYER_ENTER_COMBAT" then
        if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
            RebuildQuestMappings()
            ShareQuestData()
        end
    elseif event == "PLAYER_LEAVE_COMBAT" then
        if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
            RebuildQuestMappings()
            ShareQuestData()
        end
    end
end)

local function ExtendPfQuestConfig()
    if not pfQuest_defconfig or not pfQuestConfig then
        return false
    end

    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "epochShowPartyProgress" then
            return true
        end
    end

    table.insert(pfQuest_defconfig, {
        text = "Show Party Quest Progress on Tooltips",
        default = "1",
        type = "checkbox",
        config = "epochShowPartyProgress"
    })

    if not pfQuest_config["epochShowPartyProgress"] then
        pfQuest_config["epochShowPartyProgress"] = "1"
    end

    if pfQuestConfig.CreateConfigEntries then
        for i = 1, 50 do
            local frame = getglobal("pfQuestConfig" .. i)
            if frame then
                frame:Hide()
                frame:SetParent(nil)
            else
                break
            end
        end

        pfQuestConfig.vpos = 40
        pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)
    end

    return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("ADDON_LOADED")
configExtenderFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "pfQuest-epoch" then
        InitializeConfig()

        HookGameTooltip()

        if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then
            RebuildQuestMappings()
            local channel = GetNumRaidMembers() > 0 and "RAID" or "PARTY"
            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r Addon loaded, rebuilding and requesting sync from " .. channel)
            end
            SendAddonMessage("PFQUEST_SYNC_REQUEST", "1", channel)
            ShareQuestData()
        end

        local timer = 0
        self:SetScript("OnUpdate", function()
            timer = timer + 1
            if timer > 10 then
                if ExtendPfQuestConfig() and HookPfQuestTooltip() then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                elseif timer > 300 then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                end
            end
        end)
    end
end)