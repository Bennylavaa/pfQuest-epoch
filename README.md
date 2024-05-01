# pfQuest [Project Epoch DB]

An extension for [pfQuest-wotlk](https://github.com/shagu/pfQuest) which adds support for [Project Epoch](https://www.project-epoch.net/).
The latest version of [pfQuest-wotlk](https://github.com/shagu/pfQuest) is required and only enUS-Gameclients are supported at the time.

### Installation
1. Download **[Latest Version](https://github.com/Bennylavaa/pfQuest-epoch/archive/master.zip)**
2. Unpack the Zip file
3. Rename the folder "pfQuest-epoch-master" to "pfQuest-epoch"
4. Copy "pfQuest-epoch" into Wow-Directory\Interface\AddOns
5. Restart Wow

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

## Progress

#### Alliance Zones
| Zone           | Level         | Alliance      | Horde          | 
|----------------|---------------|---------------|----------------|
Dun Morogh|1-10|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Elwynn Forest|1-10|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Teldrassil|1-10|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Darkshore|10-20|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Loch Modan|10-20|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Westfall|10-20|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>

#### Horde Zones
| Zone           | Level         | Alliance      | Horde          | 
|----------------|---------------|---------------|----------------|
Durotar|1-10|<ul><li>[X] Done</li></ul>|<ul><li>[x] Done</li></ul>
Mulgore|1-10|<ul><li>[X] Done</li></ul>|<ul><li>[x] Done</li></ul>
Tirisfal Glades|1-10|<ul><li>[X] Done</li></ul>|<ul><li>[X] Done</li></ul>
Silverpine Forest|10-20|<ul><li>[X] Done</li></ul>|<ul><li>[X] Done</li></ul>
Barrens|10-25|<ul><li>[X] Done</li></ul>|<ul><li>[x] Done</li></ul>

#### Contested Zones
| Zone           | Level         | Alliance      | Horde          | 
|----------------|---------------|---------------|----------------|
Redridge Mountains|15-27|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Stonetalon Mountains|15-27|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Ashenvale|18-30|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Duskwood|18-30|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Hillsbrad Foothills|20-30|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Wetlands|20-30|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Thousand Needles|25-35|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Alterac Mountains|30-40|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Arathi Highlands|30-40|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Desolace|30-40|<ul><li>[x] Done</li></ul>|<ul><li>[x] Done</li></ul>
Stranglethorn Vale|30-45|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Dustwallow Marsh|35-45|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Badlands|35-45|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Swamp of Sorrows|35-45|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Feralas|40-50|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Hinterlands|40-50|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Tanaris|40-50|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Searing Gorge|45-50|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Azshara|45-55|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Blasted Lands|45-55|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Un'goro Crater|48-55|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Felwood|48-55|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Burning Steppes|50-58|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Western Plaguelands|51-58|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Eastern Plaguelands|53-60|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Winterspring|53-60|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Deadwind Pass|55-60|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Moonglade|55-60|<ul><li>[x] Done</li></ul>|<ul><li>[ ] Done</li></ul>
Silithus|55-60|<ul><li>[ ] Done</li></ul>|<ul><li>[ ] Done</li></ul>
