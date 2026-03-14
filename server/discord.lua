-- ============================================================
-- Discord Webhook Tracking for Character Storage
-- Tracks inventory contents and activity for configured storages
-- Sends/edits Discord messages via webhook
-- ============================================================

DiscordTracker = {}

-- In-memory state
local inventorySnapshots = {}   -- [storageId] = {items = {}, weapons = {}, timestamp}
local activityLogs = {}         -- [storageId] = {{timestamp, charName, charId, removed, added}, ...}
local activeStorageUsers = {}   -- [source] = {storageId, charId, charName, openTime, preSnapshot}
local discordInitialized = false

-- Constants
local MAX_ACTIVITY_LOG_ENTRIES = 50
local PLAYER_CHECK_INTERVAL = 15000     -- 15 seconds
local PLAYER_TRACK_DURATION = 180       -- 3 minutes
local ACTIVITY_RETENTION_DAYS = 30      -- Purge entries older than this

-- ============================================================
-- Debug Logging
-- ============================================================

local function DLog(message)
    if Config.DiscordDebug then
        print("[Discord DEBUG] " .. tostring(message))
    end
end

-- Always print (important status messages)
local function DPrint(message)
    print("[Discord] " .. tostring(message))
end

-- ============================================================
-- Discord HTTP Helpers
-- ============================================================

