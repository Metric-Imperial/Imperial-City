--- imperial_mdt/client/main.lua
--- Thin NUI bridge. All data comes from server callbacks; the NUI never
--- decides permissions, it just renders what the server returned (or the
--- server's rejection, which the UI presents as "access denied").

local open = false

local function setOpen(state)
    open = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'setVisible', visible = state })
end

RegisterCommand('mdt', function()
    if open then setOpen(false) return end
    setOpen(true)
end, false)
RegisterKeyMapping('mdt', 'Open MDT', 'keyboard', 'F6')

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb('ok')
end)

local function bridge(name)
    RegisterNUICallback(name, function(data, cb)
        local result = { lib.callback.await('imperial_mdt:' .. name, false, table.unpack(data.args or {})) }
        cb(result)
    end)
end

bridge('getReports')
bridge('getReport')
bridge('createReport')
bridge('getWarrants')
bridge('createWarrant')
bridge('clearWarrant')
bridge('getBolos')
bridge('createBolo')
bridge('lookupPerson')
bridge('getRecentCalls')

RegisterNUICallback('getChargeCodes', function(_, cb)
    cb(ImperialMDT.chargeCodes)
end)
