fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_shells'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Support behaviour for the prop-based housing shells used by qbx_properties'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/weather.lua',
}
