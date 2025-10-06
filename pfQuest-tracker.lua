-- multi api compat
local compat = pfQuestCompat

local fontsize = 12
local panelheight = 16
local entryheight = 20
local zoneheight = 18

local function HideTooltip()
    GameTooltip:Hide()
end

local function ShowTooltip()
    if this.tooltip then
        GameTooltip:ClearLines()
        GameTooltip_SetDefaultAnchor(GameTooltip, this)
        if this.text then
            GameTooltip:SetText(this.text:GetText())
            GameTooltip:SetText(this.text:GetText(), this.text:GetTextColor())
        else
            GameTooltip:SetText("|cff33ffccpf|cffffffffQuest")
        end

        if this.node and this.node.questid then
            if
                pfDB["quests"] and pfDB["quests"]["loc"] and pfDB["quests"]["loc"][this.node.questid] and
                    pfDB["quests"]["loc"][this.node.questid]["O"]
             then
                GameTooltip:AddLine(
                    pfDatabase:FormatQuestText(pfDB["quests"]["loc"][this.node.questid]["O"]),
                    1,
                    1,
                    1,
                    1
                )
                GameTooltip:AddLine(" ")
            end

            local qlogid = pfQuest.questlog[this.node.questid] and pfQuest.questlog[this.node.questid].qlogid
            if qlogid then
                local objectives = GetNumQuestLeaderBoards(qlogid)
                if objectives and objectives > 0 then
                    for i = 1, objectives, 1 do
                        local text, _, done = GetQuestLogLeaderBoard(i, qlogid)
                        local _, _, obj, cur, req =
                            strfind(gsub(text, "\239\188\154", ":"), "(.*):%s*([%d]+)%s*/%s*([%d]+)")
                        if done then
                            GameTooltip:AddLine(" - " .. text, 0, 1, 0)
                        elseif cur and req then
                            local r, g, b = pfMap.tooltip:GetColor(cur, req)
                            GameTooltip:AddLine(" - " .. text, r, g, b)
                        else
                            GameTooltip:AddLine(" - " .. text, 1, 0, 0)
                        end
                    end
                    GameTooltip:AddLine(" ")
                end
            end
        end

        GameTooltip:AddLine(this.tooltip, 1, 1, 1)
        GameTooltip:Show()
    end
end

local expand_states = {}
local zone_expand_states = {}

tracker = CreateFrame("Frame", "pfQuestMapTracker", UIParent)
tracker:Hide()
tracker:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
tracker:SetWidth(200)
tracker:SetMovable(true)
tracker:EnableMouse(true)
tracker:SetClampedToScreen(true)
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")
tracker:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED")
tracker:RegisterEvent("ACHIEVEMENT_EARNED")
tracker:SetScript(
    "OnEvent",
    function()
        -- update font sizes according to config
        fontsize = tonumber(pfQuest_config["trackerfontsize"]) or 12
        entryheight = ceil(fontsize * 1.6)
        zoneheight = ceil(fontsize * 1.5)

        -- Initialize scroll settings if they don't exist
        if not pfQuest_config["trackerfixedheight"] then
            pfQuest_config["trackerfixedheight"] = "0"
        end
        if not pfQuest_config["trackerfixedwidth"] then
            pfQuest_config["trackerfixedwidth"] = "0"
        end
        if not pfQuest_config["trackerheight"] then
            pfQuest_config["trackerheight"] = "400"
        end
        if not pfQuest_config["trackerwidth"] then
            pfQuest_config["trackerwidth"] = "250"
        end
        if not pfQuest_config["trackershowzones"] then
            pfQuest_config["trackershowzones"] = "1"
        end

        -- restore tracker state
        if pfQuest_config["showtracker"] and pfQuest_config["showtracker"] == "0" then
            this:Hide()
        else
            this:Show()
        end
    end
)

tracker:SetScript(
    "OnMouseDown",
    function()
        if not pfQuest_config.lock then
            this:StartMoving()
        end
    end
)

tracker:SetScript(
    "OnMouseUp",
    function()
        this:StopMovingOrSizing()
        local anchor, x, y = pfUI.api.ConvertFrameAnchor(this, pfUI.api.GetBestAnchor(this))
        this:ClearAllPoints()
        this:SetPoint(anchor, x, y)

        -- save position
        pfQuest_config.trackerpos = {anchor, x, y}
    end
)

tracker:SetScript(
    "OnUpdate",
    function()
        if WorldMapFrame:IsShown() then
            if this.strata ~= "FULLSCREEN_DIALOG" then
                this:SetFrameStrata("FULLSCREEN_DIALOG")
                this.strata = "FULLSCREEN_DIALOG"
            end
        else
            if this.strata ~= "BACKGROUND" then
                this:SetFrameStrata("BACKGROUND")
                this.strata = "BACKGROUND"
            end
        end

        local alpha = this.backdrop:GetAlpha()
        local content = tracker.buttons[1] and not tracker.buttons[1].empty and true or nil
        local goal = (content and not MouseIsOver(this)) and 0 or not content and not MouseIsOver(this) and 0.5 or 1
        if ceil(alpha * 10) ~= ceil(goal * 10) then
            this.backdrop:SetAlpha(alpha + ((goal - alpha) > 0 and .1 or (goal - alpha) < 0 and -.1 or 0))
        end

        if pfQuestCompat.QuestWatchFrame:IsShown() then
            pfQuestCompat.QuestWatchFrame:Hide()
        end
    end
)

