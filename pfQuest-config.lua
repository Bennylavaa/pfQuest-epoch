local ENTRY_HEIGHT = 22
local NUM_COLUMNS = 2
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

-- Tab layout: every config section (started by a "header" entry) is placed on
-- one tab, matched by its header text. Sections added by other modules that 
-- are not listed here end up on the fallback tab, so nothing is lost.
local TABS = {
    { name = "General", headers = { "General", "Config Window", "User Data" } },
    { name = "Quests",  headers = { "Questing", "Quest Automation", "Announce" } },
    { name = "Map",     headers = { "Map & Minimap", "Continent Map", "Dungeon Maps", "Routes" } },
    { name = "Extras",  headers = { "Nameplates", "Rare Loot Panel" } },
}
-- tab number that receives any section whose header isn't listed in TABS
local FALLBACK_TAB = 4

-- single entries that other modules append without a header, mapped to the section
-- (by header text) they should be shown in
local ENTRY_SECTION = {
    epochShowPartyProgress = "Announce",
}

local SIDEBAR_WIDTH = 130 -- vertical tab list on the left
local TAB_HEIGHT = 32
local TAB_SPACING = 4
local CONTENT_LEFT = SIDEBAR_WIDTH + 20 -- options start right of the tab list
local CONTENT_TOP = 40    -- first entry row, below the title
local CONTENT_BOTTOM = 60 -- room for the buttons at the bottom of the window

local activeTab = 1
local tabButtons = {}
local tabLookup

