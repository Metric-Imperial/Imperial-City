#!/usr/bin/env python3
"""Verify that server.cfg.template ensures resources after their dependencies.

Checks:
  1. Every custom resource in resources/[custom] is ensured in server.cfg.template.
  2. For each custom fxmanifest `dependencies`, the dependency is ensured earlier
     (folder ensures like `ensure [qbx]` count for resources placed there by the
     recipe — mapping below) or is a server/gamebuild constraint.
  3. No resource is ensured twice.
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CFG = ROOT / "recipes" / "server.cfg.template"
CUSTOM = ROOT / "resources" / "[custom]"

# Resources provided by folder-level ensures at recipe install time.
FOLDER_MEMBERS = {
    "[ox]": {"ox_doorlock", "ox_fuel", "oxmysql", "ox_lib", "ox_target", "ox_inventory"},
    "[qbx]": {
        "qbx_core", "qbx_vehicles", "qbx_spawn", "qbx_smallresources", "qbx_density",
        "qbx_hud", "qbx_adminmenu", "qbx_management", "qbx_garages", "qbx_vehicleshop",
        "qbx_vehiclesales", "qbx_customs", "qbx_vehiclekeys", "qbx_carwash", "qbx_idcard",
        "qbx_radialmenu", "qbx_scoreboard", "qbx_seatbelt", "qbx_binoculars",
        "qbx_cityhall", "qbx_medical", "qbx_ambulancejob", "qbx_police",
    },
    "[standalone]": {
        "bob74_ipl", "safecracker", "mhacking", "ultra-voltlab", "screencapture",
        "scully_emotemenu", "Renewed-Banking", "MugShotBase64", "loadscreen",
        "mana_audio", "Renewed-Weathersync", "xt-prison", "vehiclehandler",
    },
    "[appearance]": {"illenium-appearance"},
    "[voice]": {"pma-voice", "mm_radio"},
    "[maps]": {"pillbox"},
    "[housing]": {"qbx_properties"},
    "[civilian-jobs]": {
        "qbx_taxijob", "qbx_truckerjob", "qbx_towjob", "qbx_garbagejob", "qbx_busjob",
        "qbx_newsjob", "qbx_recyclejob", "qbx_mechanicjob", "qbx_diving", "qbx_divegear",
    },
    "[criminal]": {
        "qbx_storerobbery", "qbx_bankrobbery", "qbx_truckrobbery", "qbx_houserobbery",
        "qbx_jewelery", "qbx_pawnshop", "qbx_scrapyard", "qbx_drugs", "qbx_weed",
        "qbx_streetraces", "qbx_lapraces", "qbx_vineyard",
    },
    "[phone]": {"npwd_qbx_garages", "npwd_qbx_mail"},
}

IGNORED_DEPS = re.compile(r"^/(server|onesync|gamebuild|native):")


def ensured_sequence():
    order = []
    for line in CFG.read_text().splitlines():
        m = re.match(r"\s*ensure\s+(\S+)", line)
        if m:
            order.append(m.group(1))
    return order


def position_map(order):
    pos = {}
    for i, name in enumerate(order):
        if name in pos:
            print(f"FAIL: '{name}' ensured twice")
            return None
        pos[name] = i
        for member in FOLDER_MEMBERS.get(name, ()):  # folder ensure covers members
            pos.setdefault(member, i)
    return pos


def manifest_deps(path):
    text = path.read_text()
    m = re.search(r"dependencies\s*\{(.*?)\}", text, re.S)
    if not m:
        return []
    return re.findall(r"['\"]([^'\"]+)['\"]", m.group(1))


def main():
    order = ensured_sequence()
    pos = position_map(order)
    if pos is None:
        return 1
    failures = 0

    for manifest in sorted(CUSTOM.glob("*/fxmanifest.lua")):
        res = manifest.parent.name
        if res not in pos:
            print(f"FAIL: custom resource '{res}' is not ensured in server.cfg.template")
            failures += 1
            continue
        for dep in manifest_deps(manifest):
            if IGNORED_DEPS.match(dep):
                continue
            if dep not in pos:
                print(f"FAIL: {res} depends on '{dep}' which is never ensured")
                failures += 1
            elif pos[dep] > pos[res]:
                print(f"FAIL: {res} (#{pos[res]}) ensured before dependency '{dep}' (#{pos[dep]})")
                failures += 1

    print(f"startup order: {len(order)} ensures, {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
