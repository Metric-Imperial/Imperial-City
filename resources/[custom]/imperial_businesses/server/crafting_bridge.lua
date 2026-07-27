--- imperial_businesses/server/crafting_bridge.lua
--- Registers business crafting stations (barista, kitchen, fabrication…) into
--- imperial_crafting rather than duplicating a second crafting system.
--- imperial_crafting must be started before imperial_businesses (see
--- server.cfg.template tier 6 ordering).

CreateThread(function()
    if GetResourceState('imperial_crafting') ~= 'started' then return end

    for _, recipe in ipairs(ImperialBusinessRecipes) do
        exports.imperial_crafting:RegisterRecipe(recipe)
    end

    for _, site in ipairs(ImperialBusinessSites) do
        if site.craftingBench then
            exports.imperial_crafting:RegisterBench({
                id = site.craftingBench.id,
                label = site.craftingBench.label,
                coords = site.storageIngredients or site.management,
                categories = site.craftingBench.categories,
                -- gated by business employment (perm 'stock') via imperial_crafting's
                -- restrict.business delegation — not by qbx framework job/gang.
                restrict = { business = site.key, businessPerm = 'stock' },
            })
        end
    end
end)
