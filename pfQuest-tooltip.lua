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

    for playerName in pairs(partyQuestData) do
        if not validPlayers[playerName] then
            partyQuestData[playerName] = nil
        end
    end
end

local myQuestMappings = {}

local function RebuildQuestMappings()
    if debugMode then
        print("|cff33ffccpfQuest-epoch:|r REBUILD - Checking pfDB...")
        print("  pfDB exists: " .. tostring(pfDB ~= nil))
        if pfDB then
            print("  pfDB type: " .. type(pfDB))
            print("  pfDB.quests exists: " .. tostring(pfDB.quests ~= nil))
            if pfDB.quests then
                print("  pfDB.quests.data exists: " .. tostring(pfDB.quests.data ~= nil))
            end
        end
        print("  pfQuestCompat exists: " .. tostring(pfQuestCompat ~= nil))
        print("  pfMap exists: " .. tostring(pfMap ~= nil))
    end

    if not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"] then
        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r REBUILD - pfDB not available")
        end
        return
    end

    if debugMode then
        print("|cff33ffccpfQuest-epoch:|r REBUILD - Starting quest mapping rebuild")
    end

    local activeQuests = {}
    for qid = 1, GetNumQuestLogEntries() do
        local questTitle, _, _, _, _, _, complete = pfQuestCompat.GetQuestLogTitle(qid)
        if questTitle then
            activeQuests[questTitle] = {}
            local numObjectives = GetNumQuestLeaderBoards(qid)

            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r REBUILD - Found quest: " .. questTitle .. " with " .. numObjectives .. " objectives")
            end

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
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r REBUILD - Objective: " .. objName .. " (" .. current .. "/" .. total .. ")")
                        end
                    end
                end
            end
        end
    end

    if not pfDB["quests"]["enUS"] then
        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r REBUILD - No enUS localization table found")
        end
        return
    end

    for questId, localizedData in pairs(pfDB["quests"]["enUS"]) do
        local questTitle = localizedData["T"]

        if questTitle and activeQuests[questTitle] then
            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r REBUILD - Matching quest: " .. questTitle .. " (ID: " .. questId .. ")")
            end

            local questData = pfDB["quests"]["data"][questId]
            if questData and questData["obj"] then
                if debugMode then
                    print("|cff33ffccpfQuest-epoch:|r REBUILD - Quest has obj table")
                end

                if questData["obj"]["U"] then
                    for _, unitId in pairs(questData["obj"]["U"]) do
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r REBUILD - Found unit objective: Unit ID " .. tostring(unitId))
                        end

                        if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                            local targetName = pfDB["units"]["enUS"][unitId]

                            if debugMode then
                                print("|cff33ffccpfQuest-epoch:|r REBUILD - Unit name: " .. targetName)
                            end

                            for _, activeObj in ipairs(activeQuests[questTitle]) do
                                if debugMode then
                                    print("|cff33ffccpfQuest-epoch:|r REBUILD - Checking if quest log objective matches...")
                                    print("    Quest log: \"" .. activeObj.objective .. "\"")
                                    print("    Target name: \"" .. targetName .. "\"")
                                end

                                local objNameBase = activeObj.objective:gsub(" slain$", ""):gsub(" killed$", "")
                                if objNameBase == targetName or activeObj.objective:find(targetName, 1, true) then
                                    if not myQuestMappings[targetName] then
                                        myQuestMappings[targetName] = {}
                                    end

                                    local found = false
                                    for _, data in ipairs(myQuestMappings[targetName]) do
                                        if data.quest == questTitle and data.objective == activeObj.objective then
                                            data.current = activeObj.current
                                            data.total = activeObj.total
                                            data.questId = questId
                                            data.targetId = unitId
                                            data.targetType = "U"
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(myQuestMappings[targetName], {
                                            quest = questTitle,
                                            questId = questId,
                                            objective = activeObj.objective,
                                            current = activeObj.current,
                                            total = activeObj.total,
                                            targetId = unitId,
                                            targetType = "U"
                                        })
                                    end

                                    if debugMode then
                                        print("|cff33ffccpfQuest-epoch:|r REBUILD - Added " .. targetName .. " -> " .. questTitle .. " (" .. activeObj.objective .. ": " .. activeObj.current .. "/" .. activeObj.total .. ")")
                                    end
                                end
                            end
                        end
                    end
                end

                if questData["obj"]["I"] then
                    for _, itemId in pairs(questData["obj"]["I"]) do
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r REBUILD - Found item objective: Item ID " .. tostring(itemId))
                        end

                        local itemName = nil
                        if pfDB["items"] and pfDB["items"]["enUS"] and pfDB["items"]["enUS"][itemId] then
                            itemName = pfDB["items"]["enUS"][itemId]

                            if debugMode then
                                print("|cff33ffccpfQuest-epoch:|r REBUILD - Item name: " .. itemName)
                            end
                        end

                        if pfDB["items"] and pfDB["items"]["data"] and pfDB["items"]["data"][itemId] then
                            local itemData = pfDB["items"]["data"][itemId]

                            if itemData["U"] then
                                for unitId, dropRate in pairs(itemData["U"]) do
                                    if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                                        local npcName = pfDB["units"]["enUS"][unitId]

                                        if debugMode then
                                            print("|cff33ffccpfQuest-epoch:|r REBUILD - NPC " .. npcName .. " drops " .. (itemName or "item " .. itemId) .. " (" .. dropRate .. "%)")
                                        end

                                        for _, activeObj in ipairs(activeQuests[questTitle]) do
                                            if itemName and activeObj.objective:find(itemName, 1, true) then
                                                if not myQuestMappings[npcName] then
                                                    myQuestMappings[npcName] = {}
                                                end

                                                local found = false
                                                for _, data in ipairs(myQuestMappings[npcName]) do
                                                    if data.quest == questTitle and data.objective == activeObj.objective then
                                                        data.current = activeObj.current
                                                        data.total = activeObj.total
                                                        data.questId = questId
                                                        data.targetId = unitId
                                                        data.itemId = itemId
                                                        data.targetType = "I"
                                                        found = true
                                                        break
                                                    end
                                                end

                                                if not found then
                                                    table.insert(myQuestMappings[npcName], {
                                                        quest = questTitle,
                                                        questId = questId,
                                                        objective = activeObj.objective,
                                                        current = activeObj.current,
                                                        total = activeObj.total,
                                                        targetId = unitId,
                                                        itemId = itemId,
                                                        targetType = "I"
                                                    })
                                                end

                                                if debugMode then
                                                    print("|cff33ffccpfQuest-epoch:|r REBUILD - Mapped NPC " .. npcName .. " -> " .. questTitle .. " (" .. activeObj.objective .. ")")
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            if itemData["O"] then
                                for objectId, dropRate in pairs(itemData["O"]) do
                                    if pfDB["objects"] and pfDB["objects"]["enUS"] and pfDB["objects"]["enUS"][objectId] then
                                        local objName = pfDB["objects"]["enUS"][objectId]

                                        if debugMode then
                                            print("|cff33ffccpfQuest-epoch:|r REBUILD - Object " .. objName .. " contains " .. (itemName or "item " .. itemId) .. " (" .. dropRate .. "%)")
                                        end

                                        for _, activeObj in ipairs(activeQuests[questTitle]) do
                                            if itemName and activeObj.objective:find(itemName, 1, true) then
                                                if not myQuestMappings[objName] then
                                                    myQuestMappings[objName] = {}
                                                end

                                                local found = false
                                                for _, data in ipairs(myQuestMappings[objName]) do
                                                    if data.quest == questTitle and data.objective == activeObj.objective then
                                                        data.current = activeObj.current
                                                        data.total = activeObj.total
                                                        data.questId = questId
                                                        data.targetId = objectId
                                                        data.itemId = itemId
                                                        data.targetType = "I"
                                                        found = true
                                                        break
                                                    end
                                                end

                                                if not found then
                                                    table.insert(myQuestMappings[objName], {
                                                        quest = questTitle,
                                                        questId = questId,
                                                        objective = activeObj.objective,
                                                        current = activeObj.current,
                                                        total = activeObj.total,
                                                        targetId = objectId,
                                                        itemId = itemId,
                                                        targetType = "I"
                                                    })
                                                end

                                                if debugMode then
                                                    print("|cff33ffccpfQuest-epoch:|r REBUILD - Mapped object " .. objName .. " -> " .. questTitle .. " (" .. activeObj.objective .. ")")
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                if questData["obj"]["O"] then
                    for _, objectId in pairs(questData["obj"]["O"]) do
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r REBUILD - Found object objective: Object ID " .. tostring(objectId))
                        end

                        if pfDB["objects"] and pfDB["objects"]["enUS"] and pfDB["objects"]["enUS"][objectId] then
                            local objectName = pfDB["objects"]["enUS"][objectId]

                            if debugMode then
                                print("|cff33ffccpfQuest-epoch:|r REBUILD - Object name: " .. objectName)
                            end

                            for _, activeObj in ipairs(activeQuests[questTitle]) do
                                if activeObj.objective:find(objectName, 1, true) then
                                    if not myQuestMappings[objectName] then
                                        myQuestMappings[objectName] = {}
                                    end

                                    local found = false
                                    for _, data in ipairs(myQuestMappings[objectName]) do
                                        if data.quest == questTitle and data.objective == activeObj.objective then
                                            data.current = activeObj.current
                                            data.total = activeObj.total
                                            data.questId = questId
                                            data.targetId = objectId
                                            data.targetType = "O"
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(myQuestMappings[objectName], {
                                            quest = questTitle,
                                            questId = questId,
                                            objective = activeObj.objective,
                                            current = activeObj.current,
                                            total = activeObj.total,
                                            targetId = objectId,
                                            targetType = "O"
                                        })
                                    end

                                    if debugMode then
                                        print("|cff33ffccpfQuest-epoch:|r REBUILD - Added " .. objectName .. " -> " .. questTitle .. " (" .. activeObj.objective .. ": " .. activeObj.current .. "/" .. activeObj.total .. ")")
                                    end
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
        print("|cff33ffccpfQuest-epoch:|r REBUILD - Complete. Total target mappings: " .. count)
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

