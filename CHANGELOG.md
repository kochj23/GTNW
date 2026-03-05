# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.4] - 2026-03-05

### Fixed
- **Crash in era-based gameplay** — The nuclear status cleanup loop added in v1.6.3 was recreating `CountryTemplate` objects without preserving their `yearEnd` field. Historical nations (Soviet Union, West Germany, Yugoslavia, etc.) lost their expiry dates and could persist into wrong eras, corrupting game state during AI turn processing. Nuclear status cleanup moved to `GameState.adjustCountriesForEra()` where Country structs can be safely and directly mutated.

### Added
- **Era-appropriate action gating** — `PresidentialAction.eraAvailableYear` property added; `ShadowPresidentMenu` now filters out actions before they historically existed:
  - Air Patrol / Air Strike / Bombardment: 1914 (WWI)
  - Amphibious Assault / Special Forces: 1942 (WWII)
  - No-Fly Zone: 1991 (Gulf War)
  - All nuclear actions: 1945 (Manhattan Project)
  - Satellite Recon / IMINT: 1957 (Sputnik)
  - SIGINT / Code Breaking: 1940
  - Cyber Attack / Hack / Disrupt Comms: 1990
  - UN Condemnation: 1945; Arms Control Treaties: 1960
  - Asset Freezing: 1945; Oil Embargo: 1900; Olympic Boycott: 1896
