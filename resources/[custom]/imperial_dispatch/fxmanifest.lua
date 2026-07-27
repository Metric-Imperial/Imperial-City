fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_dispatch'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Unified police/EMS/fire dispatch with a documented CreateDispatchCall export for any resource to raise alerts'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
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
