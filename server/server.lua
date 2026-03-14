local VORPcore = exports.vorp_core:GetCore()
local VORPinv = exports.vorp_inventory
-- DB is now global from database.lua, so no require needed

local storageCache = {}
local initialized = false

-- Debug helper function for consistent logging
function DebugLog(message)
    if not Config.Debug then return end
    
    print("[Server Debug] " .. message)
end

-- Helper function for shallow copy
function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Parse authorized_users JSON — supports both old format ([123, 456]) and new format ([{id=123,level="basic"}, ...])
function ParseAuthorizedUsers(jsonStr)
    local ok, decoded = pcall(json.decode, jsonStr or '[]')
    if not ok or not decoded then return {} end
    local users = {}
    for _, entry in ipairs(decoded) do
        if type(entry) == "number" then
            -- Old format: plain numeric ID — migrate to new format with basic level
            table.insert(users, { id = tonumber(entry), level = "basic" })
        elseif type(entry) == "table" and entry.id then
            -- New format: object with id and level
            table.insert(users, { id = tonumber(entry.id), level = entry.level or "basic" })
        end
    end
    return users
end

-- Helper function to refresh a player's storages
function RefreshPlayerStorages(source)
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier
    
    DB.GetAccessibleStorages(charId, function(storages)
        -- Ensure authorized_jobs is included, even if empty
        for i, s in ipairs(storages) do
            storages[i].authorized_jobs = s.authorized_jobs or '{}'
        end
        TriggerClientEvent('character_storage:receiveStorages', source, storages)
        DebugLog("Refreshed storage data for player " .. source)
    end)
end

-- Function to send all available storages to a player
function SendAllStoragesToPlayer(source)
    if not source then
        print("[ERROR] Attempted to send storages to nil source")
        return
    end
    
    DebugLog("Sending all storages to player: " .. tostring(source))
    local storagesToSend = {}
    
    -- Get player character info for permission checking
    local User = VORPcore.getUser(source)
    if not User then
        DebugLog("User not found for source: " .. tostring(source))
        return
    end
    
    local Character = User.getUsedCharacter
    if not Character then
        DebugLog("Character not found for source: " .. tostring(source))
        return
    end
    
    local charId = Character.charIdentifier
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    
    for id, storageData_cached_entry in pairs(storageCache) do
        local s = shallowcopy(storageData_cached_entry) 

        s.authorized_jobs = storageData_cached_entry.authorized_jobs or '{}'
        -- Remove server-side only config fields if they were copied and not needed by client for basic display
        s.authorized_jobs_config = nil
        s.authorized_charids_config = nil

        -- Add access flag based on player's permission
        s.hasAccess = HasStorageAccess(charId, id, playerJob, playerJobGrade)

        -- Ensure .locations is correctly populated for client for ALL types
        if storageData_cached_entry.isPreset then
            -- For presets (linked or non-linked instances), .locations should already be set correctly 
            -- in storageData_cached_entry by LoadAllStorages. shallowcopy(s) would have copied it.
            if not s.locations or #s.locations == 0 then
                 DebugLog("Error: Preset storage ID " .. id .. " has missing or empty locations in SendAllStoragesToPlayer. Blip might not show.")
            end
        elseif not storageData_cached_entry.isPreset and storageData_cached_entry.pos_x then -- DB storage
            s.locations = { vector3(storageData_cached_entry.pos_x, storageData_cached_entry.pos_y, storageData_cached_entry.pos_z) }
        else
            -- This case should ideally not be hit if all storages are well-formed
            DebugLog("Warning: Storage ID " .. id .. " is neither a preset with locations nor a DB storage with pos_x. Blip might not show.")
            s.locations = {} -- Ensure .locations exists to prevent client error, even if empty
        end
        table.insert(storagesToSend, s)
    end
    TriggerClientEvent('character_storage:receiveStorages', source, storagesToSend)
end

-- Register a custom inventory for a storage
function RegisterStorageInventory(id, capacity, storageData)
    local prefix = "character_storage_" .. id
    
    local storage = storageData or storageCache[id] or {}
    local storageNameDisplay

    if storage.isPreset then
        if storage.linked then -- Linked preset (e.g., police_armory_main)
            storageNameDisplay = storage.name or "Preset Storage" -- e.g., "Evidence and Storage"
        else -- Non-linked preset instance
            local baseInstanceName = storage.storage_name -- This is the formatted name like "Notice Board (St Denis)"
            if storage.location_index then
                storageNameDisplay = baseInstanceName .. " #" .. storage.location_index -- e.g., "Notice Board (St Denis) #1"
            else
                storageNameDisplay = baseInstanceName -- Fallback if index somehow missing
            end
        end
    else -- DB storage
        storageNameDisplay = (storage.storage_name or "Storage") .. " #" .. id -- e.g., "My Stash #123"
    end
    
    -- Remove existing inventory if it exists to avoid conflicts
    if VORPinv:isCustomInventoryRegistered(prefix) then
        DebugLog("Removing existing inventory: " .. prefix)
        VORPinv:removeInventory(prefix)
    end
    
    -- Register the inventory with proper parameters
    DebugLog("Registering inventory: " .. prefix .. " with capacity " .. capacity)
    local data = {
        id = prefix,
        name = storageNameDisplay,
        limit = capacity,
        acceptWeapons = true,
        shared = true, 
        ignoreItemStackLimit = true,
        whitelistItems = false,
        UsePermissions = false,
        UseBlackList = false,
        whitelistWeapons = false,
    }
    
    local success = VORPinv:registerInventory(data)
    DebugLog("Inventory registration result: " .. tostring(success))
    return success
end

-- Load and initialize all storages
function LoadAllStorages()
    if initialized then
        print("Storage system already initialized")
        return
    end
    
    print("Initializing character storage system...")
    
    -- Delete expired storages if the feature is enabled
    if Config.EnableStorageExpiration then
        DB.DeleteExpiredStorages(function(deletedCount)
            if deletedCount > 0 then
                print("Cleaned up " .. deletedCount .. " expired storages that were inactive for " .. Config.StorageExpirationDays .. " days")
            end
        end)
    end
    
    DB.LoadAllStoragesFromDatabase(function(storages)
        if not storages then storages = {} end -- Ensure storages is a table
        
        -- Process DB storages first
        for _, storage in ipairs(storages) do
            storageCache[storage.id] = storage
            storageCache[storage.id].authorized_jobs = storage.authorized_jobs or '{}'
            storageCache[storage.id].isPreset = false -- Explicitly mark as not preset
        end
        
        -- Process Preset Storages from Config.DefaultStorages
        if Config.DefaultStorages and #Config.DefaultStorages > 0 then
            for _, preset in ipairs(Config.DefaultStorages) do
                -- Always set isPreset to true for any storage defined in Config.DefaultStorages
                if preset.linked then
                    -- Linked storage: one inventory for all locations
                    local cacheEntry = shallowcopy(preset)
                    cacheEntry.storage_name = preset.name -- Use 'name' from config as 'storage_name'
                    cacheEntry.authorized_users = '[]' 
                    cacheEntry.owner_charid = preset.owner_charid or 0 
                    cacheEntry.isPreset = true -- Automatically set to true regardless of config
                    cacheEntry.linked = true -- Mark as linked
                    cacheEntry.authorized_jobs_config = preset.authorized_jobs 
                    cacheEntry.authorized_jobs = json.encode(preset.authorized_jobs or {}) 
                    cacheEntry.authorized_charids_config = preset.authorized_charids or {}

                    storageCache[preset.id] = cacheEntry
                    RegisterStorageInventory(preset.id, preset.capacity, cacheEntry)
                    DebugLog("Registered LINKED preset storage: " .. preset.id .. " (" .. preset.name .. ")")
                else
                    -- Non-linked: each location is a separate storage instance
                    if preset.id_prefix and preset.locations then
                        for i, locData in ipairs(preset.locations) do
                            local instanceId = preset.id_prefix .. "_loc" .. i
                            local instanceName = string.format(preset.name_template or preset.name or "Preset Storage %s", locData.name_detail or i)
                            
                            local cacheEntry = shallowcopy(preset)
                            cacheEntry.id = instanceId 
                            cacheEntry.storage_name = instanceName
                            cacheEntry.name = instanceName -- Also set .name for client consistency if it expects .name for non-linked presets
                            cacheEntry.pos_x = locData.coords.x
                            cacheEntry.pos_y = locData.coords.y
                            cacheEntry.pos_z = locData.coords.z
                            cacheEntry.locations = {locData.coords} 
                            cacheEntry.authorized_users = '[]'
                            cacheEntry.owner_charid = preset.owner_charid or 0
                            cacheEntry.isPreset = true -- Automatically set to true regardless of config
                            cacheEntry.linked = false -- Mark as non-linked
                            cacheEntry.location_index = i -- Store the index of this location
                            cacheEntry.authorized_jobs_config = preset.authorized_jobs
                            cacheEntry.authorized_jobs = json.encode(preset.authorized_jobs or {})
                            cacheEntry.authorized_charids_config = preset.authorized_charids or {}

                            storageCache[instanceId] = cacheEntry
                            RegisterStorageInventory(instanceId, preset.capacity, cacheEntry)
                            DebugLog("Registered NON-LINKED preset storage instance: " .. instanceId .. " (" .. instanceName .. ") Index: " .. i)
                        end
                    end
                end
            end
        end
        
        -- Register inventories for DB storages (after presets, in case of ID conflicts, though unlikely)
        local dbStoragesToRegister = {}
        for _, s_data in ipairs(storages) do table.insert(dbStoragesToRegister, s_data) end
        DB.RegisterAllStorageInventories(dbStoragesToRegister, RegisterStorageInventory)
        
        -- Mark initialization as complete
        initialized = true
        print(("Character storage system initialized. DB Storages: %d, Preset Configs: %d. Total in cache: %d"):format(#storages, Config.DefaultStorages and #Config.DefaultStorages or 0, table.count(storageCache)))
        
        -- Immediately push data to any players already connected (resource restart scenario)
        SendStoragesToAllPlayers()
    end)
end

-- Load all storages into cache on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    LoadAllStorages()
    
    -- SendStoragesToAllPlayers is now called inside LoadAllStorages once the DB
    -- callback completes (initialized = true), so the 1-second fixed timeout is
    -- no longer needed here. We keep a fallback in case of edge cases.
    Citizen.SetTimeout(5000, function()
        if initialized then
            SendStoragesToAllPlayers()
        end
    end)
end)

-- Handle resource stop to clean up and prepare for potential restart
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    print("Character storage system stopping. Cleaning up resources...")
    
    -- Any additional cleanup can go here
    
    initialized = false
end)