tracker:SetScript(
    "OnShow",
    function()
        pfQuest_config["showtracker"] = "1"

        -- load tracker position if exists
        if pfQuest_config.trackerpos then
            this:ClearAllPoints()
            this:SetPoint(unpack(pfQuest_config.trackerpos))
        end
    end
)

tracker:SetScript(
    "OnHide",
    function()
        pfQuest_config["showtracker"] = "0"
    end
)

tracker.buttons = {}
tracker.zoneheaders = {}
tracker.questitems = {}
tracker.numQuestItems = 0
tracker.mode = "QUEST_TRACKING"

tracker.backdrop = CreateFrame("Frame", nil, tracker)
tracker.backdrop:SetAllPoints(tracker)
tracker.backdrop.bg = tracker.backdrop:CreateTexture(nil, "BACKGROUND")
tracker.backdrop.bg:SetTexture(0, 0, 0, .2)
tracker.backdrop.bg:SetAllPoints()

-- Create scroll frame
tracker.scrollframe = CreateFrame("ScrollFrame", "pfQuestTrackerScroll", tracker)
tracker.scrollframe:SetPoint("TOPLEFT", 0, -panelheight)
tracker.scrollframe:SetPoint("BOTTOMRIGHT", 0, 0)

-- Create scroll child
tracker.scrollchild = CreateFrame("Frame", nil, tracker.scrollframe)
tracker.scrollchild:SetWidth(180)
tracker.scrollchild:SetHeight(1)
tracker.scrollframe:SetScrollChild(tracker.scrollchild)

-- Mouse wheel scrolling
tracker.scrollframe:EnableMouseWheel(true)
tracker.scrollframe.currentScroll = 0
tracker.scrollframe:SetScript(
    "OnMouseWheel",
    function()
        local maxScroll = math.max(0, tracker.scrollchild:GetHeight() - (tracker:GetHeight() - panelheight))
        if maxScroll > 0 then
            if arg1 > 0 then
                this.currentScroll = math.max(0, this.currentScroll - 20)
            else
                this.currentScroll = math.min(maxScroll, this.currentScroll + 20)
            end
            this:SetVerticalScroll(this.currentScroll)
        end
    end
)

do -- button panel
    tracker.panel = CreateFrame("Frame", nil, tracker.backdrop)
    tracker.panel:SetPoint("TOPLEFT", 0, 0)
    tracker.panel:SetPoint("TOPRIGHT", 0, 0)
    tracker.panel:SetHeight(panelheight)

    local anchors = {}
    local buttons = {}
    local function CreateButton(icon, anchor, tooltip, func)
        anchors[anchor] = anchors[anchor] and anchors[anchor] + 1 or 0
        local pos = 1 + (panelheight + 1) * anchors[anchor]
        pos = anchor == "TOPLEFT" and pos or pos * -1
        local func = func

        local b = CreateFrame("Button", nil, tracker.panel)
        b.tooltip = tooltip
        b.icon = b:CreateTexture(nil, "BACKGROUND")
        b.icon:SetAllPoints()
        b.icon:SetTexture(pfQuestConfig.path .. "\\img\\tracker_" .. icon)
        if table.getn(buttons) == 0 then
            b.icon:SetVertexColor(.2, 1, .8)
        end

        b:SetPoint(anchor, pos, -1)
        b:SetWidth(panelheight - 2)
        b:SetHeight(panelheight - 2)

        b:SetScript("OnEnter", ShowTooltip)
        b:SetScript("OnLeave", HideTooltip)

        if anchor == "TOPLEFT" then
            table.insert(buttons, b)
            b:SetScript(
                "OnClick",
                function()
                    if func then
                        func()
                    end
                    for id, button in pairs(buttons) do
                        button.icon:SetVertexColor(1, 1, 1)
                    end
                    this.icon:SetVertexColor(.2, 1, .8)
                end
            )
        else
            b:SetScript("OnClick", func)
        end

        return b
    end

    tracker.btnquest =
        CreateButton(
        "quests",
        "TOPLEFT",
        pfQuest_Loc["Show Current Quests"],
        function()
            tracker.mode = "QUEST_TRACKING"
            tracker.scrollframe.currentScroll = 0
            tracker.scrollframe:SetVerticalScroll(0)
            pfMap:UpdateNodes()
        end
    )

    tracker.btndatabase =
        CreateButton(
        "database",
        "TOPLEFT",
        pfQuest_Loc["Show Database Results"],
        function()
            tracker.mode = "DATABASE_TRACKING"
            tracker.scrollframe.currentScroll = 0
            tracker.scrollframe:SetVerticalScroll(0)
            pfMap:UpdateNodes()
        end
    )

    tracker.btngiver =
        CreateButton(
        "giver",
        "TOPLEFT",
        pfQuest_Loc["Show Quest Givers"],
        function()
            tracker.mode = "GIVER_TRACKING"
            tracker.scrollframe.currentScroll = 0
            tracker.scrollframe:SetVerticalScroll(0)
            pfMap:UpdateNodes()
            tracker.Refresh()
        end
    )

    if GetTrackedAchievements then
        tracker.btnachievement =
            CreateButton(
            "achievement",
            "TOPLEFT",
            "Show Tracked Achievements",
            function()
                tracker.mode = "ACHIEVEMENT_TRACKING"
                tracker.scrollframe.currentScroll = 0
                tracker.scrollframe:SetVerticalScroll(0)
                pfMap:UpdateNodes()
                tracker.Refresh()
            end
        )
        -- Override the texture to use epoch folder
        tracker.btnachievement.icon:SetTexture("Interface\\AddOns\\pfQuest-epoch\\img\\tracker_achievement")
    end

    tracker.btnclose =
        CreateButton(
        "close",
        "TOPRIGHT",
        pfQuest_Loc["Close Tracker"],
        function()
            DEFAULT_CHAT_FRAME:AddMessage(
                pfQuest_Loc["|cff33ffccpf|cffffffffQuest: Tracker is now hidden. Type `/db tracker` to show."]
            )
            tracker:Hide()
        end
    )

    tracker.btnsettings =
        CreateButton(
        "settings",
        "TOPRIGHT",
        pfQuest_Loc["Open Settings"],
        function()
            if pfQuestConfig then
                pfQuestConfig:Show()
            end
        end
    )

    tracker.btnclean =
        CreateButton(
        "clean",
        "TOPRIGHT",
        pfQuest_Loc["Clean Database Results"],
        function()
            pfMap:DeleteNode("PFDB")
            pfMap:UpdateNodes()
        end
    )

    tracker.btnsearch =
        CreateButton(
        "search",
        "TOPRIGHT",
        pfQuest_Loc["Open Database Browser"],
        function()
            if pfBrowser then
                pfBrowser:Show()
            end
        end
    )
