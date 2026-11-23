# GTNW in WebAssembly (phase 1: the engine; phase 2: the screens)

Goal: the full GTNW engine runs in a browser, so the web port (NovaGames "GTNW Lite") can become the full game's
web and Windows front end. Phase 1 (this document) is the engine only: a Swift package that builds the engine from
the app's own sources, a WebAssembly build of it with a JSON bridge, proof that it plays the same game as the app, and
a harness behind a flag in GTNW Lite. Phase 2 is the UI (the screen list at the end).

## Layout

| Piece | Where | What |
|---|---|---|
| `GTNWCore` | `Package.swift` (target path `Shared/`) | The engine, compiled from the same files the Xcode app compiles. No copies, no moves. |
| Core-only support | `Shared/CoreSupport/` | Stand-ins for app-only types (`CoreShims.swift`), the job pump, the bridge, the golden games. Compiled only when `GTNW_CORE` is defined; the Xcode project does not see the folder. |
| Platform services | `Shared/Engine/EnginePlatform.swift` | `GameResources` (bundled data) and `GameScheduler` (deferred work). Shared by the app and the core. |
| `CGTNWExecutor` | `Wasm/Sources/CGTNWExecutor` | The Swift runtime's enqueue hooks, declared for Swift. |
| `GTNWWasm` | `Wasm/Sources/GTNWWasm` | The WASI reactor: four C-ABI exports around the bridge. |
| `gtnw-golden` | `Wasm/Sources/gtnw-golden` | Native CLI: plays the golden games, or times end turns (`--bench`). |
| JS loader | `Wasm/js/gtnw.mjs` | Loads the .wasm in a browser or Node, with a minimal WASI shim. Lite has a typed copy, `src/wasm/loader.ts`. |
| Tests | `Wasm/Tests/GTNWCoreTests`, `Wasm/parity.sh` | Package tests (`swift test`) and the parity check against the app's fixtures. |

Build:

```sh
swift build --product gtnw-golden && swift test        # native (Xcode's toolchain is fine)
Wasm/build.sh                                           # WebAssembly → Wasm/dist/gtnw.wasm   (OPT=1: + gtnw.opt.wasm)
Wasm/parity.sh [fixtures dir]                           # native + WebAssembly vs. the app's golden fixtures
```

The toolchain is the swift.org 6.4.2 release plus the matching Swift SDK for WebAssembly. Both are installed under
`/Volumes/Data` (`Wasm/build.sh` has the install commands); binaryen (`wasm-opt`) is in `/Volumes/Data/tools/binaryen`.

## Step 1: platform audit

Every platform dependency in `Shared/`, and where it ended up:

| Dependency | Where it is used | In the core |
|---|---|---|
| SwiftUI | every view; `Color` computed properties on models (Country, Advisor, DefconLevel, CrisisSeverity, NewsSeverity, EventLog, ShadowPresidentActions); `ObservableObject`/`@Published` on GameEngine and managers | Imports and `Color` properties sit behind `#if !GTNW_CORE`. No model *stores* a `Color` (every color is computed from data), so no RGBA type was needed. `ObservableObject`/`@Published` are stand-ins (`CoreShims.swift`). |
| AppKit / UIKit | views, `Motion` (Reduce Motion), NSWorkspace | App-only. |
| Combine | `GameEngine.cancellables` | Guarded. |
| os (`Logger`) | `Log.swift`, `GameOrder.swift` | `Logger` stand-in. Messages go to `CoreLog.sink`, which defaults to nil (dropped). |
| Dispatch | `DispatchQueue.main.asyncAfter` in 5 engine sites (retaliation, auto end turn, watch cues, return to title) | Now `GameScheduler.after`. The app keeps Dispatch; the core runs the work on `CoreRunLoop`'s virtual clock. |
| Swift concurrency | `endTurn` resolves the computer's moves in `Task { @MainActor in … }` | Runs to completion inside each bridge call (`JobPump`, below). |
| `Timer` | the crisis response countdown (CrisisEvents) | Guarded: there is no wall clock in the core, so a front end counts down itself. |
| URLSession / Network / NovaAIKit | AI brains (`AIBrain`, `AppAI`, `Retry.http`), live commentary, the world brief, the games DB | Guarded. In the core every country uses the rule-based brain (`brainSource` returns nil), `GameAI` is a stand-in with an optional `CoreAI.provider`, and the world brief has no provider. |
| Security / Keychain | `KeychainGameStoreCredentials` | Guarded. The core has no remote store (`GameStoreService.remote` is nil). |
| CryptoKit | SHA-256 for save checksums (`GameStore`, `GameStoreRecords`) | `SHA256` stand-in (FIPS 180-4, tested against the standard vectors). |
| AVFoundation | voices, Shadow pack audio, `AudioGate` | Guarded. `ShadowPack` is a stand-in whose `play` goes to `CoreAudio.sink`. |
| CoreGraphics | `VectorWorldMap` paths and bounds | The map's data half (outline ids, owners by year, areas from the rings) is core; drawing is guarded. |
| PostgreSQL | `GameStoreService` → games DB (remote saves, leaderboard, play history) | App-only (stand-in `GameStoreService` with no remote). |
| UserDefaults | settings, key bindings, Nova commentary memory | Settings and key bindings are app-only. Commentary keeps its in-memory suite. |
| FileManager / file I/O | `SaveManager` (local saves), `Legends.export` | Local saves write non-atomically in the core (WASI has no atomic rename); the bridge's `save()`/`load()` hand JSON to the host instead. `Legends.export` returns nil. |
| `Bundle.main` | data files (nation cabinets and characters, map outlines, war base rates), `Log.subsystem` | Through `GameResources` with a host-supplied provider (`GTNWBridge.setResource`). `Bundle.main` traps on WASI. |
| DateFormatter | `GameCalendar.format` ("Jan 20, 1962") | The core formats by hand: WASI Foundation has no locale data and prints "M01 20, 1962". |
| `Date()` / randomness | the game draws everything from the seeded `GameRNG` (state saved with the game). `Date()` is only used for log timestamps | No change. A game is a function of seed and orders. |