local function SendWebhookMessage(webhookUrl, embedData, messageId, callback)
    local url = webhookUrl
    local method = "POST"

    if messageId and messageId ~= "" then
        url = webhookUrl .. "/messages/" .. messageId
        method = "PATCH"
    else
        url = webhookUrl .. "?wait=true"
        messageId = nil
    end

    local ok_encode, payload = pcall(json.encode, { embeds = { embedData } })
    if not ok_encode then
        DPrint("ERROR: Failed to encode embed JSON: " .. tostring(payload))
        if callback then callback(false, nil) end
        return
    end

    DLog(method .. " to webhook — URL length: " .. #url .. ", Payload length: " .. #payload)
    DLog("Webhook URL: " .. url:sub(1, 80) .. "...")

    PerformHttpRequest(url, function(statusCode, responseText, headers)
        DLog("HTTP Response — Status: " .. tostring(statusCode) .. ", Body length: " .. tostring(responseText and #responseText or 0))

        if statusCode == 200 or statusCode == 204 then
            local ok_decode, response = pcall(json.decode, responseText or "")
            local returnedId = (ok_decode and response and response.id) or messageId
            DLog("Success — Message ID: " .. tostring(returnedId))
            if callback then callback(true, returnedId) end
        elseif statusCode == 404 and messageId then
            DPrint("Message " .. tostring(messageId) .. " not found (404). Creating new message.")
            SendWebhookMessage(webhookUrl, embedData, nil, callback)
        else
            DPrint("HTTP " .. tostring(method) .. " Error " .. tostring(statusCode))
            DLog("Response body: " .. tostring(responseText))
            if callback then callback(false, nil) end
        end
    end, method, payload, { ["Content-Type"] = "application/json" })
end

-- ============================================================
-- Fetch existing Discord message (GET)
-- ============================================================

local function FetchWebhookMessage(webhookUrl, messageId, callback)
    if not messageId or messageId == "" then
        if callback then callback(false, nil) end
        return
    end
    local url = webhookUrl .. "/messages/" .. messageId
    DLog("GET " .. url:sub(1, 80) .. "...")
    PerformHttpRequest(url, function(statusCode, responseText, headers)
        DLog("FetchWebhookMessage — Status: " .. tostring(statusCode))
        if statusCode == 200 then
            local ok_decode, response = pcall(json.decode, responseText or "")
            if ok_decode and response then
                if callback then callback(true, response) end
            else
                if callback then callback(false, nil) end
            end
        else
            DPrint("Failed to fetch message " .. tostring(messageId) .. " (HTTP " .. tostring(statusCode) .. ")")
            if callback then callback(false, nil) end
        end
    end, "GET", "", { ["Content-Type"] = "application/json" })
end

-- ============================================================
-- Parse activity entries from existing Discord embed
-- ============================================================

local function ParseActivityEntries(description)
    local entries = {}
    if not description or description == "" then return entries end
    if description:find("No activity recorded yet") then return entries end

    -- Split by double newline (entry separator)
    -- Lua gmatch with character class won't match literal "\n\n", so split manually
    local blocks = {}
    local current = ""
    for line in description:gmatch("[^\n]*") do
        if line == "" then
            if current ~= "" then
                table.insert(blocks, current)
                current = ""
            end
        else
            if current ~= "" then
                current = current .. "\n" .. line
            else
                current = line
            end
        end
    end
    if current ~= "" then
        table.insert(blocks, current)
    end

    for _, block in ipairs(blocks) do
        local lines = {}
        for line in block:gmatch("[^\n]+") do
            table.insert(lines, line)
        end

        if #lines > 0 then
            -- Parse header: **[MM-DD HH:MM]** Name (CID: X)
            local timestamp, charName, charId = lines[1]:match("%*%*%[(.-)%]%*%*%s+(.-)%s+%(CID:%s*(.-)%)")
            if timestamp and charName and charId then
                local entry = {
                    timestamp = timestamp,
                    charName  = charName,
                    charId    = tonumber(charId) or charId,
                    removed   = {},
                    added     = {}
                }

                for i = 2, #lines do
                    local line = lines[i]
                    -- Check for Took
                    local took_label, took_amount = line:match("Took:%s+(.-)%s+x(%d+)")
                    if took_label and took_amount then
                        table.insert(entry.removed, { label = took_label, amount = tonumber(took_amount) })
                    end
                    -- Check for Added
                    local added_label, added_amount = line:match("Added:%s+(.-)%s+x(%d+)")
                    if added_label and added_amount then
                        table.insert(entry.added, { label = added_label, amount = tonumber(added_amount) })
                    end
                end

                table.insert(entries, entry)
            end
        end
    end

    return entries
end

-- Purge entries older than ACTIVITY_RETENTION_DAYS
local function PurgeOldEntries(entries)
    if not entries or #entries == 0 then return entries end

    local now = os.time()
    local cutoff = now - (ACTIVITY_RETENTION_DAYS * 86400)
    local currentYear = tonumber(os.date("%Y"))

    local kept = {}
    for _, e in ipairs(entries) do
        -- Timestamp is "MM-DD HH:MM" — we need to reconstruct a rough os.time
        local month, day, hour, min = e.timestamp:match("(%d+)-(%d+)%s+(%d+):(%d+)")
        if month and day and hour and min then
            -- Assume current year; if parsed date is in the future, assume last year
            local entryTime = os.time({ year = currentYear, month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = 0 })
            if entryTime > now then
                entryTime = os.time({ year = currentYear - 1, month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(min), sec = 0 })
            end
            if entryTime >= cutoff then
                table.insert(kept, e)
            else
                DLog("Purged old entry from " .. e.timestamp)
            end
        else
            -- Can't parse date, keep it to be safe
            table.insert(kept, e)
        end
    end

    return kept
end

-- Restore activity logs from existing Discord message
local function RestoreActivityFromDiscord(storageId, dcfg, callback)
    local msgId = dcfg.activity_message_id
    if not msgId or msgId == "" then
        DLog("No activity_message_id for '" .. storageId .. "', skipping restore.")
        if callback then callback() end
        return
    end

    FetchWebhookMessage(dcfg.webhook, msgId, function(success, messageData)
        if success and messageData and messageData.embeds and #messageData.embeds > 0 then
            local embed = messageData.embeds[1]
            local description = embed.description or ""
            local parsed = ParseActivityEntries(description)
            -- Entries in embed are newest-first, but internal storage is oldest-first — reverse them
            local reversed = {}
            for i = #parsed, 1, -1 do
                table.insert(reversed, parsed[i])
            end
            reversed = PurgeOldEntries(reversed)

            if #reversed > 0 then
                activityLogs[storageId] = reversed
                DPrint("Restored " .. #reversed .. " activity entries for '" .. storageId .. "' from Discord.")
            else
                DLog("No valid entries found in existing activity message for '" .. storageId .. "'.")
            end
        else
            DLog("Could not fetch existing activity message for '" .. storageId .. "'.")
        end
        if callback then callback() end
    end)
end

-- ============================================================
-- Database Queries for Inventory Contents
-- ============================================================

local function GetInventoryContents(storageId, callback)
    local invId = "character_storage_" .. storageId
    DLog("Querying DB for inventory_type / curr_inv = '" .. invId .. "'")

    local itemsQuery = [[
        SELECT ci.item_name,
               SUM(ci.amount) AS total_amount,
               COALESCE(i.label, ci.item_name) AS label
        FROM character_inventories ci
        LEFT JOIN items i ON ci.item_name = i.item
        WHERE ci.inventory_type = ?
        GROUP BY ci.item_name
        ORDER BY label ASC
    ]]

    local weaponsQuery = [[
        SELECT name,
               COALESCE(custom_label, label, name) AS label,
               COUNT(*) AS count
        FROM loadout
        WHERE curr_inv = ?
        GROUP BY name
        ORDER BY label ASC
    ]]

    exports.oxmysql:execute(itemsQuery, { invId }, function(items)
        DLog("DB items query returned: " .. tostring(items and #items or "nil") .. " rows")
        exports.oxmysql:execute(weaponsQuery, { invId }, function(weapons)
            DLog("DB weapons query returned: " .. tostring(weapons and #weapons or "nil") .. " rows")
            if callback then
                callback(items or {}, weapons or {})
            end
        end)
    end)
end

-- ============================================================
-- Embed Builders
-- ============================================================

local function BuildInventoryEmbed(storageName, items, weapons, storageId)
    local fields = {}

    local itemLines = {}
    local totalItemCount = 0
    for _, item in ipairs(items) do
        table.insert(itemLines, "- " .. item.label .. " x" .. tostring(item.total_amount))
        totalItemCount = totalItemCount + tonumber(item.total_amount)
    end

    if #itemLines > 0 then
        local itemText = table.concat(itemLines, "\n")
        if #itemText > 1024 then
            itemText = itemText:sub(1, 1020) .. "\n..."
        end
        table.insert(fields, {
            name = "Items (" .. #items .. " types, " .. totalItemCount .. " total)",
            value = itemText,
            inline = false
        })
    else
        table.insert(fields, {
            name = "Items",
            value = "*No items in storage*",
            inline = false
        })
    end

    local weaponLines = {}
    local totalWeaponCount = 0
    for _, weapon in ipairs(weapons) do
        table.insert(weaponLines, "- " .. weapon.label .. " x" .. tostring(weapon.count))
        totalWeaponCount = totalWeaponCount + tonumber(weapon.count)
    end

    if #weaponLines > 0 then
        local weaponText = table.concat(weaponLines, "\n")
        if #weaponText > 1024 then
            weaponText = weaponText:sub(1, 1020) .. "\n..."
        end
        table.insert(fields, {
            name = "Weapons (" .. #weapons .. " types, " .. totalWeaponCount .. " total)",
            value = weaponText,
            inline = false
        })
    else
        table.insert(fields, {
            name = "Weapons",
            value = "*No weapons in storage*",
            inline = false
        })
    end

    return {
        title       = storageName .. " - Inventory Summary",
        color       = 3447003,
        fields      = fields,
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer      = { text = "Storage ID: " .. tostring(storageId) .. " | Last Updated" }
    }
end

local function FormatShortName(fullName)
    if not fullName or fullName == "" or fullName == "Unknown" then return fullName end
    local first, last = fullName:match("^(%S+)%s+(.+)$")
    if first and last then
        return first:sub(1, 1) .. ". " .. last
    end
    return fullName
end

local function BuildActivityEmbed(storageName, entries, storageId)
    local description

    if not entries or #entries == 0 then
        description = "*No activity recorded yet.*\n*Activity will appear here when items are taken or added.*"
    else
        local lines = {}
        for i = #entries, 1, -1 do
            local e = entries[i]
            local parts = {}
            table.insert(parts, "**[" .. e.timestamp .. "]** " .. FormatShortName(e.charName) .. " (CID: " .. tostring(e.charId) .. ")")

            if e.removed and #e.removed > 0 then
                for _, c in ipairs(e.removed) do
                    table.insert(parts, "\xF0\x9F\x94\xB4 Took: " .. c.label .. " x" .. tostring(c.amount))
                end
            end
            if e.added and #e.added > 0 then
                for _, c in ipairs(e.added) do
                    table.insert(parts, "\xF0\x9F\x9F\xA2 Added: " .. c.label .. " x" .. tostring(c.amount))
                end
            end

            table.insert(lines, table.concat(parts, "\n"))
        end

        description = table.concat(lines, "\n\n")
        if #description > 4000 then
            description = description:sub(1, 3990) .. "\n*...truncated*"
        end
    end

    return {
        title       = storageName .. " - Activity Log",
        color       = 15105570,
        description = description,
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer      = { text = "Storage ID: " .. tostring(storageId) .. " | Last Updated" }
    }
end

-- ============================================================
-- Snapshot & Change Detection
-- ============================================================

local function TakeSnapshot(storageId, callback)
    DLog("Taking snapshot for '" .. tostring(storageId) .. "'...")
    GetInventoryContents(storageId, function(items, weapons)
        local snap = { items = {}, weapons = {}, timestamp = os.time() }

        for _, item in ipairs(items) do
            snap.items[item.item_name] = {
                amount = tonumber(item.total_amount),
                label  = item.label
            }
        end
        for _, weapon in ipairs(weapons) do
            snap.weapons[weapon.name] = {
                count = tonumber(weapon.count),
                label = weapon.label
            }
        end

        local itemCount = 0
        for _ in pairs(snap.items) do itemCount = itemCount + 1 end
        local weaponCount = 0
        for _ in pairs(snap.weapons) do weaponCount = weaponCount + 1 end
        DLog("Snapshot complete for '" .. tostring(storageId) .. "': " .. itemCount .. " item types, " .. weaponCount .. " weapon types")

        if callback then callback(snap) end
    end)
end

local function CompareSnapshots(oldSnap, newSnap)
    local changes = { removed = {}, added = {} }
    if not oldSnap then return changes end

    local allItems = {}
    for n in pairs(oldSnap.items or {}) do allItems[n] = true end
    for n in pairs(newSnap.items or {}) do allItems[n] = true end

    for name in pairs(allItems) do
        local oldAmt = (oldSnap.items[name] and oldSnap.items[name].amount) or 0
        local newAmt = (newSnap.items[name] and newSnap.items[name].amount) or 0
        local label  = (newSnap.items[name] and newSnap.items[name].label)
                    or (oldSnap.items[name] and oldSnap.items[name].label)
                    or name

        if newAmt < oldAmt then
            table.insert(changes.removed, { label = label, amount = oldAmt - newAmt })
        elseif newAmt > oldAmt then
            table.insert(changes.added,   { label = label, amount = newAmt - oldAmt })
        end
    end

    local allWeapons = {}
    for n in pairs(oldSnap.weapons or {}) do allWeapons[n] = true end
    for n in pairs(newSnap.weapons or {}) do allWeapons[n] = true end

    for name in pairs(allWeapons) do
        local oldCnt = (oldSnap.weapons[name] and oldSnap.weapons[name].count) or 0
        local newCnt = (newSnap.weapons[name] and newSnap.weapons[name].count) or 0
        local label  = (newSnap.weapons[name] and newSnap.weapons[name].label)
                    or (oldSnap.weapons[name] and oldSnap.weapons[name].label)
                    or name

        if newCnt < oldCnt then
            table.insert(changes.removed, { label = label, amount = oldCnt - newCnt })
        elseif newCnt > oldCnt then
            table.insert(changes.added,   { label = label, amount = newCnt - oldCnt })
        end
    end

    return changes
end

local function HasChanges(changes)
    return #changes.removed > 0 or #changes.added > 0
end

-- ============================================================
-- Config Helpers
-- ============================================================

function DiscordTracker.GetDiscordConfig(storageId)
    if not Config.DefaultStorages then return nil end
    for _, preset in ipairs(Config.DefaultStorages) do
        if preset.id == storageId and preset.discord and preset.discord.enabled then
            return preset.discord
        end
    end
    return nil
end

local function GetStorageName(storageId)
    if Config.DefaultStorages then
        for _, preset in ipairs(Config.DefaultStorages) do
            if preset.id == storageId then
                return preset.name or storageId
            end
        end
    end
    return storageId
end

-- ============================================================
-- Discord Message Senders (callback-based, no Citizen.Wait)
-- ============================================================

local function UpdateInventoryMessage(storageId, dcfg, onDone)
    DLog("UpdateInventoryMessage called for '" .. tostring(storageId) .. "'")
    GetInventoryContents(storageId, function(items, weapons)
        DLog("Building inventory embed for '" .. tostring(storageId) .. "' - " .. #items .. " item rows, " .. #weapons .. " weapon rows")
        local embed = BuildInventoryEmbed(GetStorageName(storageId), items, weapons, storageId)
        local msgId = dcfg.inventory_message_id
        DLog("Sending inventory webhook - existing message_id: " .. tostring(msgId))
        SendWebhookMessage(dcfg.webhook, embed, msgId, function(success, returnedId)
            if success then
                if not msgId or msgId == "" then
                    DPrint("============================================================")
                    DPrint("INVENTORY message CREATED for '" .. storageId .. "'")
                    DPrint("Add this to your config.lua discord block:")
                    DPrint('  inventory_message_id = "' .. tostring(returnedId) .. '",')
                    DPrint("============================================================")
                else
                    DLog("Inventory message updated for '" .. storageId .. "'")
                end
            else
                DPrint("Failed to update inventory message for '" .. storageId .. "'")
            end
            if onDone then onDone(success) end
        end)
    end)
end

local function UpdateActivityMessage(storageId, dcfg, onDone)
    DLog("UpdateActivityMessage called for '" .. tostring(storageId) .. "'")
    local entries = activityLogs[storageId] or {}
    local embed = BuildActivityEmbed(GetStorageName(storageId), entries, storageId)
    local msgId = dcfg.activity_message_id
    DLog("Sending activity webhook - existing message_id: " .. tostring(msgId) .. ", entries: " .. #entries)
    SendWebhookMessage(dcfg.webhook, embed, msgId, function(success, returnedId)
        if success then
            if not msgId or msgId == "" then
                DPrint("============================================================")
                DPrint("ACTIVITY message CREATED for '" .. storageId .. "'")
                DPrint("Add this to your config.lua discord block:")
                DPrint('  activity_message_id = "' .. tostring(returnedId) .. '",')
                DPrint("============================================================")
            else
                DLog("Activity message updated for '" .. storageId .. "'")
            end
            -- Save returned ID so subsequent calls edit the same message
            if returnedId then
                dcfg.activity_message_id = returnedId
            end
        else
            DPrint("Failed to update activity message for '" .. storageId .. "'")
        end
        if onDone then onDone(success) end
    end)
end

-- ============================================================
-- Activity Logging
-- ============================================================

local function LogActivity(storageId, charId, charName, changes)
    if not activityLogs[storageId] then
        activityLogs[storageId] = {}
    end

    table.insert(activityLogs[storageId], {
        timestamp = os.date("%m-%d %H:%M"),
        charId    = charId,
        charName  = charName,
        removed   = changes.removed,
        added     = changes.added
    })

    while #activityLogs[storageId] > MAX_ACTIVITY_LOG_ENTRIES do
        table.remove(activityLogs[storageId], 1)
    end
end

-- ============================================================
-- Player Open Tracking
-- ============================================================

function DiscordTracker.OnStorageOpened(source, storageId, charId, charName)
    local dcfg = DiscordTracker.GetDiscordConfig(storageId)
    if not dcfg then return end

    DLog(charName .. " (CID: " .. tostring(charId) .. ") opened tracked storage: " .. tostring(storageId))

    TakeSnapshot(storageId, function(preSnap)
        activeStorageUsers[source] = {
            storageId   = storageId,
            charId      = charId,
            charName    = charName,
            openTime    = os.time(),
            preSnapshot = preSnap
        }

        DiscordTracker._SchedulePlayerCheck(source)
    end)
end

function DiscordTracker._SchedulePlayerCheck(source)
    Citizen.SetTimeout(PLAYER_CHECK_INTERVAL, function()
        local userData = activeStorageUsers[source]
        if not userData or not userData.preSnapshot then return end

        TakeSnapshot(userData.storageId, function(currentSnap)
            local changes = CompareSnapshots(userData.preSnapshot, currentSnap)

            if HasChanges(changes) then
                LogActivity(userData.storageId, userData.charId, userData.charName, changes)

                userData.preSnapshot = currentSnap
                inventorySnapshots[userData.storageId] = currentSnap

                local dcfg = DiscordTracker.GetDiscordConfig(userData.storageId)
                if dcfg then
                    UpdateActivityMessage(userData.storageId, dcfg, function()
                        Citizen.SetTimeout(1000, function()
                            UpdateInventoryMessage(userData.storageId, dcfg)
                        end)
                    end)
                end

                DPrint("Changes detected in '" .. userData.storageId .. "' - attributed to " .. userData.charName)
            end

            if os.time() - userData.openTime < PLAYER_TRACK_DURATION then
                DiscordTracker._SchedulePlayerCheck(source)
            else
                activeStorageUsers[source] = nil
                DLog("Stopped tracking player " .. tostring(source) .. " (timeout)")
            end
        end)
    end)
end

-- ============================================================
-- Periodic Full Update
-- ============================================================

local function RunPeriodicUpdate()
    DLog("Running periodic update...")

    for _, preset in ipairs(Config.DefaultStorages or {}) do
        if preset.discord and preset.discord.enabled then
            DLog("Periodic update for '" .. preset.id .. "'")

            -- Skip activity detection if a player check is already tracking this storage
            local hasActiveTracker = false
            for _, ud in pairs(activeStorageUsers) do
                if ud.storageId == preset.id then
                    hasActiveTracker = true
                    break
                end
            end

            TakeSnapshot(preset.id, function(newSnap)
                local oldSnap = inventorySnapshots[preset.id]

                if oldSnap and not hasActiveTracker then
                    local changes = CompareSnapshots(oldSnap, newSnap)
                    if HasChanges(changes) then
                        local recentUser = nil
                        for _, ud in pairs(activeStorageUsers) do
                            if ud.storageId == preset.id then
                                recentUser = ud
                            end
                        end

                        LogActivity(
                            preset.id,
                            recentUser and recentUser.charId or "Unknown",
                            recentUser and recentUser.charName or "Unknown",
                            changes
                        )

                        UpdateActivityMessage(preset.id, preset.discord)
                    end
                end

                inventorySnapshots[preset.id] = newSnap
            end)

            -- Refresh inventory summary via timeout (no Citizen.Wait in callbacks)
            Citizen.SetTimeout(2000, function()
                UpdateInventoryMessage(preset.id, preset.discord)
            end)
        end
    end
end

-- ============================================================
-- Sequential Initialization (callback-chained, no Citizen.Wait in callbacks)
-- ============================================================

local function InitializeStorage(presetIndex)
    local presets = Config.DefaultStorages or {}

    -- Find next preset with discord enabled
    local preset = nil
    while presetIndex <= #presets do
        if presets[presetIndex].discord and presets[presetIndex].discord.enabled then
            preset = presets[presetIndex]
            break
        end
        presetIndex = presetIndex + 1
    end

    if not preset then
        DPrint("All tracked storages initialized.")
        discordInitialized = true
        return
    end

    DPrint("Initializing storage '" .. preset.id .. "' (preset #" .. presetIndex .. ")...")
    DLog("  Webhook URL: " .. (preset.discord.webhook and (preset.discord.webhook:sub(1, 60) .. "...") or "NIL!"))
    DLog("  inventory_message_id: " .. tostring(preset.discord.inventory_message_id))
    DLog("  activity_message_id: " .. tostring(preset.discord.activity_message_id))

    -- Step 1: Restore existing activity log from Discord
    RestoreActivityFromDiscord(preset.id, preset.discord, function()
        DLog("  Activity restore complete for '" .. preset.id .. "'")

        -- Step 2: Take initial snapshot
        TakeSnapshot(preset.id, function(snap)
            inventorySnapshots[preset.id] = snap
            DLog("  Snapshot complete for '" .. preset.id .. "'")

            -- Step 3: Send/update inventory message
            Citizen.SetTimeout(1500, function()
                DLog("  Sending inventory message for '" .. preset.id .. "'...")
                UpdateInventoryMessage(preset.id, preset.discord, function(invSuccess)
                    DLog("  Inventory message result for '" .. preset.id .. "': " .. tostring(invSuccess))

                    -- Step 4: Send/update activity message (now includes restored entries)
                    Citizen.SetTimeout(2000, function()
                        DLog("  Sending activity message for '" .. preset.id .. "'...")
                        UpdateActivityMessage(preset.id, preset.discord, function(actSuccess)
                            DLog("  Activity message result for '" .. preset.id .. "': " .. tostring(actSuccess))

                            -- Step 5: Move to next preset
                            Citizen.SetTimeout(2000, function()
                                InitializeStorage(presetIndex + 1)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- ============================================================
-- Armory Shop Discord Tracking (activity-only, no inventory)
-- ============================================================

local armoryActivityLogs = {}       -- [shopId] = { {timestamp, charId, charName, itemLabel, price}, ... }
local armoryDiscordInit = {}        -- [shopId] = true once initialized
local MAX_ARMORY_LOG_ENTRIES = 50

-- Helper: get armory discord config by shop id
local function GetArmoryDiscordConfig(shopId)
    if not Config.ArmoryShops then return nil end
    for _, shop in ipairs(Config.ArmoryShops) do
        if shop.id == shopId and shop.discord and shop.discord.enabled then
            return shop.discord, shop.Name
        end
    end
    return nil, nil
end

-- Build activity embed for armory (purchase log, no inventory)
local function BuildArmoryActivityEmbed(shopName, entries, shopId)
    local description

    if not entries or #entries == 0 then
        description = "*No activity recorded yet.*\n*Purchases will appear here when items are taken from the armory.*"
    else
        local lines = {}
        -- Show newest first
        for i = #entries, 1, -1 do
            local e = entries[i]
            local priceStr = ""
            if e.price and e.price > 0 then
                priceStr = " ($" .. string.format("%.2f", e.price) .. ")"
            else
                priceStr = " (Free)"
            end
            local shortName = FormatShortName(e.charName)
            table.insert(lines, "**[" .. e.timestamp .. "]** " .. shortName .. " (CID: " .. tostring(e.charId) .. ")")
            table.insert(lines, "\xF0\x9F\x94\xB4 Took: " .. e.itemLabel .. " x1" .. priceStr)
            table.insert(lines, "")
        end

        description = table.concat(lines, "\n")
        if #description > 4000 then
            description = description:sub(1, 3990) .. "\n*...truncated*"
        end
    end

    return {
        title       = shopName .. " - Activity Log",
        color       = 15105570,
        description = description,
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer      = { text = "Armory ID: " .. tostring(shopId) .. " | Last Updated" }
    }
end

-- Parse armory activity entries from existing Discord message
local function ParseArmoryActivityEntries(description)
    local entries = {}
    if not description or description == "" then return entries end
    if description:find("No activity recorded yet") then return entries end

    local blocks = {}
    local current = ""
    for line in description:gmatch("[^\n]*") do
        if line == "" then
            if current ~= "" then
                table.insert(blocks, current)
                current = ""
            end
        else
            if current ~= "" then
                current = current .. "\n" .. line
            else
                current = line
            end
        end
    end
    if current ~= "" then
        table.insert(blocks, current)
    end

    for _, block in ipairs(blocks) do
        local bLines = {}
        for line in block:gmatch("[^\n]+") do
            table.insert(bLines, line)
        end

        if #bLines > 0 then
            local timestamp, charName, charId = bLines[1]:match("%*%*%[(.-)%]%*%*%s+(.-)%s+%(CID:%s*(.-)%)")
            if timestamp and charName and charId then
                local itemLabel = "Unknown"
                local price = 0
                if #bLines >= 2 then
                    local label, priceStr = bLines[2]:match("Took:%s+(.-)%s+x1%s*%((.-)%)")
                    if label then
                        itemLabel = label
                        if priceStr then
                            local num = priceStr:match("%$([%d%.]+)")
                            if num then price = tonumber(num) or 0 end
                        end
                    else
                        -- Try without price
                        local label2 = bLines[2]:match("Took:%s+(.-)%s+x1")
                        if label2 then itemLabel = label2 end
                    end
                end

                table.insert(entries, {
                    timestamp = timestamp,
                    charName  = charName,
                    charId    = tonumber(charId) or charId,
                    itemLabel = itemLabel,
                    price     = price,
                })
            end
        end
    end

    return entries
end

-- Restore armory activity from existing Discord message
local function RestoreArmoryActivity(shopId, dcfg, callback)
    local msgId = dcfg.activity_message_id
    if not msgId or msgId == "" then
        DLog("No activity_message_id for armory '" .. shopId .. "', skipping restore.")
        if callback then callback() end
        return
    end

    FetchWebhookMessage(dcfg.webhook, msgId, function(success, messageData)
        if success and messageData and messageData.embeds and #messageData.embeds > 0 then
            local embed = messageData.embeds[1]
            local description = embed.description or ""
            local parsed = ParseArmoryActivityEntries(description)
            -- Entries in embed are newest-first; internal storage is oldest-first — reverse
            local reversed = {}
            for i = #parsed, 1, -1 do
                table.insert(reversed, parsed[i])
            end

            if #reversed > 0 then
                armoryActivityLogs[shopId] = reversed
                DPrint("Restored " .. #reversed .. " activity entries for armory '" .. shopId .. "' from Discord.")
            else
                DLog("No valid entries found in armory activity message for '" .. shopId .. "'.")
            end
        else
            DLog("Could not fetch existing armory activity message for '" .. shopId .. "'.")
        end
        if callback then callback() end
    end)
end

-- Send/update armory activity message to Discord
local function UpdateArmoryActivityMessage(shopId, dcfg, shopName, onDone)
    DLog("UpdateArmoryActivityMessage called for '" .. tostring(shopId) .. "'")
    local entries = armoryActivityLogs[shopId] or {}
    local embed = BuildArmoryActivityEmbed(shopName or shopId, entries, shopId)
    local msgId = dcfg.activity_message_id
    DLog("Sending armory activity webhook - existing message_id: " .. tostring(msgId) .. ", entries: " .. #entries)
    SendWebhookMessage(dcfg.webhook, embed, msgId, function(success, returnedId)
        if success then
            if not msgId or msgId == "" then
                DPrint("============================================================")
                DPrint("ARMORY ACTIVITY message CREATED for '" .. shopId .. "'")
                DPrint("Add this to your config.lua armory discord block:")
                DPrint('  activity_message_id = "' .. tostring(returnedId) .. '",')
                DPrint("============================================================")
            else
                DLog("Armory activity message updated for '" .. shopId .. "'")
            end
            if returnedId then
                dcfg.activity_message_id = returnedId
            end
        else
            DPrint("Failed to update armory activity message for '" .. shopId .. "'")
        end
        if onDone then onDone(success) end
    end)
end

-- Public API: called from server.lua when a purchase is made
function DiscordTracker.LogArmoryPurchase(shopId, charId, charName, itemLabel, price)
    local dcfg, shopName = GetArmoryDiscordConfig(shopId)
    if not dcfg then return end

    if not armoryActivityLogs[shopId] then
        armoryActivityLogs[shopId] = {}
    end

    table.insert(armoryActivityLogs[shopId], {
        timestamp = os.date("%m-%d %H:%M"),
        charId    = charId,
        charName  = charName,
        itemLabel = itemLabel,
        price     = price or 0,
    })

    -- Trim to max entries
    while #armoryActivityLogs[shopId] > MAX_ARMORY_LOG_ENTRIES do
        table.remove(armoryActivityLogs[shopId], 1)
    end

    -- Update Discord immediately on each purchase
    UpdateArmoryActivityMessage(shopId, dcfg, shopName)
end

-- Initialize armory Discord tracking (restore existing + send initial message)
local function InitializeArmoryShop(shopIndex)
    local shops = Config.ArmoryShops or {}

    -- Find next shop with discord enabled
    local shop = nil
    while shopIndex <= #shops do
        if shops[shopIndex].discord and shops[shopIndex].discord.enabled then
            shop = shops[shopIndex]
            break
        end
        shopIndex = shopIndex + 1
    end

    if not shop then
        DPrint("All tracked armory shops initialized.")
        return
    end

    DPrint("Initializing armory shop '" .. shop.id .. "' (" .. shop.Name .. ")...")

    -- Step 1: Restore existing activity log from Discord
    RestoreArmoryActivity(shop.id, shop.discord, function()
        DLog("  Armory activity restore complete for '" .. shop.id .. "'")

        -- Step 2: Send/update activity message
        Citizen.SetTimeout(1500, function()
            DLog("  Sending armory activity message for '" .. shop.id .. "'...")
            UpdateArmoryActivityMessage(shop.id, shop.discord, shop.Name, function(actSuccess)
                DLog("  Armory activity message result for '" .. shop.id .. "': " .. tostring(actSuccess))
                armoryDiscordInit[shop.id] = true

                -- Move to next shop
                Citizen.SetTimeout(2000, function()
                    InitializeArmoryShop(shopIndex + 1)
                end)
            end)
        end)
    end)
end

-- Periodic armory activity refresh
local function RunArmoryPeriodicUpdate()
    DLog("Running armory periodic update...")
    for _, shop in ipairs(Config.ArmoryShops or {}) do
        if shop.discord and shop.discord.enabled and armoryDiscordInit[shop.id] then
            UpdateArmoryActivityMessage(shop.id, shop.discord, shop.Name)
        end
    end
end

-- ============================================================
-- Startup
-- ============================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Wrap in pcall so we can see any startup errors
    local ok, err = pcall(function()
        DPrint("Resource started - scheduling Discord tracker initialization...")

    -- Count tracked storages
    local trackedCount = 0
    for _, preset in ipairs(Config.DefaultStorages or {}) do
        if preset.discord and preset.discord.enabled then
            trackedCount = trackedCount + 1
            DLog("Found tracked storage: '" .. preset.id .. "' (" .. (preset.name or "unnamed") .. ")")
        end
    end

    -- Count tracked armory shops
    local armoryTrackedCount = 0
    for _, shop in ipairs(Config.ArmoryShops or {}) do
        if shop.discord and shop.discord.enabled then
            armoryTrackedCount = armoryTrackedCount + 1
            DLog("Found tracked armory shop: '" .. shop.id .. "' (" .. (shop.Name or "unnamed") .. ")")
        end
    end

    if trackedCount == 0 and armoryTrackedCount == 0 then
        DPrint("No storages or armory shops configured for Discord tracking. Skipping.")
        return
    end

    DPrint("Found " .. trackedCount .. " storage(s) and " .. armoryTrackedCount .. " armory shop(s) with Discord tracking enabled. Waiting for DB...")

    -- Wait for DB to be ready, then begin sequential initialization
    Citizen.SetTimeout(8000, function()
        if trackedCount > 0 then
            DPrint("Starting initialization of " .. trackedCount .. " tracked storage(s)...")
            InitializeStorage(1)
        end

        -- Initialize armory shops after a delay to stagger webhook calls
        if armoryTrackedCount > 0 then
            local armoryDelay = trackedCount > 0 and (trackedCount * 6000 + 4000) or 2000
            Citizen.SetTimeout(armoryDelay, function()
                DPrint("Starting initialization of " .. armoryTrackedCount .. " tracked armory shop(s)...")
                InitializeArmoryShop(1)
            end)
        end
    end)

    -- Start periodic update loop in a proper thread
    Citizen.CreateThread(function()
        DLog("Periodic update thread started, waiting for initialization...")
        while not discordInitialized do
            Citizen.Wait(1000)
        end
        DLog("Initialization complete, beginning periodic update loop.")

        while true do
            local waitMs = 600000 -- default 10 min
            for _, preset in ipairs(Config.DefaultStorages or {}) do
                if preset.discord and preset.discord.enabled then
                    local intervalMs = (preset.discord.update_interval or 600) * 1000
                    if intervalMs < waitMs then waitMs = intervalMs end
                end
            end
            for _, shop in ipairs(Config.ArmoryShops or {}) do
                if shop.discord and shop.discord.enabled then
                    local intervalMs = (shop.discord.update_interval or 600) * 1000
                    if intervalMs < waitMs then waitMs = intervalMs end
                end
            end

            DLog("Sleeping " .. (waitMs / 1000) .. "s until next periodic update...")
            Citizen.Wait(waitMs)
            RunPeriodicUpdate()
            RunArmoryPeriodicUpdate()
        end
    end)

    end) -- end pcall
    if not ok then
        print("[Discord] ERROR during startup: " .. tostring(err))
    end
end)
