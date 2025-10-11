DB = {}  -- Make DB global instead of local

-- Create a new storage
function DB.CreateStorage(owner_charid, name, x, y, z, callback)
    local query = "INSERT INTO character_storage (owner_charid, storage_name, pos_x, pos_y, pos_z, authorized_users, capacity, authorized_jobs) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    local params = {owner_charid, name, x, y, z, '[]', Config.DefaultCapacity, '{}'}
    exports.oxmysql:execute(query, params, function(result)
        if callback then
            callback(result.insertId)
        end
    end)
end

-- Get storage by ID
function DB.GetStorage(id, callback)
    local query = "SELECT * FROM character_storage WHERE id = ?"
    exports.oxmysql:execute(query, {id}, function(result)
        if callback then
            if result and #result > 0 then
                callback(result[1])
            else
                callback(nil)
            end
        end
    end)
end

-- Get all storages owned by a player
function DB.GetPlayerStorages(charid, callback)
    local query = "SELECT * FROM character_storage WHERE owner_charid = ?"
    exports.oxmysql:execute(query, {charid}, function(result)
        if callback then
            callback(result)
        end
    end)
end

-- Get all storages a player has access to (owned or authorized)
function DB.GetAccessibleStorages(charid, callback)
    -- Use LIKE instead of JSON_CONTAINS for better compatibility
    local query = "SELECT * FROM character_storage WHERE owner_charid = ? OR authorized_users LIKE ?"
    -- Format the search pattern to find the character ID in the JSON array
    local searchPattern = "%" .. tostring(charid) .. "%"
    
    exports.oxmysql:execute(query, {charid, searchPattern}, function(result)
        if callback then
            callback(result or {})  -- Return empty array if nil
        end
    end)
end

-- Update storage location
function DB.UpdateStorageLocation(id, x, y, z, callback)
    local query = "UPDATE character_storage SET pos_x = ?, pos_y = ?, pos_z = ? WHERE id = ?"
    exports.oxmysql:execute(query, {x, y, z, id}, function(result)
        if callback then
            callback(result.affectedRows > 0)
        end
    end)
end

-- Update storage capacity
function DB.UpdateStorageCapacity(id, capacity, callback)
    local query = "UPDATE character_storage SET capacity = ? WHERE id = ?"
    exports.oxmysql:execute(query, {capacity, id}, function(result)
        if callback then
            callback(result.affectedRows > 0)
        end
    end)
end

-- Update authorized users for a storage
function DB.UpdateAuthorizedUsers(id, authorizedUsers, callback)
    exports.oxmysql:execute("UPDATE character_storage SET authorized_users = ? WHERE id = ?", 
        {authorizedUsers, id}, 
        function(rowsChanged)
            if callback then
                callback(rowsChanged.affectedRows > 0)
            end
        end
    )
end

-- Update storage name
function DB.UpdateStorageName(id, name, callback)
    local query = "UPDATE character_storage SET storage_name = ? WHERE id = ?"
    exports.oxmysql:execute(query, {name, id}, function(result)
        if callback then
            callback(result.affectedRows > 0)
        end
    end)
end

-- Delete storage
function DB.DeleteStorage(id, callback)
    local query = "DELETE FROM character_storage WHERE id = ?"
    exports.oxmysql:execute(query, {id}, function(result)
        if callback then
            callback(result.affectedRows > 0)
        end
    end)
end

-- Get all storages (for admin purposes)
function DB.GetAllStorages(callback)
    local query = "SELECT * FROM character_storage"
    exports.oxmysql:execute(query, {}, function(result)
        if callback then
            callback(result)
        end
    end)
end

-- New function: Load all storages from database
function DB.LoadAllStoragesFromDatabase(callback)
    local query = "SELECT * FROM character_storage"
    exports.oxmysql:execute(query, {}, function(result)
        if callback then
            callback(result or {})
        end
    end)
end

