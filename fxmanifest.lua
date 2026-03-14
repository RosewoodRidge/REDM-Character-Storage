fx_version 'cerulean'
games { 'rdr3' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Rosewood Ridge Team'
description 'Character Storage System for RedM servers'
version '1.0.9'

-- Shared files
shared_scripts {
    'config.lua',
}

-- Client scripts
client_scripts {
    'client/client.lua',
    'client/menu.lua',
    'client/npc.lua',
    'client/shop.lua',
}

-- Server scripts
server_scripts {
    'server/database.lua',
    'server/server.lua',
    'server/discord.lua',
    'update.lua',
}

-- Dependencies
dependencies {
    'vorp_core',
    'vorp_inventory',
    'vorp_menu'
}

-- Ensure proper loading order
server_exports {
    'GetDatabaseAPI',
    'LoadAllStoragesFromDatabase',
    'RegisterAllStorageInventories'
}
