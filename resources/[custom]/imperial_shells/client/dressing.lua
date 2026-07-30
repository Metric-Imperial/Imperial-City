--- Fixed dressing for the housing shells: wall art and ceiling pendants.
---
--- Why these are spawned rather than baked: they are Rockstar props, so unlike
--- the wardrobe, dresser and bed -- which are our own sculpts and ARE built into
--- the shell model -- there is no geometry to bake. Spawning them at fixed
--- offsets still gives every apartment the same room and needs no
--- properties_decorations rows, and it touches neither qbx_properties nor the
--- props themselves, so nothing here reverts on a redeploy.
---
--- Offsets are from the shell's origin, which is the centre of its floor. The
--- shell is spawned unrotated, so its axes are the world axes and the offsets
--- are plain addition.

local SHELL_MODEL = `imperial_furnished_motel_room`

--- `z` is the height of the BOTTOM of the prop above the shell floor, NOT the
--- entity origin. A GTA prop's origin can sit anywhere inside it, so the spawn
--- height is derived from GetModelDimensions at runtime. Hard-coding an origin
--- offset would be a separate guess for every model.
---
--- `heading` is the direction the art's FACE points. These pieces face -Y at
--- heading 0, established in game -- the first attempt assumed +Y and hung all
--- three looking into the wall. So a piece goes on the -Y wall at heading 180,
--- the +Y wall at 0, and the -X wall at 90.
local DRESSING = {
    -- Wall art. h4_mp_h_acc_artwallm_03 is 1.37 x 1.36 and is the only one of
    -- the three supplied that actually fits: apa_p_h_acc_artwalll_01 is 2.32m
    -- tall against a wall only 2.60m to the soffit, so it would run nearly floor
    -- to ceiling, and m25_2_prop_m52_wallart_c_10 is 5.57m wide -- wider than
    -- any clear wall left once the wardrobes, dresser and door are in.
    -- Over the bed, on the dark accent wall. Bottom clears the 0.96m headboard.
    { model = `h4_mp_h_acc_artwallm_03`, x =  0.00, y = -2.46, z = 1.10, heading = 180.0 },
    -- The -X wall, which carries no furniture at all.
    { model = `h4_mp_h_acc_artwallm_03`, x = -3.96, y =  0.00, z = 0.95, heading =  90.0 },
    -- The gap on the +Y wall between the wardrobe run and the dresser.
    { model = `h4_mp_h_acc_artwallm_03`, x = -0.05, y =  2.46, z = 0.95, heading =   0.0 },

    -- Ceiling pendants. The fitting is 1.52m tall, so hung from the 2.80m
    -- ceiling its shade would sit at 1.28m: below head height, in the middle of
    -- the room. Raised so the BOTTOM clears at 2.15m. The stem then passes up
    -- through the ceiling slab and out through the roof, which nothing ever
    -- sees -- the slab occludes it from inside, and a shell sits 50m under the
    -- world with nothing around it. Spawn one on the surface with /prop and the
    -- stems will poke out of the roof; that is only true of the test spawn.
    { model = `apa_mp_h_lit_lightpendant_05b`, x = -2.00, y = 0.00, z = 2.15, heading = 0.0 },
    { model = `apa_mp_h_lit_lightpendant_05b`, x =  2.00, y = 0.00, z = 2.15, heading = 0.0 },
}

local spawned = {}
local dressedAt = nil       -- origin of the shell the dressing belongs to

---joaat comes back signed from a backtick literal but can arrive unsigned from
---the database via tonumber, so compare the low 32 bits of both.
local function sameModel(a, b)
    return (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF)
end

local function clear()
    for i = #spawned, 1, -1 do
        if DoesEntityExist(spawned[i]) then DeleteEntity(spawned[i]) end
        spawned[i] = nil
    end
    dressedAt = nil
end

--- Clear the dressing if the shell it belongs to goes away.
---
--- unloadProperty covers leaving a property, but nothing covers the shell being
--- deleted from under it -- /propdel during testing leaves the art and pendants
--- hanging in mid-air. Watching for the shell itself rather than hooking
--- propcheck keeps this self-contained and catches every other way it could
--- vanish too. Only runs while something is actually spawned.
local function watchShell()
    CreateThread(function()
        while dressedAt do
            Wait(1000)
            if not dressedAt then return end
            local shell = GetClosestObjectOfType(dressedAt.x, dressedAt.y, dressedAt.z,
                2.0, SHELL_MODEL, false, false, false)
            if shell == 0 or not DoesEntityExist(shell) then
                print('[shells] shell gone; clearing its dressing')
                clear()
                return
            end
        end
    end)
end

---Spawn the dressing around a shell whose origin is at `origin`.
local function dress(origin)
    clear()
    local placed, failed = 0, 0

    for _, d in ipairs(DRESSING) do
        if lib.requestModel(d.model, 5000) then
            -- min.z is the offset from the entity origin down to the prop's
            -- lowest point, so this lands the BOTTOM where asked regardless of
            -- where the origin happens to be.
            local min = GetModelDimensions(d.model)
            local obj = CreateObjectNoOffset(d.model,
                origin.x + d.x, origin.y + d.y, origin.z + d.z - min.z,
                false, false, false)
            SetEntityHeading(obj, d.heading)
            -- Decoration only. Collision on wall art pushes players off the
            -- wall, and on a pendant it would be an invisible obstacle at head
            -- height.
            SetEntityCollision(obj, false, false)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(d.model)
            spawned[#spawned + 1] = obj
            placed = placed + 1
        else
            failed = failed + 1
            print(('[shells] dressing model %s would not load'):format(d.model))
        end
    end

    dressedAt = vec3(origin.x, origin.y, origin.z)
    watchShell()

    print(('[shells] dressed shell at %.2f %.2f %.2f: %d placed, %d failed')
        :format(origin.x, origin.y, origin.z, placed, failed))
    return placed
end

-- createInterior carries the shell's spawn position, which IS its origin: see
-- qbx_properties/client/property.lua, which passes the same vector straight to
-- CreateObjectNoOffset.
RegisterNetEvent('qbx_properties:client:createInterior', function(interiorHash, interiorCoords)
    if not sameModel(interiorHash, SHELL_MODEL) then return end
    dress(interiorCoords)
end)

RegisterNetEvent('qbx_properties:client:unloadProperty', clear)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clear() end
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', clear)

--- Dress a shell spawned with /prop, so the layout can be checked without owning
--- a property. Finds the nearest shell rather than taking coordinates, because
--- the offsets are only meaningful relative to one.
RegisterCommand('shelldress', function(_, args)
    if (args[1] or ''):lower() == 'off' then
        clear()
        lib.notify({ type = 'info', description = 'Shell dressing removed.' })
        return
    end

    local c = GetEntityCoords(cache.ped)
    local shell = GetClosestObjectOfType(c.x, c.y, c.z, 40.0, SHELL_MODEL, false, false, false)
    if shell == 0 or not DoesEntityExist(shell) then
        lib.notify({ type = 'error',
            description = 'No imperial_furnished_motel_room nearby. Spawn one with /prop first.' })
        return
    end

    local n = dress(GetEntityCoords(shell))
    lib.notify({ type = n > 0 and 'success' or 'error',
        description = ('Dressed shell with %d prop(s) — detail in F8'):format(n) })
end, false)
