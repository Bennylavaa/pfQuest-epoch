local function ExtendPfQuestConfig()
    -- Check if already added (prevents duplicates)
    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "epochAutoAcceptQuests" then
            return true
        end
    end

    table.insert(
        pfQuest_defconfig,
        {
            text = "|cff33ffccQuest automation|r",
            type = "header"
        }
    )


    table.insert(pfQuest_defconfig,
    {
        text = "Automatically accept and complete quests",
        default = "0",
        type = "checkbox",
        config = "epochAutoQuests"
    })

    table.insert(pfQuest_defconfig,
    {
        text = "Automate runecloth donations",
        default = "0",
        type = "checkbox",
        config = "epochAutomateRuneclothDonations"
    })

    table.insert(pfQuest_defconfig,
    {
        text = "Skip accepting commission quests",
        default = "0",
        type = "checkbox",
        config = "epochSkipCommissionQuests"
    })


    if not pfQuest_config["epochAutoQuests"] then
        pfQuest_config["epochAutoQuests"] = "0"
    end

    if not pfQuest_config["epochSkipCommissionQuests"] then
        pfQuest_config["epochSkipCommissionQuests"] = "1"
    end

    if not pfQuest_config["epochAutomateRuneclothDonations"] then
        pfQuest_config["epochAutomateRuneclothDonations"] = "0"
    end

    return true
end

local configExtenderFrame = CreateFrame("Frame")
configExtenderFrame:RegisterEvent("VARIABLES_LOADED")
configExtenderFrame:SetScript("OnEvent", function()
    ExtendPfQuestConfig()
end)

local questLogFrame = CreateFrame("Frame")
questLogFrame:RegisterEvent("QUEST_DETAIL")
questLogFrame:RegisterEvent('GOSSIP_SHOW')
questLogFrame:RegisterEvent('QUEST_COMPLETE')
questLogFrame:RegisterEvent('QUEST_FINISHED')
questLogFrame:RegisterEvent('QUEST_GREETING')
questLogFrame:RegisterEvent('QUEST_LOG_UPDATE')
questLogFrame:RegisterEvent('QUEST_PROGRESS')

local function CompleteQuestWithRewards()
    if GetNumQuestChoices() == 0 then
        GetQuestReward()
    end
end

questLogFrame:SetScript("OnEvent", function(self, event, ...)
    if pfQuest_config["epochAutoQuests"] == "0" then
        return
    end

    if IsShiftKeyDown() then
        return
    end

    if event == "QUEST_PROGRESS" then
        if IsQuestCompletable() then
            CompleteQuest()
        end
    end

    if event == "QUEST_COMPLETE" then
        GetQuestReward(QuestFrameRewardPanel.itemChoice)
    end
    
    if event == "QUEST_GREETING" then
        local numActiveQuests = GetNumActiveQuests()
        for i=1, numActiveQuests do
            local title, completed = GetActiveTitle(i)
            if completed then
                SelectActiveQuest(i)
                CompleteQuestWithRewards()
            end
        end

        -- The quest dialog closes when the quest gets accepted so no need to do this in a loop
        if GetNumAvailableQuests() >= 1 then
            SelectAvailableQuest(1)
        end
    end

    if event == "QUEST_DETAIL" then
        AcceptQuest()
    end

    if event == "GOSSIP_SHOW" then
        local numAvailable = GetNumGossipAvailableQuests()
        for i = 1, numAvailable do
            local title = GetGossipAvailableQuests(i)
            if string.find(title, "Commission") then
                if pfQuest_config["epochSkipCommissionQuests"] == "0" then
                    SelectGossipAvailableQuest(i)
                end
            else          
                SelectGossipAvailableQuest(1)
            end
        end

        local numGossipActiveQuests = GetNumGossipActiveQuests()
        for i = 1, numGossipActiveQuests do
            local activeQuests = { GetGossipActiveQuests() }
            if (activeQuests[i * 4] == 1) then
                SelectGossipActiveQuest(i)
                -- OnQuestCompleteEvent() Throws an error all of a sudden. Don't remember what this was for :D
            end
        end

        if pfQuest_config["epochAutomateRuneclothDonations"] == "1" and GetNumGossipActiveQuests() == 1 then
            local title = GetGossipActiveQuests(1)
            if string.find(title, "Additional Runecloth") then
                SelectGossipActiveQuest(1)
            end
        end
    end
end)