end

-- Zone Header Functions
function tracker.CreateZoneHeader(zone)
    local header = CreateFrame("Button", nil, tracker.scrollchild)
    header:SetHeight(zoneheight)
    header.zone = zone

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()

    header.text = header:CreateFontString(nil, "HIGH", "GameFontNormal")
    header.text:SetFont(pfUI.font_default, fontsize)
    header.text:SetJustifyH("LEFT")
    header.text:SetPoint("LEFT", 18, 0)
    header.text:SetText(zone)
    header.text:SetTextColor(1, 0.82, 0)

    header.arrow = header:CreateFontString(nil, "HIGH", "GameFontNormal")
    header.arrow:SetFont(pfUI.font_default, fontsize)
    header.arrow:SetPoint("LEFT", 4, 0)
    header.arrow:SetText("+")
    header.arrow:SetTextColor(1, 1, 1)

    header:SetScript(
        "OnClick",
        function()
            if zone_expand_states[zone] then
                zone_expand_states[zone] = nil
                this.arrow:SetText("+")
            else
                zone_expand_states[zone] = true
                this.arrow:SetText("-")
            end
            tracker.Refresh()
        end
    )

    header:SetScript(
        "OnUpdate",
        function()
            local alpha = tonumber((pfQuest_config["trackeralpha"] or .2)) or .2

            if MouseIsOver(this) then
                this.bg:SetTexture(0.2, 0.2, 0.2, math.max(.5, alpha))
            else
                this.bg:SetTexture(0.1, 0.1, 0.1, math.max(.3, alpha))
            end
        end
    )

    -- Initialize as expanded
    if zone_expand_states[zone] == nil then
        zone_expand_states[zone] = true
    end

    if zone_expand_states[zone] then
        header.arrow:SetText("-")
    else
        header.arrow:SetText("+")
    end

    return header
end

function tracker.ButtonEnter()
    pfMap.highlight = this.title
    ShowTooltip()
end

function tracker.ButtonLeave()
    pfMap.highlight = nil
    HideTooltip()
end

function tracker.ButtonUpdate()
    local alpha = tonumber((pfQuest_config["trackeralpha"] or .2)) or .2

    if not this.alpha or this.alpha ~= alpha then
        this.bg:SetTexture(0, 0, 0, alpha)
        this.bg:SetAlpha(alpha)
        this.alpha = alpha
    end

    if pfMap.highlight and pfMap.highlight == this.title then
        if not this.highlight then
            this.bg:SetTexture(1, 1, 1, math.max(.2, alpha))
            this.bg:SetAlpha(math.max(.5, alpha))
            this.highlight = true
        end
    elseif this.highlight then
        this.bg:SetTexture(0, 0, 0, alpha)
        this.bg:SetAlpha(alpha)
        this.highlight = nil
    end
end