### 32-bit WebAssembly

`Int` is 32 bits on wasm32. Two things change:

- **Random draws.** The standard library's `Int.random(in:using:)`, `randomElement(using:)` and `shuffled(using:)` draw
  at the width of `Int`, so on wasm32 they consume the generator differently and the game diverges on turn one. The
  core overloads them for `GameRNG` to draw at 64 bits, which is what the app does on arm64/x86_64.
  `testRNGOverloadsMatchStandardLibraryOn64Bit` checks that the overloads equal the standard library on a 64-bit host.
- **Dollars.** Treasuries, GDP, military budgets, action costs, weapons programs, cyber costs and era aid amounts
  passed $2.1B, so they are `Int64` now (`Country.treasury/annualGDP/militaryBudget`,
  `PresidentialAction.cost`, `ActionResult.economicImpact`, `ProhibitedWeapon.developmentCost`, cyber costs,
  `GameState.eraDiplomacyAmount`, the SDI and economic-diplomacy parameters). `economicDiplomacy(amount: Int)` stays
  as an overload, so callers are unchanged. The alien invasion's `economicImpact` was -500,000,000,000 in a field that
  is in billions everywhere else; it is -500 now.

The golden games run without an overflow trap on wasm32. Overflow is still possible in paths they don't reach; a
trap shows up as a `RuntimeError: unreachable` from the bridge call, so phase 2 should run a long soak game in Wasm.

## Step 2: the core boundary

| | Files | Lines |
|---|---|---|
| **In the core**: `Engine/` (incl. `Shadow/`), `Models/`, `CoreSupport/`, `Events/EmergencyCatalog`, `Events/WorldWatch`, `AI/AIOutputSanitizer`, `Design/Accessibility` (A11y text), `Storage/GameStore`, `GameStoreRecords`, `InMemoryGameStore`, `PlayHistory`, `Views/SituationRoom/VectorWorldMap` (data half) | 91 | 41,900 |
| **Out**: views, design system, app shell, `NovaAPIServer`, AI clients (`AppAI`, `AdaptiveOpponentEngine`, `TerminalAdvisor`), audio and Shadow pack, cinematics, achievements, the 3.x side features (`Intelligence/`, `Diplomacy/`, `Analysis/`, `Warfare/`, `Economics/`, `Media/`, `Visualization/`, `Events/DynamicCrisisGenerator`), `GameStoreService` and its views, `Models/AppSettings`, `KeyBindings`, `ModernDesignSystem`, `WidgetSync` | 65 | 27,098 |

