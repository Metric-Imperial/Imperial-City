# 02 — Installation

## Prerequisites

- A fresh Linux (recommended) or Windows box able to run FXServer, with
  txAdmin.
- MariaDB **≥ 10.9** (12.3 LTS recommended — matches the official Qbox
  recipe's tested baseline).
- A valid Cfx.re server licence key (`sv_licenseKey`).
- Outbound access to GitHub and the various resource release hosts listed
  in `recipes/imperial-city-qbox.yaml` — the recipe downloads every
  third-party resource at deploy time, it does not vendor them.
- A fork of this repository (`imperial-city`) reachable at a URL you
  control, since `recipes/imperial-city-qbox.yaml`'s first task
  (`download_github`) pulls the custom `[custom]` suite, SQL migrations,
  and base config files from it. **Replace `YOUR_ORG/imperial-city` in
  that file with your fork before deploying** — this is the one edit every
  operator must make; nothing else in the recipe should need changing to
  get a base install running.

## Deploy via txAdmin

1. Start txAdmin on a clean box (`txAdmin` ships with recent `FXServer`
   builds — see Cfx.re's own txAdmin docs for the base FXServer setup,
   which is outside the scope of this recipe).
2. In the deployer, choose **"Import a Recipe"** (or the local-file
   equivalent, depending on your txAdmin version) and point it at
   `recipes/imperial-city-qbox.yaml`.
3. Fill in the recipe's requested variables: server name, max clients,
   licence key, database connection string, and the recipe metadata fields.
   **Never commit real secrets into the recipe file itself** — these are
   supplied at deploy time through txAdmin's own variable prompts, which is
   why `recipes/imperial-city-qbox.yaml` only ever references
   `{{variable}}` placeholders.
4. Let the deployer run. It will, in order: pull the custom suite and SQL
   migrations from your fork, run the migration ledger against your
   database, pull cfx-server-data base resources (minus the chat resource,
   which qbx_core replaces), pull the full ox/qbx/civilian-job/criminal/
   housing/standalone/voice/phone resource set from each project's own
   release or source, and drop the Imperial item catalogue into
   `ox_inventory/data/items.lua`.
5. Once the deploy finishes, review `server.cfg` (generated from
   `recipes/server.cfg.template`) and the five split config files it
   `exec`s (`voice.cfg`, `ox.cfg`, `permissions.cfg`, `misc.cfg`,
   `economy.cfg`) — adjust anything site-specific (Discord link, ACE
   permission grants for your actual admins, economy balancing) before
   first boot. See `docs/06-configuration.md` for what lives where.
6. Boot the server. Watch the console for resource-start errors — a clean
   boot should show all Tier 0–6 resources starting in the order documented
   in `docs/03-startup-order.md` with no "could not find" or dependency
   warnings from `qbx_core`.
7. Confirm the migration ledger applied cleanly: `SELECT * FROM
   imperial_migrations ORDER BY id;` should list all 12 migrations
   (`sql/000` through `sql/011`) — see `docs/07-database.md`.

## Post-install checklist

- [ ] Set real ACE permissions for your admin team in `permissions.cfg`
      (the shipped file is a template, not a working admin list).
- [ ] Set `qbx:discordLink` in `server.cfg` to your actual Discord.
- [ ] Set `imperial:webhook_audit` to a real Discord webhook URL if you
      want severity ≥ 3 audit events mirrored live (leave blank to rely on
      the database-only log, which is authoritative either way).
- [ ] Review `economy.cfg` against your server's intended pace — every
      figure in it is a starting baseline, not a balanced-for-you final
      value (see `docs/08-economy.md`).
- [ ] Walk `docs/19-testing.md`'s single-player checklist before opening to
      players, and the two-player/exploit checklist before a public launch.
- [ ] Confirm `imperial:debug` is `false` (it is by default) before going live.

## What this recipe does not automate

- Admin identity/ACE assignment (a security-sensitive, per-operator step —
  intentionally not scripted).
- Discord bot / external integrations beyond the optional audit webhook.
- DNS, reverse proxy, or txAdmin's own web-panel security hardening — these
  are FXServer/txAdmin operational concerns, not recipe concerns.