-- Function to send storage data to all currently connected players
function SendStoragesToAllPlayers()
    if not initialized then
        print("Storage system not yet initialized. Cannot send data to players.")
        return
    end
    
    local players = GetPlayers()
    local playerCount = #players
    
    print("Broadcasting storage data to " .. playerCount .. " connected players")
    
    local sentCount = 0
    
    for _, playerId in ipairs(players) do
        local source = tonumber(playerId)
        if source then
            -- Check if player has a character selected
            local User = VORPcore.getUser(source)
            if User then
                local Character = User.getUsedCharacter
                if Character and Character.charIdentifier then
                    SendAllStoragesToPlayer(source)
                    sentCount = sentCount + 1
                    DebugLog("Sent storage data to player " .. source .. " (Character ID: " .. tostring(Character.charIdentifier) .. ")")
                else
                    DebugLog("Player " .. source .. " doesn't have a character selected yet")
                end
            else
                DebugLog("Couldn't get User object for player " .. source)
            end
        end
    end
    
    print("Successfully sent storage data to " .. sentCount .. " out of " .. playerCount .. " players")
end

-- Register all storage inventories as a server export
exports('RegisterAllStorageInventories', function()
    if not initialized or not next(storageCache) then
        print("Storage cache not initialized yet")
        return 0
    end
    
    local storages = {}
    for _, storage in pairs(storageCache) do
        table.insert(storages, storage)
    end
    
    return DB.RegisterAllStorageInventories(storages, RegisterStorageInventory)
end)

-- Handle player loaded event - Push all available storage locations to player
RegisterServerEvent('vorp:playerSpawn')
AddEventHandler('vorp:playerSpawn', function(source, newChar, loadedFromRemove)
    -- In VORP, the first parameter might not be source for this server-side event
    local playerSource = tonumber(source) -- Ensure it's a number
    
    if not playerSource then
        DebugLog("Error: Invalid source in playerSpawn event")
        return
    end
    
    -- Short delay to ensure character is fully loaded
    Wait(2000)
    
    -- Send available storage to the player
    if not initialized then
        LoadAllStorages() -- Make sure storages are loaded
    end
    
    -- Send all storage locations to the player
    SendAllStoragesToPlayer(playerSource)
    DebugLog("Player " .. playerSource .. " spawned, sent " .. (storageCache and next(storageCache) and table.count(storageCache) or 0) .. " storages")
end)

-- Register event for when character is selected
RegisterServerEvent('vorp:SelectedCharacter')
AddEventHandler('vorp:SelectedCharacter', function(playerSource)
    -- In some VORP versions, the source is passed as parameter instead of being implicit
    local source = tonumber(playerSource)
    
    if not source then
        DebugLog("Error: Invalid source in SelectedCharacter event")
        return
    end
    
    -- Short delay to ensure character data is available
    Wait(2000)
    
    -- Send storage data to player after character selection
    SendAllStoragesToPlayer(source)
    DebugLog("Player " .. source .. " selected character, sent storages")
end)

-- Utility function to count table entries
function table.count(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- Check if player owns a storage
function IsStorageOwner(charId, storageId)
    local storage = storageCache[storageId]
    return storage and tonumber(storage.owner_charid) == tonumber(charId)
end

-- Returns the access level string for a player on a given storage:
--   "owner"   – full control
--   "manager" – open, deposit, withdraw, ledger, upgrade (no rename / access-management)
--   "member"  – open, deposit, ledger (no withdraw, no upgrade)
--   "basic"   – open storage items only
--   nil       – no access at all
function GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade)
    local storage = storageCache[storageId]
    if not storage then return nil end

    -- ── Preset Storages ──────────────────────────────────────────
    if storage.isPreset then
        -- Public access: anyone can open
        if storage.public_access then
            return "basic"
        end
        -- Check explicit char IDs from config
        if storage.authorized_charids_config then
            for _, allowedCharId in ipairs(storage.authorized_charids_config) do
                if tonumber(allowedCharId) == tonumber(charId) then
                    return "basic"
                end
            end
        end
        -- Check job rules from config
        if playerJob and playerJobGrade ~= nil and storage.authorized_jobs_config then
            local jobRules = storage.authorized_jobs_config[playerJob]
            if jobRules then
                local hasAccess = false
                if jobRules.all_grades then
                    hasAccess = true
                elseif jobRules.grades then
                    for _, grade in ipairs(jobRules.grades) do
                        if tonumber(playerJobGrade) >= tonumber(grade) then
                            hasAccess = true
                            break
                        end
                    end
                end
                if hasAccess then
                    return GetJobGradeAccessLevel(playerJobGrade)
                end
            end
        end
        return nil
    end

    -- ── DB Storages ───────────────────────────────────────────────
    -- Owner has full control
    if tonumber(storage.owner_charid) == tonumber(charId) then
        return "owner"
    end

    -- Check personal authorized_users list (new + legacy format)
    local authorizedUsers = ParseAuthorizedUsers(storage.authorized_users)
    for _, user in ipairs(authorizedUsers) do
        if user.id == tonumber(charId) then
            return user.level or "basic"
        end
    end

    -- Check job-based access rules
    if playerJob and playerJobGrade ~= nil then
        local authorizedJobs = json.decode(storage.authorized_jobs or '{}')
        if authorizedJobs[playerJob] then
            local jobRule = authorizedJobs[playerJob]
            local hasAccess = false
            if jobRule.all_grades then
                hasAccess = true
            elseif jobRule.grades then
                for _, grade in ipairs(jobRule.grades) do
                    if tonumber(playerJobGrade) >= tonumber(grade) then
                        hasAccess = true
                        break
                    end
                end
            end
            if hasAccess then
                return GetJobGradeAccessLevel(playerJobGrade)
            end
        end
    end

    return nil
end

-- Helper: map a numeric job grade to an access-level string using Config settings
function GetJobGradeAccessLevel(grade)
    local numGrade = tonumber(grade) or 0
    for _, mgrGrade in ipairs(Config.ManagerJobGrades or {}) do
        if numGrade == tonumber(mgrGrade) then return "manager" end
    end
    for _, memGrade in ipairs(Config.MemberJobGrades or {}) do
        if numGrade == tonumber(memGrade) then return "member" end
    end
    return "basic"
end

-- Legacy wrapper — returns true when the player has ANY level of access
function HasStorageAccess(charId, storageId, playerJob, playerJobGrade)
    return GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade) ~= nil
end