The "out" figure includes six dead files (1,430 lines) that no Xcode target compiles: `AIPersonalityEngine`,
`AIWarRoom`, `NarrativeEngine`, `NuclearClubProgression`, `WhatIfSimulator`, `WorldCountriesDatabase_Complete`.

The core needs no file listing when someone adds a view or an engine file: `Package.swift` lists the core folders and
walks `Shared/` for the rest. A new engine file only needs to stay free of UI imports (or guard them).

Changes to existing app files are small: 38 files, +230 / −57 lines (plus the new `EnginePlatform.swift`), almost all `#if !GTNW_CORE` guards. The few real
changes are the platform services, `Int64` money, `Advisor.roleKey(forTitle:)` (moved from ShadowPack so the
core keeps it), and `MapCountryShape.area`. The app plays exactly as before. The app's own golden export, rerun with
these changes, is byte-identical to the fixtures it wrote before them.

**Do the Xcode targets consume GTNWCore?** Not in phase 1. That would mean a `public` on every engine type and
member the views touch (thousands of declarations across 91 files), and it would collide with the command-box work
landing in the same files. Both builds compile the same files instead. The SwiftPM build is the check that the
boundary holds: an app-only import in a core file breaks `swift build`. Revisit once the UI is no longer in the same
module.

### Running the engine single-threaded

`endTurn` starts the computer's moves in a main-actor Task and returns. The app's run loop finishes the turn; a
WebAssembly reactor has no run loop, and a bridge call has to return a finished turn. `JobPump`
(`Shared/CoreSupport/JobPump.swift`) runs everything to completion inside each bridge call:

- global jobs: the runtime's `swift_task_enqueueGlobal*_hook`s (as JavaScriptKit does), run in arrival order;
- delayed jobs and `GameScheduler` work: `CoreRunLoop`, a virtual clock (earliest first, then FIFO), so a turn takes no
  wall-clock time and plays the same way every run;
- main-actor jobs: in Swift 6.4 these skip `swift_task_enqueueMainExecutor_hook` on both runtimes. On WASI the pump
  drains the cooperative main executor with `MainActor.executor.runUntil` (SPI `ExperimentalCustomExecutors`; switch
  to the public API when it lands). Natively (the CLI and the tests) it spins the main run loop while
  `isProcessingAITurn`, as the app's own tests do.

### Golden rules

The fixtures come from the app's test run, where `GameStoreService.isTestOrSmokeRun` turns off chemical threats,
covert-agent AI, the land market, the dispatch system and outbreak AI. The bridge's `rules: "golden"` sets the same
switches (`Rules.apply`); `rules: "full"` (the default) plays with everything on, like the shipping app.

## Step 3: the WebAssembly build

`Wasm/build.sh` builds `GTNWWasm` as a WASI reactor (`-mexec-model=reactor`). Its exports:

| Export | |
|---|---|
| `_initialize()` | once, before anything else |
| `gtnw_alloc(n) → ptr`, `gtnw_free(ptr)` | a request buffer |
| `gtnw_call(op, ptr, n) → len` | one bridge call. The UTF-8 JSON reply is at `gtnw_reply_ptr()`. |

| op | call | request → reply |
|---|---|---|
| 1 | `newGame` | `{"player":"USA","year":1962,"seed":"7aa","difficulty":"Normal","turnLength":"month","rules":"full"}` → `{ok, events, state}` |
| 1 | | also `{"scenario":"cuba1962"}` or `{"sitting":"sit_cuba"}` (either overrides `year`) |
| 2 | `act` | `{"action":"Send Ambassador","target":"FRA"}` and/or `{"crisisOption":0}` → `{ok, events, state}` |
| 2 | | `{"action":…,"target":…,"advised":true,"preset":"standard"}` plays it the app's Advise → Order way (cabinet sizing, default warhead) → `{ok, events, state, report}`; `"decline":true` declines it; `{"advisor":"mcnamara","recommendation":"accept"\|"reject"\|"alternative"}` answers an advisor |
| 2 | | verbs (`Shared/CoreSupport/Verbs/`): `{"verb":"fireAdvisor","id":…}` fires from the briefing (`departAdvisor`); `{"verb":"dismissAdvisor","id":…}` dismisses from the cabinet view (`fireAdvisor`); `{"verb":"executeCommand","orders":[<GameOrder>…],"source":"parser"\|"model"}` carries out a confirmed command-box plan (`executeCommand`, every order checked again) → `{ok, events, state, report:{title, lines, success, command:{carried, refused, notReached, lines}}}` |
| 3 | `endTurn` | → `{ok, events, state}`, with the computer's moves resolved |
| 4 | `snapshot` | → `{ok, state}` |
| 5 | `save` | → the app's save format (`SaveCodec`: the whole GameState, RNG included) |
| 6 | `load` | a save → `{ok, state}` (validated by `SaveCodec.decode`, like every load in the app) |
| 7 | `setResource` | `"<name>\n" + bytes`: nation_cabinets, nation_characters, world_countries, base_rates, open_wars |
| 8 | `golden` | `{"year":1962,"seed":"7aa","turns":12}` → one golden game in the fixture format |
| 9 | `goldenVectors` | → the manifest's RNG vectors |
| 10 | `query` | `{"q":"country","id":"FRA"}` → `{ok, result}`: a read-only question (below) |

