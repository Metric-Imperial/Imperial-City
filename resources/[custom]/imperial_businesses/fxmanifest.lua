fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_businesses'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Modular player-owned business framework: ownership, employees, ledger, POS, storage, leases — with a reusable server API'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'imperial_logging',
    'imperial_crafting',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'config/businesses.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/money.lua',
    'server/employees.lua',
    'server/pos.lua',
    'server/cron.lua',
    'server/crafting_bridge.lua',
}