-- Create a new storage
RegisterServerEvent('character_storage:createStorage')
AddEventHandler('character_storage:createStorage', function()
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier
    
    -- Check if player has reached max number of storages
    DB.GetPlayerStorages(charId, function(storages)
        if #storages >= Config.MaxStorages then
            VORPcore.NotifyRightTip(source, GetTranslation("max_storages_reached", Config.MaxStorages), 4000)
            return
        end
        
        -- Check if player has enough money
        if Character.money < Config.StorageCreationPrice then
            VORPcore.NotifyRightTip(source, GetTranslation("not_enough_money"), 4000)
            return
        end
        
        -- Get player position
        local coords = GetEntityCoords(GetPlayerPed(source))
        local name = Character.firstname .. "'s Storage"
        
        -- Create storage in database
        DB.CreateStorage(charId, name, coords.x, coords.y, coords.z, function(storageId)
            if storageId then
                -- Remove money from player
                Character.removeCurrency(0, Config.StorageCreationPrice)
                
                -- Register inventory for new storage
                -- For DB storages, storageData passed to RegisterStorageInventory will have isPreset=false
                local newDbStorageData = {
                    id = storageId,
                    storage_name = name,
                    capacity = Config.DefaultCapacity,
                    isPreset = false -- Ensure this is set for RegisterStorageInventory logic
                }
                RegisterStorageInventory(storageId, Config.DefaultCapacity, newDbStorageData)
                
                -- Cache the new storage
                DB.GetStorage(storageId, function(storage)
                    storage.isPreset = false -- Ensure flag is correct in cache
                    storageCache[storageId] = storage
                    
                    -- Notify client
                    VORPcore.NotifyRightTip(source, GetTranslation("storage_created", Config.StorageCreationPrice), 4000)
                    
                    -- Refresh player's storages data immediately
                    RefreshPlayerStorages(source)
                    
                    -- Update all other clients with new storage location
                    TriggerClientEvent('character_storage:updateStorageLocations', -1, {
                        id = storageId,
                        pos_x = coords.x,
                        pos_y = coords.y,
                        pos_z = coords.z,
                        owner_charid = charId,
                        storage_name = name,
                        capacity = Config.DefaultCapacity,
                        authorized_users = '[]',
                        authorized_jobs = '{}', -- Add this
                        isPreset = false, -- Explicitly send isPreset
                        linked = false -- DB storages are not linked in the preset sense
                    })
                end)
            end
        end)
    end)
end)

-- Open a storage
RegisterNetEvent("character_storage:openStorage")
AddEventHandler("character_storage:openStorage", function(storageId)
    local _source = source
    
    -- Force convert to number to avoid type issues
    storageId = tonumber(storageId)
    
    DebugLog("Open storage request: ID=" .. tostring(storageId) .. " from player=" .. _source)
    
    -- Get our cached storage info
    local storage = storageCache[storageId]
    if not storage then 
        DebugLog("ERROR: Storage " .. tostring(storageId) .. " not found in cache!")
        VORPcore.NotifyRightTip(_source, "Storage not found", 3000)
        return
    end
    
    -- Get character ID of requesting player
    local Character = VORPcore.getUser(_source).getUsedCharacter
    local charId = Character.charIdentifier
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    
    DebugLog("Player charId=" .. charId .. " (Job: " .. playerJob .. ", Grade: " .. playerJobGrade .. ") requesting access to storage owned by " .. storage.owner_charid)
    
    -- Verify access
    if not HasStorageAccess(charId, storageId, playerJob, playerJobGrade) then
        DebugLog("Access denied for player " .. charId)
        VORPcore.NotifyRightTip(_source, GetTranslation("no_permission"), 4000)
        return
    end
    
    -- Set storage name
    local storageName = (storage.storage_name or ("Storage #" .. storageId)) .. " | ID:" .. storageId
    local inventoryName = "character_storage_" .. storageId
    
    -- Make sure inventory is registered before opening it
    if not VORPinv:isCustomInventoryRegistered(inventoryName) then
        DebugLog("Registering inventory that wasn't registered before: " .. inventoryName)
        RegisterStorageInventory(storageId, storage.capacity or Config.DefaultCapacity)
    end
    
    -- Update last_accessed timestamp - ALWAYS update for player-owned storages
    if not storage.isPreset then
        DebugLog("Updating last_accessed timestamp for regular storage #" .. storageId)
        DB.UpdateLastAccessed(storageId)
    else
        DebugLog("Skipping timestamp update for preset storage #" .. storageId)
    end
    
    -- Open the inventory directly
    DebugLog("Opening inventory " .. inventoryName .. " for player " .. _source)

    -- Discord tracking: record who opened this storage
    if DiscordTracker and DiscordTracker.OnStorageOpened then
        local charName = Character.firstname .. " " .. Character.lastname
        DiscordTracker.OnStorageOpened(_source, storageId, charId, charName)
    end

    VORPinv:openInventory(_source, inventoryName)
end)

-- Helper function to get storage by ID (implement according to your database structure)
function GetStorageById(id)
    local storage = nil
    -- Replace with your database query to get storage data
    exports.ghmattimysql:execute("SELECT * FROM character_storages WHERE id = @id", {
        ['@id'] = id
    }, function(result)
        if result[1] then
            storage = result[1]
        end
    end)
    
    -- Wait for the query to complete
    while storage == nil do
        Citizen.Wait(0)
    end
    
    return storage
end

-- Check if player is storage owner and respond accordingly
RegisterServerEvent('character_storage:checkOwnership')
AddEventHandler('character_storage:checkOwnership', function(storageId)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier
    local group = Character.group
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    
    -- Check if storage exists
    if not storageCache[storageId] then
        VORPcore.NotifyRightTip(source, "Storage not found", 4000)
        return
    end

    local storageData = storageCache[storageId]

    -- Handle Preset Storages: No owner menu, direct open if access
    if storageData.isPreset then
        if HasStorageAccess(charId, storageId, playerJob, playerJobGrade) then
            local prefix = "character_storage_" .. storageId -- For presets, storageId is the inventory ID
            if not VORPinv:isCustomInventoryRegistered(prefix) then
                 RegisterStorageInventory(storageId, storageData.capacity, storageData)
            end

            -- Discord tracking: record who opened this storage
            if DiscordTracker and DiscordTracker.OnStorageOpened then
                local charName = Character.firstname .. " " .. Character.lastname
                DiscordTracker.OnStorageOpened(source, storageId, charId, charName)
            end

            VORPinv:openInventory(source, prefix)
        else
            VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        end
        return
    end
    
    -- For regular storages, update timestamp on ANY access attempt
    DebugLog("Updating last_accessed timestamp for regular storage #" .. storageId .. " (checkOwnership call)")
    DB.UpdateLastAccessed(storageId)
    
    -- Determine player's access level on this storage
    local accessLevel = GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade)
    if group == "admin" and not accessLevel then accessLevel = "basic" end

    -- Owner → full owner menu
    if IsStorageOwner(charId, storageId) then
        TriggerClientEvent('character_storage:openOwnerMenu', source, storageId, "owner")
    -- Manager / Member → management menu (filtered by level client-side)
    elseif accessLevel == "manager" or accessLevel == "member" then
        TriggerClientEvent('character_storage:openOwnerMenu', source, storageId, accessLevel)
    -- Basic (or admin fallback) → open inventory directly
    elseif accessLevel == "basic" then
        local prefix = "character_storage_" .. storageId

        -- Discord tracking: record who opened this storage
        if DiscordTracker and DiscordTracker.OnStorageOpened then
            local charName = Character.firstname .. " " .. Character.lastname
            DiscordTracker.OnStorageOpened(source, storageId, charId, charName)
        end

        VORPinv:openInventory(source, prefix)
    else
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
    end
end)

-- Get character id from character name
function GetCharIdFromName(firstname, lastname, callback)
    local query = "SELECT charidentifier FROM characters WHERE firstname = ? AND lastname = ?"
    exports.oxmysql:execute(query, {firstname, lastname}, function(result)
        if result and #result > 0 then
            callback(result[1].charidentifier)
        else
            callback(nil)
        end
    end)
end