### Queries (phase 2)

`query` never changes the game and never draws from the RNG (`QueryTests` checks a game played with and without
queries is identical). Each query is one file in `Shared/CoreSupport/Queries/` conforming to `BridgeQuery`
(`name`, `Args`, `Result`, `run`) and one line in `QueryRegistry.all` (alphabetical), so screens add queries without
touching each other's code. GTNW Lite's typed mirror is `games/gtnw-lite/src/full/bridge/types.ts` in NovaGames.

| query | args | answers |
|---|---|---|
| `actions` | `target?` | the escalation ladder (rungs, lead advisor) and every action available this era with cost, risk, odds against the target, why it can't be ordered, whether it is major and how it is sized |
| `administrations` | | the U.S. administrations (`PresidentialAdministrations`) |
| `advice` | `action, target` | the cabinet's advice (advisor, stance, reason, odds), the three-line warnings for major actions, the default sizing and warhead |
| `advisors` | `country?` | the advisor rail in order: status, loyalty, hawkishness, current advice, recommendation, briefing; the profile (expertise, influence, public support, interventionism, fiscal conservatism, department, bio, advice areas); `posts`: the seven Situation Room posts with holder, title, briefing and former holders |
| `aid` | `id` | foreign aid to one country (AidSheet): money left this year, need and sent per kind of aid |
| `airCampaign` | `target` | the strategic air campaign (AirCampaignSheet): why it can't be ordered, the two aims |
| `arsenal` | `target?, action?, troops?, aircraft?, warheads?` | the era's weapons under each military order with legal status and treaty (ArsenalLine), and the force-sizing panel for one offensive (AttackSizingPanel) with the cabinet's warnings |
| `budget` | `draft?` | the federal budget (BudgetView): sliders with limits, the projection for a draft, where the money goes, the era's reset |
| `coalitions` | `target` | a coalition against a country (CoalitionSheet): members and each candidate's odds of joining |
| `command` | `text` \| `intent` \| `model` \| `schema` | the command box (3.34.0): `CommandParser` then `CommandPlanner`, as the app runs them → `plan` (card + `GameOrder`s), `clarify` (choices carrying their intent), `answer`, `rejected`, or `unparsed` (ask a model); `model` is a translation in the app's `ModelCommand` shape, checked against the closed lists before planning; `schema` returns the lists |
| `country` | `id` | the dossier: a nation (profile, economy, intelligence estimates for foreign military and warheads, anxieties, aid need, factbook) or a colony / pre-state / unclaimed land |
| `crisis` | | the waiting crisis as DetailedCrisisView shows it: severity label, brief, epigraph, time limit, decisions waiting behind it, options with the recommending advisor's name and odds |
| `fleets` | `target, fleet?, mission?, preset?` | fleet orders (FleetOrderSheet): the era's fleets, missions, commitments, the read-out, why not, warnings, fleets out |
| `fronts` | | the War Room: every front with troop and damage assessments, momentum, the orders it allows, surrender odds, the War Powers clock, the operations log |
| `groupAction` | `pick, region?, ids?, saved?, kind, amount?, garrison?, split?, rate?` | a group action's per-nation plan and total (GroupActionSheet) |
| `manpower` | | troops, the draft in force, and the two call-ups with cost and training (ManpowerSheet) |
| `map` | | the map for the game's year: every outline's kind (nation, territory, colony, indigenous, unclaimed) with owner and what clicking selects, dots for nations without outlines and pre-state islands, fleets, live map flashes |
| `messages` | | the diplomatic inbox with the replies each message offers (DiplomaticMessagesView) |
| `nations` | `year` | the nations that exist in a year (1789–2100) for the new-game picker |
| `news` | | the news wire (`ShadowState.ticker`, saved with the game) with dates and severities, and the scenario's epigraph |
| `peace` | | the four peace paths with progress, the conditions, the wars elsewhere to broker (PeaceSheet) |
| `resources` | | territory income, extraction rates and levies (ResourcesSheet) |
| `scenarios` | | the historical scenarios and the sittings (short scored challenges) |
| `settlements` | | surrenders waiting for the President's terms (SettlementSheet): annex or a post-war government, each with the cabinet's take |
| `topbar` | | the Situation Room top bar: leader, date, turn, popularity and election line, DEFCON (ALERT before 1959), peace index, impeachment, pending offers, scenario / sitting |
| `treaties` | | treaty offers on the table (TreatyOffersSheet) |
| `warRecord` | | the Records sheet's WAR, FOG and LEGENDS panels: deliberations and stated reasons, the silences and intelligence age, the debrief and the chronicle |


