fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'forge-pause'
author 'Forge'
description 'Menu de pausa Forge com PR Bridge'
version '0.1.0'
shared_scripts { '@pr_bridge/init.lua', 'config.lua', 'settings.lua', 'blips.lua', 'world_blips.lua', 'map_blips.lua' }
server_scripts { 'server/admin.lua', 'server/map.lua', 'server/blips.lua', 'server/world_blips.lua', 'server/map_blips.lua' }
client_scripts { 'client/environment.lua', 'client/map_ground.lua', 'client/map.lua', 'client/portrait.lua', 'client/profile.lua', 'client/options.lua', 'client/blips.lua', 'client/world_blips.lua', 'client/map_blips.lua', 'client/main.lua', 'client/admin_nui.lua' }
ui_page 'web/index.html'
files { 'web/index.html', 'web/style.css', 'web/cinematic.css', 'web/navigation.css', 'web/settings.css', 'web/map-layout.css', 'web/admin.css', 'web/app.js', 'web/roads.js', 'web/map.js', 'web/settings.js', 'web/admin-map.js', 'web/admin.js', 'web/assets/*', 'web/assets/blips/*.png', 'web/assets/blips/*.jpg', 'web/assets/blips/*.jpeg', 'web/assets/blips/*.webp' }
dependency 'pr_bridge'
