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
    end)
end

-- Load all storages into cache on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    LoadAllStorages()
    
    -- Add a small delay to ensure everything is loaded properly
    Citizen.SetTimeout(1000, function()
        SendStoragesToAllPlayers()
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
                if Character then
                    SendAllStoragesToPlayer(source)
                    sentCount = sentCount + 1
                    DebugLog("Sent storage data to player " .. source .. " (Character ID: " .. Character.charIdentifier .. ")")
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

-- Check if player has access to a storage
function HasStorageAccess(charId, storageId, playerJob, playerJobGrade)
    local storage = storageCache[storageId]
    
    if not storage then return false end

    -- Handle Preset Storages
    if storage.isPreset then
        -- Check authorized_charids from config
        if storage.authorized_charids_config then
            for _, allowedCharId in ipairs(storage.authorized_charids_config) do
                if tonumber(allowedCharId) == tonumber(charId) then
                    return true
                end
            end
        end
        -- Check job-based access from config
        if playerJob and playerJobGrade ~= nil and storage.authorized_jobs_config then
            local jobRules = storage.authorized_jobs_config[playerJob]
            if jobRules then
                if jobRules.all_grades then
                    return true
                elseif jobRules.grades then
                    for _, grade in ipairs(jobRules.grades) do
                        if tonumber(grade) == tonumber(playerJobGrade) then
                            return true
                        end
                    end
                end
            end
        end
        return false -- If no explicit charid or job match for preset
    end
    
    -- Owner always has access (for DB storages)
    if tonumber(storage.owner_charid) == tonumber(charId) then
        return true
    end
    
    -- Check authorized users (personal access)
    local authorizedUsers = json.decode(storage.authorized_users or '[]')
    for _, id in pairs(authorizedUsers) do
        if tonumber(id) == tonumber(charId) then
            return true
        end
    end

    -- Check job-based access
    if playerJob and playerJobGrade ~= nil then
        local authorizedJobs = json.decode(storage.authorized_jobs or '{}')
        if authorizedJobs[playerJob] then
            local jobRule = authorizedJobs[playerJob]
            if jobRule.all_grades then
                return true
            elseif jobRule.grades then
                for _, grade in ipairs(jobRule.grades) do
                    if tonumber(grade) == tonumber(playerJobGrade) then
                        return true
                    end
                end
            end
        end
    end
    
    return false
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
            VORPinv:openInventory(source, prefix)
        else
            VORPcore.NotifyRightTip(source, GetTranslation("no_permission"), 4000)
        end
        return
    end
    
    -- For regular storages, update timestamp on ANY access attempt
    DebugLog("Updating last_accessed timestamp for regular storage #" .. storageId .. " (checkOwnership call)")
    DB.UpdateLastAccessed(storageId)
    
    -- If player is owner (DB storage), show the owner menu
    if IsStorageOwner(charId, storageId) then
        TriggerClientEvent('character_storage:openOwnerMenu', source, storageId)
    -- If player has access (personal, job, or admin), open storage directly
    elseif HasStorageAccess(charId, storageId, playerJob, playerJobGrade) or group == "admin" then
        local prefix = "character_storage_" .. storageId
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
        
        -- Update authorized users
        local storage = storageCache[storageId]
        local authorizedUsers = json.decode(storage.authorized_users or '[]')
        
        -- Check if user is already authorized
        for _, id in pairs(authorizedUsers) do
            if tonumber(id) == tonumber(targetCharId) then
                VORPcore.NotifyRightTip(source, GetTranslation("already_has_access"), 4000)
                return
            end
        end
        
        -- Add user to authorized users
        table.insert(authorizedUsers, targetCharId)
        
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
    
    -- Update authorized users
    local storage = storageCache[storageId]
    local authorizedUsers = json.decode(storage.authorized_users or '[]')
    local newAuthorizedUsers = {}
    
    -- Filter out the target user
    for _, id in pairs(authorizedUsers) do
        if tonumber(id) ~= tonumber(targetCharId) then
            table.insert(newAuthorizedUsers, id)
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
    
    local authorizedUsers = {}
    -- Safely parse JSON
    local success = pcall(function() 
        authorizedUsers = json.decode(storage.authorized_users or '[]')
    end)
    
    if not success then
        DebugLog("ERROR: Failed to parse authorized_users JSON")
        VORPcore.NotifyRightTip(source, "Error processing storage data", 4000)
        return
    end
    
    DebugLog("Current authorized users: " .. json.encode(authorizedUsers))
    
    -- Create new list without target user
    local newAuthorizedUsers = {}
    local wasRemoved = false
    local targetSource = nil
    
    for _, id in pairs(authorizedUsers) do
        if tonumber(id) ~= targetCharId then
            table.insert(newAuthorizedUsers, tonumber(id))
        else
            wasRemoved = true
            DebugLog("User " .. id .. " will be removed")
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
    
    -- Check if player is storage owner
    if not IsStorageOwner(charId, storageId) then
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
    RefreshPlayerStorages(source)
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
    
    -- Check if player has access
    if not HasStorageAccess(charId, storageId, playerJob, playerJobGrade) then
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
    
    -- Check if player has access
    if not HasStorageAccess(charId, storageId, playerJob, playerJobGrade) then
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
    
    -- Check if player has access
    if not HasStorageAccess(charId, storageId, playerJob, playerJobGrade) then
        return
    end
    
    DB.GetStorageBalance(storageId, function(balance, ledger)
        TriggerClientEvent('character_storage:receiveStorageBalance', source, storageId, balance, ledger)
    end)
end)
