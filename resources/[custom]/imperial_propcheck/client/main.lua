--- imperial_propcheck — dev tool for choosing props for activity sites.
---
--- Everything here is client-side and NON-NETWORKED: objects are local to you,
--- nobody else sees them, and nothing touches server state. Safe to leave
--- installed, but it is a dev tool — not player-facing content.
---
--- /prop <model>   spawn a prop in front of you (replaces the current one)
--- /propdel        delete the current prop
--- /propinfo       print the current prop's model and real-world size
--- /proplist       list the built-in candidate models (validated)
--- /furnlist       list the shell furnishing models with sizes (validated)
--- /shellpoint <n> capture your position as an offset from the spawned shell
--- /propnext       cycle forward through the candidate list
--- /propprev       cycle back through the candidate list
--- /nodehere       capture a bare vec3 (rocks, trees -- no facing)
--- /sitehere       capture coords + heading (props with a front)
--- /smoke          cycle particle-effect candidates
--- /smokestop      stop the current effect

-- Candidate rock/mineral props for mining nodes. Each is validated against the
-- game's model index before use, so anything not present in this build is
-- skipped rather than silently failing.
local CANDIDATES = {
    'prop_rock_1_a', 'prop_rock_1_b', 'prop_rock_1_c', 'prop_rock_1_d',
    'prop_rock_1_e', 'prop_rock_1_f', 'prop_rock_1_g', 'prop_rock_1_h',
    'prop_rock_2_a', 'prop_rock_2_b', 'prop_rock_2_c', 'prop_rock_2_d',
    'prop_rock_2_e', 'prop_rock_2_f',
    'prop_rock_3_a', 'prop_rock_3_b', 'prop_rock_3_c', 'prop_rock_3_d',
    'prop_rock_4_a', 'prop_rock_4_b', 'prop_rock_4_c', 'prop_rock_4_d',
    'prop_rock_5_a', 'prop_rock_5_b', 'prop_rock_5_c', 'prop_rock_5_d',
    'prop_rock_6_a', 'prop_rock_7_a',
    'prop_asteroid_01a',
    'xs_terrain_rock_arena_1_01',
}

-- Candidate furnishing props for the housing shells.
--
-- Most GTA interior furniture is NOT in the global model index. A prop whose
-- name carries an interior-set prefix -- v_24_, v_26_, sf_int1_, ch_, ch2_,
-- ex_p_mp_ -- has its archetype declared inside that interior's own .ytyp
-- (v_int_40.ytyp holds 75 such `v_40_*` archetypes for the hospital alone), and
-- that ytyp is only resident when its MLO is. IsModelInCdimage then returns
-- false and /prop reports "Invalid model" even though the name is correct and
-- the asset exists in the game files.
--
-- The fix for a prop that fails here is to declare a CBaseArchetypeDef for it in
-- imperial_props.ytyp, exactly as the interior's own ytyp does -- assetType
-- ASSET_TYPE_DRAWABLE, assetName the same as the name, and the correct
-- textureDictionary (the hospital props all share 'v_40_hospital_txd'). Getting
-- the txd wrong spawns the prop untextured.
--
-- /furnlist says which of these need that treatment before any time is spent
-- guessing. It only reads the index; nothing is spawned.
local FURNITURE = {
    -- Wanted for the shell. All but the door failed the first pass.
    'v_res_tre_wardrobe',              -- wardrobe (x2 side by side)
    'sf_int1_bdr_bed',                 -- bed
    'v_24_lnb_mesh_sideboard',         -- dresser
    'ex_p_mp_door_apart_door_black',   -- door (resolves: 1.30 x 0.23 x 2.30)
    'ch_chint09_locker_room_doorway',  -- doorway
    'ch2_06_windows_iref',             -- window
    'v_26_wardrobe',                   -- control: known to fail

    -- The catalogue qbx_properties' own decorating system offers, from
    -- config/client.lua. Worth testing as a block: these are the props that
    -- system expects to be able to spawn, so anything here that FAILS means the
    -- gap is upstream and not something this shell introduced. Note there is no
    -- wardrobe or dresser category anywhere in it -- exactly what we need.
    'ba_prop_battle_lights_wall_l_a',
    'h4_prop_battle_lights_ceiling_l_c',
    'apa_mp_h_lit_floorlampnight_07',
    'apa_mp_h_lit_floorlamp_17',
    'prop_couch_sm_02',
    'v_res_tre_sofa_mess_a',
    'v_res_tre_sofa_mess_b',
    'v_res_tre_sofa_mess_c',
    'prop_couch_01',
    'prop_couch_03',
    'prop_couch_04',
    'hei_heist_tab_sidelrg_02',
    'v_res_fh_diningtable',
    'v_res_j_coffeetable',
    'h4_mp_h_yacht_bed_02',
    'hei_heist_bed_double_08',          -- confirmed in game: collision loads
    'v_res_tre_bed1',
    'v_res_tre_bed2',
    'v_res_tre_bed1_messy',

    -- Built by us because GTA's interior furniture has no standalone
    -- collision. These must report collision=loaded.
    'imperial_wardrobe',
    'imperial_dresser',
    'imperial_bed',

    'imperial_furnished_motel_room',             -- our own shell; must pass
}

