local ENTRY_HEIGHT = 22
local NUM_COLUMNS = 3
local HEADER_INDENT = 10
local ITEM_INDENT = 20

local configframes = {}

local function CreateEntryFrame(data)
    local frame = CreateFrame("Frame", nil, pfQuestConfig)

    frame.caption = frame:CreateFontString(nil, "LOW", "GameFontWhite")
    frame.caption:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
    frame.caption:SetPoint("LEFT", ITEM_INDENT, 0)
    frame.caption:SetJustifyH("LEFT")
    frame.caption:SetText(data.text)

    if data.type == "header" then
        frame.caption:ClearAllPoints()
        frame.caption:SetPoint("LEFT", HEADER_INDENT, 0)
        frame.caption:SetTextColor(.3, 1, .8)
        frame.caption:SetFont(pfUI.font_default, pfUI_config.global.font_size + 2, "OUTLINE")
    elseif data.type == "checkbox" then
        frame.input = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        frame.input:SetNormalTexture("")
        frame.input:SetPushedTexture("")
        frame.input:SetHighlightTexture("")
        pfUI.api.CreateBackdrop(frame.input, nil, true)

        frame.input:SetWidth(16)
        frame.input:SetHeight(16)
        frame.input:SetPoint("RIGHT", -ITEM_INDENT, 0)

        frame.input.config = data.config
        if pfQuest_config[data.config] == "1" then
            frame.input:SetChecked()
        end

        frame.input:SetScript("OnClick", function()
            if this:GetChecked() then
                pfQuest_config[this.config] = "1"
            else
                pfQuest_config[this.config] = "0"
            end

            pfQuest:ResetAll()
        end)
    elseif data.type == "text" then
        frame.input = CreateFrame("EditBox", nil, frame)
        frame.input:SetTextColor(.2, 1, .8, 1)
        frame.input:SetJustifyH("RIGHT")
        frame.input:SetTextInsets(5, 5, 5, 5)
        frame.input:SetWidth(32)
        frame.input:SetHeight(16)
        frame.input:SetPoint("RIGHT", -ITEM_INDENT, 0)
        frame.input:SetFontObject(GameFontNormal)
        frame.input:SetAutoFocus(false)
        frame.input:SetScript("OnEscapePressed", function(self)
            this:ClearFocus()
        end)

        frame.input.config = data.config
        frame.input:SetText(pfQuest_config[data.config])

        frame.input:SetScript("OnTextChanged", function(self)
            pfQuest_config[this.config] = this:GetText()
        end)

        pfUI.api.CreateBackdrop(frame.input, nil, true)
    elseif data.type == "button" and data.func then
        frame.input = CreateFrame("Button", nil, frame)
        frame.input:SetWidth(32)
        frame.input:SetHeight(16)
        frame.input:SetPoint("RIGHT", -ITEM_INDENT, 0)
        frame.input:SetScript("OnClick", data.func)
        frame.input.text = frame.input:CreateFontString(nil, "LOW", "GameFontWhite")
        frame.input.text:SetAllPoints(frame.input)
        frame.input.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
        frame.input.text:SetText("OK")
        pfUI.api.SkinButton(frame.input)
    end

    if frame.input and pfUI.api.emulated then
        frame.input:SetWidth(frame.input:GetWidth() / .6)
        frame.input:SetHeight(frame.input:GetHeight() / .6)
        frame.input:SetScale(.8)
        if frame.input.SetTextInsets then
            frame.input:SetTextInsets(8, 8, 8, 8)
        end
    end

    return frame
end

local function CreateConfigEntries(self, config)
    for key in pairs(configframes) do
        configframes[key] = nil
    end

    local maxtext, ordered = 130, {}
    for _, data in pairs(config) do
        if data.type then
            local frame = CreateEntryFrame(data)
            configframes[data.text] = frame
            maxtext = math.max(maxtext, frame.caption:GetStringWidth())
            table.insert(ordered, { frame = frame, data = data })
        end
    end

    local width = maxtext + 100

    local sections = {}
    local current
    for _, entry in ipairs(ordered) do
        if entry.data.type == "header" or not current then
            current = { entries = {}, rows = 0 }
            table.insert(sections, current)
        end
        table.insert(current.entries, entry)
        current.rows = current.rows + 1
    end

    local byIndex = {}
    for i, section in ipairs(sections) do
        section.index = i
        table.insert(byIndex, section)
    end
    table.sort(byIndex, function(a, b) return a.rows > b.rows end)

    local columnRows, columnSections = {}, {}
    for c = 1, NUM_COLUMNS do
        columnRows[c], columnSections[c] = 0, {}
    end

    for _, section in ipairs(byIndex) do
        local best = 1
        for c = 2, NUM_COLUMNS do
            local gap = columnRows[c] > 0 and 1 or 0
            local bestGap = columnRows[best] > 0 and 1 or 0
            if columnRows[c] + gap < columnRows[best] + bestGap then
                best = c
            end
        end
        local gap = columnRows[best] > 0 and 1 or 0
        columnRows[best] = columnRows[best] + gap + section.rows
        table.insert(columnSections[best], section)
    end

    for c = 1, NUM_COLUMNS do
        table.sort(columnSections[c], function(a, b) return a.index < b.index end)
    end

    local maxw, maxh = 0, 0
    for c = 1, NUM_COLUMNS do
        local row = 0
        for _, section in ipairs(columnSections[c]) do
            if row > 0 then
                row = row + 1 -- blank line before a new section
            end
            for _, entry in ipairs(section.entries) do
                row = row + 1
                local spacer = (c - 1) * 20
                local x, y = (c - 1) * width, -(row - 1) * ENTRY_HEIGHT
                entry.frame:SetWidth(width)
                entry.frame:SetHeight(ENTRY_HEIGHT)
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", pfQuestConfig, "TOPLEFT", x + spacer + 10, y - 40)
            end
        end
        if row > 0 then
            maxw = math.max(maxw, c)
        end
        maxh = math.max(maxh, row)
    end

    local spacer = (maxw - 1) * 20
    pfQuestConfig:SetWidth(maxw * width + spacer + 20)
    pfQuestConfig:SetHeight(maxh * ENTRY_HEIGHT + 100)
end

local function UpdateConfigEntries(self)
    for _, data in pairs(pfQuest_defconfig) do
        if data.type and configframes[data.text] then
            if data.type == "checkbox" then
                configframes[data.text].input:SetChecked((pfQuest_config[data.config] == "1" and true or nil))
            elseif data.type == "text" then
                configframes[data.text].input:SetText(pfQuest_config[data.config])
            end
        end
    end
end

pfQuestConfig.CreateConfigEntries = CreateConfigEntries
pfQuestConfig.UpdateConfigEntries = UpdateConfigEntries

local function RebuildConfigUI()
    if not pfQuestConfig or not pfQuestConfig.CreateConfigEntries then
        return false
    end

    for i = 1, 200 do
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

    pfQuestConfig:SetScale(math.min(1.0, 0.6 / UIParent:GetEffectiveScale()))

    return true
end

local function OnConfigUIRebuilt()
    ResizeArrow()
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
                    OnConfigUIRebuilt()
                elseif timer > 300 then
                    self:SetScript("OnUpdate", nil)
                    self:UnregisterAllEvents()
                    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpf|cffffffffQuest |cffcccccc[Epoch]|r: Config UI rebuild failed")
                end
            end
        end)
    end
end)
