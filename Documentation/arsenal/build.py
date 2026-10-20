import json, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from data import OPTIONS, FLEETS, TREATIES, S, st, src

OUT = os.path.dirname(os.path.abspath(__file__)) + "/"   # regenerates next to this script

OPTIONS += [
    dict(id="chemical_restart", category="chemical", name="Restart a chemical weapons program (banned)",
         available_from=2023, available_to=None,
         legal_status_by_period=[st(2023, None, "treaty_banned", "Requires withdrawal from the CWC (90 days' notice, Art. XVI) or covert violation.")],
         example_systems=[], scale_note="No stockpile exists. Game suggestion: multi-year lead time before any usable capability; this is a designer estimate, not a published figure.",
         historical_use="None.", diplomatic_cost_note="Extreme: pariah status, OPCW referral, allied rupture, domestic opposition (Congress funds would be required).",
         sources=src("opcw_2023", "unoda_cwc")),
    dict(id="biological_restart", category="biological", name="Restart a biological weapons program (banned)",
         available_from=1975, available_to=None,
         legal_status_by_period=[st(1975, None, "treaty_banned", "Requires BWC withdrawal (3 months' notice, Art. XIII) or covert violation.")],
         example_systems=[], scale_note="No stockpile since the early 1970s. Game suggestion: multi-year lead time; designer estimate only.",
         historical_use="None.", diplomatic_cost_note="Extreme; arguably worse than chemical. Should be near-impossible to approve domestically.",
         sources=src("unoda_bwc", "nixon1969")),
]