function tracker.ButtonClick()
    if arg1 == "RightButton" then
        for questid, data in pairs(pfQuest.questlog) do
            if data.title == this.title then
                -- show questlog
                HideUIPanel(QuestLogFrame)
                SelectQuestLogEntry(data.qlogid)
                ShowUIPanel(QuestLogFrame)
                break
            end
        end
    elseif IsShiftKeyDown() then
        -- mark as done if node is quest and not in questlog
        if this.node.questid and not this.node.qlogid then
            -- mark as done in history
            pfQuest_history[this.node.questid] = {time(), UnitLevel("player")}
            UIErrorsFrame:AddMessage(
                string.format(
                    "The Quest |cffffcc00[%s]|r (id:%s) is now marked as done.",
                    this.title,
                    this.node.questid
                ),
                1,
                1,
                1
            )
        end

        pfMap:DeleteNode(this.node.addon, this.title)
        pfMap:UpdateNodes()

        pfQuest.updateQuestGivers = true
    elseif IsControlKeyDown() and not WorldMapFrame:IsShown() then
        -- show world map
        if ToggleWorldMap then
            -- vanilla & tbc
            ToggleWorldMap()
        else
            -- wotlk
            WorldMapFrame:Show()
        end
    elseif IsControlKeyDown() and pfQuest_config["spawncolors"] == "0" then
        -- switch color
        pfQuest_colors[this.title] = {pfMap.str2rgb(this.title .. GetTime())}
        pfMap:UpdateNodes()
    elseif expand_states[this.title] == 0 then
        expand_states[this.title] = 1
        tracker.ButtonEvent(this)
        tracker.Refresh()
    elseif expand_states[this.title] == 1 then
        expand_states[this.title] = 0
        tracker.ButtonEvent(this)
        tracker.Refresh()
    end
end

local function trackersort(a, b)
    if a.empty then
        return false
    elseif (a.zone or "") ~= (b.zone or "") then
        return (a.zone or "") < (b.zone or "")
    elseif (a.tracked and 1 or -1) ~= (b.tracked and 1 or -1) then
        return (a.tracked and 1 or -1) > (b.tracked and 1 or -1)
    elseif (a.level or -1) ~= (b.level or -1) then
        return (a.level or -1) > (b.level or -1)
    elseif (a.perc or -1) ~= (b.perc or -1) then
        return (a.perc or -1) > (b.perc or -1)
    elseif (a.title or "") ~= (b.title or "") then
        return (a.title or "") < (b.title or "")
    else
        return false
    end
end

-- Helper function to get quest zone from quest log
local function GetQuestZone(targetQlogId)
    local currentZone = "Unknown"
    local numEntries, numQuests = GetNumQuestLogEntries()

    for i = 1, numEntries do
        local title, level, tag, isHeader, collapsed, complete = compat.GetQuestLogTitle(i)
        if isHeader then
            currentZone = title
        elseif i == targetQlogId then
            return currentZone
        end
    end

    return "Unknown"
end

