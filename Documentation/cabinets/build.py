#!/usr/bin/env python3
"""Validate data.py and generate cabinets.json, generic_roles.json, cabinets.md.

Usage: python3 build.py            (writes outputs next to this file)
       python3 build.py --check    (validate only)
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import data  # noqa: E402
from nations.common import SOURCES, ROLE_KEYS, REMOVAL_KEYS, GOV_TYPES  # noqa: E402

DATE_RE = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")
ROLE_LABELS = {
    "head_of_state": "Head of state",
    "head_of_government": "Head of government",
    "paramount_leader": "Paramount leader (party)",
    "foreign": "Foreign affairs",
    "defense": "Defence / war",
    "finance": "Finance / treasury",
    "interior": "Interior / home",
    "intelligence": "Intelligence / security chief",
    "military_chief": "Military chief",
}
ALLOWED_ROLES = set(ROLE_KEYS) | {"paramount_leader", "navy_minister"}


def dkey(s, end=False):
    """Sortable key for a partial date. end=True pads missing month/day to the latest value."""
    if not s:
        return "9999-99-99"
    pad = "99" if end else "00"
    parts = s.split("-") + [pad, pad]
    return "-".join(parts[:3])


def validate(nations):
    errors, warnings = [], []
    ids = set()
    for n in nations:
        nid = n.get("id")
        if nid in ids:
            errors.append(f"duplicate nation id {nid}")
        ids.add(nid)
        for k in ("id", "name", "tier", "periods", "roles"):
            if k not in n:
                errors.append(f"{nid}: missing {k}")
        for p in n.get("periods", []):
            if p["government_type"] not in GOV_TYPES:
                errors.append(f"{nid}: period {p['name']} bad government_type {p['government_type']}")
            for r in p["removal_mechanisms"]:
                if r not in REMOVAL_KEYS:
                    errors.append(f"{nid}: period {p['name']} bad removal {r}")
            for d in (p["from"], p["to"]):
                if d and not DATE_RE.match(d):
                    errors.append(f"{nid}: period {p['name']} bad date {d!r}")
        for role, holders in n.get("roles", {}).items():
            if role not in ALLOWED_ROLES:
                errors.append(f"{nid}: unknown role key {role}")
            for h in holders:
                for k in ("name", "title", "from", "to", "sources"):
                    if k not in h:
                        errors.append(f"{nid}/{role}: holder missing {k}: {h}")
                for d in (h.get("from"), h.get("to")):
                    if d and not DATE_RE.match(d):
                        errors.append(f"{nid}/{role}: {h.get('name')} bad date {d!r}")
                if h.get("from") and h.get("to") and dkey(h["to"], True) < dkey(h["from"]):
                    errors.append(f"{nid}/{role}: {h['name']} ends before it starts ({h['from']} > {h['to']})")
                for s in h.get("sources", []):
                    if s not in SOURCES:
                        errors.append(f"{nid}/{role}: {h.get('name')} unknown source key {s}")
                if not h.get("sources"):
                    warnings.append(f"{nid}/{role}: {h.get('name')} has no source")
    return errors, warnings


def expand_sources(keys):
    return [{"key": k, "title": SOURCES[k][0], "url": SOURCES[k][1]} for k in keys]


def to_json(nations):
    out = {
        "dataset": "GTNW world leaders & cabinets",
        "coverage": "1789-2030 (data current to %s)" % data.DATASET_CUTOFF,
        "date_format": "YYYY-MM-DD | YYYY-MM | YYYY; empty 'to' = incumbent at cut-off",
        "role_keys": {k: ROLE_LABELS[k] for k in ROLE_LABELS},
        "removal_mechanisms": REMOVAL_KEYS,
        "government_types": GOV_TYPES,
        "sources": {k: {"title": v[0], "url": v[1]} for k, v in SOURCES.items()},
        "nations": [],
    }
    for n in nations:
        roles = {}
        for role, holders in n["roles"].items():
            hs = sorted(holders, key=lambda h: dkey(h["from"]))
            roles[role] = [
                dict(h) for h in hs  # sources stay as keys into top-level "sources"
            ]
        nn = {
            "id": n["id"],
            "name": n["name"],
            "tier": n["tier"],
            "periods": n["periods"],
            "roles": roles,
            "role_notes": n.get("role_notes", {}),
            "uncertain": n.get("uncertain", []),
        }
        # Attach role holders to each period too (holders whose tenure overlaps the period).
        for p in nn["periods"]:
            pf, pt = dkey(p["from"]), dkey(p["to"], True)
            p_roles = {}
            for role, hs in roles.items():
                sel = [h["name"] for h in hs if dkey(h["from"]) <= pt and dkey(h["to"], True) >= pf]
                if sel:
                    p_roles[role] = sel
            p["holders_in_period"] = p_roles
        out["nations"].append(nn)
    return out


def count(nations):
    tot = 0
    per = {}
    for n in nations:
        c = sum(len(v) for v in n["roles"].values())
        per[n["id"]] = c
        tot += c
    return tot, per


def year_span(holders):
    if not holders:
        return ""
    f = min(dkey(h["from"])[:4] for h in holders)
    t = max(dkey(h["to"])[:4] for h in holders)
    return f"{f}-{'present' if t == '9999' else t}"


def to_md(nations, generic):
    tot, per = count(nations)
    L = []
    L.append("# GTNW leaders & cabinets dataset\n")
    L.append(f"Coverage 1789-2030, data current to {data.DATASET_CUTOFF}. "
             f"{len(nations)} named nations, {tot} office-holder records. "
             "Tier-3 nations use generic titles (generic_roles.json).\n")
    L.append("Sources: Encyclopaedia Britannica, official government/parliament histories where cited, "
             "rulers.org and worldstatesmen.org (Ben Cahoon) as cross-checks, Wikipedia only as a cross-check. "
             "Holders flagged `uncertain` have conflicting or unverified dates.\n")
    L.append("## Coverage summary\n")
    L.append("| Nation | Tier | Records | " + " | ".join(ROLE_LABELS[k] for k in ROLE_KEYS) + " |")
    L.append("|---|---|---|" + "---|" * len(ROLE_KEYS))
    for n in nations:
        cells = []
        for k in ROLE_KEYS:
            hs = n["roles"].get(k, [])
            cells.append(f"{len(hs)} ({year_span(hs)})" if hs else "-")
        L.append(f"| {n['name']} | {n['tier']} | {per[n['id']]} | " + " | ".join(cells) + " |")
    L.append("")
    for n in nations:
        L.append(f"## {n['name']} (tier {n['tier']})\n")
        L.append("### Periods\n")
        L.append("| From | To | Regime | Government type | Capital | Removal |")
        L.append("|---|---|---|---|---|---|")
        for p in n["periods"]:
            L.append(f"| {p['from']} | {p['to'] or 'present'} | {p['name']} | {p['government_type']} | {p['capital']} | {', '.join(p['removal_mechanisms'])} |")
        L.append("")
        for p in n["periods"]:
            if p.get("succession") or p.get("notes"):
                L.append(f"- **{p['name']} ({p['from']}–{p['to'] or 'present'})**: {p.get('succession','')} {p.get('notes','')}".rstrip())
        L.append("")
        if n.get("role_notes"):
            L.append("### Role notes (game handling)\n")
            for k, v in n["role_notes"].items():
                L.append(f"- **{ROLE_LABELS.get(k, k)}**: {v}")
            L.append("")
        for role in list(ROLE_KEYS) + ["paramount_leader", "navy_minister"]:
            hs = n["roles"].get(role)
            if not hs:
                continue
            L.append(f"### {ROLE_LABELS.get(role, role)}\n")
            for h in sorted(hs, key=lambda h: dkey(h["from"])):
                flag = " ⚠ uncertain" if h.get("uncertain") else ""
                act = " (acting)" if h.get("acting") else ""
                nat = f" — *{h['native_title']}*" if h.get("native_title") else ""
                note = f" — {h['note']}" if h.get("note") else ""
                L.append(f"- {h['from']} → {h['to'] or 'present'}: **{h['name']}**{act}, {h['title']}{nat}{note}{flag}")
            L.append("")
        unc = list(n.get("uncertain", []))
        unc += [f"{ROLE_LABELS.get(r, r)}: {h['name']} ({h['from']}–{h['to']})" + (f" — {h['note']}" if h.get('note') else "")
                for r, hs in n["roles"].items() for h in hs if h.get("uncertain")]
        if unc:
            L.append("### Uncertainties\n")
            for u in unc:
                L.append(f"- {u}")
            L.append("")
    L.append("## Generic role titles (tier 3)\n")
    for gt, roles in generic.items():
        L.append(f"### {gt}\n")
        for k, v in roles.items():
            if k in ("notes", "removal"):
                continue
            L.append(f"- {ROLE_LABELS.get(k, k)}: {v if v else '— (role does not exist; see notes)'}")
        L.append(f"- Removal: {', '.join(roles['removal'])}")
        if roles.get("notes"):
            L.append(f"- Notes: {roles['notes']}")
        L.append("")
    return "\n".join(L)


def main():
    nations = data.NATIONS
    errors, warnings = validate(nations)
    for w in warnings:
        print("WARN", w)
    for e in errors:
        print("ERROR", e)
    if errors:
        sys.exit(1)
    tot, per = count(nations)
    print(f"{len(nations)} nations, {tot} holder records")
    for k, v in per.items():
        print(f"  {k}: {v}")
    if "--check" in sys.argv:
        return
    with open(os.path.join(HERE, "cabinets.json"), "w") as f:
        json.dump(to_json(nations), f, indent=1, ensure_ascii=False)
    with open(os.path.join(HERE, "generic_roles.json"), "w") as f:
        json.dump({"government_types": data.GENERIC_ROLES, "removal_mechanisms": REMOVAL_KEYS}, f, indent=1, ensure_ascii=False)
    with open(os.path.join(HERE, "cabinets.md"), "w") as f:
        f.write(to_md(nations, data.GENERIC_ROLES))
    print("wrote cabinets.json, generic_roles.json, cabinets.md")


if __name__ == "__main__":
    main()