### Verbs (phase 2)

A sheet's button is an order through `act`: `{"verb":"<name>", ...its fields}`. Each verb is one file in
`Shared/CoreSupport/Verbs/` conforming to `BridgeVerb` and one line in `VerbRegistry.all` (alphabetical), and calls
the same GameEngine method the app's button calls, so a game played through verbs is the app's game (it may draw
from the RNG exactly as the button does). A verb that can't be carried out answers `{"ok":false,"error":...}` with
the app's reason and leaves the game unchanged; some return a `report` (the War Room's notices, an aid reaction,
a sized order's ActionResultSheet). `WarRoomTests` checks the registry, the read-only queries and that a game played
through verbs is a function of seed and orders.

| verb | fields | the app's button |
|---|---|---|
| `answerMessage` | `id, response` | a reply on a diplomatic message (accept, decline, counter, nonAggression, apology, standFirm, trade, mediation) |
| `answerTreaty` | `id, accept` | TreatyOffersSheet ACCEPT / DECLINE |
| `brokerCeasefire` | `front` | War Room BROKER CEASEFIRE (one action) |
| `brokerPeace` | `a, b` | PeaceSheet BROKER |
| `callUp`, `standDown` | `kind` (draft, mobilization) | ManpowerSheet CALL / STAND DOWN |
| `collectLevy`, `setExtraction` | `id`, `rate` | ResourcesSheet |
| `commitTroops` | `front, side, thousands` (negative recalls) | War Room SEND TO / RECALL |
| `demandSurrender`, `sueForPeace` | `front` | War Room |
| `enactBudget` | `draft` | BudgetView ENACT BUDGET |
| `groupAction`, `saveGroup` | the `groupAction` query's fields; `name, ids` | GroupActionSheet CONFIRM / SAVE GROUP |
| `orderFleet`, `recallFleet` | `fleet, target, mission, preset`; `id` | FleetOrderSheet |
| `requestCoalition` | `target` | CoalitionSheet ASK |
| `sendAid` | `target, humanitarian?, economic?, intelligence?, military?, nuclear?` | AidSheet SEND AID |
| `settle` | `id, choice, name?` | SettlementSheet ANNEX / INSTALL |
| `sizedOrder` | `action, target, troops?, aircraft?, warheads?` | an offensive at the size set on AttackSizingPanel |
| `strategicBombing` | `target, aim` | AirCampaignSheet ORDER THE RAID |

`state` carries the golden snapshot's fields (turn, date, DEFCON, radiation, casualties, popularity, game over, RNG
state, wars, and per nation: warheads, military, stability, approval, destroyed, at war with, relation to the
player), plus what a front end shows: name, flag, alignment, GDP, population, actions remaining, game-over reason
and the waiting crisis with its options. `events` holds the log lines and ticker items new since the last call.

The imports are 34 WASI preview-1 functions. The engine really uses clock, random and stdout; the loader shims those
and answers ENOSYS/EBADF for the rest (no files, no preopens). It also supplies argv `["gtnw"]`.

Sizes (release, Swift 6.4.2, Foundation statically linked):

| | raw | brotli -q 11 |
|---|---|---|
| `gtnw.wasm` | 72.7 MB (72,696,226 B) | 15.9 MB (15,854,224 B) |
| `gtnw.opt.wasm` (`wasm-opt -Oz --strip-debug`) | 49.1 MB (49,090,169 B) | 12.9 MB (12,896,532 B) |

