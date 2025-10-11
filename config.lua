Config = {}

-- Enable/disable debug messages
Config.Debug = false

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

-- Language system
Config.DefaultLanguage = "english" -- Default language: "english" or "spanish"

-- Update system configuration
Config.CheckForUpdates = true        -- Whether to check for updates on script start
Config.ShowUpdateNotifications = true -- Show notifications to admins when updates are available
Config.AutoUpdate = false            -- Attempt to automatically update (not fully implemented)

-- Preset Storages (not in DB, managed by config)
Config.DefaultStorages = {
    {
        id = "police_armory_main", -- Unique ID for this preset storage configuration
        name = "Evidence and Storage",
        locations = {
            vector3(2908.03, 1308.82, 44.99), -- Annesburg Police Station
            vector3(-5531.36, -2929.99, -1.31),   -- Tumbleweed Police Station
            vector3(-3621.33, -2607.36, -13.29), -- Armadillo Police Station
            vector3(-764.84, -1272.38, 44.09),   -- Blackwater Police Station
            vector3(2507.56, -1301.95, 49.0),    -- St. Denis Police Station
            vector3(1361.99, -1302.32, 77.85),  -- Rhodes Police Station
            vector3(-1812.37, -355.89, 164.7),  -- Strawberry Police Station
            vector3(-278.69, 806.22, 119.38)   -- Valentine Police Station
        },
        linked = true, -- True: all locations share one inventory. False: each location is a separate instance.
        capacity = 5000,
        blipSprite = -693644997, -- Example: Hash for blip_ambient_sheriff. Replace with actual hash or string name.
        authorized_jobs = {
            ["Lemoyne"] = { all_grades = true },
            ["NewHanover"] = { all_grades = true },
            ["WestElizabeth"] = { all_grades = true },
            ["NewAustin"] = { all_grades = true },
            ["DOJM"] = { all_grades = true }
        },
        authorized_charids = {}, -- Optional: list of specific charIDs that can access
        -- owner_charid = nil, -- Not typically needed for job/shared storages
    },
    {
        id = "doctor_main", -- Unique ID for this preset storage configuration
        name = "Doctor Storage",
        locations = {
            vector3(-764.84, -1272.38, 44.09),  -- Blackwater Doctor Station
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
    }
}