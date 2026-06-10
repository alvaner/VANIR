fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vnr_zonebuilder'
author 'Vanir'
description 'Free in-game polygon zone builder - draw zones with your feet or crosshair and export to ox_lib, PolyZone, or plain Lua/JSON.'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'locales/en.lua',
    'shared/util.lua',
}

client_scripts {
    'client/draw.lua',
    'client/editor.lua',
    'client/nui.lua',
}

server_scripts {
    'server/main.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}