local current, currentModel, index = nil, nil, 0

---Real-world bounding size of a model, in metres.
local function modelSize(model)
    local min, max = GetModelDimensions(model)
    return (max - min)
end

local function deleteCurrent()
    if current and DoesEntityExist(current) then DeleteObject(current) end
    current, currentModel = nil, nil
end

---Spawn `model` roughly 2.5m in front of the player, dropped onto the terrain.
local function spawnProp(model)
    local hash = type(model) == 'string' and joaat(model) or model

    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        lib.notify({ type = 'error', description = ('Invalid model: %s'):format(model) })
        return false
    end

    if not lib.requestModel(hash, 10000) then
        lib.notify({ type = 'error', description = ('Model would not load: %s'):format(model) })
        return false
    end

    -- lib.requestModel does not request collision. Stock props already have
    -- theirs resident from world streaming; a custom streamed model does not,
    -- so without this it renders correctly but is walk-through.
    RequestCollisionForModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasCollisionForModelLoaded(hash) and GetGameTimer() < deadline do
        RequestCollisionForModel(hash)
        Wait(0)
    end
    local collisionReady = HasCollisionForModelLoaded(hash)

    deleteCurrent()

    local ped = cache.ped
    local fwd = GetEntityForwardVector(ped)
    local c = GetEntityCoords(ped) + (fwd * 2.5)

    -- isNetwork = false, netMissionEntity = false -> local only.
    -- Last argument is `dynamic`. With false the object gets no physics
    -- instance, so it renders but nothing can touch it. Create dynamic then
    -- freeze, which is how a static-but-solid prop is made.
    current = CreateObject(hash, c.x, c.y, c.z, false, false, true)
    SetEntityCollision(current, true, true)
    SetEntityLoadCollisionFlag(current, true)
    PlaceObjectOnGroundProperly(current)
    FreezeEntityPosition(current, true)
    currentModel = type(model) == 'string' and model or tostring(model)
    SetModelAsNoLongerNeeded(hash)

    local s = modelSize(hash)
    lib.notify({
        type = collisionReady and 'success' or 'warning',
        title = currentModel,
        description = ('%.2f x %.2f x %.2f m (w/d/h)\ncollision: %s')
            :format(s.x, s.y, s.z, collisionReady and 'loaded' or 'NOT LOADED'),
        duration = 7000,
    })
    print(('[propcheck] %s  size %.2f x %.2f x %.2f m  collision=%s')
        :format(currentModel, s.x, s.y, s.z, tostring(collisionReady)))
    return true
end

