fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_turfs'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Configurable gang territory control: declaration periods, capture windows, required presence, cooldowns, defender/police notifications'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
    'imperial_logging',
    'imperial_gangs',
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