Most of it is data: 35.5 MB of the optimized module's 49.1 MB is data segments, mainly ICU's tables (time zones,
currencies, converters, character names) that the statically linked Foundation pulls in. The data files the engine
reads come on top: 1.6 MB of JSON, 0.28 MB brotli. Phase 2 options, in order of payoff: link
`FoundationEssentials` only (drop ICU), lazy-load the .wasm after the title screen (the harness already does), and
cache it with a hashed name.

## Step 4: parity

`Wasm/parity.sh` plays the golden games (1789, 1962 and 2025, 12 turns each, the scripted orders of
`GTNWTests/DeterminismTests.ScriptedGame`). It compares the opening board, every turn's input and snapshot, and the RNG
vectors with the fixtures the app exported (`GoldenExportTests`; NovaGames `games/gtnw-lite/tests/fixtures/gtnw-golden`).

| Runtime | 1789 | 1962 | 2025 | RNG vectors |
|---|---|---|---|---|
| GTNWCore native (macOS arm64) | identical | identical | identical | identical |
| GTNWCore WebAssembly in Node 26 | identical | identical | identical | identical |
| GTNWCore WebAssembly in headless Chromium (Lite e2e test) | identical | identical | identical | – |

The JSON is identical, not just equal within a tolerance. The same check runs in NovaGames:
`tests/unit/wasm-engine.test.ts` (Node) and `tests/functional/wasm.test.ts` (Chromium), whenever
`public/wasm/gtnw.wasm` is present.

Set/Dictionary iteration order was a risk (Swift seeds hashing per process). The games are identical across runs, and
with `SWIFT_DETERMINISTIC_HASHING`, so the engine's random draws don't depend on hash order. The parity check would
catch a change.

## Step 5: harness in GTNW Lite

`?engine=wasm` (NovaGames `games/gtnw-lite`):

- `src/wasm/loader.ts` loads the .wasm; `src/wasm/engine.ts` adapts it to the Lite UI.
- `App.engine` is a two-method seam: `begin` and `endTurn`.
- The Lite engine still builds the opening board and carries out the player's orders. On each end of turn the Swift
  engine plays the turn, and its state is copied into the Lite state wherever the shapes match:
  - nations by id: arsenal, military, stability, approval, destroyed, wars, relations with the player;
  - DEFCON, radiation, casualties, popularity, game over;
  - ticker and log lines.
- The UI is unchanged.
- `tools/sync_wasm.sh` copies the build and its data into `public/wasm/`, which is not committed.

**CSP.** The platform policy (`script-src 'self'`) blocks WebAssembly compilation; it needs `'wasm-unsafe-eval'`.
CONTRACT.md says to ask before adding it, so the production policy is unchanged. Under it, `?engine=wasm` reports
"WebAssembly engine unavailable" and plays the Lite engine; the e2e test checks that fallback. The wasm e2e tests
serve the policy with `'wasm-unsafe-eval'` added. **Phase 2 needs that one directive in `deploy/Caddyfile`.**

End-turn time (1962, full rules, month turns, rule-based brains):

| | first end turn | later end turns |
|---|---|---|
| native (`gtnw-golden --bench`, release, Apple silicon) | 47 ms | 14–16 ms |
| WebAssembly (`gtnw.opt.wasm`) in headless Chromium (Lite harness) | 108 ms | 15–18 ms |

