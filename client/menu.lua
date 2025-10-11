local VORPcore = exports.vorp_core:GetCore()
local MenuData = exports.vorp_menu:GetMenuData()

-- References to client variables (will be set from client.lua)
local playerStorages = {}
-- Add variables to store nearby players data and current storage ID
local nearbyPlayers = {}
local currentStorageId = nil

local function UpdateStorages(storages)
    playerStorages = storages
    -- Ensure authorized_jobs is at least an empty table if not present
    for _, storage in pairs(playerStorages) do
        if storage.authorized_jobs == nil then
            storage.authorized_jobs = '{}' -- Store as JSON string initially
        end
    end
end

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

-- Helper function to print debug messages to the console and screen
function DebugMsg(message)
    if not Config.Debug then return end
    
    print("[DEBUG] " .. message)
    -- Also show to the player in development
    VORPcore.NotifyObjective("[DEBUG] " .. message, 4000)
end

-- Helper function to get character name from database (via server)
function GetCharacterName(charId, cb)
    -- Create a unique callback ID for this request
    local callbackId = "character_storage:nameCallback_" .. math.random(100000, 999999) .. "_" .. charId
    
    -- Register a one-time event handler for this specific callback
    local eventHandler
    
    -- Define the handler function separately so we can reference it properly
    local function handleNameCallback(name)
        -- First remove the event handler to prevent memory leaks
        if eventHandler then
            RemoveEventHandler(eventHandler)
        end
        
        -- Then call the callback with the name
        cb(name)
    end
    
    -- Now register the event with our handler function
    RegisterNetEvent(callbackId)
    eventHandler = AddEventHandler(callbackId, handleNameCallback)
    
    -- Request the character name from the server
    TriggerServerEvent("character_storage:getCharacterName", charId, callbackId)
end

