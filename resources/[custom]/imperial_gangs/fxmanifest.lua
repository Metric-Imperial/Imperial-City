fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_gangs'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Dynamic, database-backed gang system: creation, ranks, invites, leadership transfer, gang account, storage, reputation — compatibility exports for gang-aware resources'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'imperial_logging',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/money.lua',
}
