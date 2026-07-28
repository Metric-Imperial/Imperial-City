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

-- A .ydr alone is not enough for a NEW prop: the game also needs an archetype
-- declaring the name exists and what its bounds are. That lives in the .ytyp
-- below, and without it the model never enters the game's index -- nothing
-- spawns and IsModelInCdimage returns false. Source XML for it is in
-- _source/imperial_props.ytyp.xml; add further props as extra archetype
-- entries in that one file rather than creating a ytyp per model.
files {
    'stream/imperial_props.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/imperial_props.ytyp'
