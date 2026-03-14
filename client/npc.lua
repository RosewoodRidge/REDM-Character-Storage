-- ============================================================
-- NPC Clerk Spawner for Character Storage
-- Spawns unkillable, persistent clerk NPCs at configured locations
-- ============================================================

local spawnedNPCs = {}  -- [index] = { handle = ped, spawned = bool }
local npcModelsLoaded = {}

-- ============================================================
-- Model Loading
-- ============================================================

local function LoadModel(model)
    local hash = GetHashKey(model)
    if HasModelLoaded(hash) then return true end

    RequestModel(hash, false)
    local timeout = 50
    while not HasModelLoaded(hash) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end

    return HasModelLoaded(hash)
end

local function ReleaseModelIfUnused(model)
    local hash = GetHashKey(model)
    SetModelAsNoLongerNeeded(hash)
end

-- ============================================================
-- NPC Spawning & Despawning
-- ============================================================

local function SpawnClerkNPC(index, clerkData)
    if spawnedNPCs[index] and spawnedNPCs[index].spawned then return end

    local model = clerkData.model
    if not LoadModel(model) then
        print("[CharStorage NPC] Failed to load model: " .. model)
        return
    end

    local coords = clerkData.coords
    local ped = CreatePed(GetHashKey(model), coords.x, coords.y, coords.z, coords.w, false, false, false, false)

    if not ped or ped == 0 then
        print("[CharStorage NPC] Failed to create ped at index " .. index)
        return
    end

    -- Wait for entity to exist
    local timeout = 50
    while not DoesEntityExist(ped) and timeout > 0 do
        Wait(100)
        timeout = timeout - 1
    end

    if not DoesEntityExist(ped) then
        print("[CharStorage NPC] Ped entity never spawned for index " .. index)
        return
    end

    -- Place on ground
    PlaceEntityOnGroundProperly(ped, true)

    -- Make unkillable and non-interactive
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedCanBeTargetted(ped, false)

    -- Visible flags (same approach as banking/store NPCs)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)  -- SetEntityVisible

    -- Clear any damage/dirt
    ClearPedEnvDirt(ped)
    ClearPedDamageDecalByZone(ped, 10, "ALL")
    ClearPedBloodDamage(ped)

    -- Start scenario animation (clipboard/writing)
    if clerkData.scenario then
        TaskStartScenarioInPlace(ped, GetHashKey(clerkData.scenario), 0, true)
    end

    -- Release model memory
    ReleaseModelIfUnused(model)

    spawnedNPCs[index] = { handle = ped, spawned = true }

    if Config.Debug then
        print("[CharStorage NPC] Spawned clerk #" .. index .. " (" .. model .. ") at " ..
            string.format("%.1f, %.1f, %.1f", coords.x, coords.y, coords.z))
    end
end

local function DespawnClerkNPC(index)
    local data = spawnedNPCs[index]
    if not data or not data.spawned then return end

    if DoesEntityExist(data.handle) then
        DeletePed(data.handle)
        DeleteEntity(data.handle)
    end

    spawnedNPCs[index] = { handle = nil, spawned = false }

    if Config.Debug then
        print("[CharStorage NPC] Despawned clerk #" .. index)
    end
end

-- ============================================================
-- Distance-Based Spawn/Despawn Loop
-- ============================================================

Citizen.CreateThread(function()
    -- Wait for config to be ready
    while not Config or not Config.NPCs do
        Wait(1000)
    end

    if not Config.NPCs.Enabled then return end

    local clerks = Config.NPCs.Clerks
    if not clerks or #clerks == 0 then return end

    local spawnDist = Config.NPCs.SpawnDistance or 80.0
    local despawnDist = Config.NPCs.DespawnDistance or 100.0

    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for i, clerk in ipairs(clerks) do
            local npcCoords = vector3(clerk.coords.x, clerk.coords.y, clerk.coords.z)
            local dist = #(playerCoords - npcCoords)

            if dist <= spawnDist then
                SpawnClerkNPC(i, clerk)
            elseif dist > despawnDist then
                DespawnClerkNPC(i)
            end
        end

        -- Check less frequently when far away from any NPC
        local minDist = 999999.0
        for _, clerk in ipairs(clerks) do
            local npcCoords = vector3(clerk.coords.x, clerk.coords.y, clerk.coords.z)
            local d = #(playerCoords - npcCoords)
            if d < minDist then minDist = d end
        end

        if minDist > despawnDist * 2 then
            Wait(5000)  -- Very far, check every 5 seconds
        elseif minDist > despawnDist then
            Wait(2000)  -- Moderately far, check every 2 seconds
        else
            Wait(1000)  -- Close, check every second
        end
    end
end)

-- ============================================================
-- Cleanup on resource stop
-- ============================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for i, _ in pairs(spawnedNPCs) do
        DespawnClerkNPC(i)
    end
end)
