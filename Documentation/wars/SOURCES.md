# Wars dataset: sources, licences and mapping

`build.py` turns the files in `raw/` and `curated_1789_1815.json` into `wars.json` (803 wars, 1786–2025) and
`summary.md`. Rebuild with `python3 -I build.py` (standard library only); `--fetch` first re-downloads any
missing raw file from the URLs below. All downloads were made on 2026-11-16 and are kept byte-for-byte as served.

## Sources

| file in `raw/` | dataset | version / coverage | URL | SHA-256 |
|---|---|---|---|---|
| `Inter-StateWarData_v4.0.csv` | COW Inter-State War Data | v4.0, 1816–2007 (95 wars) | https://correlatesofwar.org/wp-content/uploads/Inter-StateWarData_v4.0.csv | `2535e30b145141c331a07d12d91e498ad8bdd3db32ba8d3bd88c4fda54817731` |
| `Extra-StateWarData_v4.0.csv` | COW Extra-State War Data (colonial/imperial) | v4.0, 1816–2007 (163 wars) | https://correlatesofwar.org/wp-content/uploads/Extra-StateWarData_v4.0.csv | `529c325fdf0355ea4e09ce1c0d13d3cb474eaffcfebe13576b7a56207b264104` |
| `Intra-State-Wars-v5.1.zip` | COW Intra-State War Data (wars + state-participants files, codebook) | v5.1 (Apr 2020), 1816–2014 (420 wars) | https://correlatesofwar.org/wp-content/uploads/Intra-State-Wars-v5.1.zip | `b2d1f4892d3cbb02604cf8e506c5c2c3e87fb85df75276f69b1089e67fb25236` |
| `Non-StateWarData_v4.0.csv` | COW Non-State War Data | v4.0, 1816–2007 (62 wars) | https://correlatesofwar.org/wp-content/uploads/Non-StateWarData_v4.0.csv | `99d3d9df70a54fd2372fe05e2085216fc85ce1d3a72a7cb9e5c86f3bae4c9b9a` |
| `States2024.zip` | COW State System Membership (ccode list; reference for the mapping table) | v2024 | https://correlatesofwar.org/wp-content/uploads/States2024.zip | `c11689e8c0aa70ede855f6b605c4dd71c7b04122b71d5827dab5ba06b32e2015` |
| `NMCv7.zip` | COW National Material Capabilities (CINC) | v7.0, 1816–2022 | https://correlatesofwar.org/wp-content/uploads/NMCv7.zip | `07b7396cbf0a06a3a57d97dfb56e316c5720b6feeab06db4578bcb6447be51a9` |
| `ucdp-prio-acd-261-csv.zip` | UCDP/PRIO Armed Conflict Dataset | 26.1, 1946–2025 | https://ucdp.uu.se/downloads/ucdpprio/ucdp-prio-acd-261-csv.zip | `5f951743222964674a446e32a5a871077b29bd13349588d85fc59953d89c878a` |
| `ucdp-brd-conf-261-csv.zip` | UCDP Battle-Related Deaths Dataset (conflict level) | 26.1, 1989–2025 | https://ucdp.uu.se/downloads/brd/ucdp-brd-conf-261-csv.zip | `a88c81fb727f10a689ff0084bacf78e6fbfaadbbe925a608f6e7be2f44a6141e` |
| `UCDPConflictTerminationDataset_v4_2024_Conflict.csv` | UCDP Conflict Termination Dataset (conflict level) | v4-2024, 1946–2024 | https://ucdp.uu.se/downloads/monadterm/UCDPConflictTerminationDataset_v4_2024_Conflict.csv | `6f3a739fa5c6e23ab3dde169d0d06f139677b7a9cf5ce5b2dcb3bf3ab39f9b7d` |
| `UCDPConflictTerminationDataset_v4_2024_Codebook.pdf` | its codebook (outcome codes) | v4-2024 | https://ucdp.uu.se/downloads/monadterm/UCDPConflictTerminationDataset_v4_2024_Codebook.pdf | `648c1601f41796f1b565ab91616b4e8968ec7e84aca5434ddad8945b2079908d` |

Landing pages: https://correlatesofwar.org/data-sets/cow-war/ , https://correlatesofwar.org/data-sets/national-material-capabilities/ ,
https://correlatesofwar.org/data-sets/state-system-membership/ , https://ucdp.uu.se/downloads/ . Nothing failed to download.
(The ACD 26.1 that was current on 2026-11-16 runs to 2025, one year past the 1946–2024 asked for.)

