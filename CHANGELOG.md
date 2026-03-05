# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Performance improvements
- Additional features based on community feedback

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
