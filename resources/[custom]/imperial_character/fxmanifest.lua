fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_character'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Character lifecycle hardening: duplicate-proof starter package, first-login onboarding hooks, spawn fallback recovery'
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
}