-- Add user to storage access list
RegisterServerEvent('character_storage:addUser')
AddEventHandler('character_storage:addUser', function(storageId, firstname, lastname)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    -- Prevent managing preset storages this way
    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be managed this way.", 4000)
        return
    end
    
    -- Check if player is storage owner
    if not IsStorageOwner(charId, storageId) then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    -- Find character id from name
    GetCharIdFromName(firstname, lastname, function(targetCharId)
        if not targetCharId then
            VORPcore.NotifyRightTip(source, GetTranslation("player_not_found"), 4000)
            return
        end
        
        -- Update authorized users (using new format, migrating old entries)
        local storage = storageCache[storageId]
        local authorizedUsers = ParseAuthorizedUsers(storage.authorized_users)
        
        -- Check if user is already authorized
        for _, user in ipairs(authorizedUsers) do
            if user.id == tonumber(targetCharId) then
                VORPcore.NotifyRightTip(source, GetTranslation("already_has_access"), 4000)
                return
            end
        end
        
        -- Add user with default basic level
        table.insert(authorizedUsers, { id = tonumber(targetCharId), level = "basic" })
        
        -- Update database
        DB.UpdateAuthorizedUsers(storageId, json.encode(authorizedUsers), function(success)
            if success then
                -- Update cache
                storage.authorized_users = json.encode(authorizedUsers)
                VORPcore.NotifyRightTip(source, GetTranslation("player_added"), 4000)
                
                -- Refresh owner's storage data
                RefreshPlayerStorages(source)
                
                -- If target player is online, notify and refresh them too
                local targetSource = GetPlayerSourceFromCharId(targetCharId)
                if targetSource then
                    -- Notify target player they've been given access
                    local storageName = storage.storage_name or "Storage #" .. storageId
                    local ownerName = Character.firstname .. " " .. Character.lastname
                    TriggerClientEvent('character_storage:notifyAccessGranted', targetSource, storageName, ownerName)
                    
                    -- Update target player's storage list
                    RefreshPlayerStorages(targetSource)
                end
            end
        end)
    end)
end)

-- Helper function to find a player's source from their character ID
function GetPlayerSourceFromCharId(charId)
    for _, playerId in ipairs(GetPlayers()) do
        local user = VORPcore.getUser(playerId)
        if user then
            local character = user.getUsedCharacter
            if character and tonumber(character.charIdentifier) == tonumber(charId) then
                return tonumber(playerId)
            end
        end
    end
    return nil
end

-- -------------------------------------------------------
-- Add user to storage by character ID with access level
-- This is the primary "add player" path used by the UI.
-- -------------------------------------------------------
RegisterServerEvent('character_storage:addUserById')
AddEventHandler('character_storage:addUserById', function(storageId, targetCharId, accessLevel)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    storageId      = tonumber(storageId)
    targetCharId   = tonumber(targetCharId)
    accessLevel    = accessLevel or "basic"

    -- Validate access level
    if accessLevel ~= "basic" and accessLevel ~= "member" and accessLevel ~= "manager" then
        accessLevel = "basic"
    end

    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be managed this way.", 4000)
        return
    end

    if not IsStorageOwner(charId, storageId) then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end

    if not targetCharId or tonumber(targetCharId) == tonumber(charId) then
        VORPcore.NotifyRightTip(source, GetTranslation("player_not_found"), 4000)
        return
    end

    local storage = storageCache[storageId]
    local authorizedUsers = ParseAuthorizedUsers(storage.authorized_users)

    for _, user in ipairs(authorizedUsers) do
        if user.id == tonumber(targetCharId) then
            VORPcore.NotifyRightTip(source, GetTranslation("already_has_access"), 4000)
            return
        end
    end

    table.insert(authorizedUsers, { id = tonumber(targetCharId), level = accessLevel })
    local newJson = json.encode(authorizedUsers)

    DB.UpdateAuthorizedUsers(storageId, newJson, function(success)
        if success then
            storage.authorized_users = newJson
            VORPcore.NotifyRightTip(source, GetTranslation("player_added"), 4000)
            RefreshPlayerStorages(source)

            local targetSource = GetPlayerSourceFromCharId(targetCharId)
            if targetSource then
                local storageName = storage.storage_name or "Storage #" .. storageId
                local ownerName = Character.firstname .. " " .. Character.lastname
                TriggerClientEvent('character_storage:notifyAccessGranted', targetSource, storageName, ownerName)
                RefreshPlayerStorages(targetSource)
            end
        end
    end)
end)

-- -------------------------------------------------------
-- Change an existing user's access level
-- -------------------------------------------------------
RegisterServerEvent('character_storage:changeUserLevel')
AddEventHandler('character_storage:changeUserLevel', function(storageId, targetCharId, newLevel)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    storageId    = tonumber(storageId)
    targetCharId = tonumber(targetCharId)
    newLevel     = newLevel or "basic"

    if newLevel ~= "basic" and newLevel ~= "member" and newLevel ~= "manager" then
        newLevel = "basic"
    end

    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be managed this way.", 4000)
        return
    end

    if not IsStorageOwner(charId, storageId) then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end

    local storage = storageCache[storageId]
    local authorizedUsers = ParseAuthorizedUsers(storage.authorized_users)
    local found = false

    for i, user in ipairs(authorizedUsers) do
        if user.id == tonumber(targetCharId) then
            authorizedUsers[i].level = newLevel
            found = true
            break
        end
    end

    if not found then
        VORPcore.NotifyRightTip(source, GetTranslation("player_not_found"), 4000)
        return
    end

    local newJson = json.encode(authorizedUsers)
    DB.UpdateAuthorizedUsers(storageId, newJson, function(success)
        if success then
            storage.authorized_users = newJson
            local levelLabel = GetTranslation("access_level_" .. newLevel)
            VORPcore.NotifyRightTip(source, GetTranslation("level_updated", levelLabel, "player"), 4000)
            RefreshPlayerStorages(source)

            local targetSource = GetPlayerSourceFromCharId(targetCharId)
            if targetSource then
                RefreshPlayerStorages(targetSource)
            end
        end
    end)
end)

-- Remove user from storage access list
RegisterServerEvent('character_storage:removeUser')
AddEventHandler('character_storage:removeUser', function(storageId, targetCharId)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    -- Prevent managing preset storages this way
    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be managed this way.", 4000)
        return
    end
    
    -- Check if player is storage owner
    if not IsStorageOwner(charId, storageId) then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    -- Update authorized users (new format; migrates old entries)
    local storage = storageCache[storageId]
    local authorizedUsers = ParseAuthorizedUsers(storage.authorized_users)
    local newAuthorizedUsers = {}
    
    -- Filter out the target user (preserve objects)
    for _, user in ipairs(authorizedUsers) do
        if user.id ~= tonumber(targetCharId) then
            table.insert(newAuthorizedUsers, user)
        end
    end
    
    -- Update database
    DB.UpdateAuthorizedUsers(storageId, json.encode(newAuthorizedUsers), function(success)
        if success then
            -- Update cache
            storage.authorized_users = json.encode(newAuthorizedUsers)
            VORPcore.NotifyRightTip(source, GetTranslation("player_removed"), 4000)
            
            -- Refresh player's storage data
            RefreshPlayerStorages(source)
            
            -- If target player is online, notify and refresh them too
            local targetSource = GetPlayerSourceFromCharId(targetCharId)
            if targetSource then
                local storageName = storage.storage_name or "Storage #" .. storageId
                local ownerName = Character.firstname .. " " .. Character.lastname
                TriggerClientEvent('character_storage:notifyAccessRevoked', targetSource, storageName, ownerName)
                RefreshPlayerStorages(targetSource)
            end
        end
    end)
end)