local function BuildStateString(targetKey, questData)
    return string.format("%s:%s:%d:%d",
        targetKey,
        questData.quest,
        questData.current,
        questData.total)
end

local function ShareQuestData(forceFullSync)
    if GetNumPartyMembers() == 0 then
        return
    end

    local channel = "PARTY"
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
            local questId = nil

            for targetKey, quests in pairs(myQuestMappings) do
                for _, questData in ipairs(quests) do
                    if questData.quest == questTitle and questData.questId then
                        questId = questData.questId
                        break
                    end
                end
                if questId then break end
            end

            if questId then
                local msg = string.format("REMOVEQ:%d:%s", questId, questTitle)
                SendAddonMessage("pfqe", msg, channel)

                if debugMode then
                    print("|cff33ffccpfQuest-epoch:|r REMOVE broadcast - Quest: " .. questTitle .. " (ID: " .. questId .. ")")
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

    local changedEntries = {}
    local currentState = {}
    local consolidatedObjectives = {}

    for targetKey, quests in pairs(myQuestMappings) do
        for _, data in ipairs(quests) do
            local stateKey = BuildStateString(targetKey, data)
            currentState[stateKey] = true

            if forceFullSync or not lastBroadcastState[stateKey] then
                if data.questId and data.targetId and data.targetType then

                    if data.targetType == "I" then
                        local objKey = data.questId .. ":" .. data.objective

                        if not consolidatedObjectives[objKey] then
                            consolidatedObjectives[objKey] = {
                                questId = data.questId,
                                objective = data.objective,
                                quest = data.quest,
                                current = data.current,
                                total = data.total,
                                targetType = "I",
                                targetId = data.itemId or data.targetId
                            }
                        else
                            if data.current > consolidatedObjectives[objKey].current then
                                consolidatedObjectives[objKey].current = data.current
                            end
                        end
                    else
                        table.insert(changedEntries, {
                            targetKey = targetKey,
                            targetType = data.targetType,
                            targetId = data.targetId,
                            questId = data.questId,
                            current = data.current,
                            total = data.total,
                            quest = data.quest,
                            objective = data.objective
                        })
                    end

                    if debugMode then
                        print("|cff33ffccpfQuest-epoch:|r DELTA - Changed: " .. targetKey .. " -> " .. data.quest .. " (" .. data.current .. "/" .. data.total .. ")")
                    end
                end
            end
        end
    end

    for _, entry in pairs(consolidatedObjectives) do
        table.insert(changedEntries, entry)
    end

    lastBroadcastState = currentState

    if table.getn(changedEntries) == 0 then
        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r BROADCAST - No changes, skipping")
        end
        return
    end

    local messages = {}
    local currentBatch = "V1|"
    local entriesInBatch = 0

    if debugMode then
        print("|cff33ffccpfQuest-epoch:|r BROADCAST - Building batches for " .. table.getn(changedEntries) .. " changed entries")
    end

    for _, entry in ipairs(changedEntries) do
        -- Compact format: UxxxQyyy:cc:tt; or OxxxQyyy:cc:tt;
        local entryStr = string.format("%s%dQ%d:%d:%d;",
            entry.targetType,
            entry.targetId,
            entry.questId,
            entry.current,
            entry.total)

        if string.len(currentBatch) + string.len(entryStr) > 250 then
            table.insert(messages, currentBatch)

            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r BATCH - Split at " .. entriesInBatch .. " entries (" .. string.len(currentBatch) .. " chars)")
            end

            currentBatch = "V1|" .. entryStr
            entriesInBatch = 1
        else
            currentBatch = currentBatch .. entryStr
            entriesInBatch = entriesInBatch + 1
        end
    end

    if string.len(currentBatch) > 3 then
        table.insert(messages, currentBatch)
    end

    if debugMode then
        print("|cff33ffccpfQuest-epoch:|r BROADCAST - Sending " .. table.getn(messages) .. " batched message(s) to " .. channel)
    end

    for i, msg in ipairs(messages) do
        SendAddonMessage("pfqe", msg, channel)

        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r   Batch " .. i .. " (" .. string.len(msg) .. " chars): " .. msg)
        end
    end

    for _, entry in ipairs(changedEntries) do
        if entry.targetKey then
            if not partyQuestData[myName] then
                partyQuestData[myName] = {}
            end
            if not partyQuestData[myName][entry.targetKey] then
                partyQuestData[myName][entry.targetKey] = {}
            end

            local found = false
            for i, existing in ipairs(partyQuestData[myName][entry.targetKey]) do
                if existing.quest == entry.quest and existing.objective == entry.objective then
                    partyQuestData[myName][entry.targetKey][i].current = entry.current
                    partyQuestData[myName][entry.targetKey][i].total = entry.total
                    partyQuestData[myName][entry.targetKey][i].lastUpdate = GetTime()
                    found = true
                    break
                end
            end

            if not found then
                table.insert(partyQuestData[myName][entry.targetKey], {
                    quest = entry.quest,
                    objective = entry.objective,
                    current = entry.current,
                    total = entry.total,
                    lastUpdate = GetTime()
                })
            end
        end
    end
