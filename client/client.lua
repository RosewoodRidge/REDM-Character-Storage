local VORPcore = exports.vorp_core:GetCore()
local storageBlips = {}
local playerStorages = {}
local nearestStorage = nil
local isAdminMode = false -- Track whether admin mode is enabled

-- Prompt variables
local PromptGroup = GetRandomIntInRange(0, 0xffffff)
local StoragePrompt

-- Helper function to get translation
function GetTranslation(key, ...)
    local lang = Config.DefaultLanguage
    if Config.Translations[lang] and Config.Translations[lang][key] then
        local text = Config.Translations[lang][key]
        if ... then
            return string.format(text, ...)
        end
        return text
    end
    return key
end

-- Helper function for debug messages
function DebugMsg(message)
    if Config.Debug then
        print("[DEBUG] " .. message)
    end
end

-- Initialize the script
Citizen.CreateThread(function()
    -- Initialize prompts
    InitializePrompts()
    
    -- Start the main loop
    MainLoop()
    
    -- Add event listeners for character loading
    RegisterEventHandlers()
    
    -- Request storages on startup (covers resource restarts while player is already in-game)
    Citizen.Wait(3000)
    TriggerServerEvent('character_storage:getPlayerStorages')
end)

-- Register character-related event handlers
function RegisterEventHandlers()
    -- When character is selected and player spawns
    AddEventHandler('vorp:SelectedCharacter', function()
        DebugMsg("Character selected, requesting storage data")
        TriggerServerEvent('character_storage:getPlayerStorages')
    end)
    
    -- Add event for when player fully loads in (safety measure)
    RegisterNetEvent('vorp:playerSpawn')
    AddEventHandler('vorp:playerSpawn', function()
        DebugMsg("Player spawned, requesting storage data")
        Citizen.Wait(1000) -- Short delay to ensure server is ready
        TriggerServerEvent('character_storage:getPlayerStorages')
    end)
end

-- Initialize prompts using native system
function InitializePrompts()
    StoragePrompt = PromptRegisterBegin()
    PromptSetControlAction(StoragePrompt, Config.PromptKey)
    local str = CreateVarString(10, 'LITERAL_STRING', GetTranslation("open_storage_prompt"))
    PromptSetText(StoragePrompt, str)
    PromptSetEnabled(StoragePrompt, true)
    PromptSetVisible(StoragePrompt, true)
    PromptSetStandardMode(StoragePrompt, true)
    PromptSetGroup(StoragePrompt, PromptGroup)
    PromptRegisterEnd(StoragePrompt)
end

-- Main loop to check for storage interactions
function MainLoop()
    Citizen.CreateThread(function()
        while true do
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local wait = 1000
            nearestStorage = nil -- Reset nearest storage each loop iteration
            
            -- Check if player is near any storage location
            for _, storage_item in pairs(playerStorages) do
                if storage_item and (storage_item.locations or storage_item.pos_x) then
                    local storageLocations = {}
                    if storage_item.locations and #storage_item.locations > 0 then 
                        storageLocations = storage_item.locations
                    elseif storage_item.pos_x then 
                        storageLocations = { vector3(storage_item.pos_x, storage_item.pos_y, storage_item.pos_z) }
                    end

                    for loc_idx, locCoords in ipairs(storageLocations) do
                        if locCoords then
                            local dist = #(coords - locCoords)
                            
                            if dist <= Config.AccessRadius then
                                nearestStorage = storage_item -- Store the whole storage object
                                wait = 0
                                
                                local baseName
                                local displayIdSuffix

                                if nearestStorage.isPreset then
                                    baseName = nearestStorage.name or "Preset"
                                    if nearestStorage.linked then
                                        displayIdSuffix = " #" .. loc_idx
                                    else
                                        displayIdSuffix = " #" .. (nearestStorage.location_index or loc_idx)
                                    end
                                else
                                    baseName = nearestStorage.storage_name or "Storage"
                                    displayIdSuffix = " #" .. nearestStorage.id
                                end
                                local displayName = baseName .. displayIdSuffix

                                local label = CreateVarString(10, 'LITERAL_STRING', displayName)
                                PromptSetActiveGroupThisFrame(PromptGroup, label)
                                
                                if PromptHasStandardModeCompleted(StoragePrompt) then
                                    TriggerServerEvent('character_storage:checkOwnership', nearestStorage.id)
                                    Wait(1000) 
                                end
                                goto next_loop_iteration -- Found a storage, process and break from inner loops
                            end
                        end
                    end
                end
            end
            ::next_loop_iteration::
            
            Citizen.Wait(wait)
        end
    end)
