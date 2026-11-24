#!/usr/bin/env python3
"""Build GTNW's states and provinces (3.36.0) from Natural Earth admin-1 (public domain).

  natural_earth_admin1_to_gtnw.py ne_10m_admin_1_states_provinces.geojson ne_10m_populated_places_simple.geojson

Writes, from the repository root:
  Shared/Resources/subdivisions.json              geometry for the app's map (not part of GTNWCore / the Wasm build):
                                                  each subdivision's outer rings (for hit-testing and fills) and the
                                                  borders two subdivisions share (drawn faintly inside a nation)
  Shared/Engine/Shadow/SubdivisionData.swift      the engine's half: id, nation, name, kind, label point and a
                                                  population weight (per mille of the nation) for every subdivision

Needs shapely (pip install shapely). Sources: https://www.naturalearthdata.com (Admin 1 – States, Provinces and
Populated Places, 1:10m, public domain). Population weights are the populations of the Natural Earth towns and cities
inside each subdivision (80%) plus an even share (20%): a rough guide, not a census. The U.S. uses its real
electoral apportionment by year instead (Shared/Engine/Shadow/USStatesHistory.swift).

France, Italy and Spain are dissolved from departments and provinces into regions and autonomous communities, and the
United Kingdom into its four nations. Overseas parts that the world map draws as their own outlines are left out.
"""
import json, os, re, sys, unicodedata
from shapely.geometry import shape, Point, MultiPolygon, Polygon, LineString, MultiLineString
from shapely.ops import unary_union, linemerge

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POLY_TOL, LINE_TOL, MIN_ISLAND = 0.1, 0.06, 0.25

# Nations with subdivisions, and how their features group. None = one feature per subdivision.
NATIONS = {
    "USA": None, "CAN": None, "MEX": None, "BRA": None, "RUS": None, "CHN": None, "IND": None, "AUS": None,
    "DEU": None, "JPN": None, "UKR": None, "ARG": None, "ZAF": None, "KOR": None, "IDN": None, "PAK": None,
    "FRA": "region", "ITA": "region", "ESP": "region", "GBR": "geonunit",
}
DROP = {"Paracel Islands", "Macquarie Island", "Lord Howe Island", "Jervis Bay Territory", "Guadeloupe", "Guyane française",
        "Martinique", "Mayotte", "Réunion", "Ceuta", "Melilla"}
NAMES = {   # English names the game uses (American spelling), by Natural Earth name or English name
    "Bretagne": "Brittany", "Normandie": "Normandy", "Corse": "Corsica", "Bourgogne-Franche-Comté": "Burgundy-Franche-Comté",
    "Centre-Val de Loire": "Centre-Loire Valley", "Provence-Alpes-Côte-d'Azur": "Provence-Alpes-Côte d'Azur",
    "Lombardia": "Lombardy", "Piemonte": "Piedmont", "Toscana": "Tuscany", "Sardegna": "Sardinia", "Valle d'Aosta": "Aosta Valley",
    "Cataluña": "Catalonia", "Andalucía": "Andalusia", "País Vasco": "Basque Country", "Foral de Navarra": "Navarre",
    "Islas Baleares": "Balearic Islands", "Canary Is.": "Canary Islands", "Valenciana": "Valencia", "Aragón": "Aragon",
    "Castilla y León": "Castile and León", "Castilla-La Mancha": "Castile-La Mancha",
    "Jewish": "Jewish Autonomous Oblast", "Federal": "Federal District", "Free Hanseatic Bremen": "Bremen",
    "Autonomous Republic of Crimea": "Crimea", "Federally Administered Tribal Areas": "Tribal Areas",
}
KIND = {"FRA": "Region", "ITA": "Region", "ESP": "Autonomous Community", "GBR": "Nation"}
ISO2 = {"FRA": "FR", "ITA": "IT", "ESP": "ES", "GBR": "GB"}
IND_UT = {"IN-AN", "IN-CH", "IN-DH", "IN-DL", "IN-JK", "IN-LA", "IN-LD", "IN-PY"}
GB = {"England": "ENG", "Scotland": "SCT", "Wales": "WLS", "Northern Ireland": "NIR"}