end

local function ProcessQuestData(sender, message)
    -- Handle consolidated quest removal (new format: REMOVEQ:questId:questTitle)
    local removeQuestId, removeQuestTitle = string.match(message, "^REMOVEQ:(%d+):(.+)$")
    if removeQuestId and removeQuestTitle then
        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r REMOVEQ from " .. sender .. " - Quest: " .. removeQuestTitle .. " (ID: " .. removeQuestId .. ")")
        end

        if partyQuestData[sender] then
            for targetKey, quests in pairs(partyQuestData[sender]) do
                local i = 1
                while i <= table.getn(quests) do
                    if quests[i].quest == removeQuestTitle then
                        table.remove(quests, i)
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Removed from " .. targetKey)
                        end
                    else
                        i = i + 1
                    end
                end

                if table.getn(quests) == 0 then
                    partyQuestData[sender][targetKey] = nil
                end
            end
        end

        return
    end

    -- Handle old format for backwards compatibility (REMOVE:targetKey:questTitle)
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

    if string.sub(message, 1, 3) == "V1|" then
        local batch = string.sub(message, 4)

        if debugMode then
            print("|cff33ffccpfQuest-epoch:|r RECEIVE V1 batch from " .. sender .. " (" .. string.len(message) .. " chars)")
        end

        local entries = {}
        for entry in string.gmatch(batch, "([^;]+)") do
            table.insert(entries, entry)
        end

        for _, entry in ipairs(entries) do
            -- Parse: UxxxQyyy:cc:tt or OxxxQyyy:cc:tt or IxxxQyyy:cc:tt
            local targetType, targetId, questId, current, total =
                string.match(entry, "^([UIO])(%d+)Q(%d+):(%d+):(%d+)$")

            if targetType and targetId and questId and current and total then
                targetId = tonumber(targetId)
                questId = tonumber(questId)
                current = tonumber(current)
                total = tonumber(total)

                local questTitle = nil
                local objectiveText = nil
                if pfDB and pfDB["quests"] and pfDB["quests"]["enUS"] and pfDB["quests"]["enUS"][questId] then
                    questTitle = pfDB["quests"]["enUS"][questId]["T"]

                    for qid = 1, GetNumQuestLogEntries() do
                        local logTitle = pfQuestCompat.GetQuestLogTitle(qid)
                        if logTitle == questTitle then
                            local numObjectives = GetNumQuestLeaderBoards(qid)
                            for i = 1, numObjectives do
                                local text = GetQuestLogLeaderBoard(i, qid)
                                if text then
                                    local objName, curr, tot = string.match(text, "(.*):%s*(%d+)%s*/%s*(%d+)")
                                    if objName then
                                        objName = string.gsub(objName, "^%s*(.-)%s*$", "%1")
                                        if tonumber(tot) == total then
                                            objectiveText = objName
                                            break
                                        end
                                    end
                                end
                            end
                            break
                        end
                    end

                    if not objectiveText then
                        objectiveText = "Quest Objective"
                    end
                end

                if targetType == "I" then
                    if pfDB and pfDB["items"] and pfDB["items"]["data"] and pfDB["items"]["data"][targetId] then
                        local itemData = pfDB["items"]["data"][targetId]

                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Expanding item quest - Item ID: " .. targetId)
                        end

                        if itemData["U"] then
                            local npcCount = 0
                            for unitId, dropRate in pairs(itemData["U"]) do
                                if pfDB["units"] and pfDB["units"]["enUS"] and pfDB["units"]["enUS"][unitId] then
                                    local npcName = pfDB["units"]["enUS"][unitId]

                                    if not partyQuestData[sender] then
                                        partyQuestData[sender] = {}
                                    end

                                    if not partyQuestData[sender][npcName] then
                                        partyQuestData[sender][npcName] = {}
                                    end

                                    local found = false
                                    for i, data in ipairs(partyQuestData[sender][npcName]) do
                                        if data.quest == questTitle then
                                            partyQuestData[sender][npcName][i].objective = objectiveText
                                            partyQuestData[sender][npcName][i].current = current
                                            partyQuestData[sender][npcName][i].total = total
                                            partyQuestData[sender][npcName][i].lastUpdate = GetTime()
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(partyQuestData[sender][npcName], {
                                            quest = questTitle,
                                            objective = objectiveText,
                                            current = current,
                                            total = total,
                                            lastUpdate = GetTime()
                                        })
                                    end

                                    npcCount = npcCount + 1
                                end
                            end

                            if debugMode then
                                print("|cff33ffccpfQuest-epoch:|r   Expanded to " .. npcCount .. " NPCs for item " .. targetId)
                            end
                        end

                        if itemData["O"] then
                            for objectId, dropRate in pairs(itemData["O"]) do
                                if pfDB["objects"] and pfDB["objects"]["enUS"] and pfDB["objects"]["enUS"][objectId] then
                                    local objName = pfDB["objects"]["enUS"][objectId]

                                    if not partyQuestData[sender] then
                                        partyQuestData[sender] = {}
                                    end

                                    if not partyQuestData[sender][objName] then
                                        partyQuestData[sender][objName] = {}
                                    end

                                    local found = false
                                    for i, data in ipairs(partyQuestData[sender][objName]) do
                                        if data.quest == questTitle then
                                            partyQuestData[sender][objName][i].objective = objectiveText
                                            partyQuestData[sender][objName][i].current = current
                                            partyQuestData[sender][objName][i].total = total
                                            partyQuestData[sender][objName][i].lastUpdate = GetTime()
                                            found = true
                                            break
                                        end
                                    end

                                    if not found then
                                        table.insert(partyQuestData[sender][objName], {
                                            quest = questTitle,
                                            objective = objectiveText,
                                            current = current,
                                            total = total,
                                            lastUpdate = GetTime()
                                        })
                                    end
                                end
                            end
                        end
                    else
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Failed to expand item quest - Item ID " .. targetId .. " not found in database")
                        end
                    end
                elseif targetType == "U" then
                    local targetName = nil
                    if pfDB and pfDB["units"] and pfDB["units"]["enUS"] then
                        targetName = pfDB["units"]["enUS"][targetId]
                    end

                    if targetName and questTitle then
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Parsed: U" .. targetId .. "Q" .. questId .. " -> " .. targetName .. ": " .. questTitle .. " (" .. current .. "/" .. total .. ")")
                        end

                        if not partyQuestData[sender] then
                            partyQuestData[sender] = {}
                        end

                        if not partyQuestData[sender][targetName] then
                            partyQuestData[sender][targetName] = {}
                        end

                        local found = false
                        for i, data in ipairs(partyQuestData[sender][targetName]) do
                            if data.quest == questTitle then
                                partyQuestData[sender][targetName][i].objective = objectiveText
                                partyQuestData[sender][targetName][i].current = current
                                partyQuestData[sender][targetName][i].total = total
                                partyQuestData[sender][targetName][i].lastUpdate = GetTime()
                                found = true
                                break
                            end
                        end

                        if not found then
                            table.insert(partyQuestData[sender][targetName], {
                                quest = questTitle,
                                objective = objectiveText,
                                current = current,
                                total = total,
                                lastUpdate = GetTime()
                            })
                        end
                    else
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Failed to resolve: U" .. targetId .. "Q" .. questId)
                        end
                    end
                elseif targetType == "O" then
                    local targetName = nil
                    if pfDB and pfDB["objects"] and pfDB["objects"]["enUS"] then
                        targetName = pfDB["objects"]["enUS"][targetId]
                    end

                    if targetName and questTitle then
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Parsed: O" .. targetId .. "Q" .. questId .. " -> " .. targetName .. ": " .. questTitle .. " (" .. current .. "/" .. total .. ")")
                        end

                        if not partyQuestData[sender] then
                            partyQuestData[sender] = {}
                        end

                        if not partyQuestData[sender][targetName] then
                            partyQuestData[sender][targetName] = {}
                        end

                        local found = false
                        for i, data in ipairs(partyQuestData[sender][targetName]) do
                            if data.quest == questTitle then
                                partyQuestData[sender][targetName][i].objective = objectiveText
                                partyQuestData[sender][targetName][i].current = current
                                partyQuestData[sender][targetName][i].total = total
                                partyQuestData[sender][targetName][i].lastUpdate = GetTime()
                                found = true
                                break
                            end
                        end

                        if not found then
                            table.insert(partyQuestData[sender][targetName], {
                                quest = questTitle,
                                objective = objectiveText,
                                current = current,
                                total = total,
                                lastUpdate = GetTime()
                            })
                        end
                    else
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r   Failed to resolve: O" .. targetId .. "Q" .. questId)
                        end
                    end
                end
            else
                if debugMode then
                    print("|cff33ffccpfQuest-epoch:|r   Failed to parse entry: " .. entry)
                end
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

    return {1.0, 1.0, 1.0}