-- New function: Register all storage inventories
function DB.RegisterAllStorageInventories(storages, registerFunction)
    if not storages or #storages == 0 then
        print("No character storages to register")
        return 0
    end
    
    local count = 0
    for _, storage in ipairs(storages) do
        local success = registerFunction(storage.id, storage.capacity, storage)
        if success then
            count = count + 1
        end
    end
    
    print(("Successfully registered %d/%d character storage inventories"):format(count, #storages))
    return count
end

-- New function: Update authorized jobs for a storage
function DB.UpdateAuthorizedJobs(id, authorizedJobsJson, callback)
    local query = "UPDATE character_storage SET authorized_jobs = ? WHERE id = ?"
    exports.oxmysql:execute(query, {authorizedJobsJson, id}, function(result)
        if callback then
            callback(result.affectedRows > 0)
        end
    end)
end

-- Update last_accessed timestamp for a storage
function DB.UpdateLastAccessed(id)
    -- Convert id to number to ensure proper comparison
    local numericId = tonumber(id)
    if not numericId then
        print("ERROR: Invalid storage ID for timestamp update: " .. tostring(id))
        return
    end

    local query = "UPDATE character_storage SET last_accessed = CURRENT_TIMESTAMP() WHERE id = ?"
    
    -- Use a more direct debug approach that doesn't depend on Config.Debug
    print("Updating last_accessed timestamp for storage #" .. numericId)
    
    exports.oxmysql:execute(query, {numericId}, function(result)
        if not result then
            print("ERROR: Failed to update last_accessed for storage #" .. numericId .. " - No result returned")
            return
        end
        
        if result.affectedRows > 0 then
            print("Successfully updated last_accessed timestamp for storage #" .. numericId)
        else
            print("WARNING: Query executed but no rows affected for storage #" .. numericId .. " - Row may not exist")
        end
    end)
end

-- Check for and delete expired storages
function DB.DeleteExpiredStorages(callback)
    if not Config.EnableStorageExpiration then
        if callback then callback(0) end
        return
    end
    
    local days = Config.StorageExpirationDays or 60
    
    -- First, check if the necessary columns exist in the table
    exports.oxmysql:execute("SHOW COLUMNS FROM character_storage LIKE 'last_accessed'", {}, function(columnResult)
        if not columnResult or #columnResult == 0 then
            print("ERROR: 'last_accessed' column doesn't exist in character_storage table. Running automatic migration...")
            
            -- Add the column if it doesn't exist
            exports.oxmysql:execute("ALTER TABLE character_storage ADD COLUMN last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP", {}, function(alterResult)
                if alterResult then
                    print("Successfully added 'last_accessed' column to character_storage table")
                else
                    print("Failed to add 'last_accessed' column")
                    if callback then callback(0) end
                    return
                end
            end)
            
            -- Also check for is_preset column
            exports.oxmysql:execute("SHOW COLUMNS FROM character_storage LIKE 'is_preset'", {}, function(presetColumnResult)
                if not presetColumnResult or #presetColumnResult == 0 then
                    exports.oxmysql:execute("ALTER TABLE character_storage ADD COLUMN is_preset TINYINT(1) NOT NULL DEFAULT 0", {})
                end
            end)
            
            if callback then callback(0) end
            return
        end
        
        -- If the column exists, proceed with deletion
        local query = [[
            DELETE FROM character_storage 
            WHERE last_accessed < DATE_SUB(CURRENT_TIMESTAMP(), INTERVAL ? DAY)
            AND (is_preset = 0 OR is_preset IS NULL)
        ]]
        
        exports.oxmysql:execute(query, {days}, function(result)
            local deletedCount = result and result.affectedRows or 0
            print("Deleted " .. deletedCount .. " expired storages (not accessed in the last " .. days .. " days)")
            
            if callback then
                callback(deletedCount)
            end
        end)
    end)
end

-- Get storage money balance
function DB.GetStorageBalance(id, callback)
    local query = "SELECT money_balance, ledger_history FROM character_storage WHERE id = ?"
    exports.oxmysql:execute(query, {id}, function(result)
        if callback then
            if result and #result > 0 then
                callback(tonumber(result[1].money_balance) or 0, result[1].ledger_history)
            else
                callback(0, nil)
            end
        end
    end)
end

-- Update storage money balance and ledger
function DB.UpdateStorageMoney(id, newBalance, ledgerHistory, callback)
    local query = "UPDATE character_storage SET money_balance = ?, ledger_history = ? WHERE id = ?"
    exports.oxmysql:execute(query, {newBalance, ledgerHistory, id}, function(result)
        if callback then
            callback(result.affectedRows > 0)
        end
    end)
end

-- Add ledger entry
function DB.AddLedgerEntry(id, playerName, amount, transactionType, callback)
    -- First get current balance and ledger
    DB.GetStorageBalance(id, function(currentBalance, currentLedger)
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local newEntry = string.format("%s|%.2f|%s|%s", playerName, amount, transactionType, timestamp)
        
        local newLedger
        if currentLedger and currentLedger ~= "" then
            newLedger = currentLedger .. ";" .. newEntry
        else
            newLedger = newEntry
        end
        
        -- Calculate new balance
        local newBalance = currentBalance
        if transactionType == "deposit" then
            newBalance = currentBalance + amount
        elseif transactionType == "withdrawal" then
            newBalance = currentBalance - amount
        end
        
        -- Update database
        DB.UpdateStorageMoney(id, newBalance, newLedger, callback)
    end)
end
