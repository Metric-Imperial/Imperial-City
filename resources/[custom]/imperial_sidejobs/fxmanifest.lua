fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_sidejobs'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Session-based side jobs without job-state pollution: fishing, mining, smelting, lumber, jeweller, materials buyer'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
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
}
