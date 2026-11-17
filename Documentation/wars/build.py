#!/usr/bin/env python3
"""Build GTNW's historical war dataset (Documentation/wars/wars.json + summary.md).

Reads only the files in raw/ (SOURCES.md says where each came from) plus curated_1789_1815.json, maps
participants to GTNW country ids, merges Correlates of War (1816-2007/2014) with UCDP/PRIO (1946-2025),
and writes wars.json and summary.md next to this script.

    python3 -I build.py            # build from raw/
    python3 -I build.py --fetch    # first download any raw file that is missing, then build

Standard library only. Run with -I: the raw files are third-party data, never code.
"""
import csv, io, json, statistics, sys, urllib.request, zipfile
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
RAW = HERE / "raw"
AS_OF = date(2025, 12, 31)          # UCDP ACD 26.1 runs through 2025; ongoing wars are measured to here

RAW_FILES = {   # local name -> source URL (verbatim downloads made 2026-11-16)
    "Inter-StateWarData_v4.0.csv": "https://correlatesofwar.org/wp-content/uploads/Inter-StateWarData_v4.0.csv",
    "Extra-StateWarData_v4.0.csv": "https://correlatesofwar.org/wp-content/uploads/Extra-StateWarData_v4.0.csv",
    "Intra-State-Wars-v5.1.zip": "https://correlatesofwar.org/wp-content/uploads/Intra-State-Wars-v5.1.zip",
    "Non-StateWarData_v4.0.csv": "https://correlatesofwar.org/wp-content/uploads/Non-StateWarData_v4.0.csv",
    "States2024.zip": "https://correlatesofwar.org/wp-content/uploads/States2024.zip",
    "NMCv7.zip": "https://correlatesofwar.org/wp-content/uploads/NMCv7.zip",
    "ucdp-prio-acd-261-csv.zip": "https://ucdp.uu.se/downloads/ucdpprio/ucdp-prio-acd-261-csv.zip",
    "ucdp-brd-conf-261-csv.zip": "https://ucdp.uu.se/downloads/brd/ucdp-brd-conf-261-csv.zip",
    "UCDPConflictTerminationDataset_v4_2024_Conflict.csv":
        "https://ucdp.uu.se/downloads/monadterm/UCDPConflictTerminationDataset_v4_2024_Conflict.csv",
}

# ---------------------------------------------------------------------------------------------------------------
# Country mapping: COW ccode / Gleditsch-Ward gwno -> GTNW id (SOURCES.md explains the choices)
# ---------------------------------------------------------------------------------------------------------------
CODE = {
    2: "USA", 20: "CAN", 31: "BHS", 40: "CUB", 41: "HTI", 42: "DOM", 51: "JAM", 52: "TTO", 53: "BRB", 54: "DMA",
    55: "GRD", 56: "LCA", 57: "VCT", 58: "ATG", 60: "KNA", 70: "MEX", 80: "BLZ", 90: "GTM", 91: "HND", 92: "SLV",
    93: "NIC", 94: "CRI", 95: "PAN", 100: "COL", 101: "VEN", 110: "GUY", 115: "SUR", 130: "ECU", 135: "PER",
    140: "BRA", 145: "BOL", 150: "PRY", 155: "CHL", 160: "ARG", 165: "URY", 200: "GBR", 205: "IRL", 210: "NLD",
    211: "BEL", 212: "LUX", 220: "FRA", 221: "MCO", 223: "LIE", 225: "CHE", 230: "ESP", 232: "AND", 235: "PRT",
    255: "DEU", 260: "DEU", 265: "DDR", 290: "POL", 300: "AUT", 305: "AUT", 310: "HUN", 315: "CSK", 316: "CZE",
    317: "SVK", 325: "ITA", 331: "SMR", 338: "MLT", 339: "ALB", 340: "SRB", 341: "MNE", 343: "MKD", 344: "HRV",
    346: "BIH", 347: "XKX", 349: "SVN", 350: "GRC", 352: "CYP", 355: "BGR", 359: "MDA", 360: "ROU", 365: "RUS",
    366: "EST", 367: "LVA", 368: "LTU", 369: "UKR", 370: "BLR", 371: "ARM", 372: "GEO", 373: "AZE", 375: "FIN",
    380: "SWE", 385: "NOR", 390: "DNK", 395: "ISL", 402: "CPV", 403: "STP", 404: "GNB", 411: "GNQ", 420: "GMB",
    432: "MLI", 433: "SEN", 434: "BEN", 435: "MRT", 436: "NER", 437: "CIV", 438: "GIN", 439: "BFA", 450: "LBR",
    451: "SLE", 452: "GHA", 461: "TGO", 471: "CMR", 475: "NGA", 481: "GAB", 482: "CAF", 483: "TCD", 484: "COG",
    490: "COD", 500: "UGA", 501: "KEN", 510: "TZA", 511: "TZA", 516: "BDI", 517: "RWA", 520: "SOM", 522: "DJI",
    530: "ETH", 531: "ERI", 540: "AGO", 541: "MOZ", 551: "ZMB", 552: "ZWE", 553: "MWI", 560: "ZAF", 565: "NAM",
    570: "LSO", 571: "BWA", 572: "SWZ", 580: "MDG", 581: "COM", 590: "MUS", 591: "SYC", 600: "MAR", 615: "DZA",
    616: "TUN", 620: "LBY", 625: "SDN", 626: "SSD", 630: "IRN", 640: "TUR", 645: "IRQ", 651: "EGY", 652: "SYR",
    660: "LBN", 663: "JOR", 666: "ISR", 670: "SAU", 678: "YEM", 679: "YEM", 680: "YEM", 690: "KWT", 692: "BHR",
    694: "QAT", 696: "ARE", 698: "OMN", 700: "AFG", 701: "TKM", 702: "TJK", 703: "KGZ", 704: "UZB", 705: "KAZ",
    710: "CHN", 712: "MNG", 713: "TWN", 730: "KOR", 731: "PRK", 732: "KOR", 740: "JPN", 750: "IND", 760: "BTN",
    770: "PAK", 771: "BGD", 775: "MMR", 780: "LKA", 781: "MDV", 790: "NPL", 800: "THA", 811: "KHM", 812: "LAO",
    816: "VNM", 817: "SVN_VN", 820: "MYS", 830: "SGP", 835: "BRN", 840: "PHL", 850: "IDN", 860: "TLS", 900: "AUS",
    910: "PNG", 920: "NZL", 935: "VUT", 940: "SLB", 946: "KIR", 947: "TUV", 950: "FJI", 955: "TON", 970: "NRU",
    983: "MHL", 986: "PLW", 987: "FSM", 990: "WSM",
}
# German and Italian states COW lists separately: GTNW folds them into DEU ("German Confederation") and ITA
# ("Italian States") -- unless the canonical state (Prussia 255 / Sardinia-Italy 325) or another state of the same
# group fights on the other side, in which case they stay "other:<name>".
MINOR = {240: ("DEU", "Hanover"), 245: ("DEU", "Bavaria"), 267: ("DEU", "Baden"), 269: ("DEU", "Saxony"),
         271: ("DEU", "Wuerttemberg"), 273: ("DEU", "Hesse-Kassel"), 275: ("DEU", "Hesse-Darmstadt"),
         280: ("DEU", "Mecklenburg-Schwerin"), 327: ("ITA", "Papal States"), 329: ("ITA", "Two Sicilies"),
         332: ("ITA", "Modena"), 335: ("ITA", "Parma"), 337: ("ITA", "Tuscany")}