-- Add a new, more direct event handler for removing access
RegisterServerEvent('character_storage:removeAccess')
AddEventHandler('character_storage:removeAccess', function(storageId, targetCharId)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local ownerCharId = Character.charIdentifier
    
    DebugLog("========== REMOVAL REQUEST START ==========")
    DebugLog("Source player: " .. source .. ", Character: " .. ownerCharId)
    DebugLog("Storage ID: " .. tostring(storageId) .. ", Target CharID: " .. tostring(targetCharId))
    
    -- Ensure proper type conversion
    storageId = tonumber(storageId)
    targetCharId = tonumber(targetCharId)

    -- Prevent managing preset storages this way
    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be managed this way.", 4000)
        DebugLog("Attempt to manage preset storage " .. storageId .. " via removeAccess denied.")
        return
    end
    
    if not storageId or not targetCharId then
        DebugLog("ERROR: Invalid IDs after conversion")
        VORPcore.NotifyRightTip(source, "Invalid storage or character ID", 4000)
        return
    end
    
    -- Check if storage exists
    if not storageCache[storageId] then
        DebugLog("ERROR: Storage " .. storageId .. " not found in cache")
        VORPcore.NotifyRightTip(source, "Storage not found", 4000)
        return
    end
    
    local storage = storageCache[storageId]
    DebugLog("Storage found: Name = " .. (storage.storage_name or "Unnamed") .. ", Owner = " .. storage.owner_charid)
    
    -- Check if player is storage owner
    if tonumber(storage.owner_charid) ~= tonumber(ownerCharId) then
        DebugLog("ERROR: Player " .. ownerCharId .. " is not the owner " .. storage.owner_charid)
        VORPcore.NotifyRightTip(source, "Only the storage owner can remove access", 4000)
        return
    end
    
    -- Get current authorized users
    DebugLog("Raw authorized_users JSON: " .. tostring(storage.authorized_users))
    
    local authorizedUsers = ParseAuthorizedUsers(storage.authorized_users)
    
    DebugLog("Current authorized users: " .. json.encode(authorizedUsers))
    
    -- Create new list without target user
    local newAuthorizedUsers = {}
    local wasRemoved = false
    local targetSource = nil
    
    for _, user in ipairs(authorizedUsers) do
        local uid = type(user) == "table" and user.id or tonumber(user)
        if uid ~= targetCharId then
            -- Preserve full object (or upgrade legacy numeric entry)
            if type(user) == "table" then
                table.insert(newAuthorizedUsers, user)
            else
                table.insert(newAuthorizedUsers, { id = tonumber(user), level = "basic" })
            end
        else
            wasRemoved = true
            DebugLog("User " .. tostring(uid) .. " will be removed")
            -- Find target player's source if they're online
            targetSource = GetPlayerSourceFromCharId(targetCharId)
        end
    end
    
    if not wasRemoved then
        DebugLog("ERROR: Target user " .. targetCharId .. " not found in authorized list")
        VORPcore.NotifyRightTip(source, "Player not found in access list", 4000)
        return
    end
    
    -- Update the database directly
    local jsonData = json.encode(newAuthorizedUsers)
    DebugLog("New authorized_users JSON: " .. jsonData)
    
    -- Use a direct query for simplicity
    exports.oxmysql:execute(
        "UPDATE character_storage SET authorized_users = ? WHERE id = ?",
        {jsonData, storageId},
        function(result)
            if result and result.affectedRows > 0 then
                DebugLog("Database updated successfully - Rows affected: " .. result.affectedRows)
                
                -- Update local cache
                storage.authorized_users = jsonData
                VORPcore.NotifyRightTip(source, "Player access has been removed", 4000)
                
                -- Refresh owner's storage data
                RefreshPlayerStorages(source)
                
                -- If target player is online, notify and refresh them too
                if targetSource then
                    local storageName = storage.storage_name or "Storage #" .. storageId
                    local ownerName = Character.firstname .. " " .. Character.lastname
                    TriggerClientEvent('character_storage:notifyAccessRevoked', targetSource, storageName, ownerName)
                    RefreshPlayerStorages(targetSource)
                end
                
                DebugLog("Success - Sent storage refresh to client")
            else
                DebugLog("ERROR: Database update failed")
                VORPcore.NotifyRightTip(source, "Failed to update database", 4000)
            end
            
            DebugLog("========== REMOVAL REQUEST COMPLETE ==========")
        end
    )
end)

-- Upgrade storage capacity
RegisterServerEvent('character_storage:upgradeStorage')
AddEventHandler('character_storage:upgradeStorage', function(storageId)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    -- Prevent managing preset storages this way
    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be upgraded.", 4000)
        return
    end
    
    -- Check if player is owner or has manager-level access
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    local accessLevel = GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade)
    if accessLevel ~= "owner" and accessLevel ~= "manager" then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end

    local storage = storageCache[storageId]
    local currentCapacity = tonumber(storage.capacity) or Config.DefaultCapacity
    
    -- Calculate the number of previous upgrades
    local previousUpgrades = math.floor((currentCapacity - Config.DefaultCapacity) / Config.StorageUpgradeSlots)
    
    -- Calculate the price with multiplier: BasePrice * (1 + Multiplier)^PreviousUpgrades
    local basePrice = Config.StorageUpgradePrice
    local multiplier = Config.StorageUpgradePriceMultiplier
    local upgradePrice = math.floor(basePrice * math.pow((1 + multiplier), previousUpgrades))
    
    -- Check if player has enough money
    if Character.money < upgradePrice then
        VORPcore.NotifyRightTip(source, GetTranslation("not_enough_money"), 4000)
        return
    end
    
    local newCapacity = currentCapacity + Config.StorageUpgradeSlots
    
    -- Update storage capacity
    DB.UpdateStorageCapacity(storageId, newCapacity, function(success)
        if success then
            -- Remove money from player
            Character.removeCurrency(0, upgradePrice)
            
            -- Update cache
            storage.capacity = newCapacity
            
            -- Update inventory limit
            local prefix = "character_storage_" .. storageId
            VORPinv:updateCustomInventorySlots(prefix, newCapacity)
            
            VORPcore.NotifyRightTip(source, GetTranslation("storage_upgraded", upgradePrice), 4000)
            
            -- Refresh the player's storage data so the client has updated capacity info
            RefreshPlayerStorages(source)
        end
    end)
end)

-- Rename storage
RegisterServerEvent('character_storage:renameStorage')
AddEventHandler('character_storage:renameStorage', function(storageId, newName)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    -- Prevent managing preset storages this way
    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Preset storages cannot be renamed.", 4000)
        return
    end
    
    -- Check if player is storage owner
    if not IsStorageOwner(charId, storageId) then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    -- Sanitize the name (remove any potential SQL injection)
    newName = newName:gsub("'", ""):gsub(";", ""):gsub("-", ""):sub(1, 50)
    
    -- Update storage name
    local query = "UPDATE character_storage SET storage_name = ? WHERE id = ?"
    exports.oxmysql:execute(query, {newName, storageId}, function(result)
        if result.affectedRows > 0 then
            -- Update cache
            storageCache[storageId].storage_name = newName
            
            -- Get the current inventory data to preserve its settings
            local prefix = "character_storage_" .. storageId
            local currentStorage = storageCache[storageId]
            currentStorage.isPreset = false -- Ensure it's marked as not a preset for RegisterStorageInventory
            
            -- Remove existing inventory and re-register with new name
            VORPinv:removeInventory(prefix)
            
            -- Re-register the inventory with the new name
            local data = {
                id = prefix,
                name = newName .. " #" .. storageId, -- For DB storage, name includes #id
                limit = currentStorage.capacity,
                acceptWeapons = true,
                shared = true,
                ignoreItemStackLimit = true,
                whitelistItems = false,
                UsePermissions = false,
                UseBlackList = false,
                whitelistWeapons = false
            }
            VORPinv:registerInventory(data)
            
            -- Notify client
            VORPcore.NotifyRightTip(source, GetTranslation("storage_renamed"), 4000)
            
            -- Refresh owner's storage data
            RefreshPlayerStorages(source)
            
            -- Update all clients with new storage name
            TriggerClientEvent('character_storage:updateStorageName', -1, storageId, newName)
        end
    end)
end)

-- Admin command to move a storage
RegisterCommand(Config.adminmovestorage, function(source, args, rawCommand)
    local Character = VORPcore.getUser(source).getUsedCharacter
    local group = Character.group
    
    -- Check if player is admin
    if group ~= "admin" then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    local storageId = tonumber(args[1])
    local x = tonumber(args[2])
    local y = tonumber(args[3])
    local z = tonumber(args[4])
    
    if not storageId or not x or not y or not z then
        VORPcore.NotifyRightTip(source, "Usage: /movestorage id x y z", 4000)
        return
    end
    
    -- Check if storage exists
    if not storageCache[storageId] then
        VORPcore.NotifyRightTip(source, "Storage not found", 4000)
        return
    end
    
    -- Update storage location
    DB.UpdateStorageLocation(storageId, x, y, z, function(success)
        if success then
            -- Update cache
            storageCache[storageId].pos_x = x
            storageCache[storageId].pos_y = y
            storageCache[storageId].pos_z = z
            
            -- Update all clients with new storage location
            TriggerClientEvent('character_storage:updateStorageLocation', -1, storageId, x, y, z)
            VORPcore.NotifyRightTip(source, GetTranslation("storage_moved", storageId), 4000)
        end
    end)
end, false)

