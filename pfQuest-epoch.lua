function hcstrsplit(delimiter, subject)
  if not subject then return nil end
  local delimiter, fields = delimiter or ":", {}
  local pattern = string.format("([^%s]+)", delimiter)
  string.gsub(subject, pattern, function(c) fields[table.getn(fields)+1] = c end)
  return unpack(fields)
end

local major, minor, fix = hcstrsplit(".", tostring(GetAddOnMetadata("pfQuest-epoch", "Version")))
fix = fix or 0 -- Set fix to 0 if it is nil

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
                        print("|cff33ffccpf|cffffffffQuest |cffcccccc[Project Epoch DB] |cffff5555[RELEASE]|r New version available! |cff66ccffhttps://github.com/Bennylavaa/pfQuest-epoch|r")
                        alreadyshown = true
                    end
                end
            end
            --This is a little check that I can use to see if people are actually using the addon.
            if v == "PING?" then
                for _, chan in ipairs(loginchannels) do
                    SendAddonMessage("pfqe", "PONG!:"..GetAddOnMetadata("pfQuest-epoch", "Version"), chan)
                end
            end
            if v == "PONG!" then
                --print(arg1 .." "..arg2.." "..arg3.." "..arg4)
            end
        end

        if event == "PARTY_MEMBERS_CHANGED" then
            local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
            if (this.group or 0) < groupsize then
                for _, chan in ipairs(groupchannels) do
                    SendAddonMessage("pfqe", "VERSION:" .. localversion, chan)
                end
            end
            this.group = groupsize
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not alreadyshown and localversion < remoteversion then
            print("|cff33ffccpf|cffffffffQuest |cffcccccc[Project Epoch DB] |cffff5555[RELEASE]|r New version available! |cff66ccffhttps://github.com/Bennylavaa/pfQuest-epoch|r")
            gpiupdateavailable = localversion
            alreadyshown = true
        end

        for _, chan in ipairs(loginchannels) do
            SendAddonMessage("pfqe", "VERSION:" .. localversion, chan)
        end
    end
end)