ERAS = [
    ("1789-1815", 1789, 1815, "Early republic, Quasi-War, Barbary Wars, War of 1812", [
        "No navy at all until 1797: the Continental Navy was disbanded in 1785; the Naval Act of 1794 funded six frigates (first launched 1797); Navy Department created 30 Apr 1798.",
        "Army: ~700-840 regulars in 1789; Legion of the United States 1792-96; War of 1812 regulars authorized ~35,000 plus state militia (often unwilling to fight outside their states).",
        "Main offensive tools: frigates and sloops (single-ship actions), privateers, a small Marine Corps (1798), embargo (1807-09), and invasion of Canada (failed 1812-14).",
        "Wars: Northwest Indian War (1785-95), Quasi-War with France (1798-1800, undeclared), First Barbary War (1801-05), War of 1812 (1812-15), Second Barbary War (1815).",
        "Constraint: Congress declares war and grants letters of marque; the President cannot raise forces without appropriations.",
    ]),
    ("1815-1860", 1816, 1860, "Distant-station squadrons, Mexican War", [
        "Navy organized as regional squadrons (Mediterranean, West India, Pacific, Brazil, East India, Home, Africa) - see fleets list.",
        "Ships of the line built (Act of 1816) but never fought a fleet battle. Steam enters (USS Fulton 1837, USS Princeton 1843).",
        "Army: ~6,000-16,000 regulars; Mexican War (1846-48) ~100,000 served incl. volunteers; Scott's Veracruz landing (Mar 1847, ~10,000 men) was the first large U.S. amphibious operation.",
        "Gunboat diplomacy: Perry opens Japan (1853-54); punitive raids (Sumatra 1832, Barrier Forts China 1856, Fiji 1855/1859).",
        "Indian removals and wars (Seminole Wars 1816-58) are the bulk of Army combat.",
    ]),
    ("1861-1865", 1861, 1865, "Civil War", [
        "Union Army ~1 million at peak (1865); ~2.1M served. Conscription from 1863.",
        "Navy grows from ~42 commissioned ships to ~670 vessels; ironclads (Monitor, Mar 1862); Anaconda blockade proclaimed 19 Apr 1861.",
        "First U.S. air arm: Union Army Balloon Corps (1861-Aug 1863) for observation only.",
        "Total-war methods: Sherman's march (1864), Sheridan in the Shenandoah. Lieber Code (1863) - first codified U.S. law-of-war instructions.",
        "GAME NOTE: largely an internal war; foreign-attack options limited by need to keep Britain/France neutral (Trent Affair 1861).",
    ]),
    ("1866-1897", 1866, 1897, "Reconstruction, Indian Wars, the 'New Navy'", [
        "Army capped at ~25,000 enlisted (1876); fighting on the Plains (Little Bighorn 1876, Wounded Knee 1890).",
        "Navy decays post-war to a few dozen obsolete ships (often described as smaller than Chile's in 1880s - approx.), then rebuilds: ABCD steel ships authorized 1883; Naval War College 1884; Mahan's 'Influence of Sea Power' 1890; first battleships commissioned 1895.",
        "Squadrons: European, North Atlantic, South Atlantic, Pacific, Asiatic (1868).",
        "Overthrow of the Hawaiian monarchy (1893) aided by Marines from USS Boston.",
    ]),
    ("1898-1913", 1898, 1913, "Spanish-American War and imperial era", [
        "Spanish-American War (Apr-Aug 1898): Dewey's Asiatic Squadron at Manila Bay (1 May), Sampson/Schley at Santiago (3 Jul); Army expands to ~275,000 incl. volunteers.",
        "Philippine-American War (1899-1902, insurgency to ~1913); Boxer Relief (1900, ~2,500 U.S. troops); Banana Wars begin (Panama 1903, Cuba 1906, Nicaragua 1912).",
        "Great White Fleet (16 battleships, Dec 1907-Feb 1909); first dreadnoughts commissioned 1910; first submarine USS Holland (1900); Army buys first airplane 1909, Navy 1911.",
        "Roosevelt Corollary (1904) frames the Caribbean as a U.S. police zone.",
    ]),
    ("1914-1918", 1914, 1918, "WWI (U.S. belligerent Apr 1917-Nov 1918)", [
        "Veracruz occupation (1914) and Punitive Expedition into Mexico (1916-17, ~10,000 troops, 1st Aero Squadron).",
        "Army ~4 million mobilized; AEF ~2 million in France; first U.S. tanks (Tank Corps, Renault FT) and Air Service (~45 front-line squadrons by Nov 1918).",
        "CHEMICAL: AEF Gas Service (Aug 1917), Chemical Warfare Service (28 Jun 1918), 1st Gas Regiment; U.S. forces used gas in 1918 (legal - no ratified ban then). U.S. suffered ~70,000 gas casualties (approx.).",
        "Navy: Battleship Division Nine with the British Grand Fleet; convoy escort; North Sea Mine Barrage (1918).",
        "Economic: Trading with the Enemy Act (Oct 1917).",
    ]),
    ("1919-1938", 1919, 1938, "Interwar", [
        "Naval arms control: Washington Treaty (1922) and London Treaties (1930, 1936) cap battleships/carriers. First carrier USS Langley 1922; Lexington/Saratoga 1927.",
        "Geneva Protocol signed 1925 but not ratified (Senate) until 1975 - chemical stockpile retained. Kellogg-Briand (1928). Neutrality Acts (1935-37) restrict arms sales to belligerents.",
        "Army small (~120,000-190,000); Marines fight Banana Wars to 1934 (Nicaragua, Haiti); Fleet Marine Force 1933 and amphibious doctrine 1934.",
        "Air Corps (1926) develops strategic bombing doctrine; B-17 enters service 1938. Good Neighbor Policy (1933) ends Caribbean interventions.",
    ]),
    ("1939-1945", 1939, 1945, "WWII (U.S. belligerent Dec 1941-Sept 1945)", [
        "Pre-war economic warfare: export controls on Japan from Jul 1940, asset freeze 26 Jul 1941, de facto oil embargo Aug 1941; Lend-Lease (Mar 1941); undeclared naval war in the Atlantic (1941).",
        "Peak ~12 million in uniform (1945); 16 million served. Navy: 6,768 ships of all types by Aug 1945 (NHHC force levels); numbered fleets created 15 Mar 1943.",
        "New options: carriers as capital ships, strategic bombing, airborne divisions, Rangers, OSS (13 Jun 1942), unrestricted submarine warfare, radio-guided bombs (Azon 1944), helicopters (1944).",
        "NUCLEAR: Manhattan Project; Trinity 16 Jul 1945; Hiroshima 6 Aug, Nagasaki 9 Aug 1945. Stockpile at end of 1945: 2 (DOE).",
        "CHEMICAL: large stockpile, FDR no-first-use pledge (Jun 1943), never used in combat. BIOLOGICAL: offensive program begins 1943 at Camp Detrick.",
    ]),
    ("1946-1961", 1946, 1961, "Early Cold War", [
        "National Security Act 1947: Air Force, CIA (18 Sept 1947), NSC. Strategic Air Command (1946). Covert ops authorized by NSC 10/2 (1948): Iran 1953, Guatemala 1954, Bay of Pigs 1961.",
        "Nuclear stockpile: 299 (1950) -> 2,422 (1955) -> 18,638 (1960) -> 22,229 (1961). Thermonuclear test Ivy Mike 1952; Soviet first test 1949 ends U.S. monopoly.",
        "Delivery: B-36, B-47, B-52 (1955); Atlas ICBM on alert Sept 1959; first Polaris SSBN patrol 15 Nov 1960; Regulus, Matador, Snark cruise missiles; Thor/Jupiter IRBMs in UK/Italy/Turkey.",
        "Korea (1950-53) under UN mandate; massive retaliation doctrine (1954). Supercarrier Forrestal (1955); USS Nautilus (1955); USS Enterprise CVN-65 (1961).",
        "Special Forces (1952); helicopters in Korea. Chemical: sarin production 1950s. Bio: production at Pine Bluff from 1954. First ASAT test (Bold Orion, Oct 1959).",
    ]),
    ("1962-1975", 1962, 1975, "Vietnam era", [
        "Cuban Missile Crisis (Oct 1962): quarantine, SAC at DEFCON 2, Jupiter withdrawal deal. Stockpile peaks at 31,255 (1967).",
        "Triad matures: 1,054 ICBMs and 41 SSBNs by 1967; Minuteman III (1970, MIRV), Poseidon (1971).",
        "Vietnam: peak 543,400 troops (Apr 1969); Rolling Thunder (1965-68), Arc Light B-52s, Linebacker I/II (1972, laser-guided bombs); airmobile 1st Cavalry Division; herbicides (Ranch Hand 1962-71); recon drones (1964-75); Haiphong mining (1972).",
        "Arms control: LTBT 1963, Outer Space Treaty 1967, NPT 1970, SALT I and ABM Treaty 1972. Nixon renounces biological weapons and chemical first use (25 Nov 1969). Geneva Protocol and BWC ratified Jan 1975.",
        "Constraints: War Powers Resolution (Nov 1973) - 60/90-day clock; Church Committee (1975); draft ends 1973. Mayaguez incident (May 1975). ASAT: Program 437 Thor (to 1975).",
    ]),
    ("1976-1991", 1976, 1991, "Late Cold War", [
        "Stockpile ~24,000 (1980) -> 22,217 (1989) -> 19,008 (1991). New systems: ALCM (1982), Tomahawk (1983), GLCM and Pershing II in Europe (1983), Peacekeeper (1986), B-1B (1986), Trident I (1979) and II (1990), Ohio SSBNs (1981+), secret F-117 (1983).",
        "Treaties: SALT II (1979, unratified, observed to 1986); INF (1987, in force 1988) eliminates intermediate missiles; START I signed 31 Jul 1991. Sept 1991 Presidential Nuclear Initiatives withdraw most tactical nukes.",
        "Ops: Desert One (1980, failed), Lebanon (1982-84), Grenada (1983), Libya El Dorado Canyon (1986), Tanker War/Praying Mantis (1988), Panama (1989), Gulf War (1991, ~540,000 deployed, first Tomahawk combat).",
        "Delta Force (1977), SOCOM (1987), Goldwater-Nichols (1986). Navy peaks near 594 ships (1987) under the 600-ship goal.",
        "Chemical binary production 1987-90; May 1991 U.S. forswears all chemical use. ASAT: F-15 ASM-135 kills Solwind satellite (Sept 1985). EO 12333 (1981) bans assassination; Iran-Contra (1986).",
    ]),
    ("1992-2001", 1992, 2001, "Post-Cold War (to 10 Sept 2001)", [
        "Stockpile 13,708 (1992) -> 10,526 (2001). Last U.S. nuclear test 23 Sept 1992; CTBT signed 1996, rejected by Senate 1999. START I in force 1994; START II never in force.",
        "Ops: Somalia (1992-94), Haiti (1994), Bosnia Deliberate Force (1995), Iraq no-fly zones and Desert Fox (1998), Infinite Reach cruise-missile strikes on Sudan/Afghanistan (Aug 1998), Kosovo Allied Force (1999; B-2 and JDAM debut).",
        "Predator UAV first deployed (Bosnia 1995, unarmed). Fifth Fleet re-established (1995). CWC ratified (Apr 1997) - chemical destruction begins in earnest.",
        "Sanctions era: Iraq (1990-2003), Iran-Libya Sanctions Act (1996).",
    ]),
    ("2001-2014", 2001, 2014, "Global War on Terror", [
        "AUMF (18 Sept 2001) and Iraq AUMF (2002). Afghanistan (from 7 Oct 2001), Iraq (from 20 Mar 2003; ~170,000 peak 2007). Armed drones: first Predator strikes Oct 2001; targeted killing in Pakistan, Yemen, Somalia.",
        "Stockpile 10,526 (2001) -> 4,717 (2014). Treaties: ABM withdrawal (2002), SORT (2003-11), New START (signed 8 Apr 2010, in force 5 Feb 2011). Peacekeeper retired 2005.",
        "Cyber: Stuxnet/Olympic Games (~2007-10, attributed); USCYBERCOM (2010); Fleet Cyber Command/10th Fleet (2010). Space: Burnt Frost ASAT shot (21 Feb 2008).",
        "SSGN conversions (2006-08); F-22 (2005); MQ-9 Reaper (2007); Fourth Fleet re-established (2008). Libya (2011, under UNSC 1973); bin Laden raid (2 May 2011); Inherent Resolve vs ISIS (from Aug 2014); Russia sanctions over Crimea (2014).",
    ]),
    ("2015-2026", 2015, 2026, "Great-power competition (to present, Oct 2026)", [
        "Stockpile 4,571 (2015) -> 3,748 (Sept 2023, last official figure); FAS Jan 2025: ~3,700 stockpiled, ~1,770 deployed. W76-2 low-yield SLBM warhead deployed (2019).",
        "Treaties: INF withdrawal (2 Aug 2019); Russia suspends New START participation (Feb 2023); New START EXPIRED 5 Feb 2026 - first time since 1972 with no binding U.S.-Russian limits. Oct 2025 directive to begin nuclear testing 'on an equal basis' (implementation unclear).",
        "Chemical stockpile destroyed (7 Jul 2023) - chemical option gone. U.S. destructive DA-ASAT test moratorium (Apr 2022). Space Force (20 Dec 2019); Counter Communications System (2020), Meadowlands jammers (2025-26).",
        "Strikes: Syria (Apr 2017, Apr 2018), MOAB (Apr 2017), Soleimani (Jan 2020), Houthis (2024-25), Midnight Hammer on Iranian nuclear sites (22 Jun 2025), maritime strikes on alleged drug boats (from Sept 2025), Venezuela raid and capture of Maduro (3 Jan 2026), Operation Epic Fury vs Iran with Israel (from 28 Feb 2026, ~5-6 weeks, followed by ceasefire; status after Apr 2026 UNCERTAIN).",
        "Post-INF ground-launched missiles return: Typhon (Philippines 2024), PrSM (2023); Dark Eagle hypersonic battery receiving operational missiles (2026). F-35 fleet; B-21 flight testing, first to Ellsworth 2027.",
        "Economic: sweeping Russia sanctions (2022), export controls on chips to China (2022-), broad tariff actions (2025).",
    ]),
    ("2027-2030", 2027, 2030, "Near future (announced, fielded or near-fielded only)", [
        "Likely by 2030: B-21 Raider in service at Ellsworth (first aircraft 2027); additional Dark Eagle batteries; Conventional Prompt Strike on USS Zumwalt; Collaborative Combat Aircraft (drone wingmen) initial fielding; Virginia Block V with payload module.",
        "Probably NOT by 2030 (flag): Sentinel ICBM (restructured 2024, schedule slipped into the 2030s); Columbia SSBN first patrol (planned ~2030-31, at risk); LRSO (~2030, uncertain); SLCM-N (mid-2030s); F-47 NGAD (first flight targeted 2028).",
        "Treaty environment: no U.S.-Russia strategic limits unless a successor is negotiated; China (~600+ warheads, DoD estimate, growing) not party to any limits.",
        "Chemical: none (destroyed). Biological: none (BWC). Both only as 'restart a banned program' options.",
    ]),
]