### Citations

- Sarkees, Meredith Reid and Frank Wayman (2010). *Resort to War: 1816–2007*. Washington DC: CQ Press. (COW inter-state, extra-state and non-state war data, v4.0.)
- Dixon, Jeffrey and Meredith Reid Sarkees (2016). *A Guide to Intra-state Wars: An Examination of Civil, Regional, and Intercommunal Wars, 1816–2014*. Thousand Oaks, CA: CQ Press. (COW intra-state war data, v5.1.)
- Correlates of War Project. 2025. "State System Membership, v2024." Online, https://correlatesofwar.org
- Singer, J. David, Stuart Bremer, and John Stuckey (1972). "Capability Distribution, Uncertainty, and Major Power War, 1820–1965." In Bruce Russett (ed.), *Peace, War, and Numbers*. Beverly Hills: Sage, 19–48. Singer, J. David (1988). "Reconstructing the Correlates of War Dataset on Material Capabilities of States, 1816–1985." *International Interactions* 14: 115–32. (NMC, version 7.0.)
- Gleditsch, Nils Petter, Peter Wallensteen, Mikael Eriksson, Margareta Sollenberg and Håvard Strand (2002). "Armed Conflict 1946–2001: A New Dataset." *Journal of Peace Research* 39(5). Davies, Shawn, Therése Pettersson and Magnus Öberg (2026). "Organized violence 1989–2025, and violent political protests." *Journal of Peace Research*. https://doi.org/10.1093/jopres/xjag046 (UCDP/PRIO ACD 26.1 and UCDP BRD 26.1.)
- Kreutz, Joakim (2010). "How and When Armed Conflicts End: Introducing the UCDP Conflict Termination Dataset." *Journal of Peace Research* 47(2). (UCDP CTD v4-2024.)
- 1789–1815: Clodfelter, Micheal (2017). *Warfare and Armed Conflicts: A Statistical Encyclopedia of Casualty and Other Figures, 1492–2015*, 4th ed. Jefferson, NC: McFarland; Wikipedia, "List of wars: 1700–1799" and "List of wars: 1800–1849" (https://en.wikipedia.org/wiki/List_of_wars:_1700%E2%80%931799, https://en.wikipedia.org/wiki/List_of_wars:_1800%E2%80%931849) as pointers, and the per-war Wikipedia articles named in each record's `ref`. See "Curated 1789–1815" below for how far these were checked.

### Licences and terms of use — read before committing

- **UCDP** (all four UCDP files): free of charge, licensed **CC BY 4.0** — use and redistribution allowed with
  citation of the publications above. Committing them and anything derived from them is fine.
- **Correlates of War** (all six COW files): the COW data-sets page says that by downloading a COW dataset you
  agree that (1) the data are **not to be used for any commercial, profit-making activity**; (2) users cite each
  dataset as its page asks; (3) users **do not distribute the dataset to any third party without written
  permission** of the COW director and data host; (4) users ask permission for other dissemination or posting.
  Consequences for GTNW:
  - `raw/.gitignore` keeps the six COW files out of git; `build.py --fetch` re-downloads them for anyone
    rebuilding. Only the UCDP raw files would be committed.
  - `wars.json` is derived from COW (dates, sides, outcomes, deaths for 740 of 803 wars). Whether a derived,
    re-coded table counts as "the dataset" under term (3) is not something these terms settle. If GTNW is
    distributed publicly — and especially if it is ever sold (term 1) — ask the COW data host for permission
    first (as of July 2026 all COW war data sets are hosted by Paul Poast, University of Chicago, contact address
    on the cow-war page), or ship only the UCDP- and curated-sourced records.
- **Wikipedia** text is CC BY-SA; no text was copied — only facts (dates, treaties), which are not copyrightable.

## Build rules

- **Unit of record.** COW: one record per war (WarNum). UCDP: one record per conflict *episode* (`conflict_id` +
  `start_date2`). Curated: one record per war.
- **Types.** COW inter-state → `interstate`; extra-state (colonial and imperial) → `colonial`; intra-state →
  `civil`, or `internationalized_civil` when COW's `Intnl` = 1; non-state → `nonstate`. UCDP
  type 1/2/3/4 → `colonial`/`interstate`/`civil`/`internationalized_civil`.
- **Dates.** `start`/`end` are `YYYY-MM-DD` when the day is known, otherwise `YYYY`; `date_precision` says which,
  and `start_month`/`end_month` keep a known month when the day is unknown. COW wars use the earliest start and the
  latest end over all phases and participants. `end` is null only when the war is ongoing at the end of the data.
- **Duration.** Months (30.44 days) between start and end, unknown days/months taken as mid-month/mid-year, never
  negative; gaps between phases are included. Ongoing wars are measured to 2025-12-31.
- **Sides.** `side_a`/`side_b` hold GTNW ids, `non-state:<name>` for armed groups and non-member polities, and
  `other:<name>` for states GTNW has no id for. COW inter-state: Side 1 / Side 2. Extra-state: the state(s) /
  their opponents. Intra-state: the government plus states intervening for it / the rebels plus states intervening
  for them (from the state-participants file). UCDP: `side_a`+`side_a_2nd` / `side_b`+`side_b_2nd`
  (secondary = states sending troops).
- **Initiator.** COW inter-state: the earliest-entering participant coded as initiator. Extra-state: side A's
  state if COW says side A initiated, else side B. Intra-state: matched from COW's initiator name (a GTNW id, or
  `non-state:<name>` when a rebel group started it). Non-state: side A/B's first party. UCDP does not code
  initiators (null). Curated: from the references.