-- Admin command to delete a storage
RegisterCommand(Config.admindeletestorage, function(source, args, rawCommand)
    local Character = VORPcore.getUser(source).getUsedCharacter
    local group = Character.group
    
    -- Check if player is admin
    if group ~= "admin" then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    local storageId = tonumber(args[1])
    
    if not storageId then
        VORPcore.NotifyRightTip(source, GetTranslation("usage_deletestorage"), 4000)
        return
    end
    
    -- Check if storage exists
    if not storageCache[storageId] then
        VORPcore.NotifyRightTip(source, GetTranslation("storage_not_found"), 4000)
        return
    end
    
    DebugLog("Admin " .. source .. " is deleting storage #" .. storageId)
    
    -- Delete storage
    DB.DeleteStorage(storageId, function(success)
        if success then
            -- Remove inventory first
            local prefix = "character_storage_" .. storageId
            VORPinv:removeInventory(prefix)
            DebugLog("Removed inventory for storage #" .. storageId)
            
            -- Remove from cache
            storageCache[storageId] = nil
            DebugLog("Removed storage #" .. storageId .. " from server cache")
            
            -- Notify all clients to remove this storage from their data
            TriggerClientEvent('character_storage:removeStorage', -1, storageId)
            DebugLog("Notified all clients to remove storage #" .. storageId)
            
            -- Notify the admin
            VORPcore.NotifyRightTip(source, GetTranslation("storage_deleted", storageId), 4000)
        else
            VORPcore.NotifyRightTip(source, "Failed to delete storage #" .. storageId, 4000)
        end
    end)
end, false)

-- Get player storages
RegisterServerEvent('character_storage:getPlayerStorages')
AddEventHandler('character_storage:getPlayerStorages', function()
    local source = source
    -- Send ALL storages (DB + presets) so the client prompt works correctly
    SendAllStoragesToPlayer(source)
end)

-- Get all online players with their positions
RegisterServerEvent('character_storage:getOnlinePlayers')
AddEventHandler('character_storage:getOnlinePlayers', function()
    local source = source
    local _source = source
    local playersList = {}
    
    -- Loop through all players
    for _, playerId in ipairs(GetPlayers()) do
        if tonumber(playerId) ~= tonumber(_source) then -- Skip the requesting player
            local targetUser = VORPcore.getUser(playerId)
            if targetUser then
                local targetCharacter = targetUser.getUsedCharacter
                local targetPed = GetPlayerPed(playerId)
                local targetCoords = GetEntityCoords(targetPed)
                
                table.insert(playersList, {
                    serverId = playerId,
                    charId = targetCharacter.charIdentifier,
                    name = targetCharacter.firstname .. " " .. targetCharacter.lastname,
                    coords = {
                        x = targetCoords.x,
                        y = targetCoords.y,
                        z = targetCoords.z
                    }
                })
            end
        end
    end
    
    TriggerClientEvent('character_storage:receiveOnlinePlayers', source, playersList)
end)

-- Add this event handler to respond to character name requests from clients
RegisterServerEvent("character_storage:getCharacterName")
AddEventHandler("character_storage:getCharacterName", function(charId, callbackId)
    local _source = source
    
    exports.oxmysql:execute("SELECT firstname, lastname FROM characters WHERE charidentifier = ?", {charId}, function(result)
        local name = nil
        if result and #result > 0 then
            name = result[1].firstname .. " " .. result[1].lastname
        end
        TriggerClientEvent(callbackId, _source, name)
    end)
end)

-- Get authorized users for a storage
exports('GetAuthorizedUsers', function(storageId)
    local storage = storageCache[storageId]
    if storage then
        return json.decode(storage.authorized_users or '[]')
    end
    return {}
end)

-- Expose Database API for external use
exports('GetDatabaseAPI', function()
    return DB
end)

-- New event to update job access rules
RegisterServerEvent('character_storage:updateJobAccess')
AddEventHandler('character_storage:updateJobAccess', function(storageId, jobName, ruleData)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier

    -- Prevent managing preset storages this way
    if storageCache[storageId] and storageCache[storageId].isPreset then
        VORPcore.NotifyRightTip(source, "Job access for preset storages is managed in the config.", 4000)
        return
    end

    if not IsStorageOwner(charId, storageId) then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end

    local storage = storageCache[storageId]
    if not storage then
        VORPcore.NotifyRightTip(source, GetTranslation("storage_not_found"), 4000)
        return
    end

    local authorizedJobs = json.decode(storage.authorized_jobs or '{}')

    if ruleData == nil then -- Remove rule
        if authorizedJobs[jobName] then
            authorizedJobs[jobName] = nil
            DB.UpdateAuthorizedJobs(storageId, json.encode(authorizedJobs), function(success)
                if success then
                    storage.authorized_jobs = json.encode(authorizedJobs)
                    VORPcore.NotifyRightTip(source, GetTranslation("job_rule_removed", jobName), 4000)
                    RefreshPlayerStorages(source)
                end
            end)
        end
    else -- Add or update rule
        -- Validate ruleData structure (grades array or all_grades boolean)
        if (type(ruleData.grades) == "table" or ruleData.all_grades == true) and type(jobName) == "string" and jobName ~= "" then
            authorizedJobs[jobName] = ruleData
            DB.UpdateAuthorizedJobs(storageId, json.encode(authorizedJobs), function(success)
                if success then
                    storage.authorized_jobs = json.encode(authorizedJobs)
                    VORPcore.NotifyRightTip(source, GetTranslation("job_rule_added", jobName), 4000)
                    RefreshPlayerStorages(source)
                end
            end)
        else
            VORPcore.NotifyRightTip(source, GetTranslation("invalid_job_or_grades"), 4000)
        end
    end
end)

-- Helper function to get translation based on character's language
function GetTranslation(key, ...)
    local lang = Config.DefaultLanguage
    
    -- Simple format function
    local result = Config.Translations[lang][key] or key
    
    if ... then
        result = string.format(result, ...)
    end
    
    return result
end

-- Admin command to check permissions for showing/hiding all storage blips
RegisterServerEvent("character_storage:checkAdminPermission")
AddEventHandler("character_storage:checkAdminPermission", function(action)
    local _source = source
    local User = VORPcore.getUser(_source)
    
    if not User then
        DebugLog("User not found for source: " .. tostring(_source))
        return
    end
    
    local Character = User.getUsedCharacter
    local group = Character.group
    
    -- Check if player is admin
    if group == "admin" then
        TriggerClientEvent("character_storage:toggleAdminMode", _source, action == "show")
        DebugLog("Admin " .. _source .. " toggled storage admin mode: " .. action)
    else
        VORPcore.NotifyRightTip(_source, GetTranslation("no_permission"), 4000)
        DebugLog("Non-admin " .. _source .. " attempted to use admin storage command")
    end
end)

-- Add an event that other resources can trigger to refresh storage data for players
RegisterNetEvent("character_storage:refreshAllPlayerStorages")
AddEventHandler("character_storage:refreshAllPlayerStorages", function()
    SendStoragesToAllPlayers()
end)

-- Export function to allow other resources to request a storage data refresh
exports('RefreshAllPlayerStorages', function()
    SendStoragesToAllPlayers()
    return true
end)

-- Deposit money into storage
RegisterServerEvent('character_storage:depositMoney')
AddEventHandler('character_storage:depositMoney', function(storageId, amount)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    
    -- Validate amount
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        VORPcore.NotifyRightTip(source, GetTranslation("invalid_amount"), 4000)
        return
    end
    
    -- Deposit requires at least member-level access
    local depositAccessLevel = GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade)
    if not depositAccessLevel or depositAccessLevel == "basic" then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    -- Check if player has enough money
    if Character.money < amount then
        VORPcore.NotifyRightTip(source, GetTranslation("insufficient_funds"), 4000)
        return
    end
    
    -- Get player name
    local playerName = Character.firstname .. " " .. Character.lastname
    
    -- Remove money from player
    Character.removeCurrency(0, amount)
    
    -- Add to storage and ledger
    DB.AddLedgerEntry(storageId, playerName, amount, "deposit", function(success)
        if success then
            VORPcore.NotifyRightTip(source, GetTranslation("deposit_success", string.format("%.2f", amount)), 4000)
            
            -- Update last_accessed timestamp
            if storageCache[storageId] and not storageCache[storageId].isPreset then
                DB.UpdateLastAccessed(storageId)
            end
            
            -- Refresh storage data for player
            TriggerClientEvent('character_storage:updateStorageBalance', source, storageId)
        end
    end)
end)

