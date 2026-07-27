fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_logging'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Shared foundation: structured audit logging, rate limiting, action locks, persistent KV, validation helpers'
license 'GPL-3.0-or-later'

dependencies {
    '/server:7290',
    'oxmysql',
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/kv.lua',
    'server/ratelimit.lua',
    'server/validate.lua',
    'server/main.lua',
}