function tracker.ButtonEvent(self)
    local self = self or this
    local title = self.title
    local node = self.node
    local id = self.id
    local qid = self.questid

    self:SetHeight(0)

    -- we got an event on a hidden button
    if not title then
        return
    end
    if self.empty then
        return
    end

    self:SetHeight(entryheight)

    -- initialize and hide all objectives
    self.objectives = self.objectives or {}
    for id, obj in pairs(self.objectives) do
        obj:Hide()
    end

    -- update button icon
    if node.texture then
        self.icon:SetTexture(node.texture)

        local r, g, b = unpack(node.vertex or {0, 0, 0})
        if r > 0 or g > 0 or b > 0 then
            self.icon:SetVertexColor(unpack(node.vertex))
        else
            self.icon:SetVertexColor(1, 1, 1, 1)
        end
    elseif pfQuest_config["spawncolors"] == "1" then
        self.icon:SetTexture(pfQuestConfig.path .. "\\img\\available_c")
        self.icon:SetVertexColor(1, 1, 1, 1)
    else
        self.icon:SetTexture(pfQuestConfig.path .. "\\img\\node")
        self.icon:SetVertexColor(pfMap.str2rgb(title))
    end

    if tracker.mode == "QUEST_TRACKING" then
        local qlogid = pfQuest.questlog[qid] and pfQuest.questlog[qid].qlogid or 0
        local qtitle, level, tag, header, collapsed, complete = compat.GetQuestLogTitle(qlogid)
        if not qlogid or not qtitle then
            return
        end
        local objectives = GetNumQuestLeaderBoards(qlogid)
        local watched = IsQuestWatched(qlogid)
        local color = pfQuestCompat.GetDifficultyColor(level)
        local cur, max = 0, 0
        local percent = 0

        -- Get zone information from quest log
        local zone = GetQuestZone(qlogid)
        self.zone = zone

        -- write expand state
        if not expand_states[title] then
            expand_states[title] = pfQuest_config["trackerexpand"] == "1" and 1 or 0
        end

        local expanded = expand_states[title] == 1 and true or nil

        if objectives and objectives > 0 then
            for i = 1, objectives, 1 do
                local text, _, done = GetQuestLogLeaderBoard(i, qlogid)
                local _, _, obj, objNum, objNeeded =
                    strfind(gsub(text, "\239\188\154", ":"), "(.*):%s*([%d]+)%s*/%s*([%d]+)")
                if objNum and objNeeded then
                    max = max + objNeeded
                    cur = cur + objNum
                elseif not done then
                    max = max + 1
                end
            end
        end

        if cur == max or complete then
            cur, max = 1, 1
            percent = 100
        else
            percent = cur / max * 100
        end

        -- expand button to show objectives
        if objectives and (expanded or (percent > 0 and percent < 100)) then
            self:SetHeight(entryheight + objectives * fontsize)

            for i = 1, objectives, 1 do
                local text, _, done = GetQuestLogLeaderBoard(i, qlogid)
                local _, _, obj, objNum, objNeeded =
                    strfind(gsub(text, "\239\188\154", ":"), "(.*):%s*([%d]+)%s*/%s*([%d]+)")

                if not self.objectives[i] then
                    self.objectives[i] = self:CreateFontString(nil, "HIGH", "GameFontNormal")
                    self.objectives[i]:SetFont(pfUI.font_default, fontsize)
                    self.objectives[i]:SetJustifyH("LEFT")
                    self.objectives[i]:SetPoint("TOPLEFT", 20, -fontsize * i - 6)
                    self.objectives[i]:SetPoint("TOPRIGHT", -10, -fontsize * i - 6)
                end

                if objNum and objNeeded then
                    local r, g, b = pfMap.tooltip:GetColor(objNum, objNeeded)
                    self.objectives[i]:SetTextColor(r + .2, g + .2, b + .2)
                    self.objectives[i]:SetText(string.format("|cffffffff- %s:|r %s/%s", obj, objNum, objNeeded))
                else
                    self.objectives[i]:SetTextColor(.8, .8, .8)
                    self.objectives[i]:SetText("|cffffffff- " .. text)
                end

                self.objectives[i]:Show()
            end
        end

        local r, g, b = pfMap.tooltip:GetColor(cur, max)
        local colorperc = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
        local showlevel =
            pfQuest_config["trackerlevel"] == "1" and "[" .. (level or "??") .. (tag and "+" or "") .. "] " or ""

        self.tracked = watched
        self.perc = percent
        self.text:SetText(
            string.format("%s%s |cffaaaaaa(%s%s%%|cffaaaaaa)|r", showlevel, title or "", colorperc or "", ceil(percent))
        )
        self.text:SetTextColor(color.r, color.g, color.b)
        self.tooltip =
            pfQuest_Loc[
            "|cff33ffcc<Click>|r Unfold/Fold Objectives\n|cff33ffcc<Right-Click>|r Show In QuestLog\n|cff33ffcc<Ctrl-Click>|r Show Map / Toggle Color\n|cff33ffcc<Shift-Click>|r Hide Nodes"
        ]
    elseif tracker.mode == "GIVER_TRACKING" then
        local level = node.qlvl or node.level or UnitLevel("player")
        local color = pfQuestCompat.GetDifficultyColor(level)

        -- red quests
        if node.qmin and node.qmin > UnitLevel("player") then
            color = {r = 1, g = 0, b = 0}
        end

        -- detect daily quests
        if node.qmin and node.qlvl and math.abs(node.qmin - node.qlvl) >= 30 then
            level, color = 0, {r = .2, g = .8, b = 1}
        end

        local showlevel = pfQuest_config["trackerlevel"] == "1" and "[" .. (level or "??") .. "] " or ""
        self.text:SetTextColor(color.r, color.g, color.b)
        self.text:SetText(showlevel .. title)
        self.level = tonumber(level)
        self.zone = nil
        self.tooltip =
            pfQuest_Loc["|cff33ffcc<Ctrl-Click>|r Show Map / Toggle Color\n|cff33ffcc<Shift-Click>|r Mark As Done"]
    elseif tracker.mode == "DATABASE_TRACKING" then
        self.text:SetText(title)
        self.text:SetTextColor(1, 1, 1, 1)
        self.text:SetTextColor(pfMap.str2rgb(title))
        self.zone = nil
        self.tooltip =
            pfQuest_Loc["|cff33ffcc<Ctrl-Click>|r Show Map / Toggle Color\n|cff33ffcc<Shift-Click>|r Hide Nodes"]
    elseif tracker.mode == "ACHIEVEMENT_TRACKING" then
        local achievementID = node.achievementID
        if achievementID then
            local _,
                name,
                points,
                completed,
                month,
                day,
                year,
                description,
                flags,
                icon,
                rewardText,
                isGuild,
                wasEarnedByMe = GetAchievementInfo(achievementID)

            self.text:SetText(name .. " |cffaaaaaa(" .. points .. " pts)|r")
            self.text:SetTextColor(1, 0.82, 0)

            -- Initialize expand state if not set
            if not expand_states[title] then
                expand_states[title] = pfQuest_config["trackerexpand"] == "1" and 1 or 0
            end

            -- Get criteria
            local numCriteria = GetAchievementNumCriteria(achievementID)
            if numCriteria > 0 and expand_states[title] == 1 then
                self:SetHeight(entryheight + numCriteria * fontsize)

                for j = 1, numCriteria do
                    local criteriaString, criteriaType, criteriaCompleted, quantity, reqQuantity =
                        GetAchievementCriteriaInfo(achievementID, j)

                    if not self.objectives[j] then
                        self.objectives[j] = self:CreateFontString(nil, "HIGH", "GameFontNormal")
                        self.objectives[j]:SetFont(pfUI.font_default, fontsize)
                        self.objectives[j]:SetJustifyH("LEFT")
                        self.objectives[j]:SetPoint("TOPLEFT", 20, -fontsize * j - 6)
                        self.objectives[j]:SetPoint("TOPRIGHT", -10, -fontsize * j - 6)
                    end

                    if quantity and reqQuantity then
                        local r, g, b = pfMap.tooltip:GetColor(quantity, reqQuantity)
                        self.objectives[j]:SetTextColor(r + .2, g + .2, b + .2)
                        self.objectives[j]:SetText(
                            string.format("|cffffffff- %s:|r %s/%s", criteriaString, quantity, reqQuantity)
                        )
                    else
                        local color = criteriaCompleted and {0, 1, 0} or {0.8, 0.8, 0.8}
                        self.objectives[j]:SetTextColor(unpack(color))
                        self.objectives[j]:SetText("|cffffffff- " .. criteriaString)
                    end

                    self.objectives[j]:Show()
                end
            end
        end

        self.tooltip = "|cff33ffcc<Click>|r Unfold/Fold Criteria\n|cff33ffcc<Shift-Click>|r Untrack Achievement"
    end

    self:Show()

    tracker.Refresh()