-- Withdraw money from storage
RegisterServerEvent('character_storage:withdrawMoney')
AddEventHandler('character_storage:withdrawMoney', function(storageId, amount)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    
    -- Validate amount
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        VORPcore.NotifyRightTip(source, GetTranslation("invalid_amount"), 4000)
        return
    end
    
    -- Withdraw requires manager-level access or higher
    local withdrawAccessLevel = GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade)
    if withdrawAccessLevel ~= "owner" and withdrawAccessLevel ~= "manager" then
        VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        return
    end
    
    -- Check storage balance
    DB.GetStorageBalance(storageId, function(currentBalance, ledger)
        if currentBalance < amount then
            VORPcore.NotifyRightTip(source, GetTranslation("insufficient_storage_funds"), 4000)
            return
        end
        
        -- Get player name
        local playerName = Character.firstname .. " " .. Character.lastname
        
        -- Add ledger entry and update balance
        DB.AddLedgerEntry(storageId, playerName, amount, "withdrawal", function(success)
            if success then
                -- Give money to player
                Character.addCurrency(0, amount)
                VORPcore.NotifyRightTip(source, GetTranslation("withdraw_success", string.format("%.2f", amount)), 4000)
                
                -- Update last_accessed timestamp
                if storageCache[storageId] and not storageCache[storageId].isPreset then
                    DB.UpdateLastAccessed(storageId)
                end
                
                -- Refresh storage data for player
                TriggerClientEvent('character_storage:updateStorageBalance', source, storageId)
            end
        end)
    end)
end)

-- Get storage balance and ledger
RegisterServerEvent('character_storage:getStorageBalance')
AddEventHandler('character_storage:getStorageBalance', function(storageId)
    local source = source
    local Character = VORPcore.getUser(source).getUsedCharacter
    local charId = Character.charIdentifier
    local playerJob = Character.job
    local playerJobGrade = Character.jobGrade
    
    -- Viewing balance/ledger requires at least member-level access
    local balanceAccessLevel = GetUserAccessLevel(charId, storageId, playerJob, playerJobGrade)
    if not balanceAccessLevel or balanceAccessLevel == "basic" then
        return
    end
    
    DB.GetStorageBalance(storageId, function(balance, ledger)
        TriggerClientEvent('character_storage:receiveStorageBalance', source, storageId, balance, ledger)
    end)
end)

-- ============================================================
-- Armory Shop System — Store NUI Type (Infinite Virtual Stock)
-- Uses VORP inventory's built-in "store" NUI. Items are virtual
-- and NEVER consumed — the grid always shows the full catalogue.
-- Taking an item fires syn_store:TakeFromStore which we handle
-- server-side to give the item and charge the player.
-- ============================================================

-- Store ID prefix for armory shops (must not collide with syn_stores IDs)
local ARMORY_STORE_PREFIX = "cs_armory_"

-- Map of armory store IDs → shop config: { [storeId] = shopConfig }
local ArmoryStoreMap = {}

-- -------------------------------------------------------
-- Helpers
-- -------------------------------------------------------

local function GetArmoryShopById(shopId)
    if not Config.ArmoryShops then return nil end
    for _, shop in ipairs(Config.ArmoryShops) do
        if shop.id == shopId then return shop end
    end
    return nil
end

local function GetArmoryStoreId(shop)
    return ARMORY_STORE_PREFIX .. shop.id
end

local function HasArmoryAccess(playerJob, joblockList)
    if not joblockList or #joblockList == 0 then return true end
    for _, allowedJob in ipairs(joblockList) do
        if playerJob == allowedJob then return true end
    end
    return false
end

--- Build green HTML price string shown in the item description
local function FormatPriceDesc(price)
    if tonumber(price) == 0 then
        return "<span style='color:#4CAF50;font-weight:bold;'>Price: Free</span>"
    else
        return string.format("<span style='color:#4CAF50;font-weight:bold;'>Price: $%.2f</span>", tonumber(price))
    end
end

--- Build the full item payload to populate the store grid.
--- This is sent via vorp_inventory:ReloadStoreInventory.
local function BuildArmoryStorePayload(shop, _source)
    local itemList = {}
    for idx, itemConf in ipairs(shop.sellitems) do
        local priceHtml = FormatPriceDesc(itemConf.price)
        if itemConf.type == 'item_weapon' then
            table.insert(itemList, {
                id           = idx,
                name         = itemConf.name,
                label        = itemConf.label,
                count        = 1,
                type         = "item_weapon",
                desc         = priceHtml,
                custom_desc  = priceHtml,
                custom_label = itemConf.label,
                serial_number = "",
                group        = 5,
                metadata     = {},
            })
        else
            table.insert(itemList, {
                id       = idx,
                name     = itemConf.name,
                label    = itemConf.label,
                count    = 999,
                type     = "item_standard",
                desc     = priceHtml,
                metadata = { description = priceHtml },
            })
        end
    end
    return {
        itemList = itemList,
        action   = "setSecondInventoryItems",
        info     = { target = _source or 0, source = _source or 0 },
    }
end

-- -------------------------------------------------------
-- Build the ArmoryStoreMap on load
-- -------------------------------------------------------

Citizen.CreateThread(function()
    Citizen.Wait(2000)
    if not Config.ArmoryShops then return end
    for _, shop in ipairs(Config.ArmoryShops) do
        local storeId = GetArmoryStoreId(shop)
        ArmoryStoreMap[storeId] = shop
    end
    print("[ArmoryShop] Registered " .. #Config.ArmoryShops .. " armory store(s) (store NUI mode)")
end)

-- -------------------------------------------------------
-- Client → Server: Open Armory Store
-- -------------------------------------------------------

RegisterServerEvent('character_storage:armoryOpenStore')
AddEventHandler('character_storage:armoryOpenStore', function(shopId)
    local _source = source
    local User = VORPcore.getUser(_source)
    if not User then return end
    local Character = User.getUsedCharacter
    if not Character then return end

    local shop = GetArmoryShopById(shopId)
    if not shop then
        DebugLog("Armory: shop not found: " .. tostring(shopId))
        return
    end

    -- Verify job access server-side
    if not HasArmoryAccess(Character.job, shop.joblock) then
        TriggerClientEvent('character_storage:armoryAccessDenied', _source)
        return
    end

    local storeId = GetArmoryStoreId(shop)

    -- geninfo tells the store NUI this is a customer view with no sell-back
    local geninfo = {
        shoptype  = 1,
        isowner   = 0,
        buyitems  = {},   -- empty = player can't sell items TO the store
        sellitems = {},
    }

    -- 1) Open the store NUI (sets store mode + geninfo on client)
    TriggerClientEvent("vorp_inventory:OpenStoreInventory", _source, shop.Name, storeId, "oo", geninfo)

    -- 2) Small delay so the NUI frame renders, then send items
    SetTimeout(300, function()
        local payload = BuildArmoryStorePayload(shop, _source)
        TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
    end)

    DebugLog("Opened armory store " .. storeId .. " for player " .. _source)
end)

-- -------------------------------------------------------
-- syn_store:TakeFromStore — Handle armory purchases
-- When a player drags an item from the store to their
-- inventory, the NUI fires this event. We check if the
-- store belongs to one of our armory shops and, if so,
-- give the item and charge the player. Then we reload
-- the store grid (same items) to reset SynPending and
-- keep the catalogue intact.
-- -------------------------------------------------------

RegisterServerEvent('syn_store:TakeFromStore')
AddEventHandler('syn_store:TakeFromStore', function(obj)
    local _source = source
    local ok, data = pcall(json.decode, obj)
    if not ok or not data then return end

    local storeId = data.store
    if not storeId or not ArmoryStoreMap[storeId] then return end -- not ours

    local shop = ArmoryStoreMap[storeId]
    local item = data.item
    local amount = tonumber(data.number) or 1
    if not item or not item.name then return end

    -- Look up the item config from the shop's sell list
    local itemConfig = nil
    for _, conf in ipairs(shop.sellitems) do
        if conf.name == item.name then
            itemConfig = conf
            break
        end
    end
    if not itemConfig then
        DebugLog("Armory take: unknown item " .. tostring(item.name))
        -- Still reload to reset SynPending
        local payload = BuildArmoryStorePayload(shop, _source)
        TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
        return
    end

    -- Get player info
    local User = VORPcore.getUser(_source)
    if not User then return end
    local Character = User.getUsedCharacter
    if not Character then return end

    local price = tonumber(itemConfig.price) or 0
    local currType = Config.ArmoryCurrencyType or 0
    local qty = (itemConfig.type == 'item_weapon') and 1 or math.max(1, amount)
    local totalPrice = price * qty

    -- Check if player can afford
    if totalPrice > 0 then
        local playerMoney = (currType == 0) and Character.money or Character.gold
        if playerMoney < totalPrice then
            VORPcore.NotifyRightTip(_source, "Not enough money", 4000)
            local payload = BuildArmoryStorePayload(shop, _source)
            TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
            return
        end
    end

    -- Give item
    if itemConfig.type == 'item_weapon' then
        VORPinv:createWeapon(_source, item.name, {})
    else
        VORPinv:addItem(_source, item.name, qty)
    end

    -- Charge the player
    if totalPrice > 0 then
        Character.removeCurrency(currType, totalPrice)
    end

    -- Small delay so VORPinv updates the client's main inventory, then reload store
    SetTimeout(500, function()
        local payload = BuildArmoryStorePayload(shop, _source)
        TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
    end)

    local charName = Character.firstname .. " " .. Character.lastname
    local charId = Character.charIdentifier
    DebugLog("Armory purchase: " .. charName .. " took x" .. qty .. " " .. itemConfig.label .. " from " .. shop.Name .. " for $" .. totalPrice)

    -- Discord activity logging
    if DiscordTracker and DiscordTracker.LogArmoryPurchase then
        DiscordTracker.LogArmoryPurchase(shop.id, charId, charName, itemConfig.label .. " x" .. qty, totalPrice)
    end
end)

