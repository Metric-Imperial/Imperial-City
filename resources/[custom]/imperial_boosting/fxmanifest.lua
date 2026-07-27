fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_boosting'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Vehicle boosting contracts: steal a targeted vehicle and deliver it to a chop contact within a time limit, feeding qbx_scrapyard'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'imperial_logging',
    'imperial_dispatch',
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
