fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_mdt'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Multi-department MDT: reports, arrests, citations, warrants, BOLOs, medical/fire records, department-scoped access, audit log'
license 'GPL-3.0-or-later'

dependencies {
    'qbx_core',
    'ox_lib',
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

ui_page 'web/index.html'

files {
    'web/index.html',
}