- **Era-scaled economic amounts** — `GameState.eraDiplomacyAmount` and `eraDiplomacyAmountLabel` provide historically appropriate values ($50K in 1790s → $5B modern). Economic Diplomacy button label and action now use era-scaled amounts.
- **Context-aware diplomatic messages** — `SafeDiplomacyService.processTurn` now checks actual game state before generating messages:
  - Countries at war with player send war-appropriate messages
  - Hostile countries reference specific grievances (player's wars, sanctions)
  - Allied countries send supportive/cooperative messages
  - Neutral countries send formal diplomatic contact requests
  - All messages use period-appropriate language (pre-modern vs modern tone)
  - Random unprovoked "provocative actions" warnings no longer sent when player is peaceful

*Released by Jordan Koch*


## [1.6.3] - 2026-03-05

### Fixed
- **Soviet Union appearing in the mid-1800s** — Russia is now correctly labeled by era:
  - Pre-1917: **Russian Empire** (Tsarist autocracy, non-aligned, 0 nukes, era-scaled GDP/military)
  - 1917–1921: **Russia** (Revolutionary/Civil War period, unstable)
  - 1922–1991: **Soviet Union** (communist, eastern bloc, nuclear from 1949)
- **Soviet Union flag showing US flag** — `ussr()` had `flag:"🇺🇸"` by mistake; fixed to `🇷🇺`
- **South Korea and Saudi Arabia existing in the 1840s** — Countries now filtered out before their founding dates:
  Saudi Arabia (1932), South Korea (1945), North Korea (1948), Pakistan (1947), Jordan (1946), Singapore (1965), UAE/Qatar/Bahrain/Kuwait (1971), Timor-Leste (2002), Kosovo (2008)
- **African nations appearing before independence** — ~44 post-colonial African states removed from pre-1960 games
- **Anachronistic nuclear status** — Nuclear capability now cleared for all countries before their first confirmed test (Saudi Arabia `.suspected` removed pre-2000; Iran `.developing` removed pre-1985)
- **"$5B economic aid" request in the 1840s** — `SafeDiplomacyService` diplomatic messages are now era-appropriate: pre-modern presidents see period-correct diplomatic language ("We propose a formal treaty of friendship and commerce") instead of modern financial references
- **`primaryThreatLabel`** — Now shows historically accurate threat framing per era: "European Powers" (pre-1815), "Civil War" (1861-1865), "Rising Fascism" (1922-1939), "Axis Powers" (1939-1945), "Soviet Union" (1945-1991), etc.

*Released by Jordan Koch*

## [1.6.2] - 2026-03-05

### Fixed
- **Pre-nuclear era atomic bombs** — `adjustCountriesForEra` was using `year <= 1945` for the USA nuclear case, giving ALL presidents before 1945 nine atomic bombs. Van Buren (1837), Lincoln (1861), FDR (1933) etc. now correctly have 0 nuclear weapons. The condition is now `year == 1945` for the initial 9 bombs, with a new `year < 1945` branch giving era-scaled conventional military and historically appropriate GDP ($0.01T in 1789 → $1.5T in 1944).
- **All 195 countries defaulting to maximum aggression (crash cause)** — `CountryTemplate.toCountry()` was not passing `aggressionLevel` to `Country.init`, so every country got the default value of 50 (the maximum-aggressive tier). With 195 AI countries all at max aggression, ~78 tried to declare war simultaneously every turn, overwhelming state processing and causing `EXC_BREAKPOINT` crashes. Fixed by passing `aggressionLevel` from each template.
- **Island nations with population=0** — `Int(0.01)` truncates to 0 for nations with <1M people (Nauru, Vatican, Tuvalu, etc.), potentially causing divide-by-zero. Fixed with `max(1, Int(populationMillions))`.

*Released by Jordan Koch*

### Planned
- Supreme Court nominations mechanic
- Midterm elections / political calendar
- Economic recession/boom cycles
- Congressional approval gates for war declarations

## [1.6.0] - 2026-03-05

### Added — All 47 Presidents + Complete Historical Coverage
- **32 pre-nuclear administrations** (Washington 1789 → FDR 1945) wired in and fully playable
- **HistoricalCrises_PreNuclear.swift** + **HistoricalCrises.swift** added to build target
- **20 missing crisis functions** written for lesser-known 19th century presidents (Van Buren Panic of 1837, Harrison's 31-day presidency, Lincoln assassination choice, etc.)
- All 47 presidents sorted chronologically in the administration picker

### Added — All 195 UN Member States + Territories
- **WorldCountriesDatabase.swift** fully rewritten and wired into CountryFactory
- All 54 African nations (was ~19), all Pacific island states (Solomon Islands, Samoa, Tonga, etc.)
- All Caribbean island states, all Balkan nations, complete Middle East, Central Asian republics
- Key territories: Taiwan, Kosovo, Hong Kong
- Every country has accurate coordinates, capital, GDP, population, military stats

### Added — Era-Accurate Country Sets
- `countriesForYear(year)` returns historically correct countries: USSR pre-1991, East/West Germany pre-1990, North/South Vietnam pre-1975, Yugoslavia pre-1992, Czechoslovakia pre-1993
- Countries absent before independence (Israel pre-1948, Bangladesh pre-1971)

### Added — Complete Historical Cabinets (~80 members)
- Every administration Truman → Trump II: VP, SecState, SecDef, CIA Director, NSA, SecTreasury
- Era-specific roles: DNI (Bush Jr.+), DHS Secretary (Bush Jr.+), UN Ambassador (Reagan)
- All with bios, personality stats, loyalty/expertise/hawkishness, and era-appropriate quotes
- Notable additions: Alben Barkley, McGeorge Bundy, McGeorge Bundy, Zbigniew Brzezinski, Brent Scowcroft, Jeane Kirkpatrick, George Tenet, John Bolton, Gina Haspel, Avril Haines, and 70+ more

### Added — NATO / Warsaw Pact Collective Defense
- `MilitaryAllianceSystem.swift` with era-accurate membership (NATO 1949 → Sweden 2024, Warsaw Pact 1955–1991)
- Article 5 triggers automatically when any alliance member is attacked
- DEFCON raises when collective defense mobilizes
- Warsaw Pact equivalent mechanic

### Added — Nuclear Arms Race Dynamics
- `ArmsRaceEngine` runs every turn — if one power leads by 40%+, lagging side builds
- Era-accurate build rates: 20–80/turn (1950s) → 200–600/turn (1970s MIRV) → static post-Cold War
- SALT I, START I, New START treaty caps reduce US/Russia arsenals naturally

### Added — WOPR Secret Ending
- `WOPRSecretEndingView`: full animated terminal sequence (38 scripted lines + timing)
- WOPR simulates 2,005 war scenarios, all WINNER: NONE
- Typewriter animation, era-accurate terminal colors, score reveal

### Added — Presidential Powers
- **Executive Orders** (10 types): bypass Congress, instant unilateral action
- **Presidential Pardons** (6 types): from whistleblower pardons to diplomatic gestures
- **Presidential Address** (6 types): State of the Union, Oval Office, Warning to Adversary, etc. with cooldowns
- **Cabinet Firings**: dismiss any non-President advisor with cascading loyalty/approval effects

### Fixed — Historical Accuracy
- Crisis advisor names now use role titles (Secretary of State, CIA Director) that resolve to the actual person for the active era — no more Marco Rubio advising Truman
- Nuclear arsenals set to historically accurate values per era (0 nukes for USSR before 1949)
- `Country.name` changed `let` → `var` for era-based renaming (Soviet Union, East Germany, etc.)
- Era-aware delivery system labels: "Atom Bombs" (pre-1957), "Missiles" (1957–59), "ICBMs" (1960+)
- Polaris/Poseidon/SLBM label progression for submarine-launched missiles
- Era-appropriate news outlets (no CNN before 1980, no Fox before 1996, no RT before 2005)
- `eraDoctrine`, `primaryThreatLabel`, `intelMethodLabel` computed properties on GameState

### Fixed — Build Health
- Resolved 331 compile errors from incomplete data model refactor
- Added `GameStats` tracking (warsStarted, nukesLaunched, presidentsPlayed, etc.) to GameState
- Fixed duplicate type definitions: CrisisSeverity → DynamicSeverity, GameEvent → LiveNewsEvent, etc.
- Removed app-layer AI types (AnalysisUnified, VoiceUnified) from Shared compilation batch
- Moved SentimentResult/Sentiment to AppSettings.swift (Shared layer)

*Released by Jordan Koch*

## [1.3.3] - 2026-03-05

### Added
- **Complete historical cabinets for all 15 presidencies (Truman through Biden)** — ~80 new cabinet members added with full stats, accurate bios, era-appropriate quotes, and distinct personalities:

  | Administration | New Members Added |
  |---|---|
  | Truman | Alben Barkley (VP), Gen. Walter Bedell Smith (CIA), John Snyder (Treasury), Tom Clark (AG) |
  | Eisenhower | Richard Nixon (VP), Charles Wilson (SecDef), Robert Cutler (NSA), George Humphrey (Treasury) |
  | Kennedy | LBJ (VP), John McCone (CIA), McGeorge Bundy (NSA), Douglas Dillon (Treasury) |
  | Johnson | Hubert Humphrey (VP), Dean Rusk (SecState), Richard Helms (CIA), Walt Rostow (NSA), Henry Fowler (Treasury) |
  | Nixon | Spiro Agnew (VP), Melvin Laird (SecDef), Richard Helms (CIA), John Connally (Treasury) |
  | Ford | Nelson Rockefeller (VP), Donald Rumsfeld (SecDef), George H.W. Bush (CIA), Brent Scowcroft (NSA), William Simon (Treasury) |
  | Carter | Walter Mondale (VP), Harold Brown (SecDef), Stansfield Turner (CIA), Michael Blumenthal (Treasury) |
  | Reagan | George H.W. Bush (VP), Colin Powell (NSA), James Baker (Treasury), Jeane Kirkpatrick (UN) |
  | Bush Sr. | Dan Quayle (VP), William Webster (CIA), Brent Scowcroft (NSA), Nicholas Brady (Treasury) |
  | Clinton | Al Gore (VP), William Cohen (SecDef), George Tenet (CIA), Sandy Berger (NSA), Robert Rubin (Treasury) |
  | Bush Jr. | George Tenet (CIA), Tom Ridge (DHS), John Negroponte (DNI), Hank Paulson (Treasury) |
  | Obama | John Brennan (CIA), Tom Donilon (NSA), Timothy Geithner (Treasury), James Clapper (DNI) |
  | Trump First | Mike Pence (VP), John Bolton (NSA), Steven Mnuchin (Treasury), Gina Haspel (CIA) |
  | Biden | Kamala Harris (VP), William Burns (CIA), Janet Yellen (Treasury), Avril Haines (DNI) |

- Each advisor has unique: `hawkishness`, `interventionism`, `fiscalConservatism`, `expertise`, `loyalty`, `publicSupport`, era-accurate quote, and advice specialty areas

*Released by Jordan Koch*

## [1.3.2] - 2026-03-05

### Fixed
- **Historical anachronism: wrong advisors for era** — Crisis event options hardcoded Trump cabinet names (Marco Rubio, Pete Hegseth, Tulsi Gabbard, etc.) regardless of which administration was being played. All 59 advisor recommendation strings now use role titles (Secretary of State, Secretary of Defense, CIA Director, etc.) which resolve dynamically to the correct person for the active era. Playing as Truman shows Dean Acheson advising, not Marco Rubio.
- **Historical anachronism: wrong country data for era** — Selecting a historical administration (e.g. Truman 1945) now adjusts all country data to match that year's geopolitical reality:
  - Soviet nuclear arsenal set to 0 before 1949 (first test), then historically accurate counts through the Cold War
  - USSR named "Soviet Union" for 1945-1991 eras
  - UK, France, China, India, Pakistan, North Korea, Israel all get zero nukes until their actual first test date
  - US nuclear arsenal scaled to historical levels (9 in 1945 → ~1,169 by end of Truman in 1953)
  - In-game year (`currentYear`) now anchors to the era start year, not a hardcoded 1945
- **Country.name** changed from `let` to `var` to allow era-based renaming

*Released by Jordan Koch*

## [1.3.1] - 2026-03-05

### Fixed
- Resolved 331 compile errors caused by an incomplete data model refactor
- Fixed all `Country` property references: `relations` → `diplomaticRelations`, `isPlayer` → `isPlayerControlled`, `hasNuclearWeapons` → `nuclearWarheads > 0`; removed stale `personality` and `memory` references
- Fixed `GameState` missing stats properties: added `warsStarted`, `nukesLaunched`, `presidentsPlayed`, `crisisesCompleted`, `totalWarheadsLaunched`, `victoryType`, and 14 others needed by `AchievementEngine`
- Added `GameState` convenience computed properties: `gameEnded`, `turnNumber`, `recentEvents`, `currentYear`
- Resolved 5 duplicate type definitions causing ambiguous-type errors: `CrisisSeverity` → `DynamicSeverity`, `DynamicCrisis`, `GameEvent` → `LiveNewsEvent`, `NewsEvent` → `LiveNewsEvent`, `ActionCategory` → `AIActionCategory`
- Fixed Xcode compilation batch isolation: removed `ImageGenerationUnified`, `VoiceUnified`, `AnalysisUnified`, `SecurityUnified` dependencies from all `Shared/` files (these compile in a separate batch from app-level files)
- Moved `SentimentResult` and `Sentiment` types to `AppSettings.swift` (Shared layer) so they are available to both compilation batches
- Fixed `DefconLevel` enum vs `Int` comparison errors (added `.rawValue` where needed)
- Fixed `War` struct usage: `War.involves()` → inline expressions, `War.description` → inline string
- Fixed `CyberAttackType` case names and `CyberOperation` API mismatches
- Fixed `CrisisOption` initializer signature (`title:outcome:` → `title:description:consequences:`)
- Fixed type-checker timeout in `DynamicCrisisView` by extracting sub-views

### Security
- No security-sensitive changes in this release

*Released by Jordan Koch*

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/GTNW/releases).*

## [1.3.4] - 2026-03-05

### Fixed
- **Era-accurate delivery system labels** — "ICBMs" is now replaced with the historically correct term based on the active administration's era:
  - **1945–1956** (Truman, Eisenhower early): **"Atom Bombs"** — nuclear gravity bombs delivered by B-29/B-47, no ballistic missiles existed yet
  - **1957–1959** (Eisenhower late): **"Missiles"** — early Atlas/R-7 ballistic missiles just entering service
  - **1960+**: **"ICBMs"** — Minuteman and beyond, the familiar term
- **SLBM label also updated**: "Polaris Missiles" (1960–1971), "Poseidon Missiles" (1972–1989), "SLBMs" (modern)
- **All display locations updated**: country stat panel, world map info popup, text command interface, crisis event descriptions, weapons malfunction event, coup crisis, espionage crisis, GameEngine build log

*Released by Jordan Koch*

## [1.4.0] - 2026-03-05

### Added

**All 195 UN Member States + Key Territories**
Complete `WorldCountriesDatabase.swift` (was a stub, now fully integrated):
- **54 African nations** — all UN members including previously missing: Mozambique, Zambia, Malawi, Rwanda, Burundi, Somalia, Eritrea, Djibouti, CAR, Chad, Gabon, Congo, Equatorial Guinea, São Tomé, South Sudan, Guinea-Bissau, Sierra Leone, Liberia, Gambia, Cape Verde, Mauritania, Togo, Benin, Comoros, Seychelles, Lesotho, Eswatini, Botswana, Namibia, Mauritius
- **14 Pacific/Oceania nations** — Solomon Islands, Vanuatu, Samoa, Tonga, Kiribati, Micronesia, Marshall Islands, Palau, Nauru, Tuvalu
- **All Caribbean island states** — Trinidad & Tobago, Barbados, St. Lucia, St. Vincent, Grenada, Antigua, St. Kitts, Dominica, Bahamas, Belize
- **All Balkan states** — Serbia, Croatia, Bosnia, Slovenia, North Macedonia, Montenegro, Albania
- **Central Asian + Caucasus** — Kazakhstan, Uzbekistan, Turkmenistan, Kyrgyzstan, Tajikistan, Georgia, Armenia, Azerbaijan  
- **All Middle East states** — UAE, Iraq, Syria, Jordan, Lebanon, Yemen, Oman, Kuwait, Qatar, Bahrain, Palestine
- Complete Western/Eastern Europe, all South & Southeast Asian nations
- Key territories: Kosovo, Taiwan, Hong Kong

**Era-Accurate Historical Country Sets (`countriesForYear()`)**
- East/West Germany split (pre-1990)
- North/South Vietnam split (pre-1975)
- Yugoslavia unified (pre-1992)
- Czechoslovakia unified (pre-1993)
- USSR replaces Russia + all post-Soviet states (pre-1991)
- Israel not present before 1948
- Bangladesh not present before 1971

**Era-Gated Technology Flags on `GameState`**
Available to views and AI logic:
- `cyberWarfareAvailable` — true from 1990
- `satelliteSurveillanceAvailable` — true from 1957
- `sdiAvailable` — true from 1983
- `precisionMunitionsAvailable` — true from 1970
- `droneStrikesAvailable` — true from 2001
- `submarineLaunchAvailable` — true from 1960

**Era-Appropriate News Outlets**
`availableNewsOutlets` returns outlets that actually existed:
- 1945+: AP, Reuters
- 1927+: BBC; 1943+: TASS; 1950+: Voice of America
- 1980+: CNN; 1996+: FOX News, Al Jazeera; 2005+: RT

**Era Flavor Text**
- `eraDoctrine` — key foreign policy doctrine per administration (Containment, Massive Retaliation, Détente, etc.)
- `primaryThreatLabel` — Soviet Union / Terrorism / China+Russia
- `intelMethodLabel` — HUMINT → Satellite → SIGINT/Cyber

*Released by Jordan Koch*