def ascii_jp(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def english(p, a3):
    n = p.get("name_en") or p.get("name") or ""
    raw = p.get("name") or ""
    if a3 == "USA": return raw
    if raw in NAMES: return NAMES[raw]
    if n in NAMES: return NAMES[n]
    if a3 == "JPN": n = ascii_jp(n.replace(" Prefecture", ""))
    if a3 == "MEX" and raw == "Distrito Federal": n = "Mexico City"
    if a3 == "RUS" and raw == "Moskva": n = "Moscow"
    if a3 == "RUS" and raw == "Moskovskaya": n = "Moscow Oblast"
    if a3 == "RUS" and raw == "Altay": n = "Altai Krai"
    if a3 == "UKR" and raw == "Kiev City": n = "Kyiv City"
    if a3 == "ARG" and (p.get("type_en") or "").lower().startswith("autonomous city"): n = "Buenos Aires City"
    return n


def kind(p, a3):
    if a3 in KIND: return KIND[a3]
    if a3 == "IND":   # Natural Earth mislabels a few
        return "Union Territory" if p.get("iso_3166_2") in IND_UT else "State"
    t = (p.get("type_en") or "Province").strip()
    t = re.sub(r"\s+", " ", t)
    return {"Autonomous Okrug": "Autonomous Okrug", "Federal District": "Federal District"}.get(t, t.title() if t.islower() else t)


SLUGS = {"Cantabria": "CB", "Canary Islands": "CN", "Castile and León": "CL", "Castile-La Mancha": "CM", "Catalonia": "CT",
         "Basque Country": "PV", "Balearic Islands": "IB", "Madrid": "MD", "Murcia": "MC", "Navarre": "NC", "Valencia": "VC",
         "Andalusia": "AN", "Aragon": "AR", "Asturias": "AS", "Extremadura": "EX", "Galicia": "GA", "La Rioja": "RI",
         "Auvergne-Rhône-Alpes": "ARA", "Burgundy-Franche-Comté": "BFC", "Brittany": "BRE", "Centre-Loire Valley": "CVL",
         "Corsica": "COR", "Grand Est": "GES", "Hauts-de-France": "HDF", "Île-de-France": "IDF", "Normandy": "NOR",
         "Nouvelle-Aquitaine": "NAQ", "Occitanie": "OCC", "Pays de la Loire": "PDL", "Provence-Alpes-Côte d'Azur": "PAC",
         "Abruzzo": "65", "Aosta Valley": "23", "Apulia": "75", "Basilicata": "77", "Calabria": "78", "Campania": "72",
         "Emilia-Romagna": "45", "Friuli-Venezia Giulia": "36", "Lazio": "62", "Liguria": "42", "Lombardy": "25", "Marche": "57",
         "Molise": "67", "Piedmont": "21", "Sardinia": "88", "Sicily": "82", "Trentino-Alto Adige": "32", "Tuscany": "52",
         "Umbria": "55", "Veneto": "34"}


def slug(s):
    if s in SLUGS: return SLUGS[s]
    raise SystemExit(f"no id for {s!r}: add it to SLUGS")


def dp_ring(coords, tol):
    ring = Polygon(coords).simplify(tol, preserve_topology=True)
    if ring.is_empty or ring.geom_type != "Polygon": return None
    return list(ring.exterior.coords)


def flat(pts):
    out = []
    for x, y in pts: out += [round(x, 2), round(y, 2)]
    return out


def main(src, places):
    feats = json.load(open(src))["features"]
    groups = {}   # id -> dict(nation, name, kind, geoms, label)
    for f in feats:
        p = f["properties"]
        a3 = p.get("adm0_a3")
        if a3 not in NATIONS: continue
        name = english(p, a3)
        if not name or (p.get("name") or "") in DROP or name in DROP: continue
        g = shape(f["geometry"])
        if not g.is_valid: g = g.buffer(0)
        how = NATIONS[a3]
        if how:
            key = p.get(how) or ""
            if key in DROP or not key: continue
            sid = f"{ISO2[a3]}-{GB[key] if a3 == 'GBR' else slug(NAMES.get(key, key))}"
            name = NAMES.get(key, key)
            k = KIND[a3]
        else:
            iso = p.get("iso_3166_2") or ""
            sid = iso if re.match(r"^[A-Z]{2}-[A-Z0-9]+$", iso) else f"{a3}-{p.get('adm1_code')}"
            k = kind(p, a3)
        gr = groups.setdefault(sid, {"nation": a3, "name": name, "kind": k, "geoms": [], "label": None})
        gr["geoms"].append(g)
        if not how and p.get("latitude") is not None: gr["label"] = (p["longitude"], p["latitude"])
    # Merge and make the geometry.
    ids = sorted(groups)
    for sid in ids:
        gr = groups[sid]
        u = unary_union(gr["geoms"])
        gr["geom"] = u
        if gr["label"] is None or not u.buffer(0.2).contains(Point(gr["label"])):
            rp = u.representative_point()
            gr["label"] = (rp.x, rp.y)
    # Population weights from towns and cities.
    pts = [(Point(x["geometry"]["coordinates"]), x["properties"].get("pop_max") or 0) for x in json.load(open(places))["features"]]
    by_nation = {}
    for sid in ids: by_nation.setdefault(groups[sid]["nation"], []).append(sid)
    for a3, members in by_nation.items():
        env = unary_union([groups[s]["geom"] for s in members]).envelope.buffer(1)
        local = [(pt, pop) for pt, pop in pts if env.contains(pt)]
        pops = {}
        for s in members:
            g = groups[s]["geom"].buffer(0.02)
            pops[s] = sum(pop for pt, pop in local if g.contains(pt))
        total = sum(pops.values()) or 1
        for s in members:
            groups[s]["weight"] = round(1000 * (0.8 * pops[s] / total + 0.2 / len(members)), 1)
    # Geometry file: outer rings, and shared borders.
    subs, borders = [], []
    for sid in ids:
        u = groups[sid]["geom"]
        polys = list(u.geoms) if u.geom_type == "MultiPolygon" else [u]
        polys.sort(key=lambda q: -q.area)
        rings = []
        for i, q in enumerate(polys):
            if i > 0 and q.area < MIN_ISLAND: continue
            r = dp_ring(list(q.exterior.coords), POLY_TOL * 2 if q.area > 40 else (POLY_TOL if q.area > 2 else POLY_TOL / 4))
            if r and len(r) >= 4: rings.append(flat(r))
        if rings: subs.append({"id": sid, "rings": rings})
    for a3, members in by_nation.items():
        members = sorted(members)
        for i, a in enumerate(members):
            ga = groups[a]["geom"]
            for b in members[i + 1:]:
                gb = groups[b]["geom"]
                if not ga.buffer(0.001).intersects(gb): continue
                shared = ga.boundary.intersection(gb.buffer(0.001))
                lines = []
                if shared.geom_type == "LineString": lines = [shared]
                elif shared.geom_type in ("MultiLineString", "GeometryCollection"):
                    lines = [x for x in getattr(shared, "geoms", []) if x.geom_type == "LineString"]
                if not lines: continue
                merged = linemerge(MultiLineString(lines)) if len(lines) > 1 else lines[0]
                parts = list(merged.geoms) if merged.geom_type == "MultiLineString" else [merged]
                out = []
                for ln in parts:
                    if ln.length < 0.1: continue
                    s = ln.simplify(LINE_TOL * 2 if ga.area > 40 and gb.area > 40 else LINE_TOL)
                    out.append(flat(list(s.coords)))
                if out: borders.append({"a": a, "b": b, "lines": out})
    geo = {"source": "Natural Earth 1:10m Admin 1 States and Provinces (public domain), simplified for GTNW",
           "subdivisions": subs, "borders": borders}
    gpath = os.path.join(ROOT, "Shared/Resources/subdivisions.json")
    json.dump(geo, open(gpath, "w"), separators=(",", ":"), ensure_ascii=False)
    # Engine data.
    rows = []
    for sid in ids:
        gr = groups[sid]
        rows.append("|".join([sid, gr["nation"], gr["name"].replace("|", "/"), gr["kind"],
                              f"{gr['label'][1]:.2f}", f"{gr['label'][0]:.2f}", f"{gr['weight']}"]))
    swift = ("//\n//  SubdivisionData.swift\n//  Global Thermal Nuclear War\n//\n"
             "//  GENERATED by tools/natural_earth_admin1_to_gtnw.py from Natural Earth admin-1 (public domain). Do not edit.\n"
             "//  One row per state or province: id|nation|name|kind|lat|lon|population weight (per mille of the nation).\n"
             "//  The geometry is Shared/Resources/subdivisions.json (app only); the engine needs only these rows.\n//\n\n"
             "enum SubdivisionData {\n    static let rows = \"\"\"\n" + "\n".join(rows) + "\n\"\"\"\n}\n")
    open(os.path.join(ROOT, "Shared/Engine/Shadow/SubdivisionData.swift"), "w").write(swift)
    print(len(subs), "subdivisions,", len(borders), "shared borders,", os.path.getsize(gpath), "bytes of geometry")
    for a3, members in sorted(by_nation.items()): print(" ", a3, len(members))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