end

function tracker.AddTrackedAchievements()
    -- Check if achievement API exists
    if not GetTrackedAchievements then
        return
    end

    local trackedAchievements = {GetTrackedAchievements()}
    if not trackedAchievements or table.getn(trackedAchievements) == 0 then
        return
    end

    for i = 1, table.getn(trackedAchievements) do
        local achievementID = trackedAchievements[i]
        if achievementID then
            local _, name, points, completed = GetAchievementInfo(achievementID)
            if name and not completed then
                local node = {
                    dummy = true,
                    addon = "ACHIEVEMENT",
                    texture = "Interface\\AddOns\\pfQuest-epoch\\img\\achievement",
                    achievementID = achievementID
                }

                tracker.ButtonAdd(name, node)
            end
        end
    end
end

function tracker.Refresh()
    -- Build array of only active buttons, sort it, then reassign
    local activeButtons = {}
    for bid, button in pairs(tracker.buttons) do
        if not button.empty then
            table.insert(activeButtons, button)
        end
    end

    table.sort(activeButtons, trackersort)

    -- Clear tracker.buttons and rebuild with sorted active buttons
    for bid, button in pairs(tracker.buttons) do
        tracker.buttons[bid] = nil
    end

    for idx, button in ipairs(activeButtons) do
        tracker.buttons[idx] = button
    end

    -- Hide all zone headers first
    for zone, header in pairs(tracker.zoneheaders) do
        header:Hide()
    end

    -- Check if zones should be shown
    local showZones = pfQuest_config["trackershowzones"] == "1"

    -- resize window and align buttons
    local height = 0
    local width = 100
    local currentZone = nil

    for bid, button in pairs(tracker.buttons) do
        if not button.empty then
            -- Check if we need a new zone header (only in modern mode)
            if showZones and tracker.mode == "QUEST_TRACKING" and button.zone and button.zone ~= currentZone then
                currentZone = button.zone

                -- Create zone header if it doesn't exist
                if not tracker.zoneheaders[currentZone] then
                    tracker.zoneheaders[currentZone] = tracker.CreateZoneHeader(currentZone)
                end

                local zheader = tracker.zoneheaders[currentZone]
                zheader:ClearAllPoints()
                zheader:SetPoint("TOPRIGHT", tracker.scrollchild, "TOPRIGHT", 0, -height)
                zheader:SetPoint("TOPLEFT", tracker.scrollchild, "TOPLEFT", 0, -height)
                zheader:Show()

                height = height + zoneheight

                if zheader.text:GetStringWidth() > width then
                    width = zheader.text:GetStringWidth() + 30
                end
            end

            -- Only show button if zone is expanded
            if not showZones or tracker.mode ~= "QUEST_TRACKING" or not currentZone or zone_expand_states[currentZone] then
                button:ClearAllPoints()
                button:SetPoint("TOPRIGHT", tracker.scrollchild, "TOPRIGHT", 0, -height)
                button:SetPoint("TOPLEFT", tracker.scrollchild, "TOPLEFT", 0, -height)
                button:Show()

                -- Handle quest items
                if tracker.mode == "QUEST_TRACKING" and button.questid and pfQuest.questlog[button.questid] then
                    local qlogid = pfQuest.questlog[button.questid].qlogid
                    if qlogid then
                        -- Get item info directly without selecting
                        local link, item, charges = GetQuestLogSpecialItemInfo(qlogid)

                        if item then
                            -- Create or reuse item button
                            if not button.itemButton then
                                button.itemButton = CreateFrame("BUTTON", "pfQuestTrackerItem_" .. bid, button, "WatchFrameItemButtonTemplate")

                                -- Create the icon texture manually
                                button.itemButton.icon = button.itemButton:CreateTexture(nil, "BACKGROUND")
                                button.itemButton.icon:SetAllPoints()

                                -- Create count text
                                button.itemButton.count = button.itemButton:CreateFontString(nil, "OVERLAY")
                                button.itemButton.count:SetFont(pfUI.font_default, 10, "OUTLINE")
                                button.itemButton.count:SetPoint("BOTTOMRIGHT", -2, 2)
                                button.itemButton.count:SetTextColor(1, 1, 1)

                                -- Add tooltip
                                button.itemButton:SetScript(
                                    "OnEnter",
                                    function()
                                        if this:GetID() and this:GetID() > 0 then
                                            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
                                            GameTooltip:SetQuestLogSpecialItem(this:GetID())
                                            GameTooltip:Show()
                                        end
                                    end
                                )

                                button.itemButton:SetScript(
                                    "OnLeave",
                                    function()
                                        GameTooltip:Hide()
                                    end
                                )
                            end

                            local itemButton = button.itemButton

                            -- Scale based on fontsize
                            local scale = fontsize / 15
                            itemButton:SetScale(scale)

                            itemButton:Show()
                            itemButton:ClearAllPoints()
                            itemButton:SetID(qlogid) -- Set the quest log ID for UseQuestLogSpecialItem

                            -- Set the texture
                            itemButton.icon:SetTexture(item)

                            -- Set the count
                            if charges and charges > 1 then
                                itemButton.count:SetText(charges)
                                itemButton.count:Show()
                            else
                                itemButton.count:Hide()
                            end

                            -- Position
                            itemButton:SetPoint("LEFT", button.icon, "RIGHT", 2, 0)

                            -- Adjust text
                            button.text:ClearAllPoints()
                            button.text:SetPoint("TOPLEFT", itemButton, "TOPRIGHT", 2, -4)
                            button.text:SetPoint("TOPRIGHT", -10, -4)
                        else
                            -- No item, hide button if it exists
                            if button.itemButton then
                                button.itemButton:Hide()
                            end
                            -- Reset text position to normal
                            button.text:ClearAllPoints()
                            button.text:SetPoint("TOPLEFT", 16, -4)
                            button.text:SetPoint("TOPRIGHT", -10, -4)
                        end
                    else
                        if button.itemButton then
                            button.itemButton:Hide()
                        end
                        -- Reset text position to normal
                        button.text:ClearAllPoints()
                        button.text:SetPoint("TOPLEFT", 16, -4)
                        button.text:SetPoint("TOPRIGHT", -10, -4)
                    end
                else
                    if button.itemButton then
                        button.itemButton:Hide()
                    end
                    -- Reset text position to normal when not in quest tracking
                    button.text:ClearAllPoints()
                    button.text:SetPoint("TOPLEFT", 16, -4)
                    button.text:SetPoint("TOPRIGHT", -10, -4)
                end

                height = height + button:GetHeight()

                if button.text:GetStringWidth() > width then
                    width = button.text:GetStringWidth()
                end

                for id, objective in pairs(button.objectives) do
                    if objective:IsShown() and objective:GetStringWidth() > width then
                        width = objective:GetStringWidth()
                    end
                end
            else
                button:Hide()
                if button.itemButton then
                    button.itemButton:Hide()
                end
            end
        else
            button:Hide()
            if button.itemButton then
                button.itemButton:Hide()
            end
        end
    end

    -- Set scroll child height
    tracker.scrollchild:SetHeight(height)

    -- Determine final dimensions
    local finalWidth, finalHeight
    local useFixedHeight = pfQuest_config["trackerfixedheight"] == "1"
    local useFixedWidth = pfQuest_config["trackerfixedwidth"] == "1"

    if useFixedWidth then
        finalWidth = tonumber(pfQuest_config["trackerwidth"]) or 250
    else
        finalWidth = min(width, 300) + 30
    end

    if useFixedHeight then
        finalHeight = tonumber(pfQuest_config["trackerheight"]) or 400
    else
        finalHeight = height + panelheight
    end

    -- Update tracker size
    tracker:SetWidth(finalWidth)
    tracker:SetHeight(finalHeight)
    tracker.scrollchild:SetWidth(finalWidth - 10)
