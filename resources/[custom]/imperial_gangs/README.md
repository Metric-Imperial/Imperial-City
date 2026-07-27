# imperial_gangs

Dynamic, database-backed gangs — created and managed entirely in-game, not
through static qbx_core config. Per the master decision rules (adapters over
core edits), this resource does **not** call `qbx_core:SetGang` or otherwise
register dynamic gangs into the framework's static gang list; instead it
exposes compatibility exports (`GetMemberRank`, `IsGangMember`,
`HasGangPermission`, `GetGang`, `GetPlayerGang`) that any gang-aware resource
(imperial_turfs, imperial_crafting's gang-gated benches, imperial_drugs lab
ownership) calls instead of reading `PlayerData.gang`.

## Founding a gang
`/creategang <name>` starts a founding session; nearby players run
`/joingang` within the window (default 90 s, 15 m radius) to join. The
founder then finalises once `minFoundingMembers` (default 3, config) have
joined — this is the "minimum founding members" requirement made concrete
without a blocking multi-step wizard. The creation fee
(`imperial:econ:gang:creationFee`) is charged only on successful finalisation.

## Structure
One gang per citizen (DB primary key on `imperial_gang_members.citizenid`
enforces this structurally — a second `INSERT` for an already-gang'd citizen
fails at the database level even if application logic were bypassed). Ranks
0–3 (Member/Senior/Officer/Leader); rank 3 is unique per gang (the leader) and
transferable via `transferLeadership`, which cannot be self-targeted-away
without a successor.

## Money & storage
Same atomic-adjust + ledger pattern as `imperial_businesses`
(`AddGangFunds`/`RemoveGangFunds` exports; `imperial_gang_txns` table).
Gang storage is a single shared `ox_inventory` stash keyed by `gang_<key>`.

## Commands
`/creategang`, `/joingang`, `/gang` (management menu), `/gangstash`.
Admin: `/gangdisband <key>` (ACE `group.admin`).

## Test checklist
- [ ] A player already in a gang cannot found or join another.
- [ ] Finalising with fewer than the minimum founders is rejected.
- [ ] Rank changes/kicks respect the rank hierarchy (cannot act on equal/higher).
- [ ] Leader cannot be kicked directly; must transfer leadership first.
- [ ] `HasGangPermission` correctly reflects rank after a `setRank` change.