def status_in(opt, y0, y1):
    out = []
    for p in opt["legal_status_by_period"]:
        a, b = p["from"], p["to"] if p["to"] is not None else 9999
        if a <= y1 and b >= y0:
            out.append(p["status"])
    return "/".join(dict.fromkeys(out)) or "-"


def available(opt, y0, y1):
    a = opt["available_from"]
    b = opt["available_to"] if opt["available_to"] is not None else 9999
    return a <= y1 and b >= y0


def esc(s):
    return s.replace("|", "/").replace("\n", " ")


def main():
    data = {
        "title": "GTNW - U.S. offensive options by era (1789-2030)",
        "generated": "2026-10-20",
        "scope_note": "Encyclopedia-level game-design research. Dates are first/last year available to the U.S.; 'approx' and 'UNCERTAIN' flags mark estimates. No technical weapon details.",
        "status_legend": {"legal": "No binding legal bar on possession/use beyond general law of war",
                          "restricted": "Lawful but limited by treaty caps, ratified use-bans with reservations, statute or binding policy",
                          "treaty_banned": "Possession/use banned by a treaty the U.S. is party to",
                          "destroyed": "Capability verifiably eliminated"},
        "eras": [{"id": e[0], "from": e[1], "to": e[2], "name": e[3], "key_facts": e[4]} for e in ERAS],
        "options": OPTIONS,
        "fleets": FLEETS,
        "treaties": [{"dates": t[0], "name": t[1], "effect": t[2]} for t in TREATIES],
    }
    with open(OUT + "gtnw_us_arsenal_by_era.json", "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    L = []
    L.append("# GTNW - U.S. Presidential Offensive Options by Era (1789-2030)\n")
    L.append("Game-design research at encyclopedia level. Machine-readable companion: `gtnw_us_arsenal_by_era.json`. "
             "Legal status vocabulary: **legal**, **restricted**, **treaty_banned**, **destroyed**. "
             "Figures marked *approx* are rounded from secondary sources; *UNCERTAIN* marks contested or unverified items.\n")
    L.append("## Nuclear stockpile over time (NNSA/DOE official, end of fiscal year)\n")
    L.append("| Year | Stockpile | Context |\n|---|---|---|")
    rows = [(1945, "2", "Trinity, Hiroshima, Nagasaki"), (1950, "299", "Korea begins"), (1955, "2,422", "B-52 enters service"),
            (1960, "18,638", "First Polaris patrol"), (1962, "25,540", "Cuban Missile Crisis"), (1967, "31,255 (peak)", "Triad complete"),
            (1975, "27,519", ""), (1980, "24,104", ""), (1989, "22,217", "Berlin Wall falls"), (1991, "19,008", "PNIs, START I signed"),
            (1995, "10,904", ""), (2001, "10,526", "9/11"), (2005, "8,360", ""), (2010, "5,066", "New START signed"),
            (2015, "4,571", ""), (2020, "3,750", ""), (2023, "3,748", "last official figure"),
            (2025, "~3,700 (FAS est.)", "~1,770 deployed; ~1,477 retired awaiting dismantlement")]
    for r in rows:
        L.append(f"| {r[0]} | {r[1]} | {r[2]} |")
    L.append("\nSources: NNSA 2024 transparency fact sheet (FY1962-2023; pre-1962 from DOE 1993 release); FAS/Bulletin Nuclear Notebook 2025.\n")

    L.append("## Treaty and norm constraints timeline\n")
    L.append("| Dates | Instrument | Effect on options |\n|---|---|---|")
    for t in TREATIES:
        L.append(f"| {t[0]} | {t[1]} | {esc(t[2])} |")
    L.append("")

    for e in ERAS:
        eid, y0, y1, name, facts = e
        L.append(f"## {eid}: {name}\n")
        for fct in facts:
            L.append(f"- {fct}")
        L.append("")
        L.append("| Option | Category | Available (US) | Status this era | Example systems / units | Diplomatic cost |\n|---|---|---|---|---|---|")
        for o in OPTIONS:
            if not available(o, y0, y1):
                continue
            to = o["available_to"] if o["available_to"] is not None else "now"
            ex = "; ".join(o["example_systems"][:4]) or "-"
            L.append(f"| {esc(o['name'])} | {o['category']} | {o['available_from']}-{to} | {status_in(o, y0, y1)} | {esc(ex)} | {esc(o['diplomatic_cost_note'])} |")
        # options NOT available but notable
        if y1 < 1917:
            L.append("\n*Not available: chemical, biological, nuclear, air power (except balloons from 1861), missiles, cyber, space.*")
        fl = [f for f in FLEETS if f["from"] <= y1 and (f["to"] or 9999) >= y0]
        if fl:
            L.append("\n**Fleets/squadrons active:** " + "; ".join(f"{f['name']} ({f['from']}-{f['to'] or 'now'}, {f['home_region']})" for f in fl))
        L.append("")

    L.append("## Option detail (scale and historical use)\n")
    for o in OPTIONS:
        to = o["available_to"] if o["available_to"] is not None else "now"
        L.append(f"### {o['name']} (`{o['id']}`, {o['available_from']}-{to})\n")
        L.append(f"- **Scale:** {o['scale_note']}")
        L.append(f"- **Historical use:** {o['historical_use']}")
        L.append("- **Legal status:** " + "; ".join(f"{p['from']}-{p['to'] or 'now'}: {p['status']}" + (f" ({p['note']})" if p.get('note') else "") for p in o["legal_status_by_period"]))
        L.append(f"- **Diplomatic cost:** {o['diplomatic_cost_note']}")
        L.append("")

    L.append("## Fleets and squadrons\n")
    L.append("| Name | From | To | Home region | Notes |\n|---|---|---|---|---|")
    for f in FLEETS:
        L.append(f"| {esc(f['name'])} | {f['from']} | {f['to'] or 'present'} | {esc(f['home_region'])} | {esc(f['notes'])} |")
    L.append("")

    L.append("## Uncertainties and caveats\n")
    for u in [
        "Squadron start/end dates are approximate; squadrons were frequently renamed, merged and suspended (esp. 1861-65). Atlantic Fleet formation date (1905/1906) varies by source.",
        "Eighth Fleet end date and Fifth Fleet WWII disestablishment date (1946 vs 1947) vary by source.",
        "Dark Eagle (LRHW): the Army said in Mar 2026 the first battery would receive operational missiles 'soon'; this file treats 2026 as first availability - verify.",
        "Stuxnet/Olympic Games attribution to the U.S. rests on press reporting (NYT 2012); never officially acknowledged.",
        "War of 1812 privateer numbers and prize counts vary widely across sources.",
        "Post-Feb 2026 nuclear arms-control status and Operation Epic Fury aftermath may have changed after April 2026 sources.",
        "Oct 2025 nuclear-testing directive: whether any explosive test preparation began is unclear in public sources.",
        "Near-future dates (Sentinel, Columbia, LRSO, CCA, CPS, F-47) are program targets that have repeatedly slipped.",
        "Chemical/biological 'restart' lead times are designer suggestions, not published estimates.",
        "Some per-unit counts (WWII aircraft, Vietnam helicopters, current inventories) are rounded approximations.",
    ]:
        L.append(f"- {u}")
    L.append("\n## Sources\n")
    used = sorted({u for o in OPTIONS for u in o["sources"]} | {u for f in FLEETS for u in f["sources"]})
    for u in used:
        L.append(f"- {u}")
    for extra in [S["aca_glance"], S["aca_newstart"], S["chatham_newstart"], S["hs_neutrality"], S["hs_kellogg"], S["hs_salt"], S["nhhc_force"]]:
        if extra not in used:
            L.append(f"- {extra}")
    with open(OUT + "gtnw_us_arsenal_by_era.md", "w") as f:
        f.write("\n".join(L) + "\n")
    print(len(OPTIONS), "options", len(FLEETS), "fleets")


main()
