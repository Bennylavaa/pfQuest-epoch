local function RebuildConfigUI()
    if not pfQuestConfig or not pfQuestConfig.CreateConfigEntries then
        return false
    end

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

    return true
end

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("VARIABLES_LOADED")
configFrame:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        local timer = 0
        self:SetScript("OnUpdate", function()
            timer = timer + 1

            if timer > 10 then
                if RebuildConfigUI() then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                elseif timer > 300 then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Config UI rebuild failed")
                end
            end
        end)
    end
end)
