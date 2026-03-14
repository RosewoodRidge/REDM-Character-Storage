-- ============================================================
-- Armory Shop System for Character Storage
-- VORP Inventory-based admin shop with job-lock and infinite stock
-- Items display in a VORP custom inventory grid. Prices show
-- in green at the bottom when selecting an item. Dragging into
-- your inventory gives you a copy; the item restocks automatically.
-- ============================================================

local VORPcore = exports.vorp_core:GetCore()

-- Prompt & interaction state
local ArmoryPromptGroup = GetRandomIntInRange(0, 0xffffff)
local ArmoryPrompt = nil
local nearestArmory = nil
local armoryBlips = {}
local spawnedArmoryNPCs = {}

-- ============================================================
-- Helpers
-- ============================================================

local function GetTrans(key, ...)
    local lang = Config.DefaultLanguage
    if Config.Translations[lang] and Config.Translations[lang][key] then
        local text = Config.Translations[lang][key]
        if ... then return string.format(text, ...) end
        return text
    end
    return key
end

local function Debug(msg)
    if Config.Debug then print("[ArmoryShop] " .. msg) end
end

-- ============================================================
-- Prompt Setup
-- ============================================================

local function InitArmoryPrompt()
    ArmoryPrompt = PromptRegisterBegin()
    PromptSetControlAction(ArmoryPrompt, Config.ArmoryPromptKey or 0x760A9C6F)
    local str = CreateVarString(10, 'LITERAL_STRING', GetTrans("armory_prompt"))
    PromptSetText(ArmoryPrompt, str)
    PromptSetEnabled(ArmoryPrompt, true)
    PromptSetVisible(ArmoryPrompt, true)
    PromptSetStandardMode(ArmoryPrompt, true)
    PromptSetGroup(ArmoryPrompt, ArmoryPromptGroup)
    PromptRegisterEnd(ArmoryPrompt)
end

-- ============================================================
-- Blip Management
-- ============================================================

local function CreateArmoryBlips()
    for _, blip in pairs(armoryBlips) do
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    armoryBlips = {}

    if not Config.ArmoryShops then return end

    for _, shop in ipairs(Config.ArmoryShops) do
        if shop.showblip and shop.Pos then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, shop.Pos.x, shop.Pos.y, shop.Pos.z)
            if blip and DoesBlipExist(blip) then
                SetBlipSprite(blip, shop.blipSprite or -145868367, 1)
                SetBlipScale(blip, 0.2)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, shop.Name or "Armory")
                table.insert(armoryBlips, blip)
            end
        end
    end
end

-- ============================================================
-- NPC Spawning (mirrors npc.lua pattern)
-- ============================================================

local function LoadModel(model)
    local hash = GetHashKey(model)
    if HasModelLoaded(hash) then return true end
    RequestModel(hash, false)
    local timeout = 50
    while not HasModelLoaded(hash) and timeout > 0 do Wait(100); timeout = timeout - 1 end
    return HasModelLoaded(hash)
end

local function SpawnArmoryNPC(index, npcData)
    if spawnedArmoryNPCs[index] and spawnedArmoryNPCs[index].spawned then return end
    if not LoadModel(npcData.model) then return end

    local coords = npcData.coords
    local ped = CreatePed(GetHashKey(npcData.model), coords.x, coords.y, coords.z, coords.w, false, false, false, false)
    if not ped or ped == 0 then return end

    local t = 50
    while not DoesEntityExist(ped) and t > 0 do Wait(100); t = t - 1 end
    if not DoesEntityExist(ped) then return end

    PlaceEntityOnGroundProperly(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedCanBeTargetted(ped, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    ClearPedEnvDirt(ped)
    ClearPedBloodDamage(ped)

    if npcData.scenario then
        TaskStartScenarioInPlace(ped, GetHashKey(npcData.scenario), 0, true)
    end

    SetModelAsNoLongerNeeded(GetHashKey(npcData.model))
    spawnedArmoryNPCs[index] = { handle = ped, spawned = true }
    Debug("Spawned armory NPC #" .. index)
end

local function DespawnArmoryNPC(index)
    local data = spawnedArmoryNPCs[index]
    if not data or not data.spawned then return end
    if DoesEntityExist(data.handle) then DeletePed(data.handle); DeleteEntity(data.handle) end
    spawnedArmoryNPCs[index] = { handle = nil, spawned = false }
end

-- ============================================================
-- Main Interaction Loop
-- ============================================================

Citizen.CreateThread(function()
    while not Config or not Config.ArmoryShops do Wait(500) end
    if #Config.ArmoryShops == 0 then return end

    InitArmoryPrompt()
    CreateArmoryBlips()

    local radius = Config.ArmoryAccessRadius or 2.0
    local spawnDist = (Config.NPCs and Config.NPCs.SpawnDistance) or 80.0
    local despawnDist = (Config.NPCs and Config.NPCs.DespawnDistance) or 100.0

    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local wait = 1000
        nearestArmory = nil

        for i, shop in ipairs(Config.ArmoryShops) do
            if shop.Pos then
                local dist = #(playerCoords - shop.Pos)

                -- NPC spawn/despawn
                if shop.npc then
                    if dist <= spawnDist then
                        SpawnArmoryNPC(i, shop.npc)
                    elseif dist > despawnDist then
                        DespawnArmoryNPC(i)
                    end
                end

                -- Prompt interaction
                if dist <= radius then
                    nearestArmory = shop
                    wait = 0

                    local label = CreateVarString(10, 'LITERAL_STRING', shop.Name)
                    PromptSetActiveGroupThisFrame(ArmoryPromptGroup, label)

                    if PromptHasStandardModeCompleted(ArmoryPrompt) then
                        -- Ask server to open the armory custom inventory
                        TriggerServerEvent('character_storage:armoryOpenStore', shop.id)
                        Wait(500)
                    end
                    break
                end
            end
        end

        Citizen.Wait(wait)
    end
end)

-- ============================================================
-- Server Response: Access denied notification
-- ============================================================

RegisterNetEvent('character_storage:armoryAccessDenied')
AddEventHandler('character_storage:armoryAccessDenied', function()
    VORPcore.NotifyRightTip(GetTrans("armory_no_access"), 4000)
end)

-- ============================================================
-- Cleanup
-- ============================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in pairs(armoryBlips) do
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    for i, _ in pairs(spawnedArmoryNPCs) do
        DespawnArmoryNPC(i)
    end
end)