- **Outcome.** COW codes 1/2/3/4/5/6/7 → `side_a_victory`/`side_b_victory`/`compromise`/`transformed`/`ongoing`/
  `stalemate`/`unclear` ("continues at below-war level"). For inter-state wars the code of the Side-1 participant
  fighting latest is used (changed-sides rows skipped). UCDP CTD codes 1/2/3/4 → `peace_agreement`/`ceasefire`/
  `side_a_victory`/`side_b_victory`; 5 (low activity) and 6 (actor ceased to exist) → `unclear`, with the reason
  in `terms`. Note: COW's Side 1 is almost always the winner, so for COW inter-state wars `initiator` and
  `cinc_share_a` say more than the side letter.
- **Terms.** COW and UCDP have no settlement text. `terms` holds: a one-line settlement for ~35 notable COW
  inter-state wars (`INTER_TERMS` in build.py, standard textbook facts), "transformed into COW war N", the UCDP
  termination type, or the curated text.
- **Deaths.** COW inter-state: sum of participants' `BatDeath`; extra-state: state + non-state deaths; intra-state:
  `TotalBDeaths` (or side A + side B); non-state: `TotalCombatDeaths`. UCDP: sum of BRD 26.1 best estimates over the
  episode's years (1989+ only; null before). `deaths_approx` = true for every curated record and for sums with a
  missing (-9) part.
