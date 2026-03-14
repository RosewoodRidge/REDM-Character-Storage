Config = {}

-- Enable/disable debug messages
Config.Debug = false
Config.DiscordDebug = false -- Enable/disable Discord webhook debug messages (set to false once working)

-- Price to create a storage
Config.StorageCreationPrice = 5

-- Price to increase storage capacity
Config.StorageUpgradePrice = 1.5

-- Price multiplier for each tier of upgrades (0.15 = 15% increase per tier)
Config.StorageUpgradePriceMultiplier = 0.1

-- Amount to increase storage by
Config.StorageUpgradeSlots = 25

-- Maximum number of storages a player can own
Config.MaxStorages = 2

-- ============================================================
-- Access Level System (job-grade based)
-- ============================================================
-- Job grades that map to "manager" access level on a storage.
-- Managers can: open storage, deposit, withdraw, view ledger, upgrade.
-- They CANNOT rename, delete, or manage who has access.
Config.ManagerJobGrades = {2}

-- Job grades that map to "member" access level on a storage.
-- Members can: open storage, deposit, view ledger.
-- They CANNOT withdraw, upgrade, rename, delete, or manage access.
Config.MemberJobGrades = {1}

-- Grade 0 (and any grade not listed above) = "basic" access: just opens storage items.

-- Default storage capacity (items)
Config.DefaultCapacity = 200

-- Storage expiration settings
Config.EnableStorageExpiration = true -- Whether to enable automatic deletion of unused storages
Config.StorageExpirationDays = 60    -- Number of days after which an unused storage is deleted

-- Storage access radius (in units)
Config.AccessRadius = 2.0

-- Blip settings
Config.UseBlips = true
Config.BlipSprite = -1138864184 -- Default blip sprite hash (BLIP_CHEST). Find more at https://redlookup.com/blips
Config.OnlyShowAccessibleBlips = true -- Only show blips for storages the player has access to

-- Prompt settings
Config.PromptKey = 0x760A9C6F -- G key

-- Commands for handling storages
Config.menustorage = 'createstorage'        -- Command for players to create a storage
Config.adminmovestorage = 'movestorage'     -- Command for admins to move storages
Config.admindeletestorage = 'deletestorage' -- Command for admins to delete storages
Config.adminStorageCommand = 'storageadmin' -- Command for admins to show/hide all storage blips
Config.adminShopCommand = 'adminshop'       -- Command for admins to open the all-items shop

-- Language system
Config.DefaultLanguage = "english" -- Default language: "english" or "spanish"

-- Update system configuration
Config.CheckForUpdates = true        -- Whether to check for updates on script start
Config.ShowUpdateNotifications = true -- Show notifications to admins when updates are available
Config.AutoUpdate = false            -- Attempt to automatically update (not fully implemented)

-- ============================================================
-- NPC Clerks (spawned at storage locations)
-- ============================================================
Config.NPCs = {
    Enabled = true,
    SpawnDistance = 80.0,   -- Distance to start spawning NPCs
    DespawnDistance = 100.0, -- Distance to despawn NPCs

    Clerks = {
        {
            model    = "MP_U_M_O_BlWPoliceChief_01",
            coords   = vector4(-758.7, -1242.85, 44.46, 87.27),
            scenario = "WORLD_HUMAN_CLIPBOARD",
        },
    },
}

