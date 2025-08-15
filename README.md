# pfQuest [Project Epoch DB]

**NOTE: I do not give permission for this addon to be hosted in any servers launchers of any kind unless directly pulled from my repo and you must contact me before doing so.**

An extension for [pfQuest-wotlk](https://github.com/shagu/pfQuest) which adds support for [Project Epoch](https://www.project-epoch.net/).
The latest version of [pfQuest-wotlk](https://github.com/shagu/pfQuest) is required and only enUS-Gameclients are supported at the time.

### Installation
1. Download the latest **[pfQuest-wotlk](https://github.com/shagu/pfQuest/releases/latest/download/pfQuest-enUS-wotlk.zip)**
2. Unzip it and place the "pfQuest-wotlk" folder into Wow-Directory\Interface\AddOns
3. Download the latest **[pfQuest-epoch](https://github.com/Bennylavaa/pfQuest-epoch/archive/master.zip)**
4. Unzip the file and Rename the folder "pfQuest-epoch-master" to "pfQuest-epoch"
5. Copy "pfQuest-epoch" into Wow-Directory\Interface\AddOns
6. It should look something like this:

<img width="328" height="62" alt="image" src="https://github.com/user-attachments/assets/1f4be26d-a126-4903-a17e-2aa1ba7334b5" />

7. It is now installed Congrats. 

## Contribute

The database format in use, is similar to the existing pfQuest databases.
You might want to also look into the "pfQuest-tbc" databases to learn how entries could be removed or manipulated.

Demo quest commit: [Do Slavers Keep Records?
](https://github.com/Bennylavaa/pfQuest-epoch/commit/39abc567413a0c004ea22ec38fed4eb2e486e9d6)

If you wish to add more content, feel free to contribute and send [Pull Requests](https://github.com/Bennylavaa/pfQuest-epoch/pulls).

### Useful Macros
Your Current Cords:
`/script SetMapToCurrentZone() local x,y=GetPlayerMapPosition("player") DEFAULT_CHAT_FRAME:AddMessage(format("%s, %s: %.1f, %.1f",GetZoneText(),GetSubZoneText(),x*100,y*100))`
[Zone IDs](https://github.com/Bennylavaa/wowchat-epoch/blob/main/src/main/resources/pre_cata_areas.csv)

Targeted Unit Information:
`/run local guid = UnitGUID("target"); local npcId = tonumber(string.sub(guid, 8, 12), 16); local npcName = UnitName("target"); print("NPC ID:", npcId, "NPC Name:", npcName)`

Selected QuestLog Data:
`/run local t, l, _, _, _, _, _, _, i = GetQuestLogTitle(GetQuestLogSelection()); print("\nID:"..i.."\nLevel:"..l.."\n[\"T\"] "..t.."\n[\"O\"] "..QuestInfoObjectivesText:GetText().."\n[\"D\"] "..QuestInfoDescriptionText:GetText())`

Hover Over Item ID:
`/run local _, link = GameTooltip:GetItem(); if link then local itemID = tonumber(link:match("item:(%d+):")); if itemID then print("Item ID:", itemID) end end`

Object ID:
No Possible way to get this info currently

Detailed list of what each section is: https://github.com/Bennylavaa/pfQuest-epoch/issues/4 

## TODO (In the order below)

- Finish fixing the ID's due to the ID squish Epoch devs did before launch
- Start adding missing quests and quests added after the last beta


![License](https://img.shields.io/badge/License-Custom-blue.svg)

## License
This project is licensed under a custom license that allows personal use and GitHub forks only. Redistribution or rehosting elsewhere is not permitted. See the [LICENSE](LICENSE) file for details.