end

-- Create blips for player storages
function CreateStorageBlips()
    -- Remove existing blips
    for i, blip in pairs(storageBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
            storageBlips[i] = nil
        end
    end
    storageBlips = {}

    if Config.Debug then
        DebugMsg("--- Dumping playerStorages before creating blips ---")
        if playerStorages and #playerStorages > 0 then
            for i, item in ipairs(playerStorages) do
                local item_id = item.id or "NO_ID"
                local item_name = item.name or item.storage_name or "NO_NAME"
                local item_isPreset = tostring(item.isPreset)
                local item_blipSprite = tostring(item.blipSprite)
                local item_hasAccess = tostring(item.hasAccess or false)
                local item_locations_json = "NIL_LOCATIONS"
                if item.locations then
                    item_locations_json = json.encode(item.locations)
                else
                    item_locations_json = "MISSING_OR_EMPTY_LOCATIONS_ARRAY"
                end
                DebugMsg(string.format("Item %d: ID=%s, Name=%s, isPreset=%s, hasAccess=%s, blipSprite=%s, locations=%s, linked=%s, location_index=%s",
                    i, tostring(item_id), tostring(item_name), item_isPreset, item_hasAccess, item_blipSprite, item_locations_json, tostring(item.linked), tostring(item.location_index)))
            end
        else
            DebugMsg("playerStorages is empty or nil.")
        end
        DebugMsg("--- End of playerStorages dump ---")
    end
    
    -- Create new blips
    if Config.UseBlips then
        for _, storage_item in pairs(playerStorages) do
            -- Only create blips for storages the player has access to OR if admin mode is enabled
            if storage_item and (storage_item.hasAccess or isAdminMode) then
                if Config.Debug then
                    DebugMsg("Processing storage item for blip creation: " .. json.encode(storage_item))
                end

                local blipSpriteToUse = Config.BlipSprite 
                local blipScaleToUse = 0.2 

                -- blipSprite = false means explicitly no blip for this storage
                if storage_item.isPreset and storage_item.blipSprite == false then
                    DebugMsg("Skipping blip (blipSprite = false) for storage ID: " .. (storage_item.id or "UNKNOWN"))
                    goto continue_outer_loop
                elseif storage_item.isPreset and storage_item.blipSprite ~= nil then
                    blipSpriteToUse = storage_item.blipSprite 
                    DebugMsg("Using PRESET blip sprite: " .. tostring(blipSpriteToUse) .. " for storage ID: " .. (storage_item.id or "UNKNOWN"))
                elseif not storage_item.isPreset then
                    DebugMsg("Using DEFAULT DB blip sprite: " .. tostring(blipSpriteToUse) .. " for storage ID: " .. (storage_item.id or "UNKNOWN"))
                else
                    DebugMsg("Warning: Preset storage ID " .. (storage_item.id or "UNKNOWN") .. " has nil blipSprite. Falling back to default: " .. Config.BlipSprite)
                end

                local storageLocationsToBlip = {}
                -- Rely on the .locations array, which server should now provide for all types.
                if storage_item.locations and #storage_item.locations > 0 then
                    storageLocationsToBlip = storage_item.locations
                else
                    DebugMsg("Skipping blip creation for storage ID: " .. (storage_item.id or "UNKNOWN") .. " - .locations array is missing or empty.")
                    goto continue_outer_loop -- Skip to next storage_item if no locations
                end

                for loc_idx, locCoords in ipairs(storageLocationsToBlip) do
                    if locCoords and locCoords.x and locCoords.y and locCoords.z then
                        DebugMsg("Attempting to create blip for " .. (storage_item.id or "UNKNOWN") .. " at loc_idx " .. loc_idx .. ": " .. json.encode(locCoords) .. " with sprite " .. blipSpriteToUse)
                        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, locCoords.x, locCoords.y, locCoords.z)
                        if blip and DoesBlipExist(blip) then
                            SetBlipSprite(blip, blipSpriteToUse, 1)
                            SetBlipScale(blip, blipScaleToUse) 
                            
                            local baseName
                            local displayIdSuffix

                            if storage_item.isPreset then
                                baseName = storage_item.name or "Preset"
                                if storage_item.linked then
                                    displayIdSuffix = " #" .. loc_idx
                                else
                                    displayIdSuffix = " #" .. (storage_item.location_index or loc_idx)
                                end
                            else
                                baseName = storage_item.storage_name or GetTranslation("storage_title", storage_item.id)
                                displayIdSuffix = " #" .. storage_item.id
                            end
                            local displayName = baseName .. displayIdSuffix

                            Citizen.InvokeNative(0x9CB1A1623062F402, blip, displayName)
                            table.insert(storageBlips, blip)
                            DebugMsg("SUCCESS: Created blip for storage ID: " .. (storage_item.id or "UNKNOWN") .. " at " .. string.format("%.2f", locCoords.x) .. "," .. string.format("%.2f", locCoords.y) .. "," .. string.format("%.2f", locCoords.z) .. " using sprite: " .. blipSpriteToUse)
                        else
                             DebugMsg("FAILED to create blip object for " .. (storage_item.id or "UNKNOWN") .. " at loc_idx " .. loc_idx)
                        end
                    else
                        DebugMsg("Invalid locCoords for storage ID: " .. (storage_item.id or "UNKNOWN") .. " at loc_idx: " .. loc_idx .. " Data: " .. json.encode(locCoords))
                    end
                end
            else
                if Config.Debug and storage_item then
                    DebugMsg("Skipping blip creation for storage ID: " .. (storage_item.id or "UNKNOWN") .. " - Player does not have access" .. (isAdminMode and " (but admin mode is enabled, this is a bug)" or ""))
                end
            end
            ::continue_outer_loop::
        end
        DebugMsg("Created " .. #storageBlips .. " storage blips in total")
    end
end

-- Register command for players to create a storage
RegisterCommand(Config.menustorage, function(source, args, rawCommand)
    local canCreate = true
    
    if canCreate then
        -- Use the menu function from menu.lua
        exports[GetCurrentResourceName()]:OpenCreateStorageMenu()
    else
        TriggerEvent('vorp:TipRight', GetTranslation("invalid_location"), 4000)
    end
end, false)

-- Add a suggestion for the command
TriggerEvent("chat:addSuggestion", "/createstorage", GetTranslation("create_storage_desc"))
TriggerEvent("chat:addSuggestion", "/" .. (Config.adminShopCommand or "adminshop"), GetTranslation("adminshop_desc") or "Opens a shop with every item on the server (admin only)")

-- Network event handlers
RegisterNetEvent('character_storage:receiveStorages')
AddEventHandler('character_storage:receiveStorages', function(storages)
    if not storages then
        DebugMsg("Received nil storages data")
        playerStorages = {}
        exports[GetCurrentResourceName()]:UpdateStorages(playerStorages)
        CreateStorageBlips() -- Changed back to direct call
        return
    end
    
    DebugMsg("Received " .. #storages .. " storage locations from server")
    playerStorages = storages or {} 
    
    -- Server should send complete data. This loop is a minimal integrity check.
    if Config.Debug then DebugMsg("--- Verifying received storages ---") end
    for i, storage_item in ipairs(playerStorages) do
        if storage_item.authorized_jobs == nil then
            playerStorages[i].authorized_jobs = '{}'
        end

        if Config.Debug then
            local item_id = storage_item.id or "NO_ID"
            local item_name = storage_item.name or storage_item.storage_name or "NO_NAME"
            local item_isPreset = tostring(storage_item.isPreset)
            local item_blipSprite = tostring(storage_item.blipSprite)
            local item_locations_json = "NIL_LOCATIONS"
            if storage_item.locations then
                item_locations_json = json.encode(storage_item.locations)
            end
            DebugMsg(string.format("Received Item %d: ID=%s, Name=%s, isPreset=%s, blipSprite=%s, locations=%s, linked=%s, location_index=%s",
                i, tostring(item_id), tostring(item_name), item_isPreset, item_blipSprite, item_locations_json, tostring(storage_item.linked), tostring(storage_item.location_index)))
        end

        -- Ensure essential fields for presets are present, log if not.
        if storage_item.isPreset then
            if not storage_item.name then DebugMsg("Warning: Preset storage ID " .. (storage_item.id or "UNKNOWN") .. " missing .name from server.") end
            if not storage_item.locations or #storage_item.locations == 0 then DebugMsg("Warning: Preset storage ID " .. (storage_item.id or "UNKNOWN") .. " missing or empty .locations from server.") end
            if storage_item.blipSprite == nil then DebugMsg("Warning: Preset storage ID " .. (storage_item.id or "UNKNOWN") .. " missing .blipSprite from server.") end
            if storage_item.linked == nil then DebugMsg("Warning: Preset storage ID " .. (storage_item.id or "UNKNOWN") .. " missing .linked boolean from server.") end
        end
    end
    if Config.Debug then DebugMsg("--- End of received storages verification ---") end
    
    exports[GetCurrentResourceName()]:UpdateStorages(playerStorages)
    CreateStorageBlips() -- Changed back to direct call
    
    if Config.Debug then
        print("[DEBUG] Storage data refreshed: " .. #playerStorages .. " storages available")
    end
end)

RegisterNetEvent('character_storage:updateStorageLocation')
AddEventHandler('character_storage:updateStorageLocation', function(id, x, y, z)
    for i, storage in ipairs(playerStorages) do
        if storage.id == id then
            playerStorages[i].pos_x = x
            playerStorages[i].pos_y = y
            playerStorages[i].pos_z = z
            break
        end
    end
    exports[GetCurrentResourceName()]:UpdateStorages(playerStorages)
    CreateStorageBlips() -- Changed back to direct call
end)

RegisterNetEvent('character_storage:updateStorageLocations')
AddEventHandler('character_storage:updateStorageLocations', function(storage)
    if storage.authorized_jobs == nil then
        storage.authorized_jobs = '{}'
    end
    
    -- Check if this is a config-defined preset storage by matching ID patterns
    if storage.isPreset == nil and Config.DefaultStorages then
         for _, presetConfig in ipairs(Config.DefaultStorages) do
            if presetConfig.id == storage.id or (presetConfig.id_prefix and string.sub(storage.id, 1, #presetConfig.id_prefix) == presetConfig.id_prefix) then
                storage.isPreset = true
                storage.name = storage.name or presetConfig.name
                storage.locations = storage.locations or presetConfig.locations
                storage.blipSprite = storage.blipSprite or presetConfig.blipSprite
                storage.linked = storage.linked
                if presetConfig.linked == false and not storage.locations then
                     storage.locations = {vector3(storage.pos_x, storage.pos_y, storage.pos_z)}
                end
                break
            end
        end
    end
    
    -- If still nil, it's not a preset storage
    if storage.isPreset == nil then
        storage.isPreset = false
    end
    
    table.insert(playerStorages, storage)
    exports[GetCurrentResourceName()]:UpdateStorages(playerStorages)
    CreateStorageBlips() -- Changed back to direct call
end)

RegisterNetEvent('character_storage:removeStorage')
AddEventHandler('character_storage:removeStorage', function(id)
    if nearestStorage and nearestStorage.id == id then
        DebugMsg("Clearing nearest storage reference as it was deleted")
        nearestStorage = nil
    end

    for i, storage in ipairs(playerStorages) do
        if storage.id == id then
            table.remove(playerStorages, i)
            DebugMsg("Removed storage #" .. id .. " from local storage table")
            break
        end
    end

    exports[GetCurrentResourceName()]:UpdateStorages(playerStorages)
    
    for i, blip in pairs(storageBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    storageBlips = {}
    
    -- Recreate blips
    CreateStorageBlips() -- Changed back to direct call
    DebugMsg("Recreated storage blips after deletion of storage #" .. id)
end)

RegisterNetEvent('character_storage:updateStorageName')
AddEventHandler('character_storage:updateStorageName', function(id, newName)
    for i, storage in ipairs(playerStorages) do
        if storage.id == id then
            playerStorages[i].storage_name = newName
            break
        end
    end
    exports[GetCurrentResourceName()]:UpdateStorages(playerStorages)
    CreateStorageBlips() -- Changed back to direct call
end)

-- Register admin command to toggle showing all storage blips
RegisterCommand(Config.adminStorageCommand, function(source, args, rawCommand)
    if not args[1] then
        VORPcore.NotifyRightTip(GetTranslation("admin_command_usage", Config.adminStorageCommand), 4000)
        return
    end
    
    local action = string.lower(args[1])
    
    if action == "show" then
        TriggerServerEvent("character_storage:checkAdminPermission", "show")
    elseif action == "hide" then
        TriggerServerEvent("character_storage:checkAdminPermission", "hide")
    else
        VORPcore.NotifyRightTip(GetTranslation("admin_invalid_option"), 4000)
    end
end, false)

-- Event handler for admin permission check response
RegisterNetEvent("character_storage:toggleAdminMode")
AddEventHandler("character_storage:toggleAdminMode", function(enableAdminMode)
    isAdminMode = enableAdminMode
    
    if isAdminMode then
        VORPcore.NotifyRightTip(GetTranslation("admin_mode_enabled"), 4000)
    else
        VORPcore.NotifyRightTip(GetTranslation("admin_mode_disabled"), 4000)
    end
    
    -- Recreate blips with the new setting
    CreateStorageBlips()
end)

-- Clean up resources on stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, blip in pairs(storageBlips) do
            RemoveBlip(blip)
        end
    end
end)