Config.WeaponArmoryItems = {
            -- MELEE
            { name = 'WEAPON_MELEE_KNIFE',                 label = 'Knife',                        price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_MELEE_HATCHET',               label = 'Hatchet',                      price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_MELEE_HATCHET_HUNTER',        label = 'Hunter Hatchet',               price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_MELEE_MACHETE',               label = 'Machete',                      price = 0.0,   type = 'item_weapon' },
            -- LASSO / MISC KITS
            { name = 'WEAPON_LASSO',                       label = 'Lasso',                        price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_LASSO_REINFORCED',            label = 'Reinforced Lasso',             price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_KIT_BINOCULARS',              label = 'Binoculars',                   price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_KIT_BINOCULARS_IMPROVED',     label = 'Improved Binoculars',          price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_KIT_CAMERA',                  label = 'Camera',                       price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_MELEE_LANTERN',               label = 'Lantern',                      price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_MELEE_TORCH',                 label = 'Torch',                        price = 0.0,   type = 'item_weapon' },
            -- BOWS
            { name = 'WEAPON_BOW',                         label = 'Bow',                          price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_BOW_IMPROVED',                label = 'Improved Bow',                 price = 0.0,   type = 'item_weapon' },
            -- PISTOLS
            { name = 'WEAPON_PISTOL_VOLCANIC',             label = 'Volcanic Pistol',              price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_PISTOL_M1899',                label = 'M1899 Pistol',                 price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_PISTOL_MAUSER',               label = 'Mauser Pistol',                price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_PISTOL_SEMIAUTO',             label = 'Semi-Auto Pistol',             price = 0.0,   type = 'item_weapon' },
            -- REVOLVERS
            { name = 'WEAPON_REVOLVER_DOUBLEACTION',       label = 'Double-Action Revolver',       price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REVOLVER_CATTLEMAN',          label = 'Cattleman Revolver',           price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REVOLVER_SCHOFIELD',          label = 'Schofield Revolver',           price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REVOLVER_LEMAT',              label = 'LeMat Revolver',               price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REVOLVER_NAVY',               label = 'Navy Revolver',                price = 0.0,   type = 'item_weapon' },
            -- REPEATERS
            { name = 'WEAPON_REPEATER_CARBINE',            label = 'Carbine Repeater',             price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REPEATER_WINCHESTER',         label = 'Winchester Repeater',          price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REPEATER_HENRY',              label = 'Henry Repeater',               price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_REPEATER_EVANS',              label = 'Evans Repeater',               price = 0.0,   type = 'item_weapon' },
            -- RIFLES
            { name = 'WEAPON_RIFLE_VARMINT',               label = 'Varmint Rifle',                price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_RIFLE_SPRINGFIELD',           label = 'Springfield Rifle',            price = 0.0,   type = 'item_weapon' },
            -- SNIPER RIFLES
            { name = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK',    label = 'Rolling Block Rifle',          price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_SNIPERRIFLE_CARCANO',         label = 'Carcano Rifle',                price = 0.0,   type = 'item_weapon' },
            -- SHOTGUNS
            { name = 'WEAPON_SHOTGUN_DOUBLEBARREL',        label = 'Double-Barrel Shotgun',        price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_SHOTGUN_SAWEDOFF',            label = 'Sawed-Off Shotgun',            price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_SHOTGUN_PUMP',                label = 'Pump Shotgun',                 price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_SHOTGUN_REPEATING',           label = 'Repeating Shotgun',            price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_SHOTGUN_SEMIAUTO',            label = 'Semi-Auto Shotgun',            price = 0.0,   type = 'item_weapon' },
            -- THROWN
            { name = 'WEAPON_THROWN_BOLAS',                label = 'Bolas',                        price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_THROWN_BOLAS_HAWKMOTH',       label = 'Hawkmoth Bolas',               price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_THROWN_BOLAS_IRONSPIKED',     label = 'Ironspiked Bolas',             price = 0.0,   type = 'item_weapon' },
            { name = 'WEAPON_THROWN_BOLAS_INTERTWINED',    label = 'Intertwined Bolas',            price = 0.0,   type = 'item_weapon' },
            ---------------------------------------------------------------------------
            -- AMMUNITION
            -- REPEATER
            { name = 'ammorepeaternormal',                 label = 'Repeater Rounds (Normal)',      price = 0.0,   type = 'item_standard' },
            { name = 'ammorepeaterexpress',                label = 'Repeater Rounds (Express)',     price = 0.0,   type = 'item_standard' },
            { name = 'ammorepeatervelocity',               label = 'Repeater Rounds (Velocity)',    price = 0.0,   type = 'item_standard' },
            { name = 'ammorepeatersplitpoint',             label = 'Repeater Rounds (Split-Point)', price = 0.0,   type = 'item_standard' },
            -- REVOLVER
            { name = 'ammorevolvernormal',                 label = 'Revolver Rounds (Normal)',      price = 0.0,   type = 'item_standard' },
            { name = 'ammorevolverexpress',                label = 'Revolver Rounds (Express)',     price = 0.0,   type = 'item_standard' },
            { name = 'ammorevolvervelocity',               label = 'Revolver Rounds (Velocity)',    price = 0.0,   type = 'item_standard' },
            { name = 'ammorevolversplitpoint',             label = 'Revolver Rounds (Split-Point)', price = 0.0,   type = 'item_standard' },
            -- RIFLE
            { name = 'ammoriflenormal',                    label = 'Rifle Rounds (Normal)',         price = 0.0,   type = 'item_standard' },
            { name = 'ammorifleexpress',                   label = 'Rifle Rounds (Express)',        price = 0.0,   type = 'item_standard' },
            { name = 'ammoriflevelocity',                  label = 'Rifle Rounds (Velocity)',       price = 0.0,   type = 'item_standard' },
            { name = 'ammoriflesplitpoint',                label = 'Rifle Rounds (Split-Point)',    price = 0.0,   type = 'item_standard' },
            -- SHOTGUN
            { name = 'ammoshotgunnormal',                  label = 'Shotgun Shells (Buckshot)',     price = 0.0,   type = 'item_standard' },
            { name = 'ammoshotgunslug',                    label = 'Shotgun Shells (Slug)',         price = 0.0,   type = 'item_standard' },
            -- PISTOL
            { name = 'ammopistolnormal',                   label = 'Pistol Rounds (Normal)',        price = 0.0,   type = 'item_standard' },
            { name = 'ammopistolexpress',                  label = 'Pistol Rounds (Express)',       price = 0.0,   type = 'item_standard' },
            { name = 'ammopistolvelocity',                 label = 'Pistol Rounds (Velocity)',      price = 0.0,   type = 'item_standard' },
            { name = 'ammopistolsplitpoint',               label = 'Pistol Rounds (Split-Point)',   price = 0.0,   type = 'item_standard' },
            -- ARROWS
            { name = 'ammoarrownormal',                    label = 'Arrows (Standard)',             price = 0.0,   type = 'item_standard' },
            { name = 'ammoarrowsmallgame',                 label = 'Arrows (Small-Game)',           price = 0.0,   type = 'item_standard' },
            -- VARMINT
            { name = 'ammovarmint',                        label = 'Varmint Rounds',                price = 0.0,   type = 'item_standard' },
            { name = 'ammovarminttranq',                   label = 'Varmint Tranquilizer',          price = 0.0,   type = 'item_standard' },
            -- THROWING
            { name = 'ammoknives',                         label = 'Throwing Knives (Ammo)',        price = 0.0,   type = 'item_standard' },
            { name = 'ammotomahawk',                       label = 'Tomahawks (Ammo)',              price = 0.0,   type = 'item_standard' },
            { name = 'ammohatchet',                        label = 'Hatchets (Ammo)',               price = 0.0,   type = 'item_standard' },
            { name = 'ammohatchetcleaver',                 label = 'Cleaver Hatchets (Ammo)',       price = 0.0,   type = 'item_standard' },
            { name = 'ammohatchethunter',                  label = 'Hunter Hatchets (Ammo)',        price = 0.0,   type = 'item_standard' },
            { name = 'ammobola',                           label = 'Bolas (Ammo)',                  price = 0.0,   type = 'item_standard' },
            -- CLEANING SUPPLIES
            { name = 'gunoil',                             label = 'Gun Oil',                       price = 0.0,   type = 'item_standard' },
            { name = 'handcuffs',                          label = 'Handcuffs',                     price = 0.0,   type = 'item_standard' },
        }

-- ============================================================
-- Admin Armory Shops (VORP-style inventory buy menu, job-locked)
-- ============================================================
Config.ArmoryShops = {
    {
        Pos        = vector3(-769.42, -1229.97, 48.46),
        blipSprite = -145868367,
        id         = "armory_blackwater",
        Name       = "Blackwater Armory",
        joblock    = {"SheriffE", "SheriffW", "Marshals"},
        showblip   = true,
        npc = {
            model    = "MP_U_M_O_BlWPoliceChief_01",
            coords   = vector4(-769.41, -1230.65, 48.46, 88.06),
            scenario = "WORLD_HUMAN_CLIPBOARD",
        },
        sellitems  = Config.WeaponArmoryItems,
        -- Discord Webhook Tracking (activity only — tracks who takes what)
        discord = {
            enabled = true,
            webhook = "https://discord.com/api/webhooks/1472013327587741738/kyRI0snTusBI2uHzfDi_EHG5YqwMth1kucppn_bV97VE3RwTstxgjEQDXsljdS99ScyB",
            activity_message_id = "1472103163610792041",   -- After first run, copy the ID from server console and paste here as a string
            update_interval = 15,       -- How often (in seconds) to refresh the activity log
        },
    },
    {
        Pos        = vector3(-778.22, -1265.5, 43.72),
        blipSprite = -211556852,
        id         = "blackwater_hotel_keys",
        Name       = "Blackwater Hotel Keys",
        joblock    = {"restaurantBWHotel"}, 
        showblip   = true,
        npc = {
            model    = "u_m_m_valhotelowner_01",
            coords   = vector4(-778.22, -1265.5, 43.72, 269.08),
            scenario = "WORLD_HUMAN_STAND_IMPATIENT_UPRIGHT",
        },
        sellitems  = {
            -- Hotel Keys
            { name = 'HOTELBW1',                 label = 'Room 1 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW2',                 label = 'Room 2 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW3',                 label = 'Room 3 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW4',                 label = 'Room 4 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW5',                 label = 'Room 5 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW6',                 label = 'Room 6 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW7',                 label = 'Room 7 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW8',                 label = 'Room 8 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW9',                 label = 'Room 9 Key',                        price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW10',                label = 'Room 10 Key',                       price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW11',                label = 'Room 11 Key',                       price = 0.0,   type = 'item_standard' },
            { name = 'HOTELBW12',                label = 'Room 12 Key',                       price = 0.0,   type = 'item_standard' },
        },
        -- Discord Webhook Tracking (activity only — tracks who takes what)
        discord = {
            enabled = false,
            webhook = "https://discord.com/api/webhooks/1472013327587741738/kyRI0snTusBI2uHzfDi_EHG5YqwMth1kucppn_bV97VE3RwTstxgjEQDXsljdS99ScyB",
            activity_message_id = "1472103163610792041",   -- After first run, copy the ID from server console and paste here as a string
            update_interval = 15,       -- How often (in seconds) to refresh the activity log
        },
    },
    -- Add more armory shop locations below if needed
    -- {
    --     Pos        = vector3(x, y, z),
    --     blipSprite = -145868367,
    --     id         = "armory_valentine",
    --     Name       = "Valentine Armory",
    --     joblock    = {"Lemoyne", "NewHanover"},
    --     showblip   = true,
    --     npc = {
    --         model    = "MP_U_M_O_BlWPoliceChief_01",
    --         coords   = vector4(x, y, z, heading),
    --         scenario = "WORLD_HUMAN_CLIPBOARD",
    --     },
    --     sellitems  = Config.MasterSellItemsGunsmithAdmin, -- reuse a master list
    -- },
}

-- Armory shop settings
Config.ArmoryAccessRadius = 2.0         -- How close player must be to interact
Config.ArmoryPromptKey = 0x760A9C6F     -- G key (same as storage)
Config.ArmoryDefaultQuantity = 1        -- Default buy quantity
Config.ArmoryCurrencyType = 0           -- 0 = cash, 1 = gold

-- Preset Storages (not in DB, managed by config)
Config.DefaultStorages = {
    {
        id = "police_evidence", -- Unique ID for this preset storage configuration
        name = "Evidence and Storage",
        locations = {
            vector3(2908.03, 1308.82, 44.99), -- Annesburg Police Station
            vector3(-5531.36, -2929.99, -1.31),   -- Tumbleweed Police Station
            vector3(-3621.33, -2607.36, -13.29), -- Armadillo Police Station
            vector3(-760.14, -1243.33, 44.46),   -- Blackwater Police Station
            vector3(2507.56, -1301.95, 49.0),    -- St. Denis Police Station
            vector3(1361.99, -1302.32, 77.85),  -- Rhodes Police Station
            vector3(-1812.37, -355.89, 164.7),  -- Strawberry Police Station
            vector3(-278.69, 806.22, 119.38)   -- Valentine Police Station
        },
        linked = true, -- True: all locations share one inventory. False: each location is a separate instance.
        capacity = 5000,
        blipSprite = -693644997, -- Example: Hash for blip_ambient_sheriff. Replace with actual hash or string name.
        authorized_jobs = {
            ["SheriffE"] = { all_grades = true },
            ["SheriffW"] = { all_grades = true },
            ["GOVT"] = { grades = { 3 } },
            ["Marshals"] = { all_grades = true }
        },
        authorized_charids = {}, -- Optional: list of specific charIDs that can access
        -- owner_charid = nil, -- Not typically needed for job/shared storages
        -- Discord Webhook Tracking (optional — add this block to any preset storage)
        discord = {
            enabled = true,
            webhook = "https://discord.com/api/webhooks/1472104104112291881/EhTsDCl045a8rABdkhWd93EEcUtAI6ocA9O3sOMs0SzTLUBc4DshfRiRwSJ1AJwPgPoD",
            inventory_message_id = "1472104559676489798",  -- After first run, copy the ID from server console and paste here as a string
            activity_message_id = "1472104568870404239",   -- After first run, copy the ID from server console and paste here as a string
            update_interval = 13,       -- How often (in seconds) to refresh the inventory summary (600 = 10 minutes)
        },
    },
    {
        id_prefix = "bwhotel_rooms", -- Used to generate unique IDs like "bwhotel_rooms_loc1"
        name_template = "Blackwater Hotel Room %s", -- %s will be replaced by room name or index
        locations = {
            { coords = vector3(-787.27, -1270.23, 53.14), name_detail = "12" }, -- Room 12
            { coords = vector3(-786.76, -1267.28, 53.14), name_detail = "11" }, -- Room 11
            { coords = vector3(-782.31, -1265.37, 53.14), name_detail = "10" }, -- Room 10
            { coords = vector3(-779.82, -1262.74, 53.14), name_detail = "9"  }, -- Room 9
            { coords = vector3(-775.3,  -1267.18, 53.14), name_detail = "8"  }, -- Room 8
            { coords = vector3(-772.64, -1272.34, 53.14), name_detail = "7"  }, -- Room 7
            { coords = vector3(-787.49, -1262.68, 48.8),  name_detail = "6"  }, -- Room 6
            { coords = vector3(-787.43, -1262.59, 48.8),  name_detail = "5"  }, -- Room 5
            { coords = vector3(-784.37, -1266.03, 48.8),  name_detail = "4"  }, -- Room 4
            { coords = vector3(-777.1,  -1264.29, 48.8),  name_detail = "3"  }, -- Room 3
            { coords = vector3(-773.42, -1266.43, 48.8),  name_detail = "2"  }, -- Room 2
            { coords = vector3(-774.89, -1270.7,  48.8),  name_detail = "1"  }, -- Room 1
        },
        linked = false, -- True: all locations share one inventory. False: each location is a separate instance.
        capacity = 500,
        blipSprite = false, -- false = no map blip for these rooms
        public_access = true, -- Anyone can open these storage bins
        discord = {
            enabled = false,
            webhook = "https://discord.com/api/webhooks/1472104104112291881/EhTsDCl045a8rABdkhWd93EEcUtAI6ocA9O3sOMs0SzTLUBc4DshfRiRwSJ1AJwPgPoD",
            inventory_message_id = "1472104559676489798",  -- After first run, copy the ID from server console and paste here as a string
            activity_message_id = "1472104568870404239",   -- After first run, copy the ID from server console and paste here as a string
            update_interval = 13,       -- How often (in seconds) to refresh the inventory summary (600 = 10 minutes)
        },
    },
    --[[{
        id = "police_weapons", -- Unique ID for this preset storage configuration
        name = "Police Armory",
        locations = {
            vector3(-769.41, -1229.96, 48.46),   -- Blackwater Police Station
        },
        linked = true, -- True: all locations share one inventory. False: each location is a separate instance.
        capacity = 5000,
        blipSprite = -1796682476, -- Example: Hash for blip_ambient_sheriff. Replace with actual hash or string name.
        authorized_jobs = {
            ["Lemoyne"] = { all_grades = true },
            ["NewHanover"] = { all_grades = true },
            ["WestElizabeth"] = { all_grades = true },
            ["NewAustin"] = { all_grades = true },
            ["GOVT"] = { grades = { 3 } },
            ["DOJM"] = { all_grades = true }
        },
        authorized_charids = {}, -- Optional: list of specific charIDs that can access
        -- owner_charid = nil, -- Not typically needed for job/shared storages

        -- Discord Webhook Tracking (optional — add this block to any preset storage)
        discord = {
            enabled = true,
            webhook = "https://discord.com/api/webhooks/1472013327587741738/kyRI0snTusBI2uHzfDi_EHG5YqwMth1kucppn_bV97VE3RwTstxgjEQDXsljdS99ScyB",
            inventory_message_id = "1472103154115154046",  -- After first run, copy the ID from server console and paste here as a string
            activity_message_id = "1472103163610792041",   -- After first run, copy the ID from server console and paste here as a string
            update_interval = 12,       -- How often (in seconds) to refresh the inventory summary (600 = 10 minutes)
        },
    },]]
    {
        id = "doctor_main", -- Unique ID for this preset storage configuration
        name = "Doctor Storage",
        locations = {
            vector3(-782.6, -1297.54, 43.73),  -- Blackwater Doctor Station
            vector3(2722.93, -1233.52, 50.37),  -- St. Denis Doctor Station
            vector3(1368.54, -1307.05, 77.97),  -- Rhodes Doctor Station
            vector3(-1806.8, -428.47, 158.83),  -- Strawberry Doctor Station
            vector3(-288.86, 803.66, 119.39),   -- Valentine Doctor Station
            vector3(2923.01, 1356.76, 44.83),   -- Annesburg Doctor Station
            vector3(-3735.52, -2632.79, -12.79) -- Armadillo Doctor Station
        },
        linked = true, -- True: all locations share one inventory. False: each location is a separate instance.
        capacity = 5000,
        blipSprite = -1546805641, -- Example: Hash for blip_ambient_sheriff. Replace with actual hash or string name.
        authorized_jobs = {
            ["LemoyneDoc"] = { all_grades = true },
            ["NewHanoverDoc"] = { all_grades = true },
            ["WestElizabethDoc"] = { all_grades = true },
            ["NewAustinDoc"] = { all_grades = true },
            ["GeneralDoc"] = { all_grades = true }
        },
        authorized_charids = {}, -- Optional: list of specific charIDs that can access
        -- owner_charid = nil, -- Not typically needed for job/shared storages
        -- Discord Webhook Tracking (optional — add this block to any preset storage)
        discord = {
            enabled = true,
            webhook = "https://discord.com/api/webhooks/1472152843426332733/V2rAiodT4S52QXaXQI0kzPGgMEF4eTn3HR00UUQ6099fmqOCxnMTMCwHUQ7Dli_QHGfz",
            inventory_message_id = "1472153610472390656",  -- After first run, copy the ID from server console and paste here as a string
            activity_message_id = "1472153619993464892",   -- After first run, copy the ID from server console and paste here as a string
            update_interval = 11,       -- How often (in seconds) to refresh the inventory summary (600 = 10 minutes)
        },
    },
    -- Example of non-linked preset storages (each location is a separate storage instance)
    -- {
    --     id_prefix = "town_notice_board", -- Used to generate unique IDs like "town_notice_board_loc1"
    --     name_template = "Notice Board (%s)", -- %s will be replaced by town name or index
    --     locations = {
    --         { coords = vector3(2400.0, -1700.0, 45.0), name_detail = "St Denis" },
    --         { coords = vector3(-300.0, 800.0, 118.0), name_detail = "Valentine" }
    --     },
    --     linked = false,
    --     capacity = 50,
    --     blipSprite = -1138864184, -- Example: Hash for BLIP_CHEST. Find more at https://redlookup.com/blips
    --     authorized_jobs = { -- Example: only accessible by a "town_crier" job
    --         ["town_crier"] = { all_grades = true }
    --     },
    --     isPreset = true
    -- }
}

-- Translation system
Config.Translations = {
    ["english"] = {
        -- Notifications
        ["storage_created"] = "Storage created for $%d",
        ["storage_moved"] = "Storage #%d moved successfully",
        ["storage_upgraded"] = "Storage capacity upgraded for $%d",
        ["not_enough_money"] = "You don't have enough money",
        ["max_storages_reached"] = "You've reached the maximum number of storages (%d)",
        ["player_added"] = "Player added to storage access list",
        ["player_removed"] = "Player removed from storage access list",
        ["no_permission"] = "You don't have permission to do this",
        ["too_far_away"] = "You are too far away from the storage",
        ["player_not_found"] = "Player not found",
        ["storage_not_found"] = "Storage not found",
        ["storage_renamed"] = "Storage name updated successfully",
        ["invalid_name"] = "Invalid storage name",
        ["already_has_access"] = "This player already has access",
        ["error_removing"] = "Error removing player access",
        ["removal_success"] = "Removing access for %s",
        ["job_access_updated"] = "Job access rules updated successfully",
        ["job_rule_added"] = "Job access rule added for %s",
        ["job_rule_removed"] = "Job access rule removed for %s",
        ["invalid_job_or_grades"] = "Invalid job name or grades format",
        ["invalid_job_rule_format"] = "Invalid format. Use 'jobname grades' (e.g., police 0,1,2 or police all)",
        
        -- Access notifications 
        ["access_granted"] = "%s has given you access to %s",
        ["access_revoked"] = "%s has removed your access to %s",
        
        -- Menu titles
        ["storage_title"] = "Storage #%d",
        ["storage_management"] = "Storage Management",
        ["access_management"] = "Manage Access",
        ["authorized_players"] = "Authorized Players",
        ["add_player"] = "Add Player",
        ["confirm_removal"] = "Confirm Removal",
        ["create_storage"] = "Create Storage",
        ["nearby_players"] = "Nearby Players",
        ["add_player_title"] = "Add Player",
        ["select_method"] = "Select method",
        ["job_access_management"] = "Manage Job Access",
        ["add_job_rule_title"] = "Add Job Rule",
        ["edit_job_rule_title"] = "Edit Job Rule for %s",
        ["confirm_job_rule_removal"] = "Confirm Job Rule Removal",
        
        -- Menu options
        ["open_storage"] = "Open Storage",
        ["rename_storage"] = "Rename Storage",
        ["access_management_option"] = "Access Management",
        ["upgrade_storage"] = "Upgrade Storage ($%d)",
        ["back_menu"] = "Back",
        ["close_menu"] = "Close",
        ["yes_remove"] = "Yes, remove access",
        ["no_cancel"] = "No, cancel",
        ["search_nearby"] = "Search Players",
        ["enter_player_name"] = "Enter Player Name",
        ["view_remove_player"] = "View / Remove Player",
        ["no_players_found"] = "No players found",
        ["manage_job_access_option"] = "Manage Job Access",
        ["add_new_job_rule"] = "Add New Job Rule",
        ["remove_job_rule_option"] = "Remove Job Rule: %s",
        ["yes_remove_job_rule"] = "Yes, remove rule",
        
        -- Descriptions
        ["open_storage_desc"] = "Access the storage contents",
        ["rename_storage_desc"] = "Change the name of your storage",
        ["manage_access_desc"] = "Add or remove players who can access this storage",
        ["upgrade_storage_desc"] = "Increase storage capacity by %d slots",
        ["create_storage_desc"] = "Create a storage at your current location",
        ["create_cost"] = "Cost: $%d",
        ["remove_access_desc"] = "Remove %s's access to this storage",
        ["keep_access_desc"] = "Keep their access",
        ["remove_access_text"] = "Remove access for %s?",
        ["manage_players_desc"] = "Manage player access to your storage",
        ["player_info_loading"] = "Loading player %d...",
        ["player_info_wait"] = "Please wait while player info loads",
        ["add_remove_desc"] = "Click to remove this player's access to your storage",
        ["all_players_desc"] = "Search all players",
        ["manual_player_desc"] = "Manually enter player name",
        ["nearby_players_desc"] = "Look for players in your vicinity",
        ["manage_job_access_desc"] = "Define which jobs and grades can access this storage",
        ["add_job_rule_desc"] = "Add a new job and grade-based access rule",
        ["remove_job_rule_desc"] = "Remove access for job: %s",
        ["job_grades_desc"] = "Enter grades (e.g., 0,1,2) or 'all'",
        ["remove_job_access_text"] = "Remove access rule for job %s?",
        ["enter_job_and_grades_desc"] = "Example: police 0,1,2  OR  police all",
        
        -- Inputs
        ["confirm"] = "Confirm",
        ["enter_new_name"] = "Enter new name",
        ["enter_first_name"] = "Enter Player First Name",
        ["enter_last_name"] = "Enter Player Last Name",
        ["confirm_upgrade"] = "Upgrade by %d slots for $%d",
        ["upgrade_confirmation"] = "Confirm Upgrade",
        ["upgrade_confirm_desc"] = "This will increase your storage capacity",
        ["enter_job_name"] = "Enter Job Name (e.g., police)",
        ["enter_job_grades"] = "Enter Allowed Grades (e.g., 0,1,2 or all)",
        ["enter_job_rule"] = "Enter Job & Grades (e.g., police 0,1,2 or police all)",
        
        -- Prompts
        ["create_storage_prompt"] = "Create Storage",
        ["open_storage_prompt"] = "Open Storage",
        
        -- Commands
        ["usage_movestorage"] = "Usage: ".. Config.adminmovestorage .." id x y z",
        ["usage_deletestorage"] = "Usage: ".. Config.admindeletestorage .." id",
        ["storage_deleted"] = "Storage #%d deleted",
        ["invalid_location"] = "You cannot create a storage here",
        
        -- Admin commands
        ["admin_mode_enabled"] = "ADMIN MODE: Showing ALL storage blips",
        ["admin_mode_disabled"] = "ADMIN MODE: Showing only accessible storage blips",
        ["admin_command_usage"] = "Usage: /%s [show/hide]",
        ["admin_invalid_option"] = "Invalid option. Use 'show' or 'hide'",
        
        -- Money/Ledger related
        ["view_ledger"] = "View Ledger",
        ["view_ledger_desc"] = "View deposit and withdrawal history",
        ["deposit_money"] = "Deposit Money",
        ["deposit_money_desc"] = "Deposit money into storage",
        ["withdraw_money"] = "Withdraw Money",
        ["withdraw_money_desc"] = "Withdraw money from storage",
        ["storage_balance"] = "Balance: $%s",
        ["enter_amount"] = "Enter Amount",
        ["deposit_success"] = "Deposited $%s into storage",
        ["withdraw_success"] = "Withdrew $%s from storage",
        ["insufficient_funds"] = "Insufficient funds",
        ["insufficient_storage_funds"] = "Storage has insufficient funds",
        ["invalid_amount"] = "Invalid amount",
        ["ledger_title"] = "Ledger History",
        ["ledger_entry"] = "%s | $%s | %s",
        ["ledger_deposit"] = "Deposit",
        ["ledger_withdrawal"] = "Withdrawal",
        ["no_transactions"] = "No transactions yet",
        ["ledger_by"] = "by %s",
        
        -- Armory Shop
        ["armory_prompt"] = "Open Armory",
        ["armory_no_access"] = "You do not have access to this armory",
        ["armory_buy_success"] = "Purchased %s for $%.2f",
        ["armory_buy_fail"] = "Could not purchase %s",
        ["armory_close"] = "Close",
        ["armory_buy"] = "Buy",
        ["armory_price"] = "Price: $%.2f",
        ["armory_free"] = "Free",
        ["armory_category_weapons"] = "Weapons",
        ["armory_category_ammo"] = "Ammunition & Supplies",
        ["armory_back"] = "Back",
        
        -- Admin Shop
        ["adminshop_not_admin"] = "You must be an admin to use this command",
        ["adminshop_loading"] = "Loading all items...",
        ["adminshop_name"] = "Admin Item Shop",
        ["adminshop_desc"] = "Opens a shop with every item on the server (admin only)",
        
        -- Access Level System
        ["access_level_manager"] = "Manager",
        ["access_level_member"] = "Member",
        ["access_level_basic"] = "Basic",
        ["select_access_level"] = "Select Access Level",
        ["access_level_manager_desc"] = "Can deposit, withdraw, view ledger, and upgrade storage",
        ["access_level_member_desc"] = "Can deposit and view ledger (no withdraw)",
        ["access_level_basic_desc"] = "Can only open the storage items",
        ["player_options_title"] = "Player Options",
        ["change_level_option"] = "Change Access Level",
        ["remove_access_option"] = "Remove Access",
        ["level_updated"] = "Access level updated to %s for %s",
        ["add_player_select_level"] = "Select level for %s",
        ["nearby_player_desc"] = "Char ID: %d | Server ID: %s",
        ["select_player"] = "Select a player to add",
        ["storage_menu_subtext_manager"] = "Manager Access",
        ["storage_menu_subtext_member"] = "Member Access",
    },
    
    ["spanish"] = {
        -- Notifications
        ["storage_created"] = "Almacenamiento creado por $%d",
        ["storage_moved"] = "Almacenamiento #%d movido con éxito",
        ["storage_upgraded"] = "Capacidad de almacenamiento mejorada por $%d",
        ["not_enough_money"] = "No tienes suficiente dinero",
        ["max_storages_reached"] = "Has alcanzado el número máximo de almacenes (%d)",
        ["player_added"] = "Jugador añadido a la lista de acceso",
        ["player_removed"] = "Jugador eliminado de la lista de acceso",
        ["no_permission"] = "No tienes permiso para hacer esto",
        ["too_far_away"] = "Estás demasiado lejos del almacén",
        ["player_not_found"] = "Jugador no encontrado",
        ["storage_not_found"] = "Almacenamiento no encontrado",
        ["storage_renamed"] = "Nombre de almacenamiento actualizado con éxito",
        ["invalid_name"] = "Nombre de almacenamiento inválido",
        ["already_has_access"] = "Este jugador ya tiene acceso",
        ["error_removing"] = "Error al eliminar el acceso del jugador",
        ["removal_success"] = "Eliminando acceso para %s",
        ["job_access_updated"] = "Reglas de acceso por trabajo actualizadas con éxito",
        ["job_rule_added"] = "Regla de acceso por trabajo añadida para %s",
        ["job_rule_removed"] = "Regla de acceso por trabajo eliminada para %s",
        ["invalid_job_or_grades"] = "Nombre de trabajo o formato de grados inválido",
        ["invalid_job_rule_format"] = "Formato inválido. Usa 'nombretrabajo grados' (ej: police 0,1,2 o police all)",

        -- Access notifications
        ["access_granted"] = "%s te ha dado acceso a %s",
        ["access_revoked"] = "%s ha eliminado tu acceso a %s",
        
        -- Menu titles
        ["storage_title"] = "Almacén #%d",
        ["storage_management"] = "Gestión de Almacenamiento",
        ["access_management"] = "Gestión de Acceso",
        ["authorized_players"] = "Jugadores Autorizados",
        ["add_player"] = "Añadir Jugador",
        ["confirm_removal"] = "Confirmar Eliminación",
        ["create_storage"] = "Crear Almacenamiento",
        ["nearby_players"] = "Jugadores Cercanos",
        ["add_player_title"] = "Añadir Jugador",
        ["select_method"] = "Seleccionar método",
        ["job_access_management"] = "Gestionar Acceso por Trabajo",
        ["add_job_rule_title"] = "Añadir Regla de Trabajo",
        ["edit_job_rule_title"] = "Editar Regla para Trabajo %s",
        ["confirm_job_rule_removal"] = "Confirmar Eliminación de Regla de Trabajo",

        -- Menu options
        ["open_storage"] = "Abrir Almacén",
        ["rename_storage"] = "Renombrar Almacén",
        ["access_management_option"] = "Gestión de Acceso",
        ["upgrade_storage"] = "Mejorar Almacén ($%d)",
        ["back_menu"] = "Atrás",
        ["close_menu"] = "Cerrar",
        ["yes_remove"] = "Sí, eliminar acceso",
        ["no_cancel"] = "No, cancelar",
        ["search_nearby"] = "Buscar Jugadores Cercanos",
        ["enter_player_name"] = "Introducir Nombre del Jugador",
        ["view_remove_player"] = "Ver / Eliminar Jugador",
        ["no_players_found"] = "No se encontraron jugadores",
        ["manage_job_access_option"] = "Gestionar Acceso por Trabajo",
        ["add_new_job_rule"] = "Añadir Nueva Regla de Trabajo",
        ["remove_job_rule_option"] = "Eliminar Regla de Trabajo: %s",
        ["yes_remove_job_rule"] = "Sí, eliminar regla",

        -- Descriptions
        ["open_storage_desc"] = "Acceder al contenido del almacén",
        ["rename_storage_desc"] = "Cambiar el nombre de tu almacén",
        ["manage_access_desc"] = "Añadir o eliminar jugadores que pueden acceder a este almacén",
        ["upgrade_storage_desc"] = "Aumentar la capacidad de almacenamiento en %d espacios",
        ["create_storage_desc"] = "Crear un almacén en tu ubicación actual",
        ["create_cost"] = "Costo: $%d",
        ["remove_access_desc"] = "Eliminar el acceso de %s a este almacén",
        ["keep_access_desc"] = "Mantener su acceso",
        ["remove_access_text"] = "¿Eliminar acceso para %s?",
        ["manage_players_desc"] = "Gestionar el acceso de jugadores a tu almacén",
        ["player_info_loading"] = "Cargando jugador %d...",
        ["player_info_wait"] = "Por favor espera mientras se carga la información",
        ["add_remove_desc"] = "Haz clic para eliminar el acceso de este jugador a tu almacén",
        ["nearby_player_desc"] = "ID de Personaje: %d\nID de Servidor: %d",
        ["manual_player_desc"] = "Introduce manualmente el nombre del jugador",
        ["nearby_players_desc"] = "Buscar jugadores en tu vecindad",
        ["manage_job_access_desc"] = "Define qué trabajos y grados pueden acceder a este almacén",
        ["add_job_rule_desc"] = "Añadir una nueva regla de acceso basada en trabajo y grado",
        ["remove_job_rule_desc"] = "Eliminar acceso para el trabajo: %s",
        ["job_grades_desc"] = "Introduce grados (ej: 0,1,2) o 'all'",
        ["remove_job_access_text"] = "¿Eliminar regla de acceso para el trabajo %s?",
        ["enter_job_and_grades_desc"] = "Ejemplo: police 0,1,2  O  police all",

        -- Inputs
        ["confirm"] = "Confirmar",
        ["enter_new_name"] = "Introducir nuevo nombre",
        ["enter_first_name"] = "Introducir Nombre del Jugador",
        ["enter_last_name"] = "Introducir Apellido del Jugador",
        ["confirm_upgrade"] = "Mejorar en %d espacios por $%d",
        ["upgrade_confirmation"] = "Confirmar Mejora",
        ["upgrade_confirm_desc"] = "Esto aumentará la capacidad de tu almacenamiento",
        ["enter_job_name"] = "Introducir Nombre del Trabajo (ej: police)",
        ["enter_job_grades"] = "Introducir Grados Permitidos (ej: 0,1,2 o all)",
        ["enter_job_rule"] = "Introducir Trabajo y Grados (ej: police 0,1,2 o police all)",
        
        -- Prompts
        ["create_storage_prompt"] = "Crear Almacén",
        ["open_storage_prompt"] = "Abrir Almacén",
        
        -- Commands
        ["usage_movestorage"] = "Uso: ".. Config.adminmovestorage .." id x y z",
        ["usage_deletestorage"] = "Uso: ".. Config.admindeletestorage .." id",
        ["storage_deleted"] = "Almacén #%d eliminado",
        ["invalid_location"] = "No puedes crear un almacén aquí",
        
        -- Admin commands
        ["admin_mode_enabled"] = "MODO ADMIN: Mostrando TODOS los blips de almacén",
        ["admin_mode_disabled"] = "MODO ADMIN: Mostrando solo blips de almacén accesibles",
        ["admin_command_usage"] = "Uso: /%s [show/hide]",
        ["admin_invalid_option"] = "Opción inválida. Utiliza 'show' o 'hide'",
        
        -- Money/Ledger related
        ["view_ledger"] = "Ver Registro",
        ["view_ledger_desc"] = "Ver historial de depósitos y retiros",
        ["deposit_money"] = "Depositar Dinero",
        ["deposit_money_desc"] = "Depositar dinero en el almacén",
        ["withdraw_money"] = "Retirar Dinero",
        ["withdraw_money_desc"] = "Retirar dinero del almacén",
        ["storage_balance"] = "Balance: $%s",
        ["enter_amount"] = "Introducir Cantidad",
        ["deposit_success"] = "Depositado $%s en el almacén",
        ["withdraw_success"] = "Retirado $%s del almacén",
        ["insufficient_funds"] = "Fondos insuficientes",
        ["insufficient_storage_funds"] = "El almacén tiene fondos insuficientes",
        ["invalid_amount"] = "Cantidad inválida",
        ["ledger_title"] = "Historial de Registro",
        ["ledger_entry"] = "%s | $%s | %s",
        ["ledger_deposit"] = "Depósito",
        ["ledger_withdrawal"] = "Retiro",
        ["no_transactions"] = "Sin transacciones aún",
        ["ledger_by"] = "por %s",
        
        -- Armory Shop
        ["armory_prompt"] = "Abrir Armería",
        ["armory_no_access"] = "No tienes acceso a esta armería",
        ["armory_buy_success"] = "Comprado %s por $%.2f",
        ["armory_buy_fail"] = "No se pudo comprar %s",
        ["armory_close"] = "Cerrar",
        ["armory_buy"] = "Comprar",
        ["armory_price"] = "Precio: $%.2f",
        ["armory_free"] = "Gratis",
        ["armory_category_weapons"] = "Armas",
        ["armory_category_ammo"] = "Munición y Suministros",
        ["armory_back"] = "Atrás",
        
        -- Admin Shop
        ["adminshop_not_admin"] = "Debes ser administrador para usar este comando",
        ["adminshop_loading"] = "Cargando todos los artículos...",
        ["adminshop_name"] = "Tienda de Admin",
        ["adminshop_desc"] = "Abre una tienda con todos los artículos del servidor (solo admin)",
        
        -- Access Level System
        ["access_level_manager"] = "Gerente",
        ["access_level_member"] = "Miembro",
        ["access_level_basic"] = "Básico",
        ["select_access_level"] = "Seleccionar Nivel de Acceso",
        ["access_level_manager_desc"] = "Puede depositar, retirar, ver registro y mejorar el almacén",
        ["access_level_member_desc"] = "Puede depositar y ver el registro (sin retiro)",
        ["access_level_basic_desc"] = "Solo puede abrir los objetos del almacén",
        ["player_options_title"] = "Opciones del Jugador",
        ["change_level_option"] = "Cambiar Nivel de Acceso",
        ["remove_access_option"] = "Eliminar Acceso",
        ["level_updated"] = "Nivel de acceso actualizado a %s para %s",
        ["add_player_select_level"] = "Seleccionar nivel para %s",
        ["nearby_player_desc"] = "ID Personaje: %d | ID Servidor: %s",
        ["select_player"] = "Selecciona un jugador para añadir",
        ["storage_menu_subtext_manager"] = "Acceso de Gerente",
        ["storage_menu_subtext_member"] = "Acceso de Miembro",
    },
    ['german'] =  {
        -- Notifications
        ["storage_created"] = "Lager erstellt für $%d",
        ["storage_moved"] = "Lager #%d erfolgreich verschoben",
        ["storage_upgraded"] = "Lagerkapazität für $%d erweitert",
        ["not_enough_money"] = "Du hast nicht genug Geld",
        ["max_storages_reached"] = "Du hast die maximale Anzahl an Lagern erreicht (%d)",
        ["player_added"] = "Person zur Lagerzugriffsliste hinzugefügt",
        ["player_removed"] = "Person von der Lagerzugriffsliste entfernt",
        ["no_permission"] = "Du hast keine Berechtigung, dies zu tun",
        ["too_far_away"] = "Du bist zu weit vom Lager entfernt",
        ["player_not_found"] = "Person nicht gefunden",
        ["storage_not_found"] = "Lager nicht gefunden",
        ["storage_renamed"] = "Lagername erfolgreich aktualisiert",
        ["invalid_name"] = "Ungültiger Lagername",
        ["already_has_access"] = "Diese Person hat bereits Zugriff",
        ["error_removing"] = "Fehler beim Entfernen des Spielerzugriffs",
        ["removal_success"] = "Zugriff für %s wird entfernt",
        ["job_access_updated"] = "Job-Zugriffsregeln erfolgreich aktualisiert",
        ["job_rule_added"] = "Job-Zugriffsregel für %s hinzugefügt",
        ["job_rule_removed"] = "Job-Zugriffsregel für %s entfernt",
        ["invalid_job_or_grades"] = "Ungültiger Jobname oder Rangformat",
        ["invalid_job_rule_format"] = "Ungültiges Format. Verwende 'jobname grades' (z. B. police 0,1,2 oder police all)",

        -- Zugriffsbenachrichtigungen 
        ["access_granted"] = "%s hat dir Zugriff auf %s gewährt",
        ["access_revoked"] = "%s hat deinen Zugriff auf %s entfernt",

        -- Menütitel
        ["storage_title"] = "Lager #%d",
        ["storage_management"] = "Lagermanagement",
        ["access_management"] = "Zugriffsverwaltung",
        ["authorized_players"] = "Autorisierte Personen",
        ["add_player"] = "Person hinzufügen",
        ["confirm_removal"] = "Entfernung bestätigen",
        ["create_storage"] = "Lager erstellen",
        ["nearby_players"] = "Spieler in der Nähe",
        ["add_player_title"] = "Person hinzufügen",
        ["select_method"] = "Methode auswählen",
        ["job_access_management"] = "Job-Zugriffsverwaltung",
        ["add_job_rule_title"] = "Job-Regel hinzufügen",
        ["edit_job_rule_title"] = "Job-Regel für %s bearbeiten",
        ["confirm_job_rule_removal"] = "Entfernung der Job-Regel bestätigen",

        -- Menüoptionen
        ["open_storage"] = "Lager öffnen",
        ["rename_storage"] = "Lager umbenennen",
        ["access_management_option"] = "Zugriffsverwaltung",
        ["upgrade_storage"] = "Lager erweitern ($%d)",
        ["back_menu"] = "Zurück",
        ["close_menu"] = "Schließen",
        ["yes_remove"] = "Ja, Zugriff entfernen",
        ["no_cancel"] = "Nein, abbrechen",
        ["search_nearby"] = "Spieler suchen",
        ["enter_player_name"] = "Spielernamen eingeben",
        ["view_remove_player"] = "Spieler anzeigen / entfernen",
        ["no_players_found"] = "Keine Spieler gefunden",
        ["manage_job_access_option"] = "Job-Zugriff verwalten",
        ["add_new_job_rule"] = "Neue Job-Regel hinzufügen",
        ["remove_job_rule_option"] = "Job-Regel entfernen: %s",
        ["yes_remove_job_rule"] = "Ja, Regel entfernen",

        -- Beschreibungen
        ["open_storage_desc"] = "Greife auf den Inhalt des Lagers zu",
        ["rename_storage_desc"] = "Ändere den Namen deines Lagers",
        ["manage_access_desc"] = "Füge Spieler hinzu oder entferne sie, die Zugriff auf dieses Lager haben",
        ["upgrade_storage_desc"] = "Erhöhe die Lagerkapazität um %d Plätze",
        ["create_storage_desc"] = "Erstelle ein Lager an deinem aktuellen Standort",
        ["create_cost"] = "Kosten: $%d",
        ["remove_access_desc"] = "Entferne den Zugriff von %s auf dieses Lager",
        ["keep_access_desc"] = "Zugriff beibehalten",
        ["remove_access_text"] = "Zugriff für %s entfernen?",
        ["manage_players_desc"] = "Verwalte den Spielerzugriff auf dein Lager",
        ["player_info_loading"] = "Lade Spieler %d...",
        ["player_info_wait"] = "Bitte warten, während die Spielerdaten geladen werden",
        ["add_remove_desc"] = "Klicke, um den Zugriff dieses Spielers auf dein Lager zu entfernen",
        ["all_players_desc"] = "Alle Spieler durchsuchen",
        ["manual_player_desc"] = "Spielernamen manuell eingeben",
        ["nearby_players_desc"] = "Suche nach Spielern in deiner Nähe",
        ["manage_job_access_desc"] = "Definiere, welche Jobs und Ränge Zugriff auf dieses Lager haben",
        ["add_job_rule_desc"] = "Füge eine neue Job- und Rangbasierte Zugriffsregel hinzu",
        ["remove_job_rule_desc"] = "Zugriff für Job entfernen: %s",
        ["job_grades_desc"] = "Ränge eingeben (z. B. 0,1,2) oder 'all'",
        ["remove_job_access_text"] = "Zugriffsregel für Job %s entfernen?",
        ["enter_job_and_grades_desc"] = "Beispiel: police 0,1,2  ODER  police all",

        -- Eingaben
        ["confirm"] = "Bestätigen",
        ["enter_new_name"] = "Neuen Namen eingeben",
        ["enter_first_name"] = "Vornamen des Spielers eingeben",
        ["enter_last_name"] = "Nachnamen des Spielers eingeben",
        ["confirm_upgrade"] = "Erweiterung um %d Plätze für $%d",
        ["upgrade_confirmation"] = "Erweiterung bestätigen",
        ["upgrade_confirm_desc"] = "Dies wird deine Lagerkapazität erhöhen",
        ["enter_job_name"] = "Jobnamen eingeben (z. B. police)",
        ["enter_job_grades"] = "Erlaubte Ränge eingeben (z. B. 0,1,2 oder all)",
        ["enter_job_rule"] = "Job & Ränge eingeben (z. B. police 0,1,2 oder police all)",

        -- Hinweise
        ["create_storage_prompt"] = "Lager erstellen",
        ["open_storage_prompt"] = "Lager öffnen",

        -- Befehle
        ["usage_movestorage"] = "Verwendung: ".. Config.adminmovestorage .." id x y z",
        ["usage_deletestorage"] = "Verwendung: ".. Config.admindeletestorage .." id",
        ["storage_deleted"] = "Lager #%d gelöscht",
        ["invalid_location"] = "Du kannst hier kein Lager erstellen",

        -- Admin-Befehle
        ["admin_mode_enabled"] = "ADMIN-MODUS: Zeige ALLE Lager-Blips",
        ["admin_mode_disabled"] = "ADMIN-MODUS: Zeige nur zugängliche Lager-Blips",
        ["admin_command_usage"] = "Verwendung: /%s [show/hide]",
        ["admin_invalid_option"] = "Ungültige Option. Verwende 'show' oder 'hide'",

        -- Geld / Buchhaltung
        ["view_ledger"] = "Kontobuch anzeigen",
        ["view_ledger_desc"] = "Zeige Einzahlungs- und Auszahlungshistorie an",
        ["deposit_money"] = "Geld einzahlen",
        ["deposit_money_desc"] = "Geld auf das Kontobuch einzahlen",
        ["withdraw_money"] = "Geld abheben",
        ["withdraw_money_desc"] = "Geld aus dem Kontobuch abheben",
        ["storage_balance"] = "Kontostand: $%s",
        ["enter_amount"] = "Betrag eingeben",
        ["deposit_success"] = "$%s auf das Konto eingezahlt",
        ["withdraw_success"] = "$%s aus dem Konto abgehoben",
        ["insufficient_funds"] = "Unzureichende Mittel",
        ["insufficient_storage_funds"] = "Im Lager ist nicht genug Geld",
        ["invalid_amount"] = "Ungültiger Betrag",
        ["ledger_title"] = "Kontobuch-Historie",
        ["ledger_entry"] = "%s | $%s | %s",
        ["ledger_deposit"] = "Einzahlung",
        ["ledger_withdrawal"] = "Auszahlung",
        ["no_transactions"] = "Noch keine Transaktionen",
        ["ledger_by"] = "by %s",
        
        -- Armory Shop
        ["armory_prompt"] = "Waffenkammer öffnen",
        ["armory_no_access"] = "Du hast keinen Zugang zu dieser Waffenkammer",
        ["armory_buy_success"] = "%s für $%.2f gekauft",
        ["armory_buy_fail"] = "%s konnte nicht gekauft werden",
        ["armory_close"] = "Schließen",
        ["armory_buy"] = "Kaufen",
        ["armory_price"] = "Preis: $%.2f",
        ["armory_free"] = "Kostenlos",
        ["armory_category_weapons"] = "Waffen",
        ["armory_category_ammo"] = "Munition & Zubehör",
        ["armory_back"] = "Zurück",
        
        -- Admin Shop
        ["adminshop_not_admin"] = "Du musst Admin sein, um diesen Befehl zu verwenden",
        ["adminshop_loading"] = "Alle Gegenstände werden geladen...",
        ["adminshop_name"] = "Admin-Shop",
        ["adminshop_desc"] = "Öffnet einen Shop mit allen Server-Gegenständen (nur Admin)",
        
        -- Access Level System
        ["access_level_manager"] = "Manager",
        ["access_level_member"] = "Mitglied",
        ["access_level_basic"] = "Basis",
        ["select_access_level"] = "Zugriffsstufe auswählen",
        ["access_level_manager_desc"] = "Kann einzahlen, abheben, Kontobuch ansehen und Lager erweitern",
        ["access_level_member_desc"] = "Kann einzahlen und Kontobuch ansehen (kein Abheben)",
        ["access_level_basic_desc"] = "Kann nur den Lagerinhalt öffnen",
        ["player_options_title"] = "Spieleroptionen",
        ["change_level_option"] = "Zugriffsstufe ändern",
        ["remove_access_option"] = "Zugriff entfernen",
        ["level_updated"] = "Zugriffsstufe auf %s geändert für %s",
        ["add_player_select_level"] = "Stufe für %s auswählen",
        ["nearby_player_desc"] = "Char-ID: %d | Server-ID: %s",
        ["select_player"] = "Spieler zum Hinzufügen auswählen",
        ["storage_menu_subtext_manager"] = "Manager-Zugriff",
        ["storage_menu_subtext_member"] = "Mitglieds-Zugriff",
    }
}