end

local function HookGameTooltip()
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        local unitName, unit = self:GetUnit()
        if not unitName or not unit then return end
        if UnitIsPlayer(unit) then return end

        local inParty = GetNumPartyMembers() > 0
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

        local inParty = GetNumPartyMembers() > 0
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
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = arg1, arg2, arg3, arg4
        if prefix == "pfqe" then
            ProcessQuestData(sender, message)
        elseif prefix == "PFQUEST_SYNC_REQUEST" then
            if GetNumPartyMembers() > 0 and sender ~= UnitName("player") then
                if debugMode then
                    print("|cff33ffccpfQuest-epoch:|r Received sync request from " .. sender .. ", rebuilding and broadcasting current data")
                end
                RebuildQuestMappings()
                ShareQuestData(true)
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        CleanupPartyData()
        if GetNumPartyMembers() > 0 then
            RebuildQuestMappings()
            SendAddonMessage("PFQUEST_SYNC_REQUEST", "1", "PARTY")
            ShareQuestData(true)
        end
    elseif event == "QUEST_LOG_UPDATE" then
        if GetNumPartyMembers() > 0 then
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

    return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("ADDON_LOADED")
configExtenderFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "pfQuest-epoch" then
        InitializeConfig()

        HookGameTooltip()

        if GetNumPartyMembers() > 0 then
            RebuildQuestMappings()
            local channel = "PARTY"
            if debugMode then
                print("|cff33ffccpfQuest-epoch:|r Addon loaded, rebuilding and requesting sync from " .. channel)
            end
            SendAddonMessage("PFQUEST_SYNC_REQUEST", "1", channel)
            ShareQuestData(true)
        end

        local timer = 0
        local rebuildRetries = 0
        self:SetScript("OnUpdate", function()
            timer = timer + 1

            if rebuildRetries < 50 and (not pfDB or not pfDB["quests"] or not pfDB["quests"]["data"]) then
                if timer % 5 == 0 then
                    rebuildRetries = rebuildRetries + 1
                    if pfDB and pfDB["quests"] and pfDB["quests"]["data"] then
                        if debugMode then
                            print("|cff33ffccpfQuest-epoch:|r pfDB now available, rebuilding quest mappings")
                        end
                        RebuildQuestMappings()
                        if GetNumPartyMembers() > 0 then
                            SendAddonMessage("PFQUEST_SYNC_REQUEST", "1", "PARTY")
                            ShareQuestData(true)
                        end
                    end
                end
            end

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

SLASH_PFQUESTDEBUG1 = "/pfqd"
SlashCmdList["PFQUESTDEBUG"] = function(msg)
    print("|cff33ffccpfQuest-epoch Debug:|r")
    print("=== Addon Status ===")
    print("pfQuest loaded: " .. tostring(IsAddOnLoaded("pfQuest")))
    print("pfQuest-epoch loaded: " .. tostring(IsAddOnLoaded("pfQuest-epoch")))
    print("pfDB exists: " .. tostring(pfDB ~= nil))
    if pfDB then
        print("  pfDB.quests exists: " .. tostring(pfDB.quests ~= nil))
        if pfDB.quests then
            print("  pfDB.quests.data exists: " .. tostring(pfDB.quests.data ~= nil))
        end
    end
    print("pfQuestCompat exists: " .. tostring(pfQuestCompat ~= nil))
    print("pfMap exists: " .. tostring(pfMap ~= nil))

    print("=== Party Status ===")
    print("Party members: " .. GetNumPartyMembers())
    print("Feature enabled: " .. tostring(pfQuest_config and pfQuest_config["epochShowPartyProgress"] == "1"))

    print("=== Quest Data ===")
    local count = 0
    for _ in pairs(myQuestMappings) do count = count + 1 end
    print("myQuestMappings targets: " .. count)

    for targetKey, quests in pairs(myQuestMappings) do
        print("  |cffffcc00Target:|r " .. targetKey)
        for _, data in ipairs(quests) do
            print("    - " .. data.quest .. ": " .. data.objective .. " (" .. data.current .. "/" .. data.total .. ")")
        end
    end

    local partyCount = 0
    for _ in pairs(partyQuestData) do partyCount = partyCount + 1 end
    print("partyQuestData players: " .. partyCount)

    for playerName, targets in pairs(partyQuestData) do
        print("  |cff00ff00Player:|r " .. playerName)
        for targetKey, quests in pairs(targets) do
            print("    |cffffcc00Target:|r " .. targetKey)
            for _, data in ipairs(quests) do
                print("      - " .. data.quest .. ": " .. data.objective .. " (" .. data.current .. "/" .. data.total .. ")")
            end
        end
    end

    if count == 0 and partyCount == 0 then
        print("|cffff0000No quest data found!|r Try killing a quest mob or running /pfqd after joining a party.")
    end
end

SLASH_PFQUEREBUILD1 = "/pfqrebuild"
SlashCmdList["PFQUEREBUILD"] = function(msg)
    print("|cff33ffccpfQuest-epoch:|r Manually triggering RebuildQuestMappings...")
    RebuildQuestMappings()
    if GetNumPartyMembers() > 0 then
        print("|cff33ffccpfQuest-epoch:|r Sending sync request and sharing data...")
        SendAddonMessage("PFQUEST_SYNC_REQUEST", "1", "PARTY")
        ShareQuestData(true)
    end
    print("|cff33ffccpfQuest-epoch:|r Done! Run /pfqd to see results.")
end

SLASH_PFQUESTFIND1 = "/pfqfind"
SlashCmdList["PFQUESTFIND"] = function(msg)
    print("|cff33ffccpfQuest-epoch:|r Checking pfDB structure...")

    if not pfDB then
        print("  |cffff0000pfDB does not exist!|r")
        return
    end

    print("  pfDB exists: |cff00ff00YES|r")
    print("  pfDB contains:")
    for k, v in pairs(pfDB) do
        if type(v) == "table" then
            local count = 0
            for _ in pairs(v) do
                count = count + 1
                if count > 1000 then break end
            end
            if k == "data" then
                print("    - " .. k .. " (table with " .. count .. "+ entries)")
            else
                print("    - " .. k .. " (table)")
            end
        end
    end
end

SLASH_PFQUESTAPI1 = "/pfqapi"
SlashCmdList["PFQUESTAPI"] = function(msg)
    print("|cff33ffccpfQuest-epoch:|r Checking pfQuest API...")
    if pfDB and pfDB.quests and pfDB.quests.data and pfDB.quests.data[7] then
        print("\nQuest ID 7 full structure:")
        for k, v in pairs(pfDB.quests.data[7]) do
            if type(v) == "table" then
                print("  [\"" .. tostring(k) .. "\"] = {")
                for k2, v2 in pairs(v) do
                    print("    [\"" .. tostring(k2) .. "\"] = " .. tostring(v2))
                end
                print("  }")
            else
                print("  [\"" .. tostring(k) .. "\"] = " .. tostring(v))
            end
        end
    end

    print("\npfDB.quests keys:")
    if pfDB and pfDB.quests then
        for k, v in pairs(pfDB.quests) do
            print("  " .. k .. " (" .. type(v) .. ")")
        end
    end
end