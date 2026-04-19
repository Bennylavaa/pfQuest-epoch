local uiRebuilt = false

local function RebuildConfigUI()
    if uiRebuilt then
        return
    end

    if not pfQuestConfig or not pfQuestConfig.CreateConfigEntries then
        return false
    end

    for i = 1, 50 do
        local frame = getglobal("pfQuestConfig" .. i)
        if frame then
            frame:Hide()
            frame:SetParent(nil)
            setglobal("pfQuestConfig" .. i, nil)
        else
            break
        end
    end

    pfQuestConfig.vpos = 40
    pfQuestConfig:CreateConfigEntries(pfQuest_defconfig)

    uiRebuilt = true
    return true
end

local function CreateSearchBar()
    if pfQuestConfig.searchBar then
        return
    end

    -- Create backdrop frame
    pfQuestConfig.searchBackdrop = CreateFrame("Frame", nil, pfQuestConfig)
    pfQuestConfig.searchBackdrop:SetHeight(24)
    pfQuestConfig.searchBackdrop:SetWidth(180)
    pfQuestConfig.searchBackdrop:SetPoint("BOTTOM", pfQuestConfig, "BOTTOM", 0, 10)

    -- Dark backdrop styling
    pfQuestConfig.searchBackdrop:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    pfQuestConfig.searchBackdrop:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    pfQuestConfig.searchBackdrop:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Create edit box
    pfQuestConfig.searchBar = CreateFrame("EditBox", "pfQuestConfigSearch", pfQuestConfig.searchBackdrop)
    pfQuestConfig.searchBar:SetAllPoints(pfQuestConfig.searchBackdrop)
    pfQuestConfig.searchBar:SetAutoFocus(false)
    pfQuestConfig.searchBar:SetTextInsets(8, 8, 0, 0)
    pfQuestConfig.searchBar:SetFontObject(GameFontNormalSmall)

    -- Placeholder text
    pfQuestConfig.searchBar.placeholder = pfQuestConfig.searchBar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pfQuestConfig.searchBar.placeholder:SetPoint("LEFT", pfQuestConfig.searchBar, "LEFT", 8, 0)
    pfQuestConfig.searchBar.placeholder:SetText("Search...")
    pfQuestConfig.searchBar.placeholder:SetJustifyH("LEFT")
    pfQuestConfig.searchBar.placeholder:Show()

    pfQuestConfig.searchBar:SetScript("OnEditFocusGained", function(self)
        self.placeholder:Hide()
    end)

    pfQuestConfig.searchBar:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self.placeholder:Show()
        end
    end)

    pfQuestConfig.searchBar:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        self.placeholder:Show()
        -- Reset all frames to visible
        for i = 1, 50 do
            local frame = getglobal("pfQuestConfig" .. i)
            if frame then
                frame:Show()
            else
                break
            end
        end
    end)

    -- Click outside to clear search (hook into existing OnMouseDown)
    local originalOnMouseDown = pfQuestConfig:GetScript("OnMouseDown")
    pfQuestConfig:SetScript("OnMouseDown", function(self, button)
        -- Call original handler for window dragging
        if originalOnMouseDown then
            originalOnMouseDown(self, button)
        end

        -- Clear search on click outside
        if button == "LeftButton" or button == "RightButton" then
            if not pfQuestConfig.searchBar:IsMouseOver() then
                if pfQuestConfig.searchBar:GetText() ~= "" then
                    pfQuestConfig.searchBar:SetText("")
                    pfQuestConfig.searchBar:ClearFocus()
                    pfQuestConfig.searchBar.placeholder:Show()
                    -- Reset all frames to visible
                    for i = 1, 50 do
                        local frame = getglobal("pfQuestConfig" .. i)
                        if frame then
                            frame:Show()
                        else
                            break
                        end
                    end
                end
            end
        end
    end)

    pfQuestConfig.searchBar:SetScript("OnTextChanged", function(self)
        local searchText = string.lower(self:GetText())

        -- Simple hide/show filtering
        for i = 1, 50 do
            local frame = getglobal("pfQuestConfig" .. i)
            if frame then
                if frame.caption then
                    local captionText = string.lower(frame.caption:GetText() or "")
                    if searchText == "" or string.find(captionText, searchText, 1, true) then
                        frame:Show()
                    else
                        frame:Hide()
                    end
                end
            else
                break
            end
        end
    end)
end

local configFrame = CreateFrame("Frame")
configFrame:RegisterEvent("VARIABLES_LOADED")
configFrame:SetScript("OnEvent", function(self, event)
    if event == "VARIABLES_LOADED" then
        local timer = 0
        self:SetScript("OnUpdate", function()
            timer = timer + 1

            if timer > 10 then
                if pfQuestConfig then
                    -- Rebuild UI on first show to include epoch entries
                    local originalOnShow = pfQuestConfig:GetScript("OnShow")
                    pfQuestConfig:SetScript("OnShow", function()
                        if originalOnShow then
                            originalOnShow()
                        end
                        RebuildConfigUI()
                        CreateSearchBar()
                    end)

                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                elseif timer > 300 then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Search bar creation failed")
                end
            end
        end)
    end
end)