local function NormalizeHeader(text)
    text = string.gsub(text or "", "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    return string.lower(text)
end

local function BuildTabLookup()
    tabLookup = {}
    for index, tab in ipairs(TABS) do
        for _, header in ipairs(tab.headers) do
            tabLookup[NormalizeHeader(header)] = index
            -- also match translated header captions
            local translated = pfQuest_Loc and pfQuest_Loc[header]
            if type(translated) == "string" then
                tabLookup[NormalizeHeader(translated)] = index
            end
        end
    end
end

local function SelectTab(index)
    activeTab = index

    for key, frame in pairs(configframes) do
        if frame.tab == index then frame:Show() else frame:Hide() end
    end

    for i, button in ipairs(tabButtons) do
        if i == index then
            button.text:SetTextColor(.3, 1, .8)
            button.underline:Show()
        else
            button.text:SetTextColor(1, 1, 1)
            button.underline:Hide()
        end
    end
end

local function GetTabButton(index)
    local button = tabButtons[index]
    if button then return button end

    button = CreateFrame("Button", nil, pfQuestConfig)
    button:SetHeight(TAB_HEIGHT)
    button.index = index

    button.text = button:CreateFontString(nil, "LOW", "GameFontWhite")
    button.text:SetPoint("LEFT", button, "LEFT", 14, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetFont(pfUI.font_default, pfUI_config.global.font_size + 1, "OUTLINE")

    -- marker bar on the left edge of the active tab
    button.underline = button:CreateTexture(nil, "OVERLAY")
    button.underline:SetWidth(3)
    button.underline:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.underline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button.underline:SetTexture(.3, 1, .8, 1)
    button.underline:Hide()

    pfUI.api.SkinButton(button)
    button:SetScript("OnClick", function()
        SelectTab(this.index)
    end)

    tabButtons[index] = button
    return button
end

-- distribute the sections of one tab over the columns, keeping the original order
local function LayoutTab(sections, width)
    local byIndex = {}
    for i, section in ipairs(sections) do
        section.index = i
        table.insert(byIndex, section)
    end
    table.sort(byIndex, function(a, b)
        if a.rows ~= b.rows then return a.rows > b.rows end
        return a.index < b.index
    end)

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

    local usedColumns, maxRows = 0, 0
    for c = 1, NUM_COLUMNS do
        local row = 0
        for _, section in ipairs(columnSections[c]) do
            if row > 0 then
                row = row + 1 -- blank line before a new section
            end
            for _, entry in ipairs(section.entries) do
                row = row + 1
                entry.x = (c - 1) * width + (c - 1) * 20 + CONTENT_LEFT
                entry.y = -(row - 1) * ENTRY_HEIGHT - CONTENT_TOP
            end
        end
        if row > 0 then
            usedColumns = math.max(usedColumns, c)
        end
        maxRows = math.max(maxRows, row)
    end

    return usedColumns, maxRows
end

local function CreateConfigEntries(self, config)
    for key in pairs(configframes) do
        configframes[key] = nil
    end

    if not tabLookup then BuildTabLookup() end

    local maxtext = 130
    local tabSections = {}
    for i = 1, table.getn(TABS) do tabSections[i] = {} end

    local current
    local sectionByHeader = {}
    local looseEntries = {}
    for _, data in pairs(config) do
        if data.type then
            local frame = CreateEntryFrame(data)
            configframes[data.text] = frame
            maxtext = math.max(maxtext, frame.caption:GetStringWidth())
            local entry = { frame = frame, data = data }

            local target
            if data.type == "header" then
                local tabIndex = tabLookup[NormalizeHeader(data.text)] or FALLBACK_TAB
                current = { entries = {}, rows = 0, tab = tabIndex }
                table.insert(tabSections[tabIndex], current)
                sectionByHeader[NormalizeHeader(data.text)] = current
                target = current
            elseif data.config and ENTRY_SECTION[data.config] then
                -- header-less entry that belongs into a specific section, placed below
                table.insert(looseEntries, entry)
            else
                if not current then
                    current = { entries = {}, rows = 0, tab = 1 }
                    table.insert(tabSections[1], current)
                end
                target = current
            end

            if target then
                frame.tab = target.tab
                table.insert(target.entries, entry)
                target.rows = target.rows + 1
            end
        end
    end

    for _, entry in ipairs(looseEntries) do
        local section = sectionByHeader[NormalizeHeader(ENTRY_SECTION[entry.data.config])]
        if not section then
            section = tabSections[1][1]
            if not section then
                section = { entries = {}, rows = 0, tab = 1 }
                table.insert(tabSections[1], section)
            end
        end
        entry.frame.tab = section.tab
        table.insert(section.entries, entry)
        section.rows = section.rows + 1
    end

    local width = maxtext + 100
    local maxCols, maxRows = 1, 0
    for tabIndex = 1, table.getn(TABS) do
        local cols, rows = LayoutTab(tabSections[tabIndex], width)
        maxCols = math.max(maxCols, cols)
        maxRows = math.max(maxRows, rows)
    end

    -- apply positions, every tab uses the same window size so it does not jump around
    for tabIndex = 1, table.getn(TABS) do
        for _, section in ipairs(tabSections[tabIndex]) do
            for _, entry in ipairs(section.entries) do
                entry.frame:SetWidth(width)
                entry.frame:SetHeight(ENTRY_HEIGHT)
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", pfQuestConfig, "TOPLEFT", entry.x, entry.y)
            end
        end
    end

    local numTabs = table.getn(TABS)
    local tabListHeight = numTabs * (TAB_HEIGHT + TAB_SPACING) - TAB_SPACING
    pfQuestConfig:SetWidth(CONTENT_LEFT + maxCols * width + (maxCols - 1) * 20 + 10)
    pfQuestConfig:SetHeight(math.max(maxRows * ENTRY_HEIGHT, tabListHeight) + CONTENT_TOP + CONTENT_BOTTOM)

    -- vertical tab list on the left
    for index, tab in ipairs(TABS) do
        local button = GetTabButton(index)
        button.text:SetText(tab.name)
        button:SetWidth(SIDEBAR_WIDTH - 10)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", pfQuestConfig, "TOPLEFT", 10, -CONTENT_TOP - (index - 1) * (TAB_HEIGHT + TAB_SPACING))
        button:Show()
    end

    -- thin separator between tab list and options
    if not pfQuestConfig.epochTabSeparator then
        pfQuestConfig.epochTabSeparator = pfQuestConfig:CreateTexture(nil, "OVERLAY")
        pfQuestConfig.epochTabSeparator:SetWidth(2)
        pfQuestConfig.epochTabSeparator:SetTexture(.3, 1, .8, .35)
    end
    pfQuestConfig.epochTabSeparator:ClearAllPoints()
    pfQuestConfig.epochTabSeparator:SetPoint("TOPLEFT", pfQuestConfig, "TOPLEFT", SIDEBAR_WIDTH + 5, -CONTENT_TOP)
    pfQuestConfig.epochTabSeparator:SetPoint("BOTTOMLEFT", pfQuestConfig, "BOTTOMLEFT", SIDEBAR_WIDTH + 5, CONTENT_BOTTOM)

    SelectTab(math.min(activeTab, numTabs))
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

local DEFAULT_CONFIG_SCALE = 0.6
local MIN_CONFIG_SCALE = 0.3
local MAX_CONFIG_SCALE = 1.5

local function ApplyConfigScale()
    if not pfQuestConfig then
        return
    end

    local target = tonumber(pfQuest_config and pfQuest_config.epochConfigScale) or DEFAULT_CONFIG_SCALE
    target = math.max(MIN_CONFIG_SCALE, math.min(MAX_CONFIG_SCALE, target))

    pfQuestConfig:SetScale(math.min(MAX_CONFIG_SCALE, target / UIParent:GetEffectiveScale()))
end

local function ExtendConfigScaleOption()
    if not pfQuest_defconfig then
        return
    end

    for _, entry in pairs(pfQuest_defconfig) do
        if entry.config == "epochConfigScale" then
            return
        end
    end

    table.insert(pfQuest_defconfig, {
        text = "|cff33ffccConfig Window|r",
        type = "header"
    })
    table.insert(pfQuest_defconfig, {
        text = "Config Window Scale",
        default = tostring(DEFAULT_CONFIG_SCALE),
        type = "text",
        config = "epochConfigScale"
    })

    pfQuest_config["epochConfigScale"] = pfQuest_config["epochConfigScale"] or tostring(DEFAULT_CONFIG_SCALE)
end

local function HookScaleInput()
    local frame = configframes["Config Window Scale"]
    if not frame or not frame.input then
        return
    end

    frame.input:SetScript("OnEnterPressed", function(self)
        this:ClearFocus()
        ApplyConfigScale()
    end)
    frame.input:SetScript("OnEditFocusLost", function(self)
        ApplyConfigScale()
    end)
end

local function RebuildConfigUI()
    if not pfQuestConfig or not pfQuestConfig.CreateConfigEntries then
        return false
    end

    ExtendConfigScaleOption()

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
    HookScaleInput()

    ApplyConfigScale()

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