-- Owner menu for storage
function OpenOwnerStorageMenu(storageId)
    MenuData.CloseAll()
    
    -- Get the storage name and balance
    local storageName = GetTranslation("storage_title", storageId)
    local currentCapacity = Config.DefaultCapacity
    local storageBalance = 0
    
    -- Find storage details
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            storageName = storage.storage_name or GetTranslation("storage_title", storageId)
            currentCapacity = tonumber(storage.capacity) or Config.DefaultCapacity
            storageBalance = tonumber(storage.money_balance) or 0
            break
        end
    end
    
    -- Calculate the upgrade price based on how many upgrades have been done
    local previousUpgrades = math.floor((currentCapacity - Config.DefaultCapacity) / Config.StorageUpgradeSlots)
    local upgradePrice = math.floor(Config.StorageUpgradePrice * math.pow((1 + Config.StorageUpgradePriceMultiplier), previousUpgrades))
    
    local elements = {
        {
            label = GetTranslation("open_storage"),
            value = "open",
            desc = GetTranslation("open_storage_desc")
        },
        {
            label = GetTranslation("deposit_money"),
            value = "deposit",
            desc = GetTranslation("deposit_money_desc")
        },
        {
            label = GetTranslation("withdraw_money"),
            value = "withdraw",
            desc = GetTranslation("withdraw_money_desc")
        },
        {
            label = GetTranslation("view_ledger"),
            value = "ledger",
            desc = GetTranslation("view_ledger_desc")
        },
        {
            label = GetTranslation("rename_storage"),
            value = "rename",
            desc = GetTranslation("rename_storage_desc")
        },
        {
            label = GetTranslation("access_management_option"),
            value = "access",
            desc = GetTranslation("manage_access_desc")
        },
        {
            label = GetTranslation("upgrade_storage", upgradePrice),
            value = "upgrade",
            desc = GetTranslation("upgrade_storage_desc", Config.StorageUpgradeSlots)
        },
        {
            label = GetTranslation("close_menu"),
            value = "close",
            desc = ""
        }
    }
    
    MenuData.Open("default", GetCurrentResourceName(), "storage_owner_menu",
    {
        title = storageName,
        subtext = GetTranslation("storage_balance", string.format("%.2f", storageBalance)),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "open" then
            DebugMsg("Open option selected for storage ID: " .. storageId)
            TriggerEvent('character_storage:openAttempt', storageId)
            menu.close()
        elseif data.current.value == "deposit" then
            menu.close()
            OpenDepositMenu(storageId)
        elseif data.current.value == "withdraw" then
            menu.close()
            OpenWithdrawMenu(storageId)
        elseif data.current.value == "ledger" then
            menu.close()
            OpenLedgerMenu(storageId)
        elseif data.current.value == "rename" then
            menu.close()
            OpenRenameMenu(storageId)
        elseif data.current.value == "access" then
            menu.close()
            OpenAccessManagementMenu(storageId)
        elseif data.current.value == "upgrade" then
            menu.close()
            ConfirmUpgradeStorage(storageId)
        elseif data.current.value == "close" then
            menu.close()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Open access management menu
function OpenAccessManagementMenu(storageId)
    if not storageId then return end -- Prevent nil storageId errors
    MenuData.CloseAll()
    
    -- Get authorized users from storage
    local authorizedUsers = {}
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            authorizedUsers = json.decode(storage.authorized_users or '[]')
            break
        end
    end
     
    local elements = {
        {
            label = GetTranslation("add_player"),
            value = "add",
            desc = GetTranslation("manage_players_desc")
        },
        {
            label = GetTranslation("view_remove_player"),
            value = "viewremove",
            desc = GetTranslation("manage_players_desc")
        },
        {
            label = GetTranslation("manage_job_access_option"),
            value = "jobaccess",
            desc = GetTranslation("manage_job_access_desc")
        }
    }
    
    -- Add back and close options
    table.insert(elements, {
        label = GetTranslation("back_menu"),
        value = "back",
        desc = GetTranslation("manage_players_desc")
    })
    
    table.insert(elements, {
        label = GetTranslation("close_menu"),
        value = "close",
        desc = GetTranslation("close_menu")
    })
    
    local storageName = GetTranslation("storage_title", storageId)
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            storageName = storage.storage_name or storageName
            break
        end
    end
    
    MenuData.Open("default", GetCurrentResourceName(), "access_management_menu",
    {
        title = storageName,
        subtext = GetTranslation("access_management"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        local action = data.current.value
        
        if action == "add" then
            menu.close()
            OpenAddPlayerMenu(storageId) -- Pass storageId directly
        elseif action == "viewremove" then
            menu.close()
            OpenRemovePlayersMenu(storageId)
        elseif action == "jobaccess" then
            menu.close()
            OpenJobAccessManagementMenu(storageId)
        elseif action == "back" then
            menu.close()
            OpenOwnerStorageMenu(storageId)
        elseif action == "close" then
            menu.close()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- New function to view and remove players with access
function OpenRemovePlayersMenu(storageId)
    if not storageId then return end
    DebugMsg("Opening remove players menu for storage ID: " .. storageId)
    MenuData.CloseAll()
    
    -- Get storage details
    local authorizedUsers = {}
    local storageName = GetTranslation("storage_title", storageId)
    
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            authorizedUsers = json.decode(storage.authorized_users or '[]')
            storageName = storage.storage_name or storageName
            break
        end
    end
    
    DebugMsg("Found " .. #authorizedUsers .. " authorized users for storage")
    
    -- Handle the case with no authorized users right away
    if #authorizedUsers == 0 then
        DebugMsg("No authorized users found")
        local elements = {
            {
                label = GetTranslation("no_players_found"),
                value = "none",
                desc = GetTranslation("manage_players_desc")
            },
            {
                label = GetTranslation("back_menu"),
                value = "back",
                desc = GetTranslation("manage_players_desc")
            }
        }
        
        MenuData.Open("default", GetCurrentResourceName(), "remove_players_menu_empty",
        {
            title = storageName,
            subtext = GetTranslation("authorized_players"),
            align = "top-right",
            elements = elements
        }, function(data, menu)
            if data.current.value == "back" then
                menu.close()
                OpenAccessManagementMenu(storageId)
            end
        end, function(data, menu)
            menu.close()
            OpenAccessManagementMenu(storageId)
        end)
        return
    end
    
    -- Prepare elements with loading placeholders
    local elements = {}
    for i, charId in pairs(authorizedUsers) do
        table.insert(elements, {
            label = GetTranslation("player_info_loading", i),
            value = "loading_" .. charId,
            desc = GetTranslation("player_info_wait")
        })
    end
    
    -- Add back button
    table.insert(elements, {
        label = GetTranslation("back_menu"),
        value = "back",
        desc = GetTranslation("manage_players_desc")
    })
    
    -- Define the menu with initial loading elements
    local menu = MenuData.Open("default", GetCurrentResourceName(), "remove_players_menu",
    {
        title = storageName,
        subtext = GetTranslation("authorized_players"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        DebugMsg("Menu selection made: " .. data.current.value)
        
        if data.current.value == "back" then
            menu.close()
            OpenAccessManagementMenu(storageId)
        elseif string.sub(data.current.value, 1, 7) == "remove_" then
            local charId = string.sub(data.current.value, 8)
            DebugMsg("Selected to remove player with CharID: " .. charId)
            
            -- Direct removal approach
            ShowRemoveConfirmation(storageId, charId, data.current.label)
        end
    end, function(data, menu)
        menu.close()
        OpenAccessManagementMenu(storageId)
    end)
    
    -- Now fetch player names and update the elements
    local updatedElements = {}
    local playersProcessed = 0
    
    for index, charId in pairs(authorizedUsers) do
        DebugMsg("Fetching name for CharID: " .. charId)
        
        GetCharacterName(charId, function(name)
            playersProcessed = playersProcessed + 1
            local displayName = name or GetTranslation("player_not_found")
            
            DebugMsg("Got name for CharID " .. charId .. ": " .. displayName)
            
            table.insert(updatedElements, {
                label = displayName .. " (ID: " .. charId .. ")",
                value = "remove_" .. charId,
                desc = GetTranslation("add_remove_desc")
            })
            
            -- When all players are processed, update the menu
            if playersProcessed == #authorizedUsers then
                DebugMsg("All player names loaded, updating menu")
                
                -- Sort elements alphabetically
                table.sort(updatedElements, function(a, b)
                    return a.label < b.label
                end)
                
                -- Add back button
                table.insert(updatedElements, {
                    label = GetTranslation("back_menu"),
                    value = "back",
                    desc = GetTranslation("manage_players_desc")
                })
                
                -- Update menu elements
                DebugMsg("Refreshing menu with " .. #updatedElements .. " elements")
                menu.setElements(updatedElements)
                menu.refresh()
            end
        end)
    end
end

-- New function to directly show removal confirmation without relying on menu.submit
function ShowRemoveConfirmation(storageId, charId, playerLabel)
    DebugMsg("Showing confirmation for storage " .. storageId .. ", charId " .. charId)
    
    -- Extract player name from the label
    local playerName = string.match(playerLabel, "^(.+) %(ID:")
    if not playerName then playerName = GetTranslation("player_not_found") end
    
    -- Ensure charId is numeric
    charId = tonumber(charId)
    if not charId then
        DebugMsg("ERROR: Invalid character ID")
        VORPcore.NotifyRightTip("Error: Invalid character ID", 3000)
        return
    end
    
    DebugMsg("Preparing confirmation to remove access for: " .. playerName)
    
    -- Create confirmation menu
    local elements = {
        {label = GetTranslation("yes_remove"), value = "yes", desc = GetTranslation("remove_access_desc", playerName)},
        {label = GetTranslation("no_cancel"), value = "no", desc = GetTranslation("keep_access_desc")}
    }
    
    MenuData.CloseAll()
    
    MenuData.Open("default", GetCurrentResourceName(), "confirm_remove_access", {
        title = GetTranslation("confirm_removal"),
        subtext = GetTranslation("remove_access_text", playerName),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "yes" then
            DebugMsg("Removal confirmed for CharID: " .. charId)
            
            -- Directly trigger server event with explicit conversion
            local numericStorageId = tonumber(storageId)
            TriggerServerEvent('character_storage:removeAccess', numericStorageId, charId)
            
            -- Show immediate feedback
            VORPcore.NotifyRightTip(GetTranslation("removal_success", playerName), 4000)
            
            -- Close menu and open the management menu again
            menu.close()
            Wait(1000)
            DebugMsg("Reopening access management menu")
            OpenAccessManagementMenu(storageId)
        else
            DebugMsg("Removal cancelled")
            menu.close()
            OpenRemovePlayersMenu(storageId)
        end
    end, function(data, menu)
        menu.close()
        OpenRemovePlayersMenu(storageId)
    end)
end

-- Update the player selection system to use VORP Core API
function OpenAddPlayerMenu(storageId)
    if not storageId then return end -- Safety check
    
    currentStorageId = storageId -- Store for callbacks
    
    -- Using VORP menu pattern for an initial selection
    local elements = {
        {
            label = GetTranslation("search_nearby"),
            value = "nearby",
            desc = GetTranslation("all_players_desc")
        },
        {
            label = GetTranslation("back_menu"),
            value = "back",
            desc = GetTranslation("manage_players_desc")
        }
    }
    
    MenuData.Open("default", GetCurrentResourceName(), "add_player_menu",
    {
        title = GetTranslation("add_player_title", storageId),
        subtext = GetTranslation("select_method"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "nearby" then
            menu.close()
            -- Request online players from server
            TriggerServerEvent('character_storage:getOnlinePlayers')
        elseif data.current.value == "back" then
            menu.close()
            OpenAccessManagementMenu(storageId)
        end
    end, function(data, menu)
        menu.close()
        OpenAccessManagementMenu(storageId)
    end)
end

-- Rename storage menu
function OpenRenameMenu(storageId)
    MenuData.CloseAll()
    
    -- Find current storage name
    local currentName = GetTranslation("storage_title", storageId)
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            currentName = storage.storage_name or currentName
            break
        end
    end
    
    -- Replace syn_inputs with vorp_inputs
    local myInput = {
        type = "enableinput", -- don't touch
        inputType = "input",
        button = GetTranslation("confirm"), -- button name
        placeholder = GetTranslation("enter_new_name"), -- placeholder name
        style = "block", -- don't touch
        attributes = {
            inputHeader = GetTranslation("enter_new_name"), -- header
            type = "text", -- inputype text, number,date,textarea ETC
            pattern = "[A-Za-z0-9 ]{2,30}", -- regular expression validated for only numbers "[0-9]", for letters only [A-Za-z]+   with charecter limit  [A-Za-z]{5,20}
            title = "Must be between 2-30 characters. No special characters allowed.", -- if input doesn't match show this message
            style = "border-radius: 10px; background-color: ; border:none;" -- style  the input
        }
    }

    TriggerEvent("vorpinputs:advancedInput", json.encode(myInput), function(result)
        local newName = tostring(result)
        if newName ~= nil and newName ~= "" then
            TriggerServerEvent('character_storage:renameStorage', storageId, newName)
        else
            -- Return to owner menu if canceled or empty
            OpenOwnerStorageMenu(storageId)
        end
    end)
end

-- Confirm upgrade storage menu
function ConfirmUpgradeStorage(storageId)
    -- Get the storage's current capacity
    local currentCapacity = Config.DefaultCapacity
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            currentCapacity = tonumber(storage.capacity) or Config.DefaultCapacity
            break
        end
    end
    
    -- Calculate how many upgrades have been done already
    local previousUpgrades = math.floor((currentCapacity - Config.DefaultCapacity) / Config.StorageUpgradeSlots)
    
    -- Calculate the price with multiplier: BasePrice * (1 + Multiplier)^PreviousUpgrades
    local basePrice = Config.StorageUpgradePrice
    local multiplier = Config.StorageUpgradePriceMultiplier
    local upgradePrice = math.floor(basePrice * math.pow((1 + multiplier), previousUpgrades))
    
    local upgradeSlots = tonumber(Config.StorageUpgradeSlots) or 0
    
    MenuData.CloseAll()
    
    local elements = {
        {
            label = GetTranslation("confirm_upgrade", upgradeSlots, upgradePrice),
            value = "confirm",
            desc = GetTranslation("upgrade_confirm_desc")
        },
        {
            label = GetTranslation("no_cancel"),
            value = "cancel",
            desc = ""
        }
    }
    
    local storageName = GetTranslation("storage_title", storageId)
    for _, storage in pairs(playerStorages) do
        if storage.id == storageId then
            storageName = storage.storage_name or storageName
            break
        end
    end
    
    MenuData.Open("default", GetCurrentResourceName(), "storage_upgrade_menu",
    {
        title = storageName,
        subtext = GetTranslation("upgrade_confirmation"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "confirm" then
            TriggerServerEvent('character_storage:upgradeStorage', storageId)
            menu.close()
        elseif data.current.value == "cancel" then
            menu.close()
            OpenOwnerStorageMenu(storageId)
        end
    end, function(data, menu)
        menu.close()
        OpenOwnerStorageMenu(storageId)
    end)
end

-- Create storage confirmation menu
function OpenCreateStorageMenu()
    MenuData.CloseAll()
    
    local elements = {
        {
            label = GetTranslation("create_storage") .. " ($" .. Config.StorageCreationPrice .. ")",
            value = "create",
            desc = GetTranslation("create_storage_desc")
        },
        {
            label = GetTranslation("close_menu"),
            value = "close",
            desc = GetTranslation("close_menu")
        }
    }
    
    MenuData.Open("default", GetCurrentResourceName(), "storage_create_menu",
    {
        title = GetTranslation("create_storage"),
        subtext = GetTranslation("create_cost", Config.StorageCreationPrice),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "create" then
            TriggerServerEvent('character_storage:createStorage')
            menu.close()
        elseif data.current.value == "close" then
            menu.close()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Add new functions for Job Access Management
function OpenJobAccessManagementMenu(storageId)
    MenuData.CloseAll()
    local storage = nil
    for _, s in pairs(playerStorages) do
        if s.id == storageId then
            storage = s
            break
        end
    end

    if not storage then return end

    local authorizedJobs = json.decode(storage.authorized_jobs or '{}')
    local elements = {}

    for jobName, rule in pairs(authorizedJobs) do
        local gradesDisplay = "All Grades"
        if not rule.all_grades and rule.grades and #rule.grades > 0 then
            gradesDisplay = "Grades: " .. table.concat(rule.grades, ", ")
        elseif not rule.all_grades and (not rule.grades or #rule.grades == 0) then
             gradesDisplay = "No specific grades (effectively no access unless 'All Grades' is set)"
        end
        table.insert(elements, {
            label = GetTranslation("remove_job_rule_option", jobName .. " (" .. gradesDisplay .. ")"),
            value = "removejob_" .. jobName,
            desc = GetTranslation("remove_job_rule_desc", jobName)
        })
    end

    table.insert(elements, {
        label = GetTranslation("add_new_job_rule"),
        value = "addjob",
        desc = GetTranslation("add_job_rule_desc")
    })
    table.insert(elements, {
        label = GetTranslation("back_menu"),
        value = "back"
    })

    local storageNameDisplay = storage.storage_name or GetTranslation("storage_title", storageId)
    MenuData.Open("default", GetCurrentResourceName(), "job_access_menu", {
        title = storageNameDisplay,
        subtext = GetTranslation("job_access_management"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        local value = data.current.value
        if value == "addjob" then
            menu.close()
            OpenAddOrEditJobRuleMenu(storageId)
        elseif value == "back" then
            menu.close()
            OpenAccessManagementMenu(storageId)
        elseif string.sub(value, 1, 10) == "removejob_" then
            local jobNameToRemove = string.sub(value, 11)
            menu.close()
            ConfirmRemoveJobRule(storageId, jobNameToRemove)
        end
    end, function(data, menu)
        menu.close()
        OpenAccessManagementMenu(storageId)
    end)
end

function OpenAddOrEditJobRuleMenu(storageId, existingJobName)
    MenuData.CloseAll()
    local storage = nil
    for _, s in pairs(playerStorages) do
        if s.id == storageId then storage = s break end
    end
    if not storage then return end

    local authorizedJobs = json.decode(storage.authorized_jobs or '{}')
    local currentRule = existingJobName and authorizedJobs[existingJobName] or {}
    local currentInputStr = ""

    if existingJobName then
        currentInputStr = existingJobName
        if currentRule.all_grades then
            currentInputStr = currentInputStr .. " all"
        elseif currentRule.grades and #currentRule.grades > 0 then
            currentInputStr = currentInputStr .. " " .. table.concat(currentRule.grades, ",")
        end
    end

    local title = existingJobName and GetTranslation("edit_job_rule_title", existingJobName) or GetTranslation("add_job_rule_title")
    local subtext = GetTranslation("enter_job_and_grades_desc")

    local myInput = {
        type = "enableinput", -- don't touch
        inputType = "input",
        button = GetTranslation("confirm"), -- button name
        placeholder = GetTranslation("enter_job_rule"), -- placeholder name
        style = "block", -- don't touch
        attributes = {
            inputHeader = title, -- header
            type = "text", -- inputype text, number,date,textarea ETC
            pattern = "[A-Za-z0-9 ,]{2,50}", -- regular expression validated for job names and grades
            title = subtext, -- if input doesn't match show this message
            style = "border-radius: 10px; background-color: ; border:none;", -- style  the input
            value = currentInputStr -- default value
        }
    }

    TriggerEvent("vorpinputs:advancedInput", json.encode(myInput), function(inputResult)
        local fullInput = inputResult and tostring(inputResult) or ""
        fullInput = fullInput:match("^%s*(.-)%s*$") -- Trim whitespace

        if fullInput == "" then
            OpenJobAccessManagementMenu(storageId) -- Cancelled or empty input
            return
        end

        local jobName, gradesStr
        -- Find the last space in the input string.
        -- The part before it is the job name, the part after is the grades string.
        local lastSpacePos
        for i = #fullInput, 1, -1 do
            if string.sub(fullInput, i, i) == " " then
                lastSpacePos = i
                break
            end
        end
        
        if lastSpacePos then
            jobName = string.sub(fullInput, 1, lastSpacePos - 1):match("^%s*(.-)%s*$") -- Text before last space
            gradesStr = string.sub(fullInput, lastSpacePos + 1):match("^%s*(.-)%s*$") -- Text after last space
        else
            -- No space found, assume the whole input is the job name and grades are "all"
            jobName = fullInput
            gradesStr = "all"
        end
        
        -- Do NOT convert jobName to lowercase here. Keep its original casing.

        if not jobName or jobName == "" then
            VORPcore.NotifyRightTip(GetTranslation("invalid_job_rule_format"), 4000)
            OpenJobAccessManagementMenu(storageId)
            return
        end

        local ruleData = {}
        gradesStr = string.lower(gradesStr) -- Convert only the grades part to lowercase

        if gradesStr == "all" then
            ruleData.all_grades = true
        else
            ruleData.grades = {}
            ruleData.all_grades = false
            for grade in string.gmatch(gradesStr, "[^,%s]+") do
                local numGrade = tonumber(grade)
                if numGrade ~= nil then
                    table.insert(ruleData.grades, numGrade)
                else
                    -- If any part of the grades string is not a number and not "all", it's invalid.
                    VORPcore.NotifyRightTip(GetTranslation("invalid_job_rule_format"), 4000)
                    OpenJobAccessManagementMenu(storageId)
                    return
                end
            end
            if #ruleData.grades == 0 and gradesStr ~= "" then -- e.g. "police abc"
                 VORPcore.NotifyRightTip(GetTranslation("invalid_job_rule_format"), 4000)
                 OpenJobAccessManagementMenu(storageId)
                 return
            end
        end
        
        -- If gradesStr was empty but not "all" and no numbers were parsed, treat as "all" if jobName is valid
        if not ruleData.all_grades and (#ruleData.grades == 0 and gradesStr == "") then
             ruleData.all_grades = true -- Default to all if only job name is provided
        end


        if ruleData.all_grades or #ruleData.grades > 0 then
            TriggerServerEvent('character_storage:updateJobAccess', storageId, jobName, ruleData)
            Wait(500) 
            OpenJobAccessManagementMenu(storageId)
        else
            VORPcore.NotifyRightTip(GetTranslation("invalid_job_rule_format"), 4000)
            OpenJobAccessManagementMenu(storageId)
        end
    end)
end

function ConfirmRemoveJobRule(storageId, jobName)
    MenuData.CloseAll()
    local elements = {
        {label = GetTranslation("yes_remove_job_rule"), value = "yes"},
        {label = GetTranslation("no_cancel"), value = "no"}
    }
    MenuData.Open("default", GetCurrentResourceName(), "confirm_remove_job_rule", {
        title = GetTranslation("confirm_job_rule_removal"),
        subtext = GetTranslation("remove_job_access_text", jobName),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "yes" then
            TriggerServerEvent('character_storage:updateJobAccess', storageId, jobName, nil) -- nil ruleData means remove
            menu.close()
            Wait(500)
            OpenJobAccessManagementMenu(storageId)
        else
            menu.close()
            OpenJobAccessManagementMenu(storageId)
        end
    end, function(data, menu)
        menu.close()
        OpenJobAccessManagementMenu(storageId)
    end)
end

-- Register network events for opening menus
RegisterNetEvent('character_storage:openOwnerMenu')
AddEventHandler('character_storage:openOwnerMenu', function(storageId)
    OpenOwnerStorageMenu(storageId)
end)

-- Add event handlers for notifications
RegisterNetEvent('character_storage:notifyAccessGranted')
AddEventHandler('character_storage:notifyAccessGranted', function(storageName, ownerName)
    VORPcore.NotifyRightTip(GetTranslation("access_granted", ownerName, storageName), 6000)
end)

RegisterNetEvent('character_storage:notifyAccessRevoked')
AddEventHandler('character_storage:notifyAccessRevoked', function(storageName, ownerName)
    VORPcore.NotifyRightTip(GetTranslation("access_revoked", ownerName, storageName), 6000)
end)

-- Add debug function to check on click
RegisterNetEvent('character_storage:openAttempt')
AddEventHandler('character_storage:openAttempt', function(storageId)
    DebugMsg("Client attempting to open storage: " .. tostring(storageId))
    -- Simply trigger the server event and add debug message  
    TriggerServerEvent('character_storage:openStorage', storageId)
end)

-- Refresh UI when receiving new storage data
RegisterNetEvent('character_storage:receiveStorages')
AddEventHandler('character_storage:receiveStorages', function(storages)
    DebugMsg("Received updated storage data from server")
    UpdateStorages(storages or {}) -- Call the updated function
    -- Any active menus may need to be refreshed here
end)

-- Add the missing function to display players
function DisplayNearbyPlayersMenu()
    MenuData.CloseAll()
    
    local elements = {}
    
    -- Sort players by name
    table.sort(nearbyPlayers, function(a, b)
        return a.name < b.name
    end)
    
    -- Add all players to the menu
    for _, player in ipairs(nearbyPlayers) do
        table.insert(elements, {
            label = player.name,
            value = "add_" .. player.charId,
            desc = GetTranslation("nearby_player_desc", player.charId, player.serverId)
        })
    end
    
    -- Add back option
    table.insert(elements, {
        label = GetTranslation("back_menu"),
        value = "back",
        desc = ""
    })
    
    MenuData.Open("default", GetCurrentResourceName(), "select_player_menu", {
        title = GetTranslation("add_player_title"),
        subtext = GetTranslation("select_player"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "back" then
            menu.close()
            OpenAddPlayerMenu(currentStorageId)
        elseif string.sub(data.current.value, 1, 4) == "add_" then
            local charId = string.sub(data.current.value, 5)
            
            -- Find player's name
            local playerName = "Unknown"
            for _, player in ipairs(nearbyPlayers) do
                if tostring(player.charId) == charId then
                    playerName = player.name
                    break
                end
            end
            
            -- Add player to storage access
            TriggerServerEvent('character_storage:addUserById', currentStorageId, tonumber(charId))
            menu.close()
        end
    end, function(data, menu)
        menu.close()
        OpenAddPlayerMenu(currentStorageId)
    end)
end

-- Update OpenAddPlayerMenu function to change "nearby" players to "all" players
function OpenAddPlayerMenu(storageId)
    if not storageId then return end -- Safety check
    
    currentStorageId = storageId -- Store for callbacks
    
    -- Using VORP menu pattern for an initial selection
    local elements = {
        {
            label = GetTranslation("search_nearby"),
            value = "nearby",
            desc = GetTranslation("all_players_desc")
        },
        {
            label = GetTranslation("back_menu"),
            value = "back",
            desc = GetTranslation("manage_players_desc")
        }
    }
    
    MenuData.Open("default", GetCurrentResourceName(), "add_player_menu",
    {
        title = GetTranslation("add_player_title", storageId),
        subtext = GetTranslation("select_method"),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "nearby" then
            menu.close()
            -- Request online players from server
            TriggerServerEvent('character_storage:getOnlinePlayers')
        elseif data.current.value == "back" then
            menu.close()
            OpenAccessManagementMenu(storageId)
        end
    end, function(data, menu)
        menu.close()
        OpenAccessManagementMenu(storageId)
    end)
end

-- Add event handler for receiving online players
RegisterNetEvent('character_storage:receiveOnlinePlayers')
AddEventHandler('character_storage:receiveOnlinePlayers', function(playersList)
    DebugMsg("Received " .. #playersList .. " online players from server")
    
    -- Store all players received, not just nearby ones
    nearbyPlayers = playersList
    
    if #nearbyPlayers > 0 then
        DebugMsg("Found " .. #nearbyPlayers .. " players")
        DisplayNearbyPlayersMenu()
    else
        VORPcore.NotifyRightTip(GetTranslation("no_players_found"), 3000)
        -- Go back to add player menu if no players found
        Wait(500)
        OpenAddPlayerMenu(currentStorageId) 
    end
end)

-- Export functions for client.lua to use
exports('OpenOwnerStorageMenu', OpenOwnerStorageMenu)
exports('OpenCreateStorageMenu', OpenCreateStorageMenu)
exports('UpdateStorages', UpdateStorages)

-- Deposit money menu
function OpenDepositMenu(storageId)
    MenuData.CloseAll()
    
    local myInput = {
        type = "enableinput",
        inputType = "input",
        button = GetTranslation("confirm"),
        placeholder = GetTranslation("enter_amount"),
        style = "block",
        attributes = {
            inputHeader = GetTranslation("deposit_money"),
            type = "number",
            pattern = "[0-9]+",
            title = "Enter amount to deposit",
            style = "border-radius: 10px; background-color: ; border:none;"
        }
    }

    TriggerEvent("vorpinputs:advancedInput", json.encode(myInput), function(result)
        local amount = tonumber(result)
        if amount and amount > 0 then
            TriggerServerEvent('character_storage:depositMoney', storageId, amount)
            Wait(500)
            -- Request updated balance
            TriggerServerEvent('character_storage:getStorageBalance', storageId)
        else
            VORPcore.NotifyRightTip(GetTranslation("invalid_amount"), 3000)
        end
        OpenOwnerStorageMenu(storageId)
    end)
end

-- Withdraw money menu
function OpenWithdrawMenu(storageId)
    MenuData.CloseAll()
    
    local myInput = {
        type = "enableinput",
        inputType = "input",
        button = GetTranslation("confirm"),
        placeholder = GetTranslation("enter_amount"),
        style = "block",
        attributes = {
            inputHeader = GetTranslation("withdraw_money"),
            type = "number",
            pattern = "[0-9]+",
            title = "Enter amount to withdraw",
            style = "border-radius: 10px; background-color: ; border:none;"
        }
    }

    TriggerEvent("vorpinputs:advancedInput", json.encode(myInput), function(result)
        local amount = tonumber(result)
        if amount and amount > 0 then
            TriggerServerEvent('character_storage:withdrawMoney', storageId, amount)
            Wait(500)
            -- Request updated balance
            TriggerServerEvent('character_storage:getStorageBalance', storageId)
        else
            VORPcore.NotifyRightTip(GetTranslation("invalid_amount"), 3000)
        end
        OpenOwnerStorageMenu(storageId)
    end)
end

-- View ledger history menu
function OpenLedgerMenu(storageId)
    MenuData.CloseAll()
    
    -- Request ledger data from server
    TriggerServerEvent('character_storage:getStorageBalance', storageId)
    
    -- Wait a moment for server response
    Wait(200)
    
    -- Find storage
    local storage = nil
    for _, s in pairs(playerStorages) do
        if s.id == storageId then
            storage = s
            break
        end
    end
    
    if not storage then return end
    
    local ledgerHistory = storage.ledger_history or ""
    local elements = {}
    
    if ledgerHistory ~= "" then
        -- Parse ledger: format is "Name|Amount|Type|Timestamp;Name|Amount|Type|Timestamp"
        for entry in string.gmatch(ledgerHistory, "[^;]+") do
            local parts = {}
            for part in string.gmatch(entry, "[^|]+") do
                table.insert(parts, part)
            end
            
            if #parts >= 4 then
                local fullName = parts[1] -- e.g., "John Smith"
                local amount = string.format("%.2f", tonumber(parts[2]) or 0)
                local transType = parts[3] == "deposit" and GetTranslation("ledger_deposit") or GetTranslation("ledger_withdrawal")
                local timestamp = parts[4]
                
                -- Format the name for display (e.g., "Smith, John" or keep "John Smith")
                local displayName = fullName
                local firstName, lastName = string.match(fullName, "^(%S+)%s+(.+)$")
                if firstName and lastName then
                    displayName = lastName .. ", " .. firstName -- Display as "Last, First"
                end
                
                table.insert(elements, 1, { -- Insert at beginning for newest first
                    label = string.format("%s | $%s | %s", timestamp, amount, transType),
                    value = "entry_" .. #elements,
                    desc = displayName
                })
            end
        end
    end
    
    if #elements == 0 then
        table.insert(elements, {
            label = GetTranslation("no_transactions"),
            value = "none",
            desc = ""
        })
    end
    
    table.insert(elements, {
        label = GetTranslation("back_menu"),
        value = "back",
        desc = ""
    })
    
    local storageName = storage.storage_name or GetTranslation("storage_title", storageId)
    local balance = tonumber(storage.money_balance) or 0
    
    MenuData.Open("default", GetCurrentResourceName(), "ledger_menu",
    {
        title = GetTranslation("ledger_title"),
        subtext = storageName .. " - " .. GetTranslation("storage_balance", string.format("%.2f", balance)),
        align = "top-right",
        elements = elements
    }, function(data, menu)
        if data.current.value == "back" then
            menu.close()
            OpenOwnerStorageMenu(storageId)
        end
    end, function(data, menu)
        menu.close()
        OpenOwnerStorageMenu(storageId)
    end)
end

-- Update storage balance when received from server
RegisterNetEvent('character_storage:receiveStorageBalance')
AddEventHandler('character_storage:receiveStorageBalance', function(storageId, balance, ledger)
    -- Update local storage data
    for i, storage in pairs(playerStorages) do
        if storage.id == storageId then
            playerStorages[i].money_balance = balance
            playerStorages[i].ledger_history = ledger
            break
        end
    end
end)

-- Update balance trigger
RegisterNetEvent('character_storage:updateStorageBalance')
AddEventHandler('character_storage:updateStorageBalance', function(storageId)
    TriggerServerEvent('character_storage:getStorageBalance', storageId)
end)
