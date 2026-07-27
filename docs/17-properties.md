# 17 — Real Estate & Property

Housing runs on **qbx_properties** (Qbox-project/qbx_properties, GPLv3, active).
It is the only maintained free Qbox-native housing system (see
`docs/05-resource-selection.md`); `qbx_apartments`/`qbx_houses` are archived
upstream and must not be installed alongside it.

## Coverage from qbx_properties
Purchase, rental, sale, transfer, keys/key-sharing, door access, stash,
wardrobe, and furniture placement/persistence are native to the resource.
Apartment and house shells are supported out of the box; MLO interiors are
added via its config per the upstream README.

## Imperial integration points
* **Garages** — property garages are provided by `qbx_garages` reading
  property ownership from qbx_properties; no bridge code needed (both are
  Qbox-native and share the qbx_core data model).
* **Business properties / warehouses / leases** — handled by
  `imperial_businesses` (see docs/10), which is the authority for anything
  that is a *business* asset (warehouses, workshops, business leases, gang
  properties are gang-owned via `imperial_gangs`, not qbx_properties).
* **Realtor role** — the `dynasty8` seed business in imperial_businesses
  gives a management structure (hire/fire/ledger) for a realtor job; the
  actual listing/sale flow remains qbx_properties'.
* **Starter accommodation** — `imperial_character`'s first-login hook
  (`imperial_character:server:firstLogin`) is the integration point for
  offering a starter rental; disabled by default, documented in docs/06.

## Documented WIP gaps (from repository inspection, 2026-07)
qbx_properties' own issue tracker lists realtor-job polish, decoration
options, and MLO support as in-progress. Operators should:
1. Test the purchase/rental/key-sharing/eviction flow on a staging server
   before going live (see docs/19 testing plan, Property Tests section).
2. Review qbx_properties' door/access validation is server-side before
   trusting it for high-value MLO interiors — do not assume client-side
   checks are sufficient (see docs/18 security review).
3. Track upstream releases; this recipe pins to `ref: main` for
   qbx_properties specifically because there are no tagged releases yet —
   revisit pinning to a commit SHA once the project cuts one (see docs/21).
