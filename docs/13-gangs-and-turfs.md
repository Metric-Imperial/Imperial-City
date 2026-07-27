# 13 — Gangs & Turfs

## Gangs (`imperial_gangs`)
Fully dynamic, database-backed — no `qbx_core:SetGang` calls, no static
config edits required to add a gang. Gang-aware resources call
`GetMemberRank`/`IsGangMember`/`HasGangPermission`/`GetGang`/`GetPlayerGang`
rather than reading `PlayerData.gang`. See its README for the founding-session
flow (`minFoundingMembers`, `foundingWindowSec`), ranks, money, and storage.

## Turfs (`imperial_turfs`)
Declaration period → presence-gated capture window → resolution, with
defender advantage, cooldowns, participation caps, and a timeout. See its
README for the full conflict-rule breakdown. Ownership benefits (drug-sale
bonuses, black-market access, crafting discounts) are a documented extension
point via `GetTurfOwner`/`GetGangTurfs` — only a flat per-cycle cash income is
wired in by default, so operators choose how aggressively territory should
matter to their economy.

## Wiring a new ownership bonus (example)
```lua
-- inside any resource, e.g. a drug-sale price calculation
if GetResourceState('imperial_turfs') == 'started' then
    local ownerGang = exports.imperial_turfs:GetTurfOwner('turf_grovest')
    local sellerGang = exports.imperial_gangs:GetPlayerGang(citizenid)
    if sellerGang and ownerGang == sellerGang.key then
        price = math.floor(price * 1.15) -- 15% home-turf bonus
    end
end
```