- **COW vs UCDP de-duplication.** COW is preferred wherever it has coverage (inter/extra/non-state to 2007,
  intra-state to 2014). A UCDP episode is linked to a COW war when the types are compatible, the years overlap
  (±1 year; a war COW left ongoing is taken to run to the end of COW's coverage), and they share at least two
  states (interstate) or the UCDP location/side-A government is one of the COW war's states (other types). Linked
  episodes are listed in the COW record's `ucdp_conflict_ids`. For COW wars coded *ongoing*, the end and outcome
  come from the most similar linked UCDP conflict. Only **war-level** UCDP episodes (intensity 2: 1,000+ battle
  deaths in a calendar year, matching COW's threshold) that start in 2008 or later and link to no COW war are added
  (19 records). Ten war-level UCDP episodes from 1946–2007 have no COW counterpart and are left out (listed in
  `summary.md`).
- **Hand-coded ends** (`OVERRIDES` in build.py; record `notes` say so): COW Afghan Resistance → 2021-08-30 and COW
  Afghan-Taliban War → 2021-08-15, Taliban victory; COW Syrian war → 2024-12-08, rebel victory (fall of Assad);
  COW Donbas War → 2022-02-24, transformed into the Russia–Ukraine war; UCDP Ethiopia–TPLF 2020–22 → peace agreement
  (Pretoria, Nov 2022); UCDP Israel–Hamas 2014 → ceasefire (26 Aug 2014). These are well-documented events the
  sources' coverage stops short of.
- **Not covered:** anything after 2025 (e.g. how wars ongoing in 2025 have gone in 2026); UCDP minor conflicts
  (25–999 deaths a year), so e.g. the 2008 Russo-Georgian war (well under 1,000 battle deaths) is absent.

## Curated 1789–1815

44 wars in `curated_1789_1815.json`, each with `ref` naming the reference article. They were compiled from the
standard narrative facts (declarations, treaties, major battles), not transcribed line by line from Clodfelter.
To avoid inventing precision: dates are to the day only for documented events, otherwise month or year;
`battle_deaths` is filled only for the War of 1812 (≈3,800 combat deaths) and the 1812 invasion of Russia
(≈550,000 military deaths from all causes, a midpoint of commonly cited ranges), and is null with a note
elsewhere; every curated record has `deaths_approx: true`. Wars running past 1816 (Mexican and South American
independence, Ottoman–Wahhabi, Anglo-Nepalese, Second Serbian Uprising) are recorded whole and overlap COW
records of their later phases (`related`). Four wars that began in 1786–1788 but were being fought in 1789 are
included and counted in the 1789–1815 era.

## Mapping to GTNW ids

GTNW ids are the ISO3-style ids of `Shared/Resources/world_countries.json` plus the era-board ids in
`Shared/Models/WorldCountriesDatabase.swift` (CSA, CSK, DDR, YUG, SVN_VN, XKX). Choices follow how GTNW draws the
historical board (`WorldPolitics.swift` rivalries: "DEU stands for Prussia / the German states before 1871, TUR for
the Ottoman Empire, CHN for the Qing"; `PreStateModel.ownerNames`; era templates such as "Italian States",
"German Confederation", "Persia", "Joseon Korea").

| source entity (COW ccode / GW gwno) | GTNW id |
|---|---|
| Prussia / Germany 255, West Germany 260, German Confederation | DEU |
| East Germany 265 | DDR |
| Hanover 240, Bavaria 245, Baden 267, Saxony 269, Württemberg 271, Hesse-Kassel 273, Hesse-Darmstadt 275, Mecklenburg-Schwerin 280 | DEU — or `other:<name>` when Prussia or another German state fights on the other side (1866 Seven Weeks War) |
| Sardinia-Piedmont / Italy 325 | ITA |
| Papal States 327, Two Sicilies 329, Modena 332, Parma 335, Tuscany 337 | ITA — or `other:<name>` when fighting Sardinia/Italy (1860–61) |
| Austrian Empire / Austria-Hungary 300, Austria 305 | AUT |
| Ottoman Empire / Turkey 640 | TUR |
| Russian Empire / USSR / Russia 365 | RUS |
| Qing / Republic of China / PRC 710 | CHN; Taiwan 713 → TWN |
| Serbia/Yugoslavia 345 | SRB before 1918 and from 1992 (FRY), YUG 1918–1991; GW 340 → SRB |
| Czechoslovakia 315 | CSK; Czech Republic 316 → CZE |
| Korea (Joseon/Korean Empire) 730, South Korea 732 | KOR; North Korea 731 → PRK |
| (North) Vietnam 816 | VNM; Republic of Vietnam 817 → SVN_VN |
| Yemen Arab Republic 678, Yemen 679, South Yemen 680 | YEM (GTNW has no separate South Yemen) |
| Zanzibar 511 | TZA |
| Persia/Iran 630 | IRN |
| Kosovo 347 | XKX (the id GTNW's country database uses; the map file calls the shape KOS) |
| Confederate States (COW intra-state side B "Confederacy") | CSA |
| Polish–Lithuanian Commonwealth (curated) | POL |
| Every other ccode/gwno | its ISO3 counterpart (table `CODE` in build.py) |
| Non-member polities named in COW with no ccode that GTNW models as countries: Afghanistan, Persia, China, Korea, Morocco, Tunisia, Ethiopia, Mexico, Bhutan, Burma, Madagascar, Egypt, Siam/Thailand, Oman, Haiti, Santo Domingo, Serbia, Montenegro, Argentina, Bolivia, Uruguay, Peru, Chile, Vietnam, Cambodia, Nepal, the Central American states | their ISO3 id (`NAME_ID`) |
| Everything else without a ccode (tribes, rebel movements, khanates, Boer republics, Barbary regencies, Mysore, Marathas…) | `non-state:<name as in the source>` |

Unmappable states kept as `other:<name>`: Duchy of Warsaw (curated 1812), Gran Colombia, Peru–Bolivian
Confederation, the German and Italian minor states in the wars noted above; `other:Hyderabad` / `other:Tibet` exist
in the code path for GW 751/711 but no war-level record uses them.
