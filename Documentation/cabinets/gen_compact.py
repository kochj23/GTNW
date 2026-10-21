#!/usr/bin/env python3
"""Compact cabinets.json + generic_roles.json into Shared/Resources/nation_cabinets.json for the app (3.11.0).

Run from anywhere:  python3 Documentation/cabinets/gen_compact.py
Keeps names, titles, dates and the uncertain / acting flags; drops sources and notes (they stay in cabinets.json).
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "Shared", "Resources", "nation_cabinets.json")


def main():
    d = json.load(open(os.path.join(HERE, "cabinets.json")))
    g = json.load(open(os.path.join(HERE, "generic_roles.json")))
    nations = []
    for n in d["nations"]:
        roles = {}
        for role, holders in n["roles"].items():
            roles[role] = [[h["name"], h["title"], h["from"], h["to"] or "",
                            ("u" if h.get("uncertain") else "") + ("a" if h.get("acting") else "")] for h in holders]
        periods = [{"from": p["from"], "to": p["to"] or "", "name": p["name"], "gov": p["government_type"],
                    "removal": p["removal_mechanisms"]} for p in n["periods"]]
        nations.append({"id": n["id"], "name": n["name"], "periods": periods, "roles": roles})
    generic = {k: {"titles": {r: (v.get(r) or "") for r in d["role_keys"]}, "removal": v.get("removal", [])}
               for k, v in g["government_types"].items()}
    out = {"role_keys": list(d["role_keys"]), "generic": generic, "nations": nations}
    with open(OUT, "w") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    print(f"wrote {os.path.normpath(OUT)} ({os.path.getsize(OUT) // 1024} KB, {len(nations)} nations)")


if __name__ == "__main__":
    main()