GW_EXTRA = {711: "other:Tibet", 751: "other:Hyderabad", 972: "TON", 971: "NRU", 970: "KIR", 973: "TUV"}
UNMAPPED = {751: "Hyderabad", 89: "United Provinces of Central America", 99: "Gran Colombia",
            563: "Transvaal", 564: "Orange Free State"}
# Non-member polities (no COW ccode) that GTNW models as a country of the day.
NAME_ID = {
    "Afghanistan": "AFG", "Persia": "IRN", "China": "CHN", "Korea": "KOR", "South Korea": "KOR", "Morocco": "MAR",
    "Tunisia": "TUN", "Ethiopia": "ETH", "Mexico": "MEX", "Bhutan": "BTN", "Burma": "MMR", "Madagascar": "MDG",
    "Madagasar": "MDG", "Egypt": "EGY", "Argentina": "ARG", "Bolivia": "BOL", "Uruguay": "URY", "Siam": "THA",
    "Thailand": "THA", "Oman": "OMN", "Haiti": "HTI", "Haitians": "HTI", "Guatemala": "GTM", "Honduras": "HND",
    "El Salvador": "SLV", "Nicaragua": "NIC", "Costa Rica": "CRI", "Peru": "PER", "Chile": "CHL", "Vietnam": "VNM",
    "Cambodia": "KHM", "Nepal": "NPL", "Santo Domingo": "DOM", "Santo-Domingo": "DOM", "Serbia": "SRB",
    "Montenegro": "MNE", "Confederacy": "CSA", "Confederate States": "CSA", "Gran Colombia": "other:Gran Colombia",
    "Peru-Bolivia Confederation": "other:Peru-Bolivian Confederation",
}


def code_id(code, year, gw=False):
    """GTNW id for a COW ccode (or GW gwno) in a year; None if not a state code."""
    if code is None or code < 0:
        return None
    if code == 345:                       # 345: Serbia before 1918, Yugoslavia 1918-91, then rump Serbia (FRY)
        return "SRB" if year < 1918 or year >= 1992 else "YUG"
    if gw and code in GW_EXTRA:
        return GW_EXTRA[code]
    if code in CODE:
        return CODE[code]
    if code in MINOR:
        return MINOR[code][0]
    return "other:" + UNMAPPED.get(code, f"ccode {code}")


def name_id(name):
    name = name.strip()
    return NAME_ID.get(name, "non-state:" + name)


