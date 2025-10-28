function hcstrsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

function formatVersion(versionNum)
  local major = math.floor(versionNum / 10000)
  local minor = math.floor((versionNum % 10000) / 100)
  local fix = versionNum % 100
  return major .. "." .. minor .. "." .. fix
end

local major, minor, fix = hcstrsplit(".", tostring(GetAddOnMetadata("pfQuest-epoch", "Version")))
fix = fix or 0
local alreadyshown = false
local localversion  = tonumber(major*10000 + minor*100 + fix)
local remoteversion = tonumber(gpiupdateavailable) or 0
local loginchannels = { "BATTLEGROUND", "RAID", "GUILD", "PARTY" }
local groupchannels = { "BATTLEGROUND", "RAID", "PARTY" }

gpiupdater = CreateFrame("Frame")
gpiupdater:RegisterEvent("CHAT_MSG_ADDON")
gpiupdater:RegisterEvent("PLAYER_ENTERING_WORLD")
gpiupdater:RegisterEvent("PARTY_MEMBERS_CHANGED")
gpiupdater:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local arg1, arg2 = ...
        if arg1 == "pfqe" then
            local v, remoteversion = hcstrsplit(":", arg2)
            remoteversion = tonumber(remoteversion)
            if v == "VERSION" and remoteversion then
                if remoteversion > localversion then
                    gpiupdateavailable = remoteversion
                    if not alreadyshown then
                        local currentVer = formatVersion(localversion)
                        local availableVer = formatVersion(remoteversion)
                        print("|cff33ffccpfQuest |cffcccccc[Project Epoch DB]|r New version available!")
                        print("Current: |cff66ccff" .. currentVer .. "|r -> Available: |cff66ccff" .. availableVer .. "|r")
                        print("|cff66ccffhttps://github.com/Bennylavaa/pfQuest-epoch|r")
                        alreadyshown = true
                    end
                end
            end
            if v == "PING?" then
                if arg3 == "WHISPER" then
                    SendAddonMessage("pfqe", "PONG!:"..GetAddOnMetadata("pfQuest-epoch", "Version"), "WHISPER", arg4)
                else
                    for _, chan in ipairs(loginchannels) do
                        SendAddonMessage("pfqe", "PONG!:"..GetAddOnMetadata("pfQuest-epoch", "Version"), chan)
                    end
                end
            end
            if v == "PONG!" then
                if UnitName("player") == "Bennylava" then
                    local pongCmd, pongversion = hcstrsplit(":", arg2)
                    print("|cffff8000"..arg4.."|r - |cff66ccffv"..pongversion.."|r")
                end
            end
        end
    elseif event == "PARTY_MEMBERS_CHANGED" then
        local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
        if (gpiupdater.group or 0) < groupsize then
            for _, chan in ipairs(groupchannels) do
                SendAddonMessage("pfqe", "VERSION:" .. localversion, chan)
            end
        end
        gpiupdater.group = groupsize
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not alreadyshown and localversion < remoteversion then
            local currentVer = formatVersion(localversion)
            local availableVer = formatVersion(remoteversion)
            print("|cff33ffccpfQuest |cffcccccc[Project Epoch DB]|r New version available!")
            print("Current: |cff66ccff" .. currentVer .. "|r -> Available: |cff66ccff" .. availableVer .. "|r")
            print("|cff66ccffhttps://github.com/Bennylavaa/pfQuest-epoch|r")
            gpiupdateavailable = localversion
            alreadyshown = true
        end
        for _, chan in ipairs(loginchannels) do
            SendAddonMessage("pfqe", "VERSION:" .. localversion, chan)
        end
    end
end)

SLASH_PFQEPING1 = "/pfqe"
SlashCmdList["PFQEPING"] = function(msg)
    if msg == "" then
        print("Usage: /pfqe PLAYERNAME")
        return
    end
    SendAddonMessage("pfqe", "PING?", "WHISPER", msg)
end