end

function tracker.ButtonAdd(title, node)
    if not title or not node then
        return
    end

    local questid = title
    for qid, data in pairs(pfQuest.questlog) do
        if data.title == title then
            questid = qid
            break
        end
    end

    if tracker.mode == "QUEST_TRACKING" then -- skip everything that isn't in questlog
        if node.addon ~= "PFQUEST" then
            return
        end
        if not pfQuest.questlog or not pfQuest.questlog[questid] then
            return
        end
    elseif tracker.mode == "GIVER_TRACKING" then -- skip everything that isn't a questgiver
        if node.addon ~= "PFQUEST" then
            return
        end
        -- break on already taken quests
        if not pfQuest.questlog or pfQuest.questlog[questid] then
            return
        end
        -- every layer above 2 is not a questgiver
        if not node.layer or node.layer > 2 then
            return
        end
    elseif tracker.mode == "DATABASE_TRACKING" then -- skip everything that isn't db query
        if node.addon ~= "PFDB" then
            return
        end
    elseif tracker.mode == "ACHIEVEMENT_TRACKING" then
        if node.addon ~= "ACHIEVEMENT" then
            return
        end
    end

    local id

    -- skip duplicate titles
    for bid, button in pairs(tracker.buttons) do
        if button.title and button.title == title then
            if node.dummy or not node.texture then
                -- We found a node icon (1st prio)
                -- use the ID and update the button
                id = bid
                break
            elseif node.cluster and (not button.node or button.node.texture) then
                -- We found a cluster icon (2nd prio)
                -- set the id, but still try to find a node icon
                id = bid
            else
                -- got none of the above, therefore
                -- no icon update required, skip here
                return
            end
        end
    end

    if not id then
        -- use maxcount + 1 as default id
        id = table.getn(tracker.buttons) + 1

        -- detect a reusable button - USE ipairs() FOR SEQUENTIAL ORDER
        for bid = 1, table.getn(tracker.buttons) do
            if tracker.buttons[bid].empty then
                id = bid
                break
            end
        end
    end

    if id > 25 then
        return
    end

    -- create one if required
    if not tracker.buttons[id] then
        tracker.buttons[id] = CreateFrame("Button", "pfQuestMapButton" .. id, tracker.scrollchild)
        tracker.buttons[id]:SetHeight(entryheight)

        tracker.buttons[id].bg = tracker.buttons[id]:CreateTexture(nil, "BACKGROUND")
        tracker.buttons[id].bg:SetTexture(1, 1, 1, .2)
        tracker.buttons[id].bg:SetAllPoints()
        tracker.buttons[id].bg:SetAlpha(0)

        tracker.buttons[id].text = tracker.buttons[id]:CreateFontString("pfQuestIDButton", "HIGH", "GameFontNormal")
        tracker.buttons[id].text:SetFont(pfUI.font_default, fontsize)
        tracker.buttons[id].text:SetJustifyH("LEFT")
        tracker.buttons[id].text:SetPoint("TOPLEFT", 16, -4)
        tracker.buttons[id].text:SetPoint("TOPRIGHT", -10, -4)

        tracker.buttons[id].icon = tracker.buttons[id]:CreateTexture(nil, "BORDER")
        tracker.buttons[id].icon:SetPoint("TOPLEFT", 2, -4)
        tracker.buttons[id].icon:SetWidth(12)
        tracker.buttons[id].icon:SetHeight(12)

        tracker.buttons[id]:RegisterEvent("QUEST_WATCH_UPDATE")
        tracker.buttons[id]:RegisterEvent("QUEST_LOG_UPDATE")
        tracker.buttons[id]:RegisterEvent("QUEST_FINISHED")

        tracker.buttons[id]:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        tracker.buttons[id]:SetScript("OnEnter", tracker.ButtonEnter)
        tracker.buttons[id]:SetScript("OnLeave", tracker.ButtonLeave)
        tracker.buttons[id]:SetScript("OnUpdate", tracker.ButtonUpdate)
        tracker.buttons[id]:SetScript("OnEvent", tracker.ButtonEvent)
        tracker.buttons[id]:SetScript("OnClick", tracker.ButtonClick)
    end

    -- set required data
    tracker.buttons[id].empty = nil
    tracker.buttons[id].title = title
    tracker.buttons[id].node = node
    tracker.buttons[id].questid = questid
    tracker.buttons[id].zone = nil

    -- reload button data
    tracker.ButtonEvent(tracker.buttons[id])
end

function tracker.Reset()
    tracker:SetHeight(panelheight)
    for id, button in pairs(tracker.buttons) do
        button.level = nil
        button.title = nil
        button.perc = nil
        button.zone = nil
        button.empty = true
        button:SetHeight(0)
        button:Hide()

        -- Hide item button if it exists
        if button.itemButton then
            button.itemButton:Hide()
        end
    end

    -- add tracked quests
    local _, numQuests = GetNumQuestLogEntries()
    local found = 0

    -- iterate over all quests
    for qlogid = 1, 40 do
        local title, level, tag, header, collapsed, complete = compat.GetQuestLogTitle(qlogid)
        if title and not header then
            local watched = IsQuestWatched(qlogid)
            if watched then
                local img =
                    complete and pfQuestConfig.path .. "\\img\\complete_c" or pfQuestConfig.path .. "\\img\\complete"
                pfQuest.tracker.ButtonAdd(title, {dummy = true, addon = "PFQUEST", texture = img})
            end

            found = found + 1
            if found >= numQuests then
                break
            end
        end
    end

    if tracker.mode == "ACHIEVEMENT_TRACKING" then
        tracker.AddTrackedAchievements()
    end
    tracker.Refresh()
end

-- make global available
pfQuest.tracker = tracker