-- -------------------------------------------------------
-- syn_store:MoveToStore — Block storing items in armory
-- If a player drags an item from their inventory to the
-- armory store, we block it and reload to restore the UI.
-- -------------------------------------------------------

RegisterServerEvent('syn_store:MoveToStore')
AddEventHandler('syn_store:MoveToStore', function(obj)
    local _source = source
    local ok, data = pcall(json.decode, obj)
    if not ok or not data then return end

    local storeId = data.store
    if not storeId or not ArmoryStoreMap[storeId] then return end -- not ours

    local shop = ArmoryStoreMap[storeId]
    VORPcore.NotifyRightTip(_source, "Cannot store items in the armory", 3000)

    -- Reload to restore the player's inventory in the NUI
    SetTimeout(200, function()
        local payload = BuildArmoryStorePayload(shop, _source)
        TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
    end)
end)

-- ============================================================
-- Admin Shop — All Items Store (admin-only command)
-- Queries the DB `items` table + VORP SharedData.Weapons to
-- build a full alphabetical catalogue. Opens the same store
-- NUI so items are infinite / virtual. Completely free.
-- ============================================================

local ADMIN_STORE_ID = "cs_admin_shop"
local AdminShopItemCache = nil   -- populated lazily on first use
local AdminShopCacheTime = 0     -- timestamp of last cache build
local ADMIN_CACHE_TTL = 300      -- rebuild cache every 5 minutes

--- Build (or return cached) alphabetical item list from DB + weapons
local function GetAdminShopItems(cb)
    local now = os.time()
    if AdminShopItemCache and (now - AdminShopCacheTime) < ADMIN_CACHE_TTL then
        return cb(AdminShopItemCache)
    end

    exports.oxmysql:execute("SELECT item, label, `limit`, `desc`, type FROM items ORDER BY label ASC", {}, function(dbItems)
        local items = {}
        local seen = {}  -- track names to avoid duplicates

        -- 1) Add all DB items (standard items)
        if dbItems then
            for _, row in ipairs(dbItems) do
                if row.item and row.label then
                    table.insert(items, {
                        name  = row.item,
                        label = row.label,
                        type  = "item_standard",
                        desc  = row.desc or "",
                    })
                    seen[row.item] = true
                end
            end
        end

        -- 2) Add all weapons from VORP SharedData.Weapons
        if SharedData and SharedData.Weapons then
            for hashName, wpn in pairs(SharedData.Weapons) do
                if not seen[hashName] then
                    table.insert(items, {
                        name  = hashName,
                        label = wpn.Name or hashName,
                        type  = "item_weapon",
                        desc  = wpn.Desc or "",
                    })
                    seen[hashName] = true
                end
            end
        end

        -- 3) Sort alphabetically by label (case-insensitive)
        table.sort(items, function(a, b)
            return string.lower(a.label) < string.lower(b.label)
        end)

        AdminShopItemCache = items
        AdminShopCacheTime = now
        DebugLog("Admin shop cache built: " .. #items .. " items")
        cb(items)
    end)
end

--- Build the store NUI payload from the admin item list
local function BuildAdminStorePayload(items, _source)
    local itemList = {}
    for idx, it in ipairs(items) do
        local freeHtml = "<span style='color:#4CAF50;font-weight:bold;'>Free</span>"
        if it.type == "item_weapon" then
            table.insert(itemList, {
                id            = idx,
                name          = it.name,
                label         = it.label,
                count         = 1,
                type          = "item_weapon",
                desc          = freeHtml,
                custom_desc   = freeHtml,
                custom_label  = it.label,
                serial_number = "",
                group         = 5,
                metadata      = {},
            })
        else
            table.insert(itemList, {
                id       = idx,
                name     = it.name,
                label    = it.label,
                count    = 999,
                type     = "item_standard",
                desc     = freeHtml,
                metadata = { description = freeHtml },
            })
        end
    end
    return {
        itemList = itemList,
        action   = "setSecondInventoryItems",
        info     = { target = _source or 0, source = _source or 0 },
    }
end

-- -------------------------------------------------------
-- /adminshop command
-- -------------------------------------------------------

RegisterCommand(Config.adminShopCommand or 'adminshop', function(_source, args, rawCommand)
    if _source == 0 then print("[AdminShop] Cannot run from console") return end

    local User = VORPcore.getUser(_source)
    if not User then return end
    local Character = User.getUsedCharacter
    if not Character then return end

    -- Admin check (same pattern as existing admin commands)
    if Character.group ~= "admin" then
        VORPcore.NotifyRightTip(_source, GetTranslation("adminshop_not_admin") or "Admin only", 4000)
        return
    end

    VORPcore.NotifyRightTip(_source, GetTranslation("adminshop_loading") or "Loading...", 2000)

    GetAdminShopItems(function(items)
        if not items or #items == 0 then
            VORPcore.NotifyRightTip(_source, "No items found in database", 4000)
            return
        end

        local storeName = GetTranslation("adminshop_name") or "Admin Item Shop"
        local geninfo = {
            shoptype  = 1,
            isowner   = 0,
            buyitems  = {},
            sellitems = {},
        }

        -- Open the store NUI
        TriggerClientEvent("vorp_inventory:OpenStoreInventory", _source, storeName, ADMIN_STORE_ID, "oo", geninfo)

        -- Send item list after a short delay
        SetTimeout(300, function()
            local payload = BuildAdminStorePayload(items, _source)
            TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
        end)

        DebugLog("Admin " .. Character.firstname .. " " .. Character.lastname .. " opened admin shop (" .. #items .. " items)")
    end)
end, false)

-- -------------------------------------------------------
-- syn_store:TakeFromStore — Admin shop purchases (free)
-- We hook the same event; if storeId matches ADMIN_STORE_ID
-- we give the item for free. The armory handler above
-- already returns early for non-armory stores, and this
-- handler returns early for non-admin-shop stores.
-- -------------------------------------------------------

-- Note: We piggyback on the existing syn_store:TakeFromStore.
-- FiveM/RedM allows MULTIPLE handlers for the same event.
-- The armory handler above checks ArmoryStoreMap and returns
-- early if the store isn't an armory. This handler checks
-- for ADMIN_STORE_ID and returns early otherwise.

AddEventHandler('syn_store:TakeFromStore', function(obj)
    local _source = source
    local ok, data = pcall(json.decode, obj)
    if not ok or not data then return end

    if data.store ~= ADMIN_STORE_ID then return end -- not ours

    local item = data.item
    local amount = tonumber(data.number) or 1
    if not item or not item.name then return end

    -- Re-verify admin
    local User = VORPcore.getUser(_source)
    if not User then return end
    local Character = User.getUsedCharacter
    if not Character then return end
    if Character.group ~= "admin" then return end

    -- Give item (free)
    if item.type == "item_weapon" then
        VORPinv:createWeapon(_source, item.name, {})
    else
        VORPinv:addItem(_source, item.name, math.max(1, amount))
    end

    DebugLog("Admin shop: " .. Character.firstname .. " " .. Character.lastname .. " took x" .. amount .. " " .. item.name)

    -- Reload the store to reset SynPending
    GetAdminShopItems(function(items)
        local payload = BuildAdminStorePayload(items, _source)
        TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
    end)
end)

-- Block storing into admin shop
AddEventHandler('syn_store:MoveToStore', function(obj)
    local _source = source
    local ok, data = pcall(json.decode, obj)
    if not ok or not data then return end

    if data.store ~= ADMIN_STORE_ID then return end

    VORPcore.NotifyRightTip(_source, "Cannot store items here", 3000)

    GetAdminShopItems(function(items)
        local payload = BuildAdminStorePayload(items, _source)
        TriggerClientEvent("vorp_inventory:ReloadStoreInventory", _source, json.encode(payload), false)
    end)
end)