# ---------------------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------------------
def read_csv(text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return [{k.strip(): (v or "").strip() for k, v in r.items() if k} for r in csv.DictReader(io.StringIO(text))]


def raw_text(name, member=None, encoding="latin-1"):
    p = RAW / name
    if member is None:
        return p.read_bytes().decode(encoding)
    with zipfile.ZipFile(p) as z:
        return z.read(member).decode(encoding)


def num(s, default=None):
    try:
        return int(float(s))
    except (TypeError, ValueError):
        return default


class D:
    """A date with known precision ('day' | 'month' | 'year')."""
    def __init__(self, y, m=None, d=None):
        self.y = y
        self.m = m if m and 1 <= m <= 12 else None
        self.d = d if self.m and d and 1 <= d <= 31 else None
        self.prec = "day" if self.d else "month" if self.m else "year"

    @classmethod
    def parse(cls, s):
        return cls(*[int(p) for p in s.split("-")])

    def text(self):
        return f"{self.y:04d}-{self.m:02d}-{self.d:02d}" if self.d else f"{self.y:04d}"

    def mid(self):
        """Point estimate for durations: unknown day -> mid-month, unknown month -> mid-year."""
        if self.d:
            last = 28 if self.m == 2 else 30 if self.m in (4, 6, 9, 11) else 31
            return date(self.y, self.m, min(self.d, last))
        return date(self.y, self.m, 15) if self.m else date(self.y, 7, 1)

    def lo(self):
        return (self.y, self.m or 0, self.d or 0)

    def hi(self):
        return (self.y, self.m or 13, self.d or 32)


def months_between(a, b):
    """Months from a to b (a D, or a date for ongoing wars); never negative (an end known only to the month can
    fall before a start known to the day)."""
    return max(0.0, round(((b.mid() if isinstance(b, D) else b) - a.mid()).days / 30.4375, 1))


ERAS = [(1700, 1815, "1789-1815"), (1816, 1870, "1816-1870"), (1871, 1913, "1871-1913"), (1914, 1945, "1914-1945"),
        (1946, 1991, "1946-1991"), (1992, 2100, "1992-present")]
ERA_LABELS = [e[2] for e in ERAS]


def era_of(y):
    return next(label for lo, hi, label in ERAS if lo <= y <= hi)


COW_OUT = {1: "side_a_victory", 2: "side_b_victory", 3: "compromise", 4: "transformed", 5: "ongoing",
           6: "stalemate", 7: "unclear"}
UCDP_OUT = {1: "peace_agreement", 2: "ceasefire", 3: "side_a_victory", 4: "side_b_victory", 5: "unclear", 6: "unclear"}
UCDP_OUT_TEXT = {1: "peace agreement", 2: "ceasefire agreement", 3: "victory for side A",
                 4: "victory for side B", 5: "low activity (fighting fell below 25 battle deaths a year)",
                 6: "an actor ceased to exist"}


def dedupe(seq):
    out = []
    for x in seq:
        if x and x not in out:
            out.append(x)
    return out


def record(**kw):
    s, e = kw["_s"], kw["_e"]
    r = {"id": kw["id"], "name": kw["name"], "type": kw["type"], "start": s.text(), "end": e.text() if e else None,
         "duration_months": months_between(s, e if e else AS_OF)}
    for k in ("side_a", "side_b", "initiator", "outcome", "terms", "battle_deaths", "deaths_approx", "source",
              "source_id"):
        r[k] = kw.get(k)
    r["era"] = era_of(s.y)
    r["date_precision"] = {"start": s.prec, "end": e.prec if e else None}
    if s.prec == "month":
        r["start_month"] = s.m
    if e and e.prec == "month":
        r["end_month"] = e.m
    for k in ("notes", "related", "cinc_share_a"):
        if kw.get(k) not in (None, "", []):
            r[k] = kw[k]
    return r


def start_of(r):
    return D(int(r["start"][:4]), r.get("start_month")) if len(r["start"]) == 4 else D.parse(r["start"])


def earliest(ds):
    return min(ds, key=D.lo) if ds else None


def latest(ds):
    return max(ds, key=D.hi) if ds else None


def cow_dates(r, pairs):
    """Starts, ends and an ongoing flag over a COW row's phase columns ((m,d,y) start, (m,d,y) end)."""
    starts, ends, ongoing = [], [], False
    for (sm, sd, sy), (em, ed, ey) in pairs:
        y = num(r.get(sy))
        if y and y > 0:
            starts.append(D(y, num(r.get(sm)), num(r.get(sd))))
        ye = num(r.get(ey))
        if ye == -7:
            ongoing = True
        elif ye and ye > 0:
            ends.append(D(ye, num(r.get(em)), num(r.get(ed))))
    return starts, ends, ongoing


# ---------------------------------------------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------------------------------------------
def load_cinc():
    with zipfile.ZipFile(RAW / "NMCv7.zip") as outer:
        with zipfile.ZipFile(io.BytesIO(outer.read("NMCv7/NMC-v7-abridged.zip"))) as inner:
            rows = read_csv(inner.read("NMC-70-abridged.csv").decode("latin-1"))
    return {(int(r["ccode"]), int(r["year"])): float(r["cinc"]) for r in rows if r["cinc"] not in ("", "-9")}


INTER_TERMS = {   # short, well-known settlements of notable COW inter-state wars (keyed by COW WarNum)
    4: "Treaty of Adrianople: Russia gains the Danube mouth and eastern Black Sea coast; Greek and Serbian autonomy.",
    7: "Treaty of Guadalupe Hidalgo: Mexico cedes California, Nevada, Utah and most of Arizona/New Mexico to the U.S.",
    22: "Treaty of Paris (1856): Black Sea neutralised; Russia cedes southern Bessarabia to Moldavia.",
    28: "Lombardy passes to Sardinia (Villafranca/Zurich); Savoy and Nice go to France in 1860.",
    46: "Treaty of Vienna (1864): Denmark cedes Schleswig, Holstein and Lauenburg to Prussia and Austria.",
    49: "Paraguay defeated, occupied and loses territory to Argentina and Brazil; catastrophic population loss.",
    55: "Peace of Prague: Austria excluded from Germany; Prussia annexes Hanover, Hesse-Kassel, Nassau, Frankfurt; Venetia to Italy.",
    58: "Treaty of Frankfurt: Alsace-Lorraine to Germany, 5 billion franc indemnity; German Empire proclaimed.",
    61: "San Stefano / Congress of Berlin: Romania, Serbia, Montenegro independent; autonomous Bulgaria; Russia gains Kars, Batum, southern Bessarabia.",
    64: "Chile gains Tarapaca and Bolivia's Antofagasta coast; Bolivia becomes landlocked.",
    73: "Treaty of Shimonoseki: China cedes Taiwan and the Penghu islands, recognises Korean independence, pays an indemnity.",
    79: "Treaty of Paris (1898): Spain cedes Puerto Rico, Guam and the Philippines to the U.S.; Cuba independent.",
    85: "Treaty of Portsmouth: Japan gains southern Sakhalin, the Port Arthur lease and a free hand in Korea.",
    97: "Treaty of Ouchy: Tripolitania, Cyrenaica (Libya) and the Dodecanese to Italy.",
    100: "Treaty of London (1913): the Ottoman Empire loses almost all its European territory; Albania created.",
    103: "Treaty of Bucharest (1913): Bulgaria loses most Macedonian gains; Southern Dobruja to Romania.",
    106: "Versailles, St-Germain, Trianon, Neuilly, Sevres: German, Austro-Hungarian, Russian and Ottoman empires broken up.",
    109: "Peace of Riga: Poland gains western Belarus and western Ukraine.",
    115: "Treaty of Lausanne: Greece gives up Smyrna and Eastern Thrace; Greek-Turkish population exchange.",
    124: "Bolivia cedes most of the Chaco Boreal to Paraguay (1938 treaty).",
    127: "Ethiopia annexed into Italian East Africa.",
    139: "Unconditional surrender of Germany and Japan; occupation; borders of Germany, Poland and Japan redrawn.",
    142: "Moscow Peace: Finland cedes the Karelian Isthmus, Viipuri and Salla (about 9% of its territory).",
    148: "1949 armistice lines: Israel holds about 78% of Mandate Palestine; West Bank to Jordan, Gaza to Egypt.",
    151: "Armistice of 27 Jul 1953: DMZ near the 38th parallel; no peace treaty.",
    169: "Israel takes Sinai, Gaza, the West Bank, East Jerusalem and the Golan Heights.",
    178: "East Pakistan becomes independent Bangladesh.",
    181: "UN ceasefire; disengagement agreements, leading to Camp David (1978).",
    199: "UN Resolution 598 ceasefire; status quo ante bellum.",
    202: "Argentine surrender; British control of the Falklands restored.",
    211: "Kuwait liberated; Iraq under UN sanctions and inspections.",
    219: "Algiers Agreement (2000); boundary commission awards Badme to Eritrea (2002).",
    221: "Kumanovo Agreement: Yugoslav forces withdraw; Kosovo under UN administration (UNSC 1244).",
    225: "Taliban government overthrown.",
    227: "Ba'athist government overthrown; occupation.",
}


def cow_inter(cinc):
    rows = read_csv(raw_text("Inter-StateWarData_v4.0.csv"))
    wars = defaultdict(list)
    for r in rows:
        wars[r["WarNum"]].append(r)
    pairs = [(("StartMonth1", "StartDay1", "StartYear1"), ("EndMonth1", "EndDay1", "EndYear1")),
             (("StartMonth2", "StartDay2", "StartYear2"), ("EndMonth2", "EndDay2", "EndYear2"))]
    out = []
    for wn, ps in wars.items():
        starts, ends, ongoing, part = [], [], False, []
        for r in ps:
            s, e, og = cow_dates(r, pairs)
            starts += s; ends += e; ongoing |= og
            part.append((r, earliest(s), latest(e)))
        y0 = earliest(starts).y
        sides = {1: [], 2: []}
        for r, s, e in part:
            c, side = num(r["ccode"]), num(r["Side"])
            gid = code_id(c, s.y if s else y0)
            if c in MINOR:
                group = MINOR[c][0]
                other = {num(x["ccode"]) for x in ps if num(x["Side"]) != side}
                if any(code_id(o, y0) == group for o in other):
                    gid = "other:" + MINOR[c][1]
            sides[side].append(gid)
        a, b = dedupe(sides[1]), dedupe(sides[2])
        inits = sorted([(s.lo(), code_id(num(r["ccode"]), s.y)) for r, s, e in part if num(r["Initiator"]) == 1 and s])
        initiator = inits[0][1] if inits else None
        if initiator and initiator not in a + b:          # a minor state renamed "other:" above
            initiator = next((x for x in a + b if x.startswith("other:")), initiator)
        # Outcome: the code of the side-1 participant fighting latest (changed-sides rows, code 8, are skipped).
        cand = [((e.hi() if e else (9999, 99, 99)), num(r["Outcome"])) for r, s, e in part
                if num(r["Side"]) == 1 and num(r["Outcome"]) in COW_OUT]
        outcome = COW_OUT[max(cand)[1]] if cand else "unclear"
        deaths = [num(r["BatDeath"]) for r in ps]
        known = [d for d in deaths if d is not None and d >= 0]
        terms = INTER_TERMS.get(num(wn))
        if outcome == "transformed":
            t2 = sorted({r["TransTo"] for r in ps if num(r["TransTo"], -8) > 0})
            if t2:
                terms = ((terms + " ") if terms else "") + "Transformed into COW war " + ", ".join(t2) + "."
        ca = sum(cinc.get((num(r["ccode"]), y0), 0) for r in ps if num(r["Side"]) == 1)
        cb = sum(cinc.get((num(r["ccode"]), y0), 0) for r in ps if num(r["Side"]) == 2)
        out.append(record(id=f"cow-inter-{wn}", name=ps[0]["WarName"], type="interstate", _s=earliest(starts),
                          _e=None if ongoing else latest(ends), side_a=a, side_b=b, initiator=initiator,
                          outcome=outcome, terms=terms, battle_deaths=sum(known) if known else None,
                          deaths_approx=len(known) < len(deaths), source="COW-inter", source_id=wn,
                          cinc_share_a=round(ca / (ca + cb), 3) if ca + cb > 0 else None))
    return out


def cow_extra():
    rows = read_csv(raw_text("Extra-StateWarData_v4.0.csv"))
    wars = defaultdict(list)
    for r in rows:
        wars[r["WarNum"]].append(r)
    pairs = [(("StartMonth1", "StartDay1", "StartYear1"), ("EndMonth1", "EndDay1", "EndYear1")),
             (("StartMonth2", "StartDay2", "StartYear2"), ("EndMonth2", "EndDay2", "EndYear2"))]
    out = []
    for wn, ps in wars.items():
        starts, ends, ongoing, a, b = [], [], False, [], []
        for r in ps:
            s, e, og = cow_dates(r, pairs)
            starts += s; ends += e; ongoing |= og
            y = s[0].y if s else num(ps[0]["StartYear1"])
            if num(r["ccode1"], -8) > 0:
                a.append(code_id(num(r["ccode1"]), y))
            if num(r["ccode2"], -8) > 0:
                b.append(code_id(num(r["ccode2"]), y))
            elif r["SideB"] not in ("-8", "-9", ""):
                for nm in (r["SideB"].split(", ") if r["SideB"] == "Serbia, Montenegro" else [r["SideB"]]):
                    b.append(name_id(nm.replace("\x92", "'")))
        a, b = dedupe(a), dedupe(b)
        ini = Counter(num(r["Initiator"]) for r in ps).most_common(1)[0][0]     # 1 = side A (state) initiated
        initiator = a[0] if ini == 1 and a else (b[0] if b else None)
        oc = Counter(num(r["Outcome"]) for r in ps if num(r["Outcome"]) in COW_OUT).most_common(1)
        vals, partial = [], False
        for r in ps:
            for k in ("BatDeath", "NonStateDeaths"):
                v = num(r[k])
                if v is not None and v >= 0:
                    vals.append(v)
                elif v == -9:
                    partial = True
        out.append(record(id=f"cow-extra-{wn}", name=ps[0]["WarName"], type="colonial", _s=earliest(starts),
                          _e=None if ongoing else latest(ends), side_a=a, side_b=b, initiator=initiator,
                          outcome=COW_OUT[oc[0][0]] if oc else "unclear", terms=None,
                          battle_deaths=sum(vals) if vals else None, deaths_approx=partial and bool(vals),
                          source="COW-extra", source_id=wn,
                          notes="COW extra-state war, " + ("colonial" if ps[0]["WarType"] == "2" else "imperial")))
    return out


def cow_intra():
    main = read_csv(raw_text("Intra-State-Wars-v5.1.zip", "INTRA-STATE WARS v5.1 CSV.csv"))
    parts = read_csv(raw_text("Intra-State-Wars-v5.1.zip", "INTRA-STATE_State_participants v5.1 CSV.csv"))
    pa = defaultdict(list)
    for r in parts:
        pa[r["WarNum"]].append(r)
    pairs = [((f"StartMo{i}", f"StartDy{i}", f"StartYr{i}"), (f"EndMo{i}", f"EndDy{i}", f"EndYr{i}")) for i in (1, 2, 3, 4)]
    kinds = {"4": "civil war for central control", "5": "civil war over local issues", "6": "regional internal war",
             "7": "intercommunal war"}
    out = []
    for r in main:
        wn = r["WarNum"]
        starts, ends, ongoing = cow_dates(r, pairs)
        y = earliest(starts).y
        ca = num(r["CcodeA"], -8)
        a = [code_id(ca, y) if ca > 0 else name_id(r["SideA"])]
        b = [name_id(r["SideB"])] if r["SideB"] not in ("-8", "-9", "") else []
        for p in pa.get(wn, []):
            if num(p["CcodeA"], -8) > 0:
                a.append(code_id(num(p["CcodeA"]), y))
            if num(p["CcodeB"], -8) > 0:
                b.append(code_id(num(p["CcodeB"]), y))
        a, b = dedupe(a), dedupe(b)
        ini, sa, sb = r["Initiator"].strip().lower(), r["SideA"].strip().lower(), r["SideB"].strip().lower()
        initiator = None
        if ini and ini not in ("-8", "-9"):
            if sa and (ini in sa or sa in ini):
                initiator = a[0]
            elif sb and b and (ini in sb or sb in ini):
                initiator = b[0]
            else:
                initiator = name_id(r["Initiator"])
        outcome = COW_OUT.get(num(r["Outcome"]), "unclear")
        terms = f"Transformed into COW war {r['TransTo']}." if outcome == "transformed" and num(r["TransTo"], -8) > 0 else None
        d = num(r["TotalBDeaths"])
        approx = False
        if d is None or d < 0:
            known = [x for x in (num(r["DeathsSideA"]), num(r["DeathsSideB"])) if x is not None and x >= 0]
            d = sum(known) if known else None
            approx = d is not None
        out.append(record(id=f"cow-intra-{wn}", name=r["WarName"],
                          type="internationalized_civil" if r["Intnl"] == "1" else "civil",
                          _s=earliest(starts), _e=None if ongoing else latest(ends), side_a=a, side_b=b,
                          initiator=initiator, outcome=outcome, terms=terms, battle_deaths=d, deaths_approx=approx,
                          source="COW-intra", source_id=wn, notes=kinds.get(r["WarType"])))
    return out


def cow_nonstate():
    out = []
    for r in read_csv(raw_text("Non-StateWarData_v4.0.csv")):
        s = D(num(r["StartYear"]), num(r["StartMonth"]), num(r["StartDay"]))
        ey = num(r["EndYear"])
        e = None if ey == -7 else D(ey, num(r["EndMonth"]), num(r["EndDay"]))
        a = dedupe([name_id(r[k]) for k in ("SideA1", "SideA2") if r[k] not in ("-8", "-9", "")])
        b = dedupe([name_id(r[k]) for k in ("SideB1", "SideB2", "SideB3", "SideB4", "SideB5") if r[k] not in ("-8", "-9", "")])
        initiator = a[0] if r["Initiator"] == "A" and a else b[0] if r["Initiator"] == "B" and b else None
        d = num(r["TotalCombatDeaths"])
        out.append(record(id=f"cow-nonstate-{r['WarNum']}", name=r["WarName"], type="nonstate", _s=s, _e=e,
                          side_a=a, side_b=b, initiator=initiator, outcome=COW_OUT.get(num(r["Outcome"]), "unclear"),
                          terms=None, battle_deaths=d if d is not None and d >= 0 else None, deaths_approx=False,
                          source="COW-nonstate", source_id=r["WarNum"],
                          notes="COW non-state war, " + ("in non-state territory" if r["WarType"] == "8" else "across state borders")))
    return out


def ucdp_episodes():
    """UCDP/PRIO ACD 26.1 conflict episodes, with battle deaths (BRD 26.1) and termination (CTD v4-2024)."""
    acd = read_csv(raw_text("ucdp-prio-acd-261-csv.zip", "UcdpPrioConflict_v26_1.csv", "utf-8"))
    brd = read_csv(raw_text("ucdp-brd-conf-261-csv.zip", "BattleDeaths_v26_1_conf.csv", "utf-8"))
    ctd = read_csv(raw_text("UCDPConflictTerminationDataset_v4_2024_Conflict.csv", encoding="utf-8"))
    deaths = defaultdict(int)
    for r in brd:
        deaths[(r["conflict_id"], int(r["year"]))] += int(r["bd_best"])
    term = defaultdict(list)                 # conflict_id -> [(episode start year, end year, outcome)]
    for r in ctd:
        if r["c_epterm"] == "1":
            term[r["conflict_id"]].append((num(r["c_ep_startyear"]), num(r["c_ep_endyear"]), num(r["c_outcome"])))
    eps = defaultdict(list)
    for r in acd:
        eps[(r["conflict_id"], r["start_date2"])].append(r)
    last_year = max(int(r["year"]) for r in acd)

    def ids(names, gws, year):
        g = [num(x) for x in gws.split(",") if x.strip()]
        if g:
            return [code_id(c, year, gw=True) for c in g]
        return ["non-state:" + n.strip() for n in names.split(",") if n.strip()]

    def clean(s):
        return s.replace("Government of ", "")

    out = []
    for (cid, sd2), rs in eps.items():
        rs.sort(key=lambda r: int(r["year"]))
        y0, y1 = int(rs[0]["year"]), int(rs[-1]["year"])
        endrow = next((r for r in rs if r["ep_end"] == "1"), None)
        ongoing = endrow is None and y1 == last_year
        end = None if ongoing else (D.parse(endrow["ep_end_date"]) if endrow and endrow["ep_end_date"] else D(y1))
        tc = rs[0]["type_of_conflict"]
        a, b = [], []
        for r in rs:
            yy = int(r["year"])
            a += ids(r["side_a"], r["gwno_a"], yy) + ids("", r["gwno_a_2nd"], yy)
            b += ids(r["side_b"], r["gwno_b"], yy) + ids("", r["gwno_b_2nd"], yy)
        a, b = dedupe(a), dedupe(b)
        loc = dedupe([code_id(num(x), y0, gw=True) for x in rs[0]["gwno_loc"].split(",") if x.strip()])
        bd = [deaths.get((cid, y)) for y in range(y0, y1 + 1)]
        known = [x for x in bd if x is not None]
        battle = sum(known) if known else None
        outcome, terms = ("ongoing", None) if ongoing else ("unclear", None)
        if not ongoing:
            t = [x for x in term.get(cid, []) if x[1] is not None and y0 <= x[1] <= y1]
            if t:
                o = t[-1][2]
                outcome = UCDP_OUT.get(o, "unclear")
                terms = "UCDP termination: " + UCDP_OUT_TEXT.get(o, "unknown") + "."
            else:
                terms = "How it ended is not coded in the UCDP Conflict Termination Dataset v4-2024."
        war = any(r["intensity_level"] == "2" for r in rs)
        if tc in ("1", "2"):
            name = f"{clean(rs[0]['side_a'])} vs {clean(rs[0]['side_b'])}"
        else:
            name = f"{rs[0]['location']}: {clean(rs[-1]['side_b'])}"
        name += f" ({y0}-{'' if ongoing else end.y})"
        rec = record(id=f"ucdp-{cid}-{y0}", name=name,
                     type={"1": "colonial", "2": "interstate", "3": "civil", "4": "internationalized_civil"}[tc],
                     _s=D.parse(sd2), _e=end, side_a=a, side_b=b, initiator=None, outcome=outcome, terms=terms,
                     battle_deaths=battle, deaths_approx=battle is not None and len(known) < len(bd),
                     source="UCDP-ACD", source_id=f"{cid}:{sd2}",
                     notes=f"UCDP conflict {cid}, episode from {sd2}; " +
                           ("war-level (1,000+ battle deaths in a year)" if war else "minor"))
        out.append({"rec": rec, "war": war, "cid": cid, "y0": y0, "y1": end.y if end else last_year, "tc": tc,
                    "states": {x for x in a + b + loc if not x.startswith(("non-state:", "other:"))},
                    "loc": {x for x in loc + ids("", rs[0]["gwno_a"], y0) if not x.startswith(("non-state:", "other:"))}})
    return out


def curated():
    data = json.loads((HERE / "curated_1789_1815.json").read_text(encoding="utf-8"))
    out = []
    for w in data["wars"]:
        note = (w.get("notes", "") + (" Ref: " + w["ref"] + "." if w.get("ref") else "")).strip()
        out.append(record(id="curated-" + w["slug"], name=w["name"], type=w["type"], _s=D.parse(w["start"]),
                          _e=D.parse(w["end"]) if w["end"] else None, side_a=w["side_a"], side_b=w["side_b"],
                          initiator=w["initiator"], outcome=w["outcome"], terms=w["terms"],
                          battle_deaths=w["battle_deaths"], deaths_approx=True, source="curated",
                          source_id=w["slug"], notes=note, related=w.get("related")))
    return out


# ---------------------------------------------------------------------------------------------------------------
# Merge COW and UCDP
# ---------------------------------------------------------------------------------------------------------------
TYPE_MATCH = {"interstate": {"2"}, "colonial": {"1", "3", "4"}, "civil": {"3", "4"}, "internationalized_civil": {"3", "4"}}
COW_END = {"COW-inter": 2007, "COW-extra": 2007, "COW-intra": 2014, "COW-nonstate": 2007}


def merge(cow, ucdp):
    """Link UCDP episodes to the COW wars they overlap; take end/outcome for wars COW left ongoing; return the
    war-level UCDP episodes COW lacks (starting 2008 or later) and the unmatched earlier ones.

    A UCDP episode overlaps a COW war when its type is compatible, its years overlap the war's (COW's coverage end
    standing in for the end of a war COW left ongoing), and -- for interstate wars -- at least two states are shared,
    otherwise the UCDP location state or primary side-A government is one of the COW war's states."""
    used = set()
    for w in cow:
        if w["type"] not in TYPE_MATCH:
            continue
        sy = int(w["start"][:4])
        ey = int(w["end"][:4]) if w["end"] else COW_END[w["source"]]
        if ey < 1946:
            continue
        states = {x for x in w["side_a"] + w["side_b"] if not x.startswith(("non-state:", "other:"))}

        def overlaps(u):
            if u["tc"] not in TYPE_MATCH[w["type"]] or u["y0"] > ey + 1 or u["y1"] < sy - 1:
                return False
            return len(states & u["states"]) >= 2 if w["type"] == "interstate" else bool(states & u["loc"])
        hits = [u for u in ucdp if overlaps(u)]
        if not hits:
            continue
        used.update(id(u) for u in hits)
        w["ucdp_conflict_ids"] = sorted({u["cid"] for u in hits}, key=int)
        if w["outcome"] == "ongoing":
            # COW coded it ongoing at the end of its coverage: the closest UCDP conflict says how it went on.
            best = max(hits, key=lambda u: (u["war"], -abs(u["y0"] - sy), u["y1"]))
            last = max((u for u in hits if u["cid"] == best["cid"]), key=lambda u: u["y1"])
            r = last["rec"]
            w["end"], w["outcome"] = r["end"], r["outcome"]
            w["date_precision"]["end"] = r["date_precision"]["end"]
            w["duration_months"] = months_between(start_of(w), D.parse(r["end"]) if r["end"] else AS_OF)
            w["terms"] = (f"COW coded this war ongoing as of {COW_END[w['source']]}; end and outcome from UCDP conflict "
                          f"{last['cid']} ({r['name']}). " + (r["terms"] or "")).strip()
    added, unmatched_pre = [], []
    for u in ucdp:
        if u["war"] and id(u) not in used:
            (added if u["y0"] >= 2008 else unmatched_pre).append(u["rec"])
    return added, unmatched_pre


# Wars the sources leave ongoing (COW ends 2007/2014) whose end is well documented. Applied after the merge.
OVERRIDES = {
    "cow-extra-481": dict(end="2021-08-30", outcome="side_b_victory",
                          terms="Taliban take Kabul (15 Aug 2021); last U.S. troops leave 30 Aug 2021 under the 2020 Doha Agreement."),
    "cow-intra-991.4": dict(end="2021-08-15", outcome="side_b_victory",
                            terms="Taliban take Kabul; the Islamic Republic of Afghanistan collapses."),
    "cow-intra-979": dict(end="2024-12-08", outcome="side_b_victory",
                          terms="Assad government falls to the HTS-led offensive (8 Dec 2024). UCDP codes the conflict as "
                                "continuing against the new government."),
    "cow-intra-993": dict(end="2022-02-24", outcome="transformed",
                          terms="Merged into the Russian invasion of Ukraine (Russia vs Ukraine, 2022-)."),
    "ucdp-267-2020": dict(outcome="peace_agreement",
                          terms="Pretoria Agreement (2 Nov 2022): permanent cessation of hostilities between the "
                                "Ethiopian government and the TPLF."),
    "ucdp-234-2014": dict(outcome="ceasefire", terms="Egyptian-brokered open-ended ceasefire (26 Aug 2014) ends the Gaza war."),
}


def apply_overrides(wars):
    for w in wars:
        o = OVERRIDES.get(w["id"])
        if o:
            w.update(o)
            if "end" in o:
                w["date_precision"]["end"] = "day"
                w["duration_months"] = months_between(start_of(w), D.parse(o["end"]))
            w["notes"] = ((w.get("notes") or "") + " " + ("End and outcome" if "end" in o else "Outcome") +
                          " hand-coded from a well-documented event (see SOURCES.md).").strip()


# ---------------------------------------------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------------------------------------------
TYPES = ["interstate", "colonial", "civil", "internationalized_civil", "nonstate"]
OUTS = ["side_a_victory", "side_b_victory", "compromise", "stalemate", "ceasefire", "peace_agreement", "transformed",
        "ongoing", "unclear"]


def q(xs):
    xs = sorted(xs)
    if not xs:
        return "-"
    if len(xs) == 1:
        return f"{xs[0]:.1f} (n=1)"
    qs = statistics.quantiles(xs, n=4, method="inclusive")
    return f"{statistics.median(xs):.1f} [{qs[0]:.1f}-{qs[2]:.1f}] (n={len(xs)})"


def summary(wars, unmatched_pre, n_eps, n_war_eps):
    L = ["# GTNW war dataset: summary", "",
         f"Generated by `build.py` from `raw/` and `curated_1789_1815.json`: **{len(wars)} wars**, 1786-2025. "
         "Durations are in months from the first to the last date of the war (gaps between phases included; unknown "
         "days/months taken as mid-month/mid-year). Ongoing wars are left out of duration statistics (right-censored). "
         "Format: median [25th-75th percentile] (n).", "",
         "Coverage: curated 1789-1815; COW inter-state and extra-state 1816-2007, intra-state 1816-2014, non-state "
         "1816-2007; UCDP/PRIO ACD 26.1 adds war-level episodes (1,000+ battle deaths in a calendar year) from 2008 "
         "to 2025 that COW lacks, and gives the end and outcome of wars COW left ongoing.", ""]
    by = defaultdict(list)
    for w in wars:
        by[(w["type"], w["era"])].append(w)
    L += ["## Counts by type and era", "", "| type | " + " | ".join(ERA_LABELS) + " | total |",
          "|---|" + "---:|" * (len(ERA_LABELS) + 1)]
    for t in TYPES:
        row = [len(by[(t, e)]) for e in ERA_LABELS]
        L.append(f"| {t} | " + " | ".join(map(str, row)) + f" | {sum(row)} |")
    tot = [sum(len(by[(t, e)]) for t in TYPES) for e in ERA_LABELS]
    L += ["| **all** | " + " | ".join(map(str, tot)) + f" | {sum(tot)} |", "",
          "By source: " + ", ".join(f"{k} {v}" for k, v in sorted(Counter(w["source"] for w in wars).items())) + ".", ""]

    done = [w for w in wars if w["end"]]
    dm = lambda f: [w["duration_months"] for w in done if f(w)]
    L += ["## Duration (months) by type", "", "| type | median [IQR] (n) |", "|---|---|"]
    L += [f"| {t} | {q(dm(lambda w: w['type'] == t))} |" for t in TYPES]
    L += ["", "## Duration (months) by era", "", "| era | all wars | interstate | civil + internationalized civil |",
          "|---|---|---|---|"]
    for e in ERA_LABELS:
        L.append(f"| {e} | {q(dm(lambda w: w['era'] == e))} | {q(dm(lambda w: w['era'] == e and w['type'] == 'interstate'))} | "
                 f"{q(dm(lambda w: w['era'] == e and w['type'] in ('civil', 'internationalized_civil')))} |")
    L += ["", "## Median duration (months) by type and era", "", "| type | " + " | ".join(ERA_LABELS) + " |",
          "|---|" + "---|" * len(ERA_LABELS)]
    for t in TYPES:
        cells = []
        for e in ERA_LABELS:
            xs = dm(lambda w: w["type"] == t and w["era"] == e)
            cells.append(f"{statistics.median(xs):.1f} (n={len(xs)})" if xs else "-")
        L.append(f"| {t} | " + " | ".join(cells) + " |")

    L += ["", "## Outcome shares by era (all types, % of the era's wars)", "",
          "| era | " + " | ".join(OUTS) + " |", "|---|" + "---:|" * len(OUTS)]
    for e in ERA_LABELS:
        ws = [w for w in wars if w["era"] == e]
        c = Counter(w["outcome"] for w in ws)
        L.append(f"| {e} (n={len(ws)}) | " + " | ".join(f"{100 * c[o] / len(ws):.0f}" for o in OUTS) + " |")
    L += ["", "## Interstate outcome shares by era", "", "| era | " + " | ".join(OUTS) + " |", "|---|" + "---:|" * len(OUTS)]
    for e in ERA_LABELS:
        ws = [w for w in wars if w["era"] == e and w["type"] == "interstate"]
        c = Counter(w["outcome"] for w in ws)
        L.append(f"| {e} (n={len(ws)}) | " + " | ".join(f"{100 * c[o] / len(ws):.0f}" if ws else "-" for o in OUTS) + " |")
    L += ["", "Side A is the government side in civil wars and the state side in colonial wars; for COW inter-state wars "
          "it is COW's Side 1 -- which in practice is nearly always the winning side, so `side_a_victory` there carries "
          "little information; use `initiator` and the capability table below instead. For UCDP inter-state episodes "
          "side A is UCDP's side A.", ""]
    iw = [w for w in wars if w["type"] == "interstate" and w["initiator"] and w["outcome"] in ("side_a_victory", "side_b_victory")]
    won = sum(1 for w in iw if (w["initiator"] in w["side_a"]) == (w["outcome"] == "side_a_victory"))
    L += ["## Interstate wars: did the initiator win?", "",
          f"Of {len(iw)} decided interstate wars with a coded initiator, the initiator's side won {won} "
          f"({100 * won / max(1, len(iw)):.0f}%).", ""]

    cw = [w for w in wars if w["source"] == "COW-inter" and w.get("cinc_share_a") is not None]
    L += ["## Interstate wars by capability ratio (COW NMC v7 CINC)", "",
          "The stronger side's share of both sides' summed CINC scores in the war's start year (all participants). "
          f"COW inter-state wars only ({len(cw)} with CINC data); curated and UCDP wars have no CINC join.", "",
          "| capability balance | n | median duration [IQR] | stronger side won | weaker side won | other outcome |",
          "|---|---:|---|---:|---:|---:|"]
    for label, lo, hi in [("balanced (<60%)", 0.5, 0.6), ("unequal (60-80%)", 0.6, 0.8), ("lopsided (>=80%)", 0.8, 1.01)]:
        ws = [w for w in cw if lo <= max(w["cinc_share_a"], 1 - w["cinc_share_a"]) < hi]
        dec = [w for w in ws if w["outcome"] in ("side_a_victory", "side_b_victory")]
        sw = sum(1 for w in dec if (w["cinc_share_a"] >= 0.5) == (w["outcome"] == "side_a_victory"))
        L.append(f"| {label} | {len(ws)} | {q([w['duration_months'] for w in ws if w['end']])} | {sw} | {len(dec) - sw} | {len(ws) - len(dec)} |")

    def line(w):
        return (f"| {w['name']} | {w['type']} | {w['start']} | {w['end'] or 'ongoing'} | {w['duration_months']} | "
                f"{w['outcome']} | {w['source']} |")
    hdr = ["| war | type | start | end | months | outcome | source |", "|---|---|---|---|---:|---|---|"]
    inter = [w for w in wars if w["type"] == "interstate"]
    L += ["", "## Longest interstate wars", ""] + hdr + [line(w) for w in sorted(inter, key=lambda w: -w["duration_months"])[:12]]
    L += ["", "## Quickest interstate wars", ""] + hdr + \
         [line(w) for w in sorted([w for w in inter if w["end"]], key=lambda w: w["duration_months"])[:12]]
    L += ["", "## Sanity checks", ""] + hdr
    for key in ("Franco-Prussian", "Iran-Iraq", "Russia (Soviet Union) vs Ukraine", "Seven Weeks", "Six Day War",
                "Crimean", "Korean", "World War I", "World War II", "Falkland", "Gulf War", "War of 1812",
                "French invasion of Russia", "Syrian Arab Spring", "Russian Civil War", "Peninsular War"):
        L += [line(w) for w in wars if key in w["name"]]
    ongoing = [w for w in wars if w["outcome"] == "ongoing"]
    L += ["", f"## Ongoing at the end of the data ({len(ongoing)})", "",
          "Measured to 2025-12-31 (end of UCDP 26.1). Nothing from 2026 is in the sources.", ""] + hdr + \
         [line(w) for w in sorted(ongoing, key=lambda w: w["start"])]
    L += ["", "## Data notes", "",
          f"- UCDP ACD 26.1 has {n_eps} conflict episodes (1946-2025), {n_war_eps} of them war-level. War-level "
          "episodes starting 2008 or later with no overlapping COW war are added as records; minor (25-999 deaths a "
          f"year) episodes are not. {len(unmatched_pre)} war-level UCDP episodes from 1946-2007 have no COW match "
          "and are not added (COW's coverage; most differ in coding rules or dates): "
          + "; ".join(sorted(w["name"] for w in unmatched_pre)) + ".",
          "- Curated 1789-1815 wars that ran past 1816 overlap COW records of their later phases (see `related`).",
          "- `battle_deaths` follows each source: COW battle deaths (inter-state: sum over participants; extra-state: "
          "state plus non-state deaths; intra-state: TotalBDeaths), UCDP best estimates (BRD 26.1, 1989 onward only; "
          "earlier UCDP years are missing). `deaths_approx` is true for curated values and for sums with missing parts.",
          ""]
    return "\n".join(L)


# 3.30.0: the two committable outputs the game bundles. base_rates.json holds aggregate statistics only (computed
# from every source, COW included: no COW record leaves this machine); open_wars.json holds per-war records only
# from UCDP (CC BY 4.0) and the hand-curated 1789-1815 list.
DECISIVE = {"side_a_victory", "side_b_victory"}
NEGOTIATED = {"compromise", "stalemate", "ceasefire", "peace_agreement"}
BUCKETS = [(0.65, "even"), (0.9, "lopsided"), (1.01, "overwhelming")]   # the stronger side's share of capability


def bucket(w):
    s = w.get("cinc_share_a")
    if s is None:
        return None
    return next(label for hi, label in BUCKETS if max(s, 1 - s) < hi)


def cell(ws):
    ended = [w for w in ws if w["outcome"] != "ongoing" and w["end"]]
    d = sorted(w["duration_months"] for w in ended)
    if len(d) < 3:
        return None
    qs = statistics.quantiles(d, n=4, method="inclusive")
    n = len(ended)
    return {"n": n, "median_months": round(statistics.median(d), 1), "q1_months": round(qs[0], 1), "q3_months": round(qs[2], 1),
            "decisive": round(sum(w["outcome"] in DECISIVE for w in ended) / n, 2),
            "negotiated": round(sum(w["outcome"] in NEGOTIATED for w in ended) / n, 2),
            "initiator_won": (round(sum(w["initiator"] is not None and w["outcome"] == "side_a_victory" and w["initiator"] in w["side_a"]
                                        for w in ended) / max(1, sum(w["initiator"] is not None for w in ended)), 2)
                              if any(w["initiator"] for w in ended) else None)}


def nation_rates(wars):
    """{country: {era: {n, as_initiator, initiator_won, median_months}}} for interstate wars — aggregates only, and
    only where a nation fought at least three in the era. 3.32.2: Prussia 1806 and Brazil 2026 must not draw from
    the same shelf."""
    out = {}
    inter = [w for w in wars if w["type"] == "interstate" and w["end"] and w["outcome"] != "ongoing"]
    codes = sorted({c for w in inter for c in w["side_a"] + w["side_b"] if len(c) == 3 and c.isupper()})
    for code in codes:
        for era in ERA_LABELS:
            ws = [w for w in inter if w["era"] == era and code in w["side_a"] + w["side_b"]]
            if len(ws) < 3:
                continue
            started = [w for w in ws if w["initiator"] == code]
            won = sum(1 for w in started
                      if (w["outcome"] == "side_a_victory" and code in w["side_a"])
                      or (w["outcome"] == "side_b_victory" and code in w["side_b"]))
            lost = sum(1 for w in ws
                       if (w["outcome"] == "side_a_victory" and code in w["side_b"])
                       or (w["outcome"] == "side_b_victory" and code in w["side_a"]))
            out.setdefault(code, {})[era] = {
                "n": len(ws), "as_initiator": len(started),
                "initiator_won": round(won / len(started), 2) if started else None,
                "lost": round(lost / len(ws), 2),
                "median_months": round(statistics.median([w["duration_months"] for w in ws]), 1)}
    return out


def stakes(wars):
    """{era: {median_battle_deaths, share_decisive, share_initiator_lost}} for interstate wars: what this kind of
    war cost, and how often the side that started it lost, in that century. Aggregates only."""
    out = {}
    for era in ERA_LABELS:
        ws = [w for w in wars if w["type"] == "interstate" and w["era"] == era and w["end"] and w["outcome"] != "ongoing"]
        if len(ws) < 3:
            continue
        deaths = [w["battle_deaths"] for w in ws if w.get("battle_deaths")]
        started = [w for w in ws if w["initiator"]]
        lost = sum(1 for w in started
                   if (w["outcome"] == "side_a_victory" and w["initiator"] in w["side_b"])
                   or (w["outcome"] == "side_b_victory" and w["initiator"] in w["side_a"]))
        out[era] = {"n": len(ws),
                    "median_battle_deaths": int(statistics.median(deaths)) if deaths else None,
                    "share_decisive": round(sum(w["outcome"] in DECISIVE for w in ws) / len(ws), 2),
                    "share_initiator_lost": round(lost / len(started), 2) if started else None}
    return out


def base_rates(wars):
    """{type: {era: {"all": cell, "even"|"lopsided"|"overwhelming": cell}}}; cells with fewer than 3 ended wars are
    left out."""
    out = {}
    for t in TYPES:
        for era in ERA_LABELS:
            ws = [w for w in wars if w["type"] == t and w["era"] == era]
            row = {}
            if (c := cell(ws)):
                row["all"] = c
            for _, label in BUCKETS:
                if (c := cell([w for w in ws if bucket(w) == label])):
                    row[label] = c
            if row:
                out.setdefault(t, {})[era] = row
    return {"generated_by": "Documentation/wars/build.py",
            "sources": "Aggregates of Correlates of War (Inter-, Extra-, Intra-, Non-State War Data; NMC v7 for capability "
                       "shares), UCDP/PRIO Armed Conflict Dataset 26.1 and Conflict Termination v4 (CC BY 4.0), and a "
                       "hand-curated 1789-1815 list. Statistics only: no per-war records.",
            "buckets": "Stronger side's share of combined capability (COW CINC, interstate only): even < 0.65 <= lopsided < 0.9 <= overwhelming.",
            "rates": out,
            "nations": nation_rates(wars),
            "stakes": stakes(wars)}


OPEN_FIELDS = ("id", "name", "type", "start", "end", "duration_months", "side_a", "side_b", "initiator", "outcome", "terms",
               "battle_deaths", "source", "era")


def open_wars(wars):
    keep = [{k: w.get(k) for k in OPEN_FIELDS} for w in wars if w["source"] in ("curated", "UCDP-ACD")]
    return {"attribution": "UCDP records: Uppsala Conflict Data Program, UCDP/PRIO Armed Conflict Dataset version 26.1 "
                           "(Davies, Pettersson & Öberg; Gleditsch et al. 2002) and UCDP Conflict Termination Dataset v4 "
                           "(Kreutz 2010), licensed CC BY 4.0, https://ucdp.uu.se. Curated records: GTNW, from the "
                           "references in each record's notes.",
            "wars": keep}


def fetch():
    RAW.mkdir(exist_ok=True)
    for name, url in RAW_FILES.items():
        if not (RAW / name).exists():
            print("fetching", url)
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (GTNW data build)"})
            (RAW / name).write_bytes(urllib.request.urlopen(req, timeout=120).read())


def main():
    if "--fetch" in sys.argv:
        fetch()
    missing = [n for n in RAW_FILES if not (RAW / n).exists()]
    if missing:
        sys.exit("missing raw files (run with --fetch): " + ", ".join(missing))
    cow = cow_inter(load_cinc()) + cow_extra() + cow_intra() + cow_nonstate()
    ucdp = ucdp_episodes()
    added, unmatched_pre = merge(cow, ucdp)
    wars = sorted(curated() + cow + added, key=lambda w: (w["start"], w["id"]))
    apply_overrides(wars)
    (HERE / "wars.json").write_text(json.dumps(wars, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    (HERE / "summary.md").write_text(summary(wars, unmatched_pre, len(ucdp), sum(u["war"] for u in ucdp)), encoding="utf-8")
    (HERE / "base_rates.json").write_text(json.dumps(base_rates(wars), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    (HERE / "open_wars.json").write_text(json.dumps(open_wars(wars), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {len(wars)} wars:", dict(Counter(w["source"] for w in wars)))


if __name__ == "__main__":
    main()
