fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'imperial_assets'
author 'Imperial City Dev Team'
version '1.0.0'
description 'Shared streamed assets (props, textures, collision) for the imperial_* suite'

-- No scripts. This resource exists purely to stream the contents of stream/.
-- FiveM picks that folder up automatically, and streamed assets are global --
-- every resource on the server can spawn these models, not just this one.

-- If an imported pack ships a .ytyp, register it here, e.g.:
--   files { 'stream/your_pack.ytyp' }
--   data_file 'DLC_ITYP_REQUEST' 'stream/your_pack.ytyp'
