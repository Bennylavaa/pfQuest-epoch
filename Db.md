# Db Structure

**Short explanation of each file:**

- **fac** -- Faction by letter: A (Alliance), H (Horde), AH (both)
- **U** -- Unit
- **O** -- Object
- **I** -- Item
- **IR** -- Itemreq, see quests-itemreq-epoch

---

## `db/`

### `quests-epoch.lua`
Contains quest information, including start and end points, level, and the next quest in a chain.
Not all fields are mandatory.

**Format:**
```lua
[QUESTID#] = {
    ["start"] = {
        ["U"] = { UNITID# },  -- Quest giver unit ID
    },
    ["end"] = {
        ["U"] = { UNITID# },  -- Quest turn-in unit ID
    },
    ["lvl"]   = quest_level,  -- Recommended quest level
    ["min"]   = min_level,    -- Minimum level to accept
    ["next"]  = next_quest_id, -- Next quest in the chain
    ["pre"]   = prev_quest_id, -- Previous quest in the chain
    ["close"] = { conflicting_quest_ids }, -- Quests that cannot be taken together (e.g., profession specializations)
    ["skill"] = skill_id,     -- Required profession/skill ID (e.g., 165 (Leatherworking))
    ["race"] = race_requirement, -- Race bitflag, advanced see pfQuest code https://github.com/shagu/pfQuest/blob/104f35678ca39ab1fb78b655f815cc7016f5e0c8/database.lua#L333
    ["class"] = class_requirement, -- see https://github.com/shagu/pfQuest/blob/104f35678ca39ab1fb78b655f815cc7016f5e0c8/database.lua#L351
    ["event"] = event_id, -- Event id
    ["obj"] = {  -- Quest objectives
        ["I"] = { item_ids_to_collect },  -- Items to collect
        ["U"] = { unit_ids_to_kill },    -- Units to kill
        ["O"] = { object_ids },          -- Objects to interact with
        ["IR"] = { item_req_ids },       -- see quests-itemreq-epoch.lua
    },
}
```

**Example:**
```lua
[27246] = {
    ["start"] = {
        ["U"] = { 14624 },
    },
    ["end"] = {
        ["U"] = { 46164 },
    },
    ["obj"] = {
        ["I"] = { 8165, 8203, 8204 },
    },
    ["lvl"] = 50,
    ["min"] = 50,
    ["next"] = 27242,
},
```

---

### `units-epoch.lua`
Contains unit information such as level, ID, coordinates, and faction.
Both quest NPCs and mobs are in this file.

**Format:**
```lua
[UNITID#] = {
    ["coords"] = { -- List of spawn locations and respawn timer
        [1] = { x, y, zoneid, respawn },
        [2] = { x, y, zoneid, respawn },
    },
    ["fac"] = faction,
    ["lvl"] = level, -- can be ranges like 21-23
    ["rnk"] = rank  -- 1 = elite?, 2 = rare elite?, no rank = normal mob
},
```

**Example:**
```lua
[61100] = {
    ["coords"] = {
        [1] = { 96.5, 66.8, 440, 280 },
        [2] = { 52.7, 80.7, 5121, 280 },
    },
    ["fac"] = "AH",
    ["lvl"] = "55",
},
```

---

### `items-epoch.lua`
Contains item information, including which units (`"U"`) and objects (`"O"`) they drop from. An item can drop from multiple units or objects.

**Format:**
```lua
[ITEMID#] = {
    ["O"] = { -- object
        [OBJECTID#] = drop%number, -- first object it drops from
        [OBJECTID#] = drop%number, -- second object it drops from
    },
    ["U"] = { -- unit
        [UNITID#] = drop%number, -- first NPC it drops from
        [UNITID#] = drop%number, -- second NPC it drops from
    },
    ["V"] = { -- vendor
        [UNITID#] = 0,
    }
},
```

**Example:**
```lua
[4606] = {
    ["O"] = {
        [153462] = 4.17,
    },
    ["U"] = {
        [3] = 4.73,
        [48] = 4.55,
    },
},
```

---

### `areatrigger-epoch.lua`
Contains area trigger locations for exploration quests.

**Format:**
```lua
[AREATRIGGERID#] = {
    ["coords"] = {
        [1] = { x, y, zoneid },
    },
},
```

**Example:**
```lua
[1] = {
    ["coords"] = {
        [1] = { 35.8, 62.1, 11 },
    },
},
```

---

### `objects-epoch.lua`
Contains object information, such as coordinates and ID.

**Format:**
```lua
[OBJECTID#] = {
    ["coords"] = {
        [1] = { x, y, zoneid, respawn },
    },
    ["fac"] = faction_letters
},
```

**Example:**
```lua
[34] = {
    ["coords"] = {
        [1] = { 40.6, 17, 40, 2700 },
    },
},
```

---

### `meta-epoch.lua`
Contains meta-relations, such as lists of game objects that are ores, unit IDs that are flight points, etc.

**Format:**
```lua
["chests"] = {
    [-CHESTID#] = 0,
},
["flight"] = {
    [UNITID#] = "FACTIONLETTER",
    [UNITID#] = "FACTIONLETTER",
    [UNITID#] = "FACTIONLETTER",
},
["rares"] = {
    [UNITID#] = LEVEL,
    [UNITID#] = LEVEL,
},
```

**Example:**
```lua
["chests"] = {
    [-3000248] = 0,
    [-3000247] = 0,
},
["flight"] = {
    [352] = "A",
    [1233] = "AH",
    [1387] = "H",
},
["rares"] = {
    [61] = 11,
    [79] = 10,
},
```

---

### `minimap-epoch.lua`
Contains minimap scale factors for specific areas, which helps to correctly display dots on the minimap inside buildings.

**Format:**
```lua
[MAPID] = { xsize, ysize },
```

**Example:**
```lua
[25] = { 711.56, 468.68 },
```

---

### `quests-itemreq-epoch.lua`
Contains a list of items required for a quest that are usable in the floating quest log UI.

### `refloot-epoch.lua`
Contains item requirements for specific quests, such as listing all anvil objects for the "Broken Tools" quest.

### `zones-epoch.lua`
Contains information about zones and their positions on maps, as well as the maps themselves.
*(No format or example provided in the original text)*

---

## `enUS/` (Localization Folder)

### `items-epoch.lua`
Contains item IDs and their corresponding names.

**Format:**
```lua
[ITEMID#] = ITEMNAME,
```

---

### `objects-epoch.lua`
Contains object IDs and their corresponding names.

**Format:**
```lua
[OBJECTID#] = OBJECTNAME,
```

---

### `professions-epoch.lua`
Contains IDs and names for custom professions only.

**Format:**
```lua
[PROFESSIONID#] = PROFESSIONNAME,
```

---

### `quests-epoch.lua`
Contains quest IDs and their title, objective, and description.

**Format:**
```lua
[QUESTID#] = {
    ["T"] = quest_title
    ["O"] = quest_ojective,
    ["D"] = quest_description,
},
```

---

### `units-epoch.lua`
Contains unit IDs and their corresponding names.

**Format:**
```lua
[UNITID#] = unit_name,
```

---

### `zones-epoch.lua`
Contains zone IDs and their corresponding names.

**Format:**
```lua
[ZONEID#] = zone_name,
```