A whole 12-turn golden game (1962) takes 205 ms natively, 307 ms in Node and 359 ms in Chromium. So WebAssembly
costs about 1.1–1.8× native, and a warm turn takes about one display frame. The native CLI's figure
includes up to 2 ms per turn of run-loop polling (`JobPump`'s Darwin path). The first turn is slower everywhere:
caches warm, and in the browser the tiers compile.

## Phase 2: UI parity

Every SwiftUI screen, what it needs from the engine beyond phase 1's bridge, and a rough size in Lite (TypeScript/DOM,
reusing Lite's map, ticker, modal and dossier where they exist). The Swift lines give the scale.

| Screen (Swift) | Swift lines | Needs from the bridge | Lite work |
|---|---|---|---|
| Title / new game: `ContentView`, `CountrySelectionView`, `NationPickerSheet`, `AdministrationSelectionView`, `ScenarioList`, `OneSittingList` | 870 | nations and administrations by year, scenarios | M: Lite's title exists; add any-nation, any-year (1789–2025) |
| Situation Room shell: `SituationRoomView`, `SituationTopBar`, `MainTabView`, `GameTabBar`, `SpectatorBar` | 500 | top-bar numbers (in `state`), spectator autoplay | S: Lite has it |
| World map: `VectorWorldMap`, `MapLegend`, `SimpleModernWorldMap`, `WorldMap` | 1,000 | owners by year, territories, flashes | M: Lite's canvas map; add era owners and colonies |
| Country dossier: `CountryDossier`, `FactbookSheet` | 520 | the full Country (cabinet, leader, profile, economy) | M |
| Action ladder: `ActionLadder`, `ActionLadderSheet`, `ShadowPresidentMenu`, `PresidentialPowersViews`, `AdvancedActionsPanel` | 965 | the action catalog per era, costs, advice (`AdviceEngine`) | M: the bridge's `act` covers execution; add advice and availability |
| Advisors: `AdvisorRail`, `AdvisorBriefingSheet`, `AdvisorViews`, `AdvicePanel`, `CabinetWarningsView` | 790 | advisors, recommendations, warnings | M |
| Crisis: `CrisisView`, `ActionResultSheet` | 260 | `state.crisis` (already in phase 1) + results | S |
| News: `NewsTicker`, `LiveNewsNetwork`, `QuoteViews` | 460 | `events` (already) | S |
| Command center / terminal / command box: `UnifiedCommandCenter`, `CommandView`, `ModernCommandView`, `TextCommandInterface`, `CommandBoxView` | 4,500 | a `command` op wrapping `CommandPlanner` / `GameOrder` (core already) | L |
| Budget & aid: `BudgetView`, `AidSheet`, `ResourcesSheet`, `ManpowerSheet` | 300 | budget, aid vectors, resources, manpower | M |
| War: `AttackSizingPanel`, `FleetOrderSheet`, `AirCampaignSheet`, `ArsenalLine`, `WarRoomView`, `PeaceSheet`, `SettlementSheet` | 760 | fronts, fleets, arsenal, settlements | L |
| Diplomacy: `DiplomaticMessagesView`, `CoalitionSheet`, `GroupActionSheet`, `TreatyOffersSheet` | 630 | messages, coalitions, treaty offers | M |
| Domestic politics: `CongressSheet`, `CongressBadge`, `GovernSheet`, `ElectionNightView`, `DomesticEndingBanner`, `ImpeachmentRiskBadge`, `DirtyTacticsSheet` | 410 | Congress, elections, impeachment, dirty tactics | M |
| Empire & land: `AcquisitionSheet`, `StatehoodSheet`, `UnclaimedLandsSheet`, `TerritoryNameSheet`/`Field`, `SpaceSheet` | 360 | acquisitions, statehood, land market, space race | M |
| Cities: `CityView`, `DrawnCityTile`, `BurningOverlay` | 120 | strike damage per city | S (canvas) |
| Systems / Intelligence tabs: `SystemsView`, `IntelligenceView` | 750 | GameSystems summary, intel reports | M |
| Saves & records: `SaveLoadView`, `RecordsSheet`, `ScorecardSheet`, `WorldEvaluationView`, `LeaderboardView`, `VictoryScreen` | 1,090 | `save`/`load` (already), records, scorecard | M: Lite's IndexedDB saves take the `save()` JSON |
| Tutorial: `TutorialSheet` | 50 | none | S |
| AI brains & settings: `BrainAssignmentView`, `GTNWAIViews`, settings, key bindings | 370 | remote brains are out of the core (see the audit). The web needs its own AI path (games-ai) | M |
| Side features (3.x): `TheLivingRoom`, `PredictiveIntelligence`, `NaturalLanguageIntel`, `MultiPerspectiveAnalyzer`, `EconomicWarfareSimulator`, `CyberWarfareTheater`, `PropagandaEngine`, `SentimentWorldMap`, `CinematicEngine`, `AchievementEngine` | 4,700 | these live in app-only files and would join the core first | L each, or drop |

S is under 200 lines of Lite code, M is 200–600, L is over 600. Phase 2 also needs:

- the bridge ops those screens read: done as typed queries (op 10, above), one file per query;
- the CSP directive: done (NovaGames `deploy/Caddyfile`, 2026-11-23);
- a size pass (FoundationEssentials-only linking);
- a long Wasm soak game for 32-bit overflow.