---Move through the candidate list, skipping models this build doesn't have.
local function cycle(step)
    local tried = 0
    repeat
        index = index + step
        if index > #CANDIDATES then index = 1 end
        if index < 1 then index = #CANDIDATES end
        tried = tried + 1
        if spawnProp(CANDIDATES[index]) then
            lib.notify({ type = 'info', description = ('%d / %d'):format(index, #CANDIDATES) })
            return
        end
    until tried >= #CANDIDATES
    lib.notify({ type = 'error', description = 'No valid models in the candidate list.' })
end

RegisterCommand('prop', function(_, args)
    if not args[1] then
        lib.notify({ type = 'error', description = 'Usage: /prop <model>' })
        return
    end
    spawnProp(args[1])
end, false)

RegisterCommand('propdel', function()
    if not current then
        lib.notify({ type = 'info', description = 'Nothing spawned.' })
        return
    end
    deleteCurrent()
    lib.notify({ type = 'info', description = 'Prop deleted.' })
end, false)

RegisterCommand('propinfo', function()
    if not current or not DoesEntityExist(current) then
        lib.notify({ type = 'info', description = 'Nothing spawned.' })
        return
    end
    local s = modelSize(joaat(currentModel))
    local c = GetEntityCoords(current)
    print(('[propcheck] %s'):format(currentModel))
    print(('[propcheck]   size   %.2f x %.2f x %.2f m'):format(s.x, s.y, s.z))
    print(('[propcheck]   coords vec3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z))
    lib.notify({ type = 'info', title = currentModel,
        description = ('%.2f x %.2f x %.2f m — full detail in F8'):format(s.x, s.y, s.z),
        duration = 8000 })
end, false)

--- Capture where you are standing as an OFFSET from the spawned shell's origin.
---
--- qbx_properties' `interiors` config takes offsets, not world coords: see
--- CalculateOffsetCoords in its shared/main.lua, which adds them to the property
--- coords. So a raw /nodehere reading is the wrong shape for a shell.
---
--- The shell's origin is the centre of its walkable floor, so a point at floor
--- level should come out with z ~ 0, which is what every existing entry uses.
RegisterCommand('shellpoint', function(_, args)
    if not current or not DoesEntityExist(current) then
        lib.notify({ type = 'error', description = 'Spawn the shell first: /prop <shell>' })
        return
    end

    -- Offsets are only a plain subtraction while the shell is axis-aligned. If it
    -- were ever spawned rotated, the delta would need rotating back into the
    -- shell's own frame, so refuse rather than emit a wrong number.
    local shellHeading = GetEntityHeading(current)
    if math.abs((shellHeading + 180.0) % 360.0 - 180.0) > 0.5 then
        lib.notify({ type = 'error',
            description = ('Shell is rotated %.1f deg. Respawn it unrotated.'):format(shellHeading) })
        return
    end

    local label = args[1] or 'point'
    local origin = GetEntityCoords(current)
    local ped = cache.ped
    local here = GetEntityCoords(ped)
    local o = here - origin
    local heading = GetEntityHeading(ped)

    print(('[propcheck] shell point %q relative to %s'):format(label, currentModel))
    print(('[propcheck]   %s = vec3(%.2f, %.2f, %.2f)'):format(label, o.x, o.y, o.z))
    print(('[propcheck]   with heading: vec4(%.2f, %.2f, %.2f, %.2f)')
        :format(o.x, o.y, o.z, heading))
    if math.abs(o.z) > 0.25 then
        print(('[propcheck]   note: z is %.2f, not ~0 -- are you on the shell floor?'):format(o.z))
    end
    lib.notify({ type = 'success', title = label,
        description = ('vec3(%.2f, %.2f, %.2f) — full detail in F8'):format(o.x, o.y, o.z),
        duration = 8000 })
end, false)

RegisterCommand('proplist', function()
    print('[propcheck] candidate models (* = present in this build):')
    for i, m in ipairs(CANDIDATES) do
        local ok = IsModelInCdimage(joaat(m))
        print(('[propcheck]   %2d %s %s'):format(i, ok and '*' or ' ', m))
    end
    lib.notify({ type = 'info', description = 'Candidate list printed to F8.' })
end, false)

-- Which furnishing props actually resolve in this build. Reports the model's
-- real size for the ones that do, so the shell can be dimensioned around them
-- without spawning anything.
RegisterCommand('furnlist', function()
    print('[propcheck] furnishing models (* = in this build):')
    local ok, fail = 0, 0
    for _, m in ipairs(FURNITURE) do
        local hash = joaat(m)
        local present = IsModelInCdimage(hash) and IsModelValid(hash)
        local size = ''
        if present then
            ok = ok + 1
            -- GetModelDimensions needs the model loaded to be meaningful.
            if lib.requestModel(hash, 5000) then
                local s = modelSize(hash)
                size = ('  %.2f x %.2f x %.2f m'):format(s.x, s.y, s.z)
                SetModelAsNoLongerNeeded(hash)
            else
                size = '  (indexed but would not load)'
            end
        else
            fail = fail + 1
        end
        print(('[propcheck]   %s %-34s%s'):format(present and '*' or ' ', m, size))
    end
    print(('[propcheck] %d resolved, %d need a ytyp archetype'):format(ok, fail))
end, false)

RegisterCommand('propnext', function() cycle(1) end, false)
RegisterCommand('propprev', function() cycle(-1) end, false)

-- Capture a node coordinate by standing where you want it.
--
-- This exists because guessing coordinates does not work. The mining nodes were
-- configured at z values that turned out to be below the terrain, and no amount
-- of runtime ground-probing fixed that reliably -- it only hid the real problem.
-- Standing on the spot and reading the position off the game is exact.
--
-- Prints the player's foot position, which is exactly where a prop whose origin
-- sits at its base should be placed.
RegisterCommand('nodehere', function()
    local ped = cache.ped
    local c = GetEntityCoords(ped)
    -- GetEntityCoords returns the ped's root; subtract to get ground contact.
    local _, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    local line = ('vec3(%.2f, %.2f, %.2f),'):format(c.x, c.y, groundZ ~= 0 and groundZ or c.z)

    print('[propcheck] ' .. line)
    print(('[propcheck]   ped z=%.2f  ground z=%.2f  heading=%.1f')
        :format(c.z, groundZ or 0.0, GetEntityHeading(ped)))

    lib.setClipboard(line)
    lib.notify({
        type = 'success',
        title = 'Node coordinate copied',
        description = line,
        duration = 8000,
    })
end, false)

-- Capture a coordinate AND a facing, for props where orientation matters.
--
-- /nodehere gives a bare vec3, which is all a boulder needs -- a rock looks the
-- same from any angle. A smelter does not: it has a front. This prints the full
-- config entry instead.
--
-- Stand on the spot facing the smelter the way you want it to end up, and the
-- heading is used as-is.
--
-- An earlier version added 180 degrees, reasoning that the smelter's firebox is
-- modelled on -Y while a GTA entity points +Y at heading 0. That cancels out:
-- the player's own heading is measured the same way, so the raw value is
-- already correct and the correction turned every prop back to front. Verified
-- in-game on both smelter sites.
RegisterCommand('sitehere', function()
    local ped = cache.ped
    local c = GetEntityCoords(ped)
    local _, groundZ = GetGroundZFor_3dCoord(c.x, c.y, c.z + 1.0, false)
    local h = GetEntityHeading(ped)
    local line = ('{ coords = vec3(%.2f, %.2f, %.2f), heading = %.1f },')
        :format(c.x, c.y, groundZ ~= 0 and groundZ or c.z, h)

    print('[propcheck] ' .. line)
    lib.setClipboard(line)
    lib.notify({ type = 'success', title = 'Site captured',
        description = line, duration = 8000 })
end, false)

-- ── Particle effects ────────────────────────────────────────────────────
--
-- ptfx asset names cannot be derived or listed at runtime, and a wrong one
-- fails silently -- no error, just nothing. Same problem as prop names, so the
-- same answer: cycle candidates in-game and keep what looks right.
--
-- /smoke              cycle to the next candidate at your feet
-- /smoke <dict> <fx>  try a specific pair
-- /smokestop          stop the current effect

local SMOKE_CANDIDATES = {
    { 'core', 'ent_amb_smoke_general' },
    { 'core', 'exp_grd_bzgas_smoke' },
    { 'core', 'fire_wrecked_plane_cabin' },
    { 'core', 'ent_ray_paleto_gas_flames' },
    { 'core', 'ent_dst_gen_gobstop' },
    { 'scr_carsteal4', 'scr_carsteal4_wheel_burnout' },
    { 'scr_trevor3', 'scr_trev3_trailer_boosh' },
    { 'scr_agencyheistb', 'scr_agency3b_smoke' },
    { 'cut_trevor1', 'cs_trev1_camp_fire' },
}

local smokeFx, smokeIndex = nil, 0

local function stopSmoke()
    if smokeFx then
        StopParticleFxLooped(smokeFx, false)
        smokeFx = nil
    end
end

local function playSmoke(dict, effect)
    stopSmoke()
    if not lib.requestNamedPtfxAsset(dict, 8000) then
        lib.notify({ type = 'error', description = ('dict %s would not load'):format(dict) })
        print(('[propcheck] ptfx dict FAILED: %s'):format(dict))
        return false
    end
    UseParticleFxAsset(dict)

    local c = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 1.5
    smokeFx = StartParticleFxLoopedAtCoord(effect, c.x, c.y, c.z + 1.0,
        0.0, 0.0, 0.0, 1.0, false, false, false, false)

    -- A bad effect name inside a good dict returns a handle anyway and simply
    -- draws nothing, so the handle is not proof it worked -- your eyes are.
    print(('[propcheck] ptfx %s / %s  handle=%s'):format(dict, effect, tostring(smokeFx)))
    lib.notify({ type = 'info', title = dict, description = effect, duration = 6000 })
    return true
end

RegisterCommand('smoke', function(_, args)
    if args[1] and args[2] then
        playSmoke(args[1], args[2])
        return
    end
    smokeIndex = smokeIndex + 1
    if smokeIndex > #SMOKE_CANDIDATES then smokeIndex = 1 end
    local c = SMOKE_CANDIDATES[smokeIndex]
    lib.notify({ type = 'info',
        description = ('%d / %d'):format(smokeIndex, #SMOKE_CANDIDATES) })
    playSmoke(c[1], c[2])
end, false)

RegisterCommand('smokestop', function()
    stopSmoke()
    lib.notify({ type = 'info', description = 'Effect stopped.' })
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == cache.resource then
        deleteCurrent()
        stopSmoke()
    end
end)

print('[propcheck] loaded — /prop /propdel /propinfo /proplist /propnext /propprev')
