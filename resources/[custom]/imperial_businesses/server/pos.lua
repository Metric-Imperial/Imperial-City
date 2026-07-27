--- imperial_businesses/server/pos.lua
--- Point of sale: employee charges a nearby customer; customer must confirm.
--- Tax is applied to the business side and sunk (government).

local pending = {} -- [customerSrc] = { businessId, employeeSrc, amount, expires, ref }

lib.callback.register('imperial_businesses:pos:charge', function(src, businessKey, targetSource, amount, note)
    if not exports.imperial_logging:RateLimit(src, 'biz:pos', 6, 10000) then return false end
    local okPerm, business, snap = BizHasPermission(src, businessKey, 'pos')
    if not okPerm then return false end
    local okAmt, n = exports.imperial_logging:ValidateAmount(amount, 1, ImperialBusinesses.posMaxCharge)
    if not okAmt then return false end
    if type(targetSource) ~= 'number' or targetSource == src then return false end

    local customer = exports.qbx_core:GetPlayer(targetSource)
    if not customer then return false, 'nocustomer' end

    local a = GetEntityCoords(GetPlayerPed(src))
    local b = GetEntityCoords(GetPlayerPed(targetSource))
    if #(a - b) > 8.0 then return false, 'toofar' end

    if pending[targetSource] then return false, 'busy' end
    local ref = ('%s-%d-%d'):format(businessKey, os.time(), math.random(999))
    pending[targetSource] = {
        businessId = business.id,
        businessKey = businessKey,
        employeeSrc = src,
        employeeCitizenid = snap.citizenid,
        amount = n,
        note = type(note) == 'string' and note:sub(1, 80) or nil,
        expires = os.time() + 60,
        ref = ref,
    }
    TriggerClientEvent('imperial_businesses:client:posPrompt', targetSource,
        business.label, n, pending[targetSource].note)
    return true
end)

lib.callback.register('imperial_businesses:pos:respond', function(src, accept)
    local invoice = pending[src]
    pending[src] = nil
    if not invoice then return false end
    if os.time() > invoice.expires then return false, 'expired' end
    if accept ~= true then
        local emp = invoice.employeeSrc
        if emp then exports.qbx_core:Notify(emp, 'Customer declined the charge', 'error') end
        return true, 'declined'
    end

    local customer = exports.qbx_core:GetPlayer(src)
    if not customer then return false end

    -- prefer bank, fall back to cash
    local paid = customer.Functions.RemoveMoney('bank', invoice.amount, 'imperial-pos')
        or customer.Functions.RemoveMoney('cash', invoice.amount, 'imperial-pos')
    if not paid then return false, 'insufficient' end

    local taxPct = GetConvarInt(ImperialBusinesses.posTaxConvar, 4)
    local tax = math.floor(invoice.amount * taxPct / 100)
    local net = invoice.amount - tax

    BizAdjust(invoice.businessId, net, 'pos_sale', invoice.employeeCitizenid, invoice.ref)
    if tax > 0 then
        exports.imperial_logging:Log({
            resource = 'imperial_businesses', category = 'money', action = 'biz_tax_sink',
            amount = tax, data = { business = invoice.businessKey, ref = invoice.ref },
        })
    end

    if invoice.employeeSrc then
        exports.qbx_core:Notify(invoice.employeeSrc,
            ('Payment received: $%s'):format(net), 'success')
    end
    return true, 'paid'
end)

-- expire stale invoices
CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, invoice in pairs(pending) do
            if now > invoice.expires then pending[src] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    pending[source] = nil
end)
