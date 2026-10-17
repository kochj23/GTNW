#!/usr/bin/env python3
"""Build the local Shadow Pack for GTNW from assets harvested out of YOUR OWN copy of Shadow President (1993).

  build_shadow_pack.py [--source DIR] [--data DIR] [--dest DIR] [--only-gtnw]

--source: an extraction folder containing CATALOG.json (default /Volumes/Data/reverse/shadow/assets)
--data:   decoded scenario JSON (scenario_S0.json ...) copied to <dest>/data for the 1990 scenario
          (default /Volumes/Data/reverse/shadow/out/data; skipped if missing)
--dest:   default ~/Library/Application Support/GTNW/ShadowPack
The pack is personal, local data: it is never added to this repository (see .gitignore).
"""
import argparse
import json
import os
import shutil
import sys

DEFAULT_SRC = "/Volumes/Data/reverse/shadow/assets"
DEFAULT_DATA = "/Volumes/Data/reverse/shadow/out/data"
DEFAULT_DEST = os.path.expanduser("~/Library/Application Support/GTNW/ShadowPack")
KINDS = {"image", "sprite", "animation", "sound", "map"}      # 'capture' screenshots are reference only


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--source", default=DEFAULT_SRC)
    ap.add_argument("--dest", default=DEFAULT_DEST)
    ap.add_argument("--data", default=DEFAULT_DATA)
    ap.add_argument("--only-gtnw", action="store_true", help="skip entries without a suggested GTNW use")
    a = ap.parse_args(argv)
    cat = json.load(open(os.path.join(a.source, "CATALOG.json")))
    entries = cat["entries"] if isinstance(cat, dict) else cat
    os.makedirs(a.dest, exist_ok=True)
    out, missing = [], 0
    for e in entries:
        if e.get("kind") not in KINDS or (a.only_gtnw and not e.get("gtnw_use")):
            continue
        src = os.path.join(a.source, e["path"])
        if not os.path.isfile(src):
            missing += 1
            continue
        dst = os.path.join(a.dest, e["path"])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
            shutil.copy2(src, dst)
        out.append({k: e.get(k) for k in ("id", "kind", "path", "depicts", "width", "height")})
    with open(os.path.join(a.dest, "CATALOG.json"), "w") as f:
        json.dump({"version": 1, "source": "Shadow President (1993) - local, personal pack", "entries": out}, f, indent=1)
    copied = 0
    if os.path.isdir(a.data):
        os.makedirs(os.path.join(a.dest, "data"), exist_ok=True)
        for name in sorted(os.listdir(a.data)):
            if name.startswith("scenario_") and name.endswith(".json"):
                shutil.copy2(os.path.join(a.data, name), os.path.join(a.dest, "data", name))
                copied += 1
    print(f"Shadow Pack: {len(out)} assets, {copied} scenario files -> {a.dest} ({missing} catalog entries had no file)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
