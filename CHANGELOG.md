# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.17.4] - 2026-10-21 — Dirty tactics: deception

### Added
- **The deception group** (`DirtyTactics.deception`):
  - **Manufactured pretext** (1789–, legal → UN Charter Art. 2(4) 1945 → Rome Statute 2002): the Mukden incident of
    18 September 1931, the Gleiwitz raid of 31 August 1939, Operation Northwoods — proposed by the Joint Chiefs in
    March 1962 and refused — and the Gulf of Tonkin attack of 4 August 1964 that never happened, three days before
    the resolution. **It counts as a casus belli Congress accepts** (`pretextBonus`, added to
    `CongressModel.casusBelli` in `authorizationOdds`) until it is exposed; exposure annuls the authorization it
    bought, takes 20 congressional support and 30 war support, and brings articles of impeachment.
  - **Yellow journalism** (1895–, legal): Hearst's *Journal* and Pulitzer's *World* from 1895, the de Lôme letter
    and the *Maine* of 15 February 1898. War support and approval now; an exposé takes both back.
  - **Enemy uniforms** (1789–, legal → Hague IV Art. 23(f) 1907 → perfidy under AP I 1977 → Rome 2002): Operation
    Greif in the Ardennes, December 1944. Momentum on a front, and men shot when it comes out.
  - **Counterfeit the enemy's currency** (1789–, legal → the 1929 counterfeiting convention, in force 1931): the
    forged Continental dollars printed in New York in 1776–79 and Operation Bernhard's £132 million from
    Sachsenhausen, 1942–45. Cash for the President, output and stability out of the enemy.
  - **The opium trade as state policy** (1789–, legal → the Hague Opium Convention 1912 → the Single Convention
    1961): the two wars of 1839–42 and 1856–60, after which the Convention of Peking legalised the trade.
- **Drug operations are a real verb now** (`runDrugOperations`): the existing `drugOps` covert action pays into the
  President's funds and costs the target stability and goodwill — and while the opium trade is state policy against
  that country it runs at three times the scale. Play event `drug_operations`.
- **`applyExposureExtra`**: the particular ruin a particular lie brings, beyond the treaty price.

### Changed
- 10 tests across all seven categories (646 total, single muted run); snapshots in `Screenshots/3.17.4/`.

## [3.17.3] - 2026-10-21 — Dirty tactics: civilians and land

### Added
- **The civilians and land group** (`DirtyTactics.civilians`):
  - **Reconcentration camps** (1896–, legal → Hague 1907 → Geneva IV Art. 49 1949 → Rome 2002): Weyler's order in
    Cuba of February 1896, J. Franklin Bell in Batangas from December 1901, and the British camps of 1900–02 in
    which some 28,000 Boers and at least 14,000 Black Africans died. The insurgency in a territory collapses; the
    death rates are published two years later.
  - **Forced removal** (1830–, lawful under the Indian Removal Act of 28 May 1830 and against *Worcester v.
    Georgia* 1832 → Hague 1907 → Geneva IV Art. 49 1949 → Rome 2002): the Cherokee removal of 1838–39, about 16,000
    people moved and some 4,000 dead on the way. The land goes quiet because the people are no longer on it.
  - **Internment** (1942–, lawful under Executive Order 9066 and *Korematsu* 1944 → the Non-Detention Act 1971 →
    Rome 2002): war support and calm at home now; the Civil Liberties Act of 10 August 1988 — an apology and
    $20,000 a survivor, about $1.6B — forty-six years later.
  - **Maximum extraction** (1789–, legal → Hague IV Art. 52 1907 → Geneva IV Art. 55 1949 → Rome 2002): the Congo
    Free State's rubber quota under Leopold II, 1885–1908, and Roger Casement's report of 1904.
  - **Coercive interrogation** (1789–, legal → Lieber Code Art. 16 1863 → Geneva 1949 and the Convention against
    Torture → Rome 2002): the water cure in the Philippines in 1900–02 and Major Edwin Glenn's court-martial in
    1902, France in Algiers in 1957, enhanced interrogation after 2001 and the Senate's findings of December 2014.
    Half the time the prisoner's answer checks out; half the time it is worth nothing.
- **`ExtractionRate.maximum`**: a fifth rate, ×4 income, +50 insurgency, −6 stability a month, −10 world relations
  a year, and the same revolt risk as Plunder. It is reached only through the DIRTY TACTICS panel, so `setExtraction`
  refuses it and the ordinary rate buttons (`ExtractionRate.ordinary`) do not offer it.

### Changed
- A territory revolts under any rate with an insurgency shift of 30 or more, not only Plunder.
- 11 tests across all seven categories (636 total, single muted run); snapshots in `Screenshots/3.17.3/`.

### Deliberately not in the game
- Forced removal here is the historical removal policy and nothing more. There is still no player action for
  genocide or ethnic cleansing, and none for slavery or slave labour.

## [3.17.2] - 2026-10-21 — Dirty tactics: starvation and supply

### Added
- **Stances** (`setStance`, `processTacticStances`): a tactic that stays in force until it is lifted instead of
  being ordered once. It does its work every turn, pays 35% of its full price a year while it runs (a standing
  policy is nobody's secret), and lapses by itself when its conditions go.
- **The starvation and supply group** (`DirtyTactics.starvation`):
  - **Scorched earth** (1789–, legal → Lieber 1863 → Hague 1907 → Geneva 1949 → AP I Art. 54 1977 → Rome 2002):
    Russia ahead of Napoleon in 1812, Sheridan in the Shenandoah in 1864, British farm burning from 1900. Takes the
    enemy's supply, his output and his will.
  - **Starvation blockade** (a stance on a blockade you already have; legal under the Declaration of Paris 1856 →
    restricted Geneva IV 1949 → banned AP I 1977 → Rome 2002): stop food and fertiliser, not only war material. The
    Union's Anaconda plan from 1861; the British blockade of Germany from 1914 until the Versailles signature in
    June 1919, which the German Board of Public Health blamed for 763,000 deaths. It bites 10% of output a year and
    lapses the moment the blockade is lifted.
  - **Destroy the herds** (1868–1884, legal — a Texas bill to stop it was vetoed in 1875): the commercial hide hunt
    that took the southern herd in 1872–74 and the northern by 1883. Resistance on a people's land ends in hunger.
  - **Requisition the harvest** (1789–, legal → Lieber 1863 → Hague Art. 52 1907 → Geneva IV Art. 55 1949 → Rome
    2002): one and a half times a levy out of an occupied territory now, famine and the relief appeals a year later.
  - **War-profiteering contracts** (1861–, legal → Pure Food and Drug Act and Meat Inspection Act 1906): the Army's
    canned and chemically treated beef of 1898 that Nelson A. Miles called embalmed and the Dodge Commission sat on
    through the winter of 1898–99. Cash and kickbacks at once, your own men sick on the front, and a commission of
    inquiry eighteen months later that opens impeachment hearings.
- `exposureBonus`: federal food inspection after 30 June 1906 multiplies the chance a ration scandal comes out by
  2.5. The only per-tactic modifier in the model, and it is there because the law really changed.

### Changed
- The panel shows PUT IN FORCE / LIFT IT for a stance and IN FORCE while one runs; its pickers use a light label
  colour so the unselected options are legible on the dark panel in both skins.
- `profiteer_contracts` finds the front the United States is actually on, whether as attacker, defender or ally.
- 11 tests across all seven categories (625 total, single muted run); snapshots in `Screenshots/3.17.2/`.

## [3.17.1] - 2026-10-21 — Dirty tactics: incendiaries by era

### Added
- **The incendiary group** (`DirtyTactics.incendiary`), six ways to set fire to the enemy, each in its real window:
  - **Heated shot** (1789–1865, legal): round shot heated in a furnace, as at Gibraltar in 1782 and in coastal forts
    until iron hulls and explosive shell ended it. Costs the enemy's navy and his waterfront trade.
  - **Congreve rockets** (1805–1870, legal → Lieber Code 1863): in service from 1805 — Boulogne 1806, Copenhagen
    1807, Fort McHenry September 1814, a U.S. rocket battery at Veracruz 1847. They cannot be aimed, which is the
    point.
  - **Incendiary shells and arson** (1861–1945, legal → Lieber 1863 → Hague 1907 → Geneva IV Art. 53 1949): the
    "Greek fire" shells fired into Charleston from the Marsh Battery in August 1863, and the Confederate attempt on
    the New York hotels of 25 November 1864. The only incendiary one man can do quietly, so the only one with a
    covert option. The panel notes that **Byzantine Greek fire, first used in 672, predates the game and its recipe
    was lost**.
  - **Burn the towns** (1789–, legal → Lieber 1863 → Hague 1907 → Geneva 1949 → Rome Statute 2002): Washington on
    24 August 1814, Atlanta in November 1864, Columbia in February 1865, the Shenandoah through September and
    October 1864. The heaviest blow to an enemy's output, stability and will — and an army cannot do it quietly.
  - **Flamethrowers** (1915–, legal → CCW Protocol III 1983): Hooge, 30 July 1915; the M1A1 and M2 across the
    Pacific from 1943. They push the assault on whichever front the United States is fighting.
  - **Napalm and white phosphorus** (1942–, legal → CCW Protocol III 1983 → Rome Statute 2002): Fieser's work at
    Harvard in 1942–43, in combat from 1944.
- `burnTarget` and `frontBlow`: shared benefit helpers over the existing country and War Room front models.
- Nova has lines for fire.

### Changed
- The DIRTY TACTICS panel gains a group picker now there is more than one group, and opens on a chosen group.
- 11 tests across all seven categories (614 total, single muted run); snapshots in `Screenshots/3.17.1/`.

## [3.17.0] - 2026-10-21 — Dirty tactics: early chemical and biological

The first of seven releases that let the President fight dirty and let the game judge him for it — but only if he
is caught. Jordan's rule: **it's only illegal if you get caught.**

### Added
- **`DirtyTactics`** (`DirtyTactics.swift`), the frame every later group plugs into. Each tactic carries:
  - a **real era window** (`from` / `to`), with a research programme able to pull something earlier only where the
    era's technology plausibly allowed it;
  - a **legal status by era** (`LegalStatus`, reused from the 3.6.0 weapons catalog) that tightens with the real
    treaties, and the treaty line that did it;
  - an **open or covert** choice. `discoveryChance` = 6% × the era (`eraExposure`: a partisan press before 1850, a
    mass press to 1915, aerial reconnaissance and correspondents to 1960, satellites to 1990, modern intelligence
    after), × the crowd in on it (√ the hundreds involved), × the scale ordered (Probe / Standard / Overwhelming),
    capped at 90%;
  - the **consequences on discovery**: the 3.6.0 treaty cost (relations with the target and the world, allies,
    ruthlessness, approval, sanctions, impeachment hearings) plus a quarter again for the cover-up, and a
    **war-crimes tribunal** roll in the eras that have one (none before Nuremberg, 10% to 1993, 20% to 2002, 35%
    under the Rome Statute). A covert use always costs a fifth of its ruthlessness, because the men who did it know.
- **Five tactics** (`DirtyTactics.chemical`):
  - **Crude war-gas programme** (1880–, legal → Hague 1899 → Geneva Protocol 1928 → CWC 1997): four years and $12B
    of industrial chemistry to put chlorine and phosgene in shells before 1917. It delivers a real stockpile the
    weapons catalog then prices as usual. **A 1790s programme is refused with the reason** — electrolytic chlorine
    plants date from the 1890s, and no money moves that.
  - **Contaminated goods** (1789–, legal → Lieber Code 1863 → Hague 1899 → Geneva 1949): the Fort Pitt precedent of
    June 1763, correctly attributed to British officers. Low, random effectiveness, and a 35% chance the sickness
    crosses back into American camps and towns.
  - **Gas against a resisting people** (1920–; the Rif 1921–27, Ethiopia 1935–36): resistance collapses on a
    people's land, so it is cheaper to take afterwards (`shadow.resistanceBroken` feeds `claimIndigenousLand`).
  - **Human-subject biological programme** (1932–; Unit 731 at Pingfang, 1932–45): three years to a biological
    arsenal, 30 hundred people in on it, and no political survival if it comes out.
  - **Defoliants** (1961–; Operation Ranch Hand, Jan 1962 – Jan 1971, about 20 million gallons): the enemy loses his
    cover, his harvest and 4% of his output per scale point — and the dioxin bill arrives twenty years later
    (`TacticAftermath`).
- **Delayed costs** (`TacticAftermath`): a cost queued for a date years away, applied by `processDirtyTactics`, and
  able to repeat yearly until its window closes.
- **DIRTY TACTICS panel** (`DirtyTacticsSheet`, top-bar **TACTICS**): the era's tactics with legal status, the
  treaty behind each, the covert risk at the chosen scale, OPENLY / IN SECRET buttons — and the tactics the era
  cannot do yet, with the reason.
- **Hall of Infamy**: two records, *most dirty tactics ordered* and *most tactics exposed*.
- **Nova** has lines for an exposure and for the chemical trade.
- Play events `tactic_used`, `tactic_exposed`, `tactic_tribunal`, `tactic_program_started`, `tactic_program_ready`,
  `tactic_program_discovered`, `tactic_aftermath`.

### Changed
- `PresidentialAction.isAvailable(on:in:)` takes the game state, so a programme the President ran himself can put
  chemical or biological weapons on the board before history did. Without it only the historical dates count.
- 13 tests across all seven categories (603 total, single muted run); snapshots in `Screenshots/3.17.0/`.

### Deliberately not in the game
- No player action for chattel slavery or slave labour, and none for genocide or ethnic cleansing. Both stay as
  history and as things other powers do.

## [3.16.2] - 2026-10-20 — Historical absorptions; polish

### Added
- **Historical absorptions** (`processAbsorptions`, in the yearly era sync): a nation still following history is
  absorbed on the real date into the nation that took it, when that nation follows history too. Nations the era
  board drops (Korea 1910, the Baltic states 1940) go to the owner history gave their land; `WorldPolitics.absorptions`
  covers the rest (the third partition of Poland 1795, the Anschluss 1938, Czechoslovakia and Poland 1939). They are
  restored on their historical dates or when the era board brings them back (`shadow.historicalAbsorptions`). A target
  allied with the player or under a defence treaty becomes a crisis instead: the absorber declares war and the target
  appeals to Washington. Play events `nation_absorbed`, `annexation_crisis`. Hawaii and Texas aren't separate lands
  on the map, so they don't apply.

### Changed
- **Profiling**: a full 2025 Nightmare end-turn takes about 0.25 s (0.5 s at worst, on the year's era sync) and a
  1789 Nightmare end-turn about 0.02 s in a Debug build on the Studio, under the 1 s budget, so no optimisation was
  needed; a performance test now holds the line.
- **README**: an overview of the 3.x series, features grouped by theme (fighting a war, land and empire, the world
  around you, scenarios, peace) instead of one release-ordered list, a refreshed introduction and testing section.
- 8 tests across all seven categories (590 total, single muted run); snapshots in `Screenshots/3.16.2/`.

## [3.16.1] - 2026-10-20 — Mid-game foundings; commentary on the AI phase

### Added
- **Mid-game foundings** (`processFoundings`, in the yearly era sync): a nation new to this year's era board
  (`shadow.eraBoardIDs` remembers last year's) is founded with its historical government and relations when its land
  is still with its historical owner (colony, dependency or nobody). Successor states absorb constituent lands still
  on their historical path (`WorldMapData.historicalOwners`). Land taken by the player or a computer-run power gets an
  independence movement instead (unrest +20, stability −10). Play events `nation_founded`, `independence_movement`;
  `worldStats` gains `foundings` and `transitions`.

### Changed
- Nova's commentary runs after the AI phase (`endTurn`), on everything new that turn, so AI nuclear strikes and war
  declarations are included; the limits are unchanged (one line, or up to two flash events).
- 9 tests across all seven categories (582 total, single muted run); snapshots in `Screenshots/3.16.1/`.

## [3.16.0] - 2026-10-20 — Peace victories

### Added
- **`PeaceModel`** (`PeaceModel.swift`): four peace paths with progress (`progress`, `PeacePath`): treaty network
  (35% of nations) → Master Diplomat, alliance leadership (largest bloc, at least max(8, 20%)) → **Leader of the Free
  World** (new, 1100), economic dominance (30% of world output, era-relative from `shadow.startOutputShare`, and the
  largest economy) → Economic Tycoon, Nobel moments (three peaces brokered) → **Nobel Laureate** (new, 1300). All need
  the player at peace, no nuclear weapon used and five years in office.
- **Broker peace** (`brokerPeace`): one action, odds from both sides' relations with the player; success ends the war,
  counts a Nobel moment and adds approval. Play event `peace_brokered`.
- **PEACE** panel (`PeaceSheet`): progress bars, what's missing, and up to five wars elsewhere to broker.
- **Peace scoring** (`GameScore.peaceBonus`): treaty partners ×25, Nobel moments ×200, years at peace ×10, output
  share ×1000.

### Changed
- Proposing or signing a treaty and non-aggression pacts now record a treaty (once per pair and type).
- Peace Maker and WOPR's Choice depend on the player's own record (`shadow.playerWarsStarted`, at peace now) instead
  of every war on Earth having ended, which the living world made impossible.
- The old Master Diplomat (alliances with 80% of nations) and Economic Tycoon (GDP above all others combined) checks
  are replaced by the paths above.
- 9 tests across all seven categories (573 total, single muted run); snapshots in `Screenshots/3.16.0/`.

## [3.15.0] - 2026-10-20 — Nova's commentary, the Hall of Infamy, era transitions

### Added
- **Nova's live commentary** (`NovaCommentary.swift`): `processCommentary` after each Shadow turn picks the turn's
  biggest notable headline (or up to two flash events) and posts a deterministic template line to the ticker and
  `shadow.novaLines`; a live generator wired to `AIBackendManager` (two attempts via `Retry`) replaces it with
  Nova's own line when it answers cleanly. Prompts carry only the date, the player's country and the headline;
  `clean` keeps one plain line and drops links, addresses and markup. Setting: "Nova's live commentary"
  (`GTNW.novaCommentary`). Play event `nova_commentary` with the source.
- **The Hall of Infamy** (`HallOfInfamy`, `InfamyRecord`): seven personal records kept across sittings in local
  defaults (a throwaway suite under XCTest) and as `record_set` play events; beating an earlier sitting's record is
  announced. **RECORDS** button and `RecordsSheet`.
- **Era transitions** (`processEraTransitions`): once a game year, nations still following history take the era's
  name, government, flag and alignment (from `GameState.eraBoard(year:)`); a nation whose government something else
  changed, or that was conquered, stops following history (`shadow.eraDiverged`). Play event `era_transition`.
  `Country.flag` is now mutable.
- 15 tests across all seven categories (564 total, single muted run); snapshots in `Screenshots/3.15.0/`.

## [3.14.1] - 2026-10-20 — Independent Africa, the Balkan states, AI territories with stakes

### Fixed
- **Ethiopia was never unclaimed**: the Ethiopian Empire is on the board from 1789 (Italian East Africa 1936–41).
  Liberia is a state from 1847 and Madagascar's Merina Kingdom until the French conquest of 1896
  (`WorldCountriesDatabase.independentAfrica`). Morocco and Egypt were already era-correct.
- **West and East African states**: the Ashanti Empire (to 1901), the Hausa kingdoms and Sokoto Caliphate (to 1903)
  and the Sultanate of Zanzibar's coast (under Oman to 1856, to 1885) are peoples' land, followed by the Gold Coast,
  Nigeria Protectorate, German East Africa and Tanganyika as colonies. Land with a pre-state status is never also
  unclaimed.
- **The Balkans**: Serbia from 1817 (Principality; Kingdom 1882), Greece from 1829 (Kingdom), Montenegro and Romania
  from 1878 (Kingdom of Montenegro 1910, of Romania 1881), Bulgaria from 1878 (Principality; Kingdom 1908); Macedonia
  and Kosovo pass from the Ottomans to Serbia in 1913. The Serbo-Turkish, Serbo-Bulgarian and Balkan wars join the
  rivalries.
- Niue and the Cook Islands stay British until New Zealand is on the board.

### Added
- **AI territories with stakes** (`processAITerritories`): AI-held land uses the player's occupation model with thin
  colonial garrisons (60% of need), pays the owner the same `annualIncome`, and may revolt (unrest above 70, 30% a
  year). AI land ramps up from its claim date. `worldStats` gains `revolts` and `aiIncomeCents`.
- 9 tests across all seven categories, including a map sweep around the new dates (549 total, single muted run);
  snapshots in `Screenshots/3.14.1/`.
- Older tests that used Nigeria and Ghana as their stock unclaimed land now use Cameroon and Gabon (Nigeria and
  Ghana are Sokoto and Ashanti land in those years).

## [3.14.0] - 2026-10-20 — A living world

### Added
- **`WorldPolitics`** (`WorldPolitics.swift`), run each turn from `processShadowTurn`:
  - Era rivalries and wars (`rivalries`): relations of −60 or worse while a rivalry lasts; wars declared on their
    real dates between computer-run powers (never forcing the player), peace when the era ends.
  - The race for land (`aiTakeLand`): colonial powers claim unclaimed and peoples' land (rate by era, highest
    1880–1914), others only within 25° of home; powers at war seize enemy colonies.
  - Reactions to U.S. expansion over the difficulty's threshold: protests, proxy revolts, seizing weakly
    garrisoned territories, a coalition, and on Hard/Nightmare a declaration of war.
  - Alliances break when allies fall out; nations offer the player treaties (`TreatyOffer`, top-bar **Treaty**
    button, `TreatyOffersSheet`, `answerTreaty`).
  - `ShadowState.worldStats` counts AI wars, claims and diplomacy; play events `world_war`, `world_claim`,
    `territory_seized`, `treaty_answered`.
- `startNewGame(year:)` starts on Inauguration Day of any year with the administration then in office.

### Changed
- **AI activity scales with difficulty** (`WorldPolitics.activity`: 0.6 / 1 / 1.6 / 2.6): act rate, the wait weight,
  the hostility and strength gates for war, and a 0.4 floor on the war weight so monarchies fight too.
- AI wars between other nations no longer raise DEFCON unless a nuclear power is involved.
- Post-1945 special relations (U.S.–Russia, NATO, the EU and so on) apply only from their eras.

### Fixed
- **Passive AI**: starting relations bottomed out at exactly −40 while war needed less than −40, and pre-modern
  monarchies had a war weight of 0, so 1789 games were nearly still.
- **Anachronistic nations**: states founded later are off early boards (`WorldCountriesDatabase.founded`;
  Yugoslavia and Czechoslovakia from 1918); the Qing aren't renamed "Republic of China" before 1912 (nor Vietnam,
  Egypt, Sudan or Burma given later names early); crises, news, AI War Room, intel and advice pick only from
  `GameState.liveCountries`; the LLM crisis prompt lists the era's nations and drops any others; relations are never
  set toward nations off the board; U.S. marshals catch spies before 1908.
- **Map selection**: every outline resolves in every era (`WorldMapData.selection`, era `dependencies`, and any other
  land with a template counts as unclaimed); the card grid shows colonies and peoples' land; Mongolia is the Qing's
  until 1921. A sweep test clicks every outline in 1789, 1850, 1913, 1950 and 2025.
- **"Mobilizes the reserves: 0K"** in 1792: before 1861 it's a militia call (13K, 50K from 1812), there's no
  federal draft before 1863, and sizes round instead of truncating.
- The Resources panel shows "first income next month" instead of $0.00B/yr in a territory's first month.
- 14 tests across all seven categories, including 200-turn simulations from five eras on every difficulty
  (540 total, single muted run); snapshots in `Screenshots/3.14.0/`.

## [3.13.2] - 2026-10-20 — Territory money fixes

### Fixed
- The levy cooldown, "producing in N months" and recovery countdowns use calendar months: a levy is ready again
  after exactly six monthly turns (it sometimes took seven).
- The low-stability warning no longer shows on nearly every new territory. In its first year a territory with an
  adequate garrison under Light or Normal extraction recovers to 60 stability by its anniversary
  (`ExpansionModel.stabilityRecoveryMonths`, applied in `processOccupation`); the Resources panel shows
  "Stability 45 → 60 in ~N months at this garrison." The 60 threshold is unchanged.
- 8 tests across all seven categories (526 total, single muted run); snapshots in `Screenshots/3.13.2/`.

## [3.13.1] - 2026-10-20 — Territory money

### Added
- **Territory cash in your funds**: `processTerritoryEconomy` credits each turn's earnings to `shadow.aidRemaining`
  (spendable on aid, group actions and purchases), records `shadow.lastTurnCash`, and posts "Territories paid $X B
  this <turn>." A quarter also adds to GDP (it used to be all of it).
- **Extraction rates** (`ExtractionRate`, `GameEngine.setExtraction`): Light ×0.6, Normal, Heavy ×1.5, Plunder ×2.5
  income; heavier rates add insurgency (+12/+30), drain stability (1/3 a month) and cost world opinion (1/4 a year).
  Plunder with unrest above 60 risks a revolt (25% a year).
- **Levies** (`GameEngine.collectLevy`): half a year's income at once (min $0.2B), −10 stability, +10 unrest,
  six-month cooldown; play event `territory_levy`.
- **Resources panel**: this turn's cash and funds, per-territory rate buttons, COLLECT / cooldown, "producing in N
  months", and the limiting factor with a one-line fix (`ExpansionModel.limit`).
- **Group actions**: Extraction and Collect Levy for all territories (free, like garrisons).

### Changed
- Colony purchases and backing independence draw on funds first (`spendFunds`), then GDP.
- `annualIncome` includes the extraction rate and self-rule share; the Govern sheet no longer applies the share twice.
- 11 tests across all seven categories (518 total, single muted run); snapshots in `Screenshots/3.13.1/`.

## [3.13.0] - 2026-10-20 — Takeable land on every continent

### Added
- **Pre-state land data**: `Documentation/territories/data.py` (99 dated eras on every continent plus 5 historical
  acquisitions, sources listed) → `build.py` (validates, no overlapping eras) → `Shared/Engine/Shadow/TerritoryData.swift`.
- **`PreStateModel`** (`PreStateModel.swift`):
  - `GameState.preState` and `colonyLandIDs` / `indigenousLandIDs`. A colony whose owner isn't in the game counts as
    unheld.
  - Map: colonies in the owner's colour, hatched, with a "Name (Owner)" label; indigenous land in parchment with its
    peoples' name; the legend gains Colony.
  - `seizeColony`: sized troops against a colonial garrison (1.5% of the owner's force pool); war with the owner;
    amphibious fleets can land.
  - `purchaseColony`: price = ten years of value × relation factor; never at war.
  - `supportIndependence`: $2B; likelier within five years of the real date. Success creates an allied state.
  - `claimIndigenousLand`: resistance strength, a restless territory, and condemnation scaled by era.
  - Historical U.S. offers: `openAcquisitions` / `acceptAcquisition` / `AcquisitionSheet`, announced on the ticker
    as their windows open, plus a top-bar **Offer** button. Their value is added to territory income
    (`ShadowState.acquisitionIncome`).
- **Alaska** is split out of the U.S. outline (`USA_AK`), drawn as Russian America before 1867 and as U.S. land
  afterwards or once bought. The Virgin Islands get a template.
- Play history: `colony_seized`, `land_purchased`, `independence_backed`; indigenous claims are flagged on
  `claimed_land`.
- 13 tests across all seven categories (507 total, single muted run); snapshots in `Screenshots/3.13.0/`.

## [3.12.2] - 2026-10-20 — Evolving cabinets; the Gulf War scenario

### Added
- **Evolving cabinets** (`GameEngine.processCabinets`, each turn and at setup):
  - Non-U.S. players' cabinets follow the research dates (the outgoing minister is retired, the new one appointed,
    ticker line) while `ShadowState.cabinetFollowsHistory`.
  - That stops when the player appoints anyone (any departure), wins an election, or history puts someone else in
    the player's own office.
  - Computer-run nations with data show their historical leader on the dossier (`ShadowState.leaderNames`) until
    their government changes or they are annexed or destroyed (`divergedNations`).
- **"The Gulf War, 1990"** scenario (2 Aug 1990) with a five-line scorecard. Thirteen Days (1962) gains "Naval
  quarantine of Cuba" (24 Oct 1962) and "DEFCON 2 reached".
- 10 tests (494 total; the suite now runs once per release, muted); snapshots in `Screenshots/3.12.2/`.

## [3.12.1] - 2026-10-20 — Mute switch

### Fixed
- **Test runs no longer make noise or take over the desktop.** New `AudioGate` (`Shared/Engine/Shadow/AudioGate.swift`):
  - The app is muted when the environment has `GTNW_MUTE=1`, the launch arguments have `-GTNWMute YES`, or it runs
    as an XCTest host (`XCTestConfigurationFilePath`).
  - Every audio path checks the gate first: Shadow Pack sounds, cinematic audio, Living Room and world-leader voice
    playback, and speech synthesis. The synthesizer is now created on first use, so a muted run never creates an
    audio player, synthesizer or engine.
  - Under XCTest the app sets a prohibited activation policy at launch and keeps its windows ordered out.
  - The scheme's test action sets `GTNW_MUTE=1`.
- 3 tests (484 total): the host is muted, never active and has `GTNW_MUTE`; playback is suppressed; each switch is
  honoured.

## [3.12.0] - 2026-10-20 — Coalitions and historical scenarios

### Added
- **Coalitions** (`Shared/Engine/Shadow/Coalitions.swift`, `CoalitionSheet`, dossier **Coalition**):
  - Candidates are treaty, in-play and friendly nations, never the target's allies.
  - `CoalitionModel.joinOdds` uses relations, ties to the target, a legislative authorization, the casus belli and
    any chemical/biological use.
  - Members send 10% of their forces to the front and the world reaction is shared (1/(n+1), applied to sized
    attacks); refusers lose 5 relations. Coalitions persist in `ShadowState.coalitions`.
  - Play event `coalition_request`.
- **Scenarios**: Day of Infamy 1941, the Berlin Blockade 1948, Korea 1950 and September 11, 2001, with boards set by
  date. The new `ScenarioDefinition.boardYear` / `GameState(boardYear:)` builds countries for the scenario year
  rather than the administration's first year. Every scenario has a **scorecard** (`Scorecard`, `ScorecardSheet`,
  top-bar **Scorecard**) comparing yes/no milestones with dated history.
- 11 tests across all seven categories (481 total); snapshots in `Screenshots/3.12.0/`.

## [3.11.0] - 2026-10-20 — Play as other nations

### Added
- **Cabinet research in the repo**: `Documentation/cabinets/`. `data.py`, `build.py` and `nations/` regenerate
  `cabinets.json`, `generic_roles.json` and `cabinets.md` (33 nations, 12,967 officeholders, 905 uncertain records).
  `gen_compact.py` builds the bundled `Shared/Resources/nation_cabinets.json`.
- **`NationModel`** (`Shared/Engine/Shadow/NationModel.swift`):
  - Holders by date (Gregorian, including Russian imperial dates), with generic titles by government type for gaps
    and never an invented name. Uncertain holders are marked "?". After 30 Apr 2026 the last earlier holder is kept,
    marked "(acting/unverified)".
  - The player's office by government type: PM, party leader or head of state.
  - The cabinet maps onto the Situation Room posts via the new optional `Advisor.role`, and the rail shows national
    office titles.
  - `RemovalMechanism`: no-confidence, coup, revolution, party congress, junta decision or royal dismissal, each with
    staged warnings and a new `DomesticEnding` and banner. These replace impeachment and the Senate trial for
    non-U.S. players.
- **Start screen**: a Nation picker (`NationPickerSheet`) lists every nation in the start year with its leader on
  that date.
- Non-U.S. games:
  - No U.S. presidential elections; the U.S. is computer-run.
  - Congress, War Powers, the draft, statehood and named U.S. fleets are hidden or refused.
  - Removal risk is labelled by mechanism.
- Play history: `country_name` on `game_start` and in the summary, plus `leader`.
- 13 tests across all seven categories (470 total); snapshots in `Screenshots/3.11.0/`.

### Fixed
- The 3.8.0 Senate-trial test tolerates a random assassination after an acquittal.

## [3.10.0] - 2026-10-20 — Antarctica and group actions

### Added
- **Antarctica** (`Shared/Engine/Shadow/Antarctica.swift`):
  - Claimable in every era via `GameState.unclaimedLandIDs`. The Natural Earth outline is drawn now, and the world
    map runs to 74°S so the coast shows in both styles and the card grid.
  - Legal status: open before 1 Dec 1959, restricted until entry into force on 23 Jun 1961, then treaty-banned. The
    cost comes from `applyTreatyCost`, the 3.6.0 machinery now shared with chemical/biological weapons.
  - The dossier lists the seven national claims by year; the advisors warn.
  - Garrison need 0.5K, 5% monthly attrition and $0.4B a year upkeep per thousand men; no insurgency.
  - Resources: sealing, whaling, science prestige, and minerals and oil from 2048.
- **Group actions** (`Shared/Engine/Shadow/GroupActions.swift`, `GroupActionSheet`, top-bar **Group**):
  - Groups: territories, allies (era treaty bloc plus in-play alliances), a region, a hand-picked set, or saved
    groups (`ShadowState.savedGroups`).
  - Actions: money, aid (even or by need), garrisons, sanctions, diplomatic message, recall.
  - `planGroupAction` gives the per-nation breakdown and total for the confirmation. `executeGroupAction` runs the
    existing single-nation code for each member, costs one action, counts the domestic effect once, and logs one
    `group_action` play event with the members.
- 13 tests across all seven categories (457 total); snapshots in `Screenshots/3.10.0/`.

### Changed
- A modern game's unclaimed land is now just Antarctica (test updated).
- The 3.7.0 replay test ignores a random assassination, which could end it early about 2% of the time.

## [3.9.0] - 2026-10-20 — Occupation, statehood, draft and mobilization

### Added
- **`OccupationModel`** (`Shared/Engine/Shadow/OccupationModel.swift`):
  - Per-territory policy (`ShadowState.territoryPolicies`): military governor, local elections or self-rule.
  - Garrisons (`setGarrison`, from the free troop pool; needed ≈ 2K × √population). Insurgency and stability drift
    toward targets set by garrison and government.
  - Breakaway when a territory boils over for a year with under half its needed garrison.
  - Statehood (`petitionStatehood`): five years held, stability 60+, insurgency ≤ 30 and two years of elected
    government, then a congressional vote. The state is numbered from the real admissions of its era
    (`ShadowState.statesAdmitted`), keeps its name, is shown as "U.S. STATE ★N" (`GameState.territoryLabel`) and
    scores +1000.
  - Annexations get an occupation garrison. `GovernSheet` is opened from the territory dossier.
- **`ManpowerModel`** (`ManpowerModel.swift`):
  - The U.S. troop pool is the era's standing force plus historical drafts in force. Called drafts and reserve
    mobilizations (`callUp`, `standDown`) carry a political cost and a training ramp of six months or one month.
  - `AttackSizing.troopPool` / `freeTroops` use it for the U.S. Standard troops, new player fronts and War Room
    commitments are capped by what is free.
  - `ManpowerSheet` (top-bar **Troops**).
- **AI attack sizing**: `AttackSizing.aiPreset` (aggression and relative strength) sizes computer-run countries' new
  fronts and nuclear salvos with the 3.4.0 multipliers.
- **World Map card grid**: unclaimed-land cards with an expedition sheet (then naming), and Rename on U.S. territory
  detail sheets.
- Play history: `draft_called`, `mobilization_called`, `statehood`, `territory_lost`.
- 12 tests across all seven categories (444 total); snapshots in `Screenshots/3.9.0/`.

### Fixed
- Two 3.8.0 Congress tests depended on the random starting congressional and war support and could fail
  occasionally; they now fix those values.

## [3.8.0] - 2026-10-20 — Congress, the war powers, and advisor warnings

### Added
- **`CongressModel`** (`Shared/Engine/Shadow/CongressModel.swift`):
  - Support by chamber: House = ½ congressional support + ½ approval; Senate = 0.7 + 0.3.
  - `requestAuthorization` (one action) for a Declaration of War or an AUMF, voted by both chambers. Expected yes =
    0.5 support + 0.3 war support + 30 × casus belli (+8 for an AUMF) + 5; pass odds (yes − 42) ÷ 16 per chamber.
  - A pass gives war support +10 and approval +3 and clears the clock; a rebuff costs approval −3 and support −5.
  - War Powers Resolution from 7 Nov 1973 (`processWarPowers`): unauthorized hostilities the U.S. starts or joins
    start a 60-day clock, warned at 45 and 60 days, then 30 days to withdraw. Defiance costs Congress −15 and
    outrage +15.
  - Congress's support drifts monthly toward 30 + ½ approval − 0.2 outrage.
  - Impeachment stages are named (inquiry, articles, House vote, Senate trial). Removal now needs a Senate trial with
    two-thirds to convict (Senate support under 34); an acquittal resets it with a small rally.
- **`CongressSheet`** (dossier **Congress**): odds and expected votes by chamber, casus belli, past votes.
  **`CongressBadge`** in the top bar: Congress by chamber and the War Powers clock.
- **Advisor warnings** (`AdvisorWarnings.swift`, `CabinetWarningsView`): one line each from the Joint Chiefs, the
  Secretary of State and the Vice President before attacks, nukes, chemical/biological weapons, annexations, claims
  and fleet orders. Every figure comes from the engine's own functions (odds, losses, retaliation, world reaction,
  treaties, approval, the War Powers clock, impeachment pressure). DO IT becomes OVERRULE & PROCEED on a danger line.
  *Settings → Advisor warnings before major actions* (on by default).
- Play history: `congress_vote`, `war_powers_violation`.
- 12 tests across all seven categories (432 total); snapshots in `Screenshots/3.8.0/`.

## [3.7.0] - 2026-10-20 — Territory wealth, fair expansion, no surprise impeachment

Jordan's 3.3.0 session (1913 start, 27 claims in two months) ended in removal in Sep 1913 with a score of 1290: each
claim added a flat +5 ruthlessness, so 27 claims pushed Congress's pressure (ruthlessness × 0.4) to ~54 against a
threshold of 12 and impeachment advanced a stage at every monthly poll, while land brought no reward at all.

### Added
- **`ExpansionModel`** (`Shared/Engine/Shadow/ExpansionModel.swift`). Resource table: about 40 lands with approximate
  first-exploitation years, sourced in comments. Lands without an entry, or before their resources, farm a little.
  Income ramps up from 6 months to full at 2 years and scales with stability and garrison. Annexed countries without
  an entry pay 2% of GDP a year. Income adds to U.S. output and gives up to +5 approval from prosperity. Territories
  announce "X is now producing …" on the ticker and in play history (`territory_producing`).
- **Strategic resources** in their eras: oil (1910+) gives +15% aircraft and +10% fleet speed, uranium (1942+) about
  +20 warheads a year, and rubber (1914–18, 1939–45) +10% troops.
- **`ResourcesSheet`** (top bar **Resources**): income per territory and in total, earnings to date and active
  strategic effects.
- **Score**: `GameScore.expansionBonus`, +100 per territory, +10 per $1B earned and +1000 per statehood (hook for the
  coming statehood feature). Optional, so older score records decode.
- **Politics of expansion** (`ExpansionModel.politics`, design choices). Before 1919, +0.5 approval for each of the
  first six claims a year, then −0.03 × (n − 6); outrage 0.5 + 0.003 × (n − 4)². Interwar costs more. From 1945,
  −3 approval and outrage 8 + 0.02 n², with world reaction ×3. Replaces the flat +5; annexations count toward the pace.
- **No surprise impeachment**:
  - `ImpeachmentRiskBadge` in the top bar shows the risk (LOW / RISING / HIGH, the same pressure Congress uses) and
    the 38% approval floor.
  - The Chief of Staff warns on the dossier before a claim that would tip the pressure.
  - A ticker warning goes out the turn pressure crosses the threshold, after the poll so it precedes the next one.
  - The "articles drafted" stage now says the House votes at the next poll unless approval recovers.
- 12 tests across all seven categories (420 total). Included: a replay of Jordan's pattern, which now ends with
  approval in the low 40s and no impeachment stage; a 47-claim spree in one week, which still opens hearings after a
  warning; resource eras (Libyan oil only from 1959, Congo rubber to 1920); ramp-up, hold and politics curves; income,
  score and strategic oil; tribute and neglect; persistence and old saves; and the "Gotit is now producing copper"
  play event. Snapshots in `Screenshots/3.7.0/`.

## [3.6.0] - 2026-10-20 — Era weapons catalog

### Added
- **`ArsenalCatalog`** (`Shared/Engine/Shadow/ArsenalCatalog.swift`) with **`ArsenalData.swift`**, generated by
  `Documentation/arsenal/gen_swift.py` from `gtnw_us_arsenal_by_era.json`: 47 U.S. offensive options 1789–2030 with
  years, legal status by period (legal / restricted / treaty-banned / destroyed), notes and example systems. Options
  first available after April 2026 are flagged low-confidence and never gate an action alone.
- **`PresidentialAction.isAvailable(on:)`** drives the action sheets and the engine: era years as before, nothing
  nuclear before Trinity (16 Jul 1945), chemical from 1917, biological 1943–1969.
- **`ArsenalLine`** under each action: the era's arsenal for it, its legal status and treaty (INF 1988–2019, NPT, CWC,
  BWC…). Restricted and banned options are labelled, not hidden.
- **Chemical Attack / Biological Attack** (Military rung) and **Restart Chemical / Biological Program** (Covert rung).
  Costs by legal status (`ArsenalCatalog.cost`, design choices): legal (1917–18) target −40, world −5; restricted
  target −60, world −15 (allies −25 in all); treaty-banned target −90, world −40 (allies −70 in all), ruthlessness +60, popularity −20,
  sanctions −3% U.S. output, impeachment hearings opened. Effects are game stats only (casualties, stability, army,
  front line). Destroyed stockpiles (chemical from 7 Jul 2023, biological from 1970) need a restarted program first:
  2 / 3 years' lead time (design choices) with 35%/year discovery risk (`ShadowState.wmdPrograms`).
- Play history: `wmd_used`, `wmd_program_started`, `wmd_program_discovered`.
- 13 tests across all seven categories (408 total): chemical 1917 / 1975 / 1997 / 7 Jul 2023 boundaries, biological to
  1969 then restart-only, no nukes before Trinity, INF label, the 47-option table, costs by status, WWI vs post-CWC
  use, the restart flow, discovery odds, guards, save/load, play events, renders (`Screenshots/3.6.0/`).

### Fixed
- `AttackSizingTests.testBiggerInvasionOpensWithMoreTroopsAndFightsHarder` used a probe-sized invasion, which can fail
  by design (≈71%), so it was flaky; it now compares two sizes at or above Standard.

## [3.5.0] - 2026-10-20 — Naval operations

### Added
- **Named U.S. fleets by era** (`Shared/Engine/Shadow/NavalModel.swift`): 27 fleets and squadrons with dated home-port
  periods, taken from the arsenal research now kept in `Documentation/arsenal/` (`data.py` + `build.py` regenerate
  `gtnw_us_arsenal_by_era.json` / `.md`). No navy 1789–1797 and no named squadron before 1801; real gaps (Fifth Fleet
  1947–1995, Second Fleet 2011–2018, Fourth Fleet 1950–2008); uncertain dates rounded to the year. Era-typical
  composition (`FleetComposition`): carriers from 1922, submarines from 1900, amphibious ships from 1942.
- **Fleet orders** (`FleetOrderSheet`, from the dossier's **Fleet** button and unclaimed coastal land): show of force,
  blockade, naval strike (weapon by era; Tomahawk from 1983) and amphibious invasion (opens a front with the landing
  force, or claims unclaimed coastal land), committing 25 / 50 / 100% of the fleet (the 3.4.0 presets). One action.
- **The fleet as a force**: transit in game days = great-circle km ÷ era speed; `FleetDeployment` saved in
  `ShadowState.fleetDeployments` with its position derived from the dates and drawn on the map (marker + dashed wake,
  both skins); engagements on arrival and during blockades (`NavalModel.shipsLost`, by the defender's share of combined
  strength); a fleet with no ships left is gone; ships on station are tied up until **Recall**. Landlocked targets
  (Factbook flag plus the 44 landlocked states) are refused with the reason.
- Play history: `fleet_ordered`, `fleet_action` ("Fifth Fleet blockaded Japan") and `fleet_recalled`.
- 14 tests across all seven categories (395 total): the era table (no carriers in 1850) checked against the research
  file, transit maths, the landlocked guard, every mission, losses, double orders and recalls, save/load of fleet
  positions and old saves, play events, and retro/modern renders (`Screenshots/3.5.0/`).

### Fixed
- `PlayHistoryIntegrationTests` waited on nothing after `endTurn()`, so asynchronous AI moves could post news between
  its two syncs and fail it about one run in five; it now waits for the AI turn to finish.

## [3.4.0] - 2026-10-20 — Size your offensives

### Added
- **A sizing step before every offensive the President launches.** `AttackSizing` (CombatModel.swift) maps each attack
  to the forces it uses (`ForceKind`: ground invasion → troops; air strike, bombardment → aircraft; launch / tactical /
  strategic / preemptive / first-strike / retaliation nukes → warheads). `AttackSizingPanel` in the action sheet shows
  Probe / Standard / Overwhelming (`AttackPreset`, ×0.5 / ×1 / ×2.5) and a slider per force, bounded by what is free
  (`AttackSizing.available`: troops not on a front or garrisoning a territory; an era air arm, none before 1914, less
  aircraft lost; warheads in the stockpile, none before 1945), plus a read-out of odds, losses, world reaction and
  escalation from the engine's own functions.
- Size changes outcomes (all monotonic in m = chosen ÷ standard, documented on `AttackSizing`): success odds √m capped
  at 1; the target's relation change × (0.75 + 0.25 m); the rest of the world −4 (m − 1) and ruthlessness +5 (m − 1);
  DEFCON one step more at m ≥ 2; a new front opens with the troops sent; aircraft lost to air defences
  (`ShadowState.aircraftLost`) and a bigger raid thins the enemy line; the chosen warheads go to the existing strike.
- Expeditions to unclaimed land (3.3.0) take a troop count (1K is enough; 5K standard); the troops stay as the
  garrison (`ShadowState.garrisons`) and a larger garrison means a steadier territory.
- Play history: event `attack_ordered` with the sizes and a summary ("12 warheads"); `claimed_land` gains `troops_k`.
- 17 tests across all seven categories (381 total), including monotonicity, bounds and Standard = legacy; snapshots in
  `Screenshots/3.4.0/`.

### Unchanged
- **Standard reproduces the pre-3.4 attack exactly** (tested side by side for invasion, air strike and nukes), and
  callers that pass no size (the AI, Nova's API, the older command views) behave as before. Computer-run countries still
  attack at fixed sizes. Saves gain two optional fields; older saves load.

## [3.3.0] - 2026-10-20 — Unclaimed lands

### Added
- **Claim land no country holds in your era.** `WorldCountriesDatabase.unclaimedLands` lists the lands the era filter
  removes with no era entity standing in for them: the 45 post-colonial African states before 1960, Libya before 1951
  and South Africa before 1910. Removals a predecessor covers (Soviet republics → Russian Empire / USSR, Germany, the
  Yugoslav and Czechoslovak states, Korea, Ottoman / British-ruled lands…) never count. `GameState.unclaimedLandIDs`
  = that table for the start year minus lands already claimed, so it needs no new saved fields.
- Unclaimed land is drawn parchment (modern) / light gray (EGA) under every map filter, is selectable, gets an
  `UNCLAIMED` tag (selected or hovered at world zoom; every land wide enough when zoomed in), a hover line, an
  *Unclaimed* legend swatch and a dossier ("Unclaimed land — no government, no army") with **Send expedition**.
- `GameEngine.claimLand(_:)`: no army to fight, so the land becomes a U.S. territory at once (`CombatModel.claim`,
  reusing 3.2.0 annexation) for one action, ruthlessness +5, relations −5 rivals / −2 others / 0 allies, unrest capped
  at 20 and a small garrison. Computer-run countries never claim land; unclaimed land never takes a turn.
- **Naming territories.** `TerritoryNameSheet` opens after a claim (prefilled with the land's modern name) and from
  **Rename** on the dossier of any U.S. territory; the 3.2.0 annex option takes an optional new name (blank keeps the
  old one). `GameEngine.renameTerritory(_:to:)` and `CombatModel.validTerritoryName`: trimmed, 1–40 characters, no
  newlines or control characters; names are shown as plain text. Renaming to the same name is a no-op.
- Play history: events `claimed_land` and `renamed_territory` (with the names) via `GameEngine.logPlayEvent`.
- 19 tests across all seven categories (364 total); snapshots in `Screenshots/3.3.0/`.

### Unchanged
- Saves from 3.2.x and earlier load as before; an 1850 save from before 3.3.0 shows its African lands unclaimed.

## [3.2.0] - 2026-10-19 — Terms of surrender

### Added
- **Annex or choose the government after a U.S. victory.** When a country surrenders to the United States (or to a
  side the U.S. committed troops to), a *Terms of Surrender* sheet opens with one line from the relevant advisor on
  each option:
  - **Annex as a U.S. territory**: `Country.territoryOf`. The territory takes the owner's colour on the Alliances map
    and is hatched with a dashed border and a `U.S. TERRITORY` tag on every map filter; the legend gains *Territory*,
    the dossier and Map-tab cards a badge, and the hover line reads "U.S. TERRITORY — <name>". Its arsenal is seized
    into the U.S. stockpile, it joins the U.S. alliance and computer turns skip it. Occupation: unrest +40 (insurgent
    attacks instead of a change of government), stability −25, output −30%, relations with Eastern-bloc countries −20,
    others −10, U.S. allies −3, and ruthlessness +15.
  - **Choose the new government**: Democratic Republic, Constitutional Monarchy, Military Junta, Communist One-Party
    State, Theocracy, Provisional Government or Client State (`PostWarGovernment`), each setting government type,
    ideology, camp, stability, relations, ambition and ethic. A client state joins the victor's alliance.
- `ShadowState.pendingSettlements` holds open choices; an unanswered one falls back at the next turn to the previous
  behaviour (a government shaped like the victor's).
- 14 tests: routing for U.S., U.S.-backed and AI-vs-AI victories; annexation (arsenal, alliance, map label, world
  reaction); every government type; the client-state alliance; the next-turn default; unknown ids ignored; save/load
  round trip and pre-3.2 saves; territories never toppled by unrest; performance; and a snapshot render of the map and
  sheet in both skins (`Screenshots/3.2.0/`).

### Unchanged
- Surrenders between computer-run countries still install a government shaped like the victor's.
- Saves from 3.1.x load with no territories and nothing pending.

## [3.1.3] - 2026-10-18 — Crisis crash fix

### Fixed
- **Crash on End Turn late in a game.** Random crises picked a target country with `randomElement()!`; once no
  eligible country was left (e.g. no armed rivals after nuclear exchanges) the app trapped. All 15 crisis factories
  now return no crisis when nothing qualifies (`createCrisis` returns `CrisisEvent?`), including the Shadow
  simulation's anxiety-spike crises. Regression test: every crisis type in a disarmed and in an empty world.
- Async-unsafe `NSLock` use in a retry test helper (Swift 6 error) replaced with `withLock`.

## [3.1.2] - 2026-10-18 — Play history

### Added
- **Play-session logging** to the shared `play` schema of the Nova Games DB (`play.sessions`, `play.events`) for
  Nova's game reporter. `game='gtnw'`, `client='mac'`, player = the store's player id.
  - A new game or scenario starts a session; loading a save to continue starts a new one with `resumed_from_turn`.
  - The session id and wall-clock start are kept on the game (`ShadowState.playSessionID`, `playSessionStartedAt`;
    older saves load without them).
  - Each turn: `ticker` events for new items with severity ≥ 2, `nuclear_strike` events, and an upsert of
    `last_seen_at`, `actions` (turns this session) and a running summary. Also `game_start` and `game_over` events.
  - Game over: `ended_at`, `outcome` (`victory`/`defeat`), `score` and the full summary (the contract's GTNW keys,
    capped lists, under 64 KB). The `gtnw.game_history` row now uses the session id, so the two join.
  - Starting another game closes the open session as `abandoned`; quitting the app closes it as `quit`.
- New `PendingOp` cases `playSession` / `playEvent` on the existing offline-first queue: same retry and backoff; a
  newer upsert replaces the queued one in place (staying ahead of its events); play events are shed first when the
  queue is full; rows the DB rejects, or a missing `play` grant, are dropped and never block saves.
- 19 tests across all seven categories (327 in total).

## [3.1.1] - 2026-10-17 — Text size

### Added
- **Text size setting** (Settings › Game): 1×, 1.5×, 2×, 2.5×. The default is **2× on macOS** and 1× on iOS/iPadOS,
  where native Dynamic Type is kept. The choice is saved in UserDefaults (`GTNW.fontScale`) and applies live.
- One central factor, `FontScale.factor`. Every font goes through `Font.scaled(size:weight:design:)`,
  `Font.scaled(.style, design:)` (text styles mapped to their macOS point sizes), `Font.scaledCustom` (Retro Monaco),
  `ThemeFont` or `EGA.font`. That covers about 665 font calls across both skins, `Theme`, `ModernDesign` and
  `ModernDesignSystem`.
- Scaled SwiftUI controls replace native AppKit ones that ignore `.font`: `ScaledSegmentedPicker`, `ScaledMenuPicker`,
  `.scaledCheckbox`, and a themed **game tab bar** on macOS in place of the fixed-size `TabView` strip.
- Tests:
  - A source guard (Security) fails on any unscaled `.font(`, `Font.system`, `Font.custom`, `NSFont` or `UIFont`.
  - Unit and Functional tests check the factor maths and persistence, and that every font path doubles.
  - Frame tests check that the top bar, Situation Room, leaderboard, DB badge, Settings, scaled controls and tab bar
    fit at 2× in both skins.
  - 308 tests in total.

### Changed
- Layout at large text:
  - About 280 fixed frames (panels, sheets, leaderboard columns, map labels, the DB status badge) now scale with
    `FontScale.w`, `FontScale.h` and `FontScale.of`, capped to the screen.
  - The minimum window scales the same way.
  - The Situation Room top bar wraps onto two rows when it doesn't fit on one.
- `GameEngine.aiBackend` is now a main-actor computed property.
- `Codable` model ids are `var`, so they round-trip.

### Fixed
- Release builds now have zero compiler warnings on macOS and iOS (Swift 6 isolation, unused throwing tasks, Codable
  ids, result-builder availability).
- The iOS target builds again on iOS 15. `LabeledContent` and the macOS-only menu style are availability-gated.
- `GameStoreService.syncNow()` no longer returns a stale failure. Before, a caller could join a pass that had started
  while the DB was unreachable and get that pass's failure. Now the caller gets one fresh pass. This fixes a flaky
  performance test.

## [3.1.0] - 2026-10-17 — Games DB

### Added
- **Durable game state in the Nova Games Postgres** (database `games`, schema `gtnw`, not Nova's DB): save slots
  and autosave, leaderboard, game history, scenario progress and achievements. `GameStore` protocol with Postgres
  (PostgresNIO, TLS verify-full against the bundled games-pg CA, SCRAM), local cache and in-memory stores.
- Versioned schema migrations (run as `gtnw_owner`) with check constraints and indexes.
- **Local first, offline tolerant**: writes land on the device and queue, and a sync pass with retry and backoff
  pushes them. A top-bar badge (DB ONLINE / SYNCING / OFFLINE / LOCAL) appears in both skins.
- One-time, idempotent import of the legacy UserDefaults leaderboard and achievements and the save files, with a
  timestamped backup first and a count check (`--migrate-store`).
- Settings › Saves & DB: host and port override, plus one-time credential setup (SSH `getpw` or paste) into GTNW's
  Data Protection keychain.

### Changed
- Settings (skin, sound, window, AI backend) stay in UserDefaults. The leaderboard and achievements no longer do.

## [3.0.0] - 2026-10-17 — The Situation Room

### Added
- **Situation Room** home screen: map, seven advisors, country dossier, escalation ladder, news ticker, top bar with
  date / popularity / days to election / DEFCON / world peace.
- **Game calendar**: Day / Week / Month (default) / Year turns with 1 / 1 / 2 / 4 actions; all rates scale by game
  time; calendar-driven budget, State of the Union, polls and elections.
- **Bordered world map** (Natural Earth, public domain) with hover/click, three zoom levels and 23 filters.
- **Advice engine** (approve / caution / oppose) and standing advisor recommendations wired to ACCEPT / REJECT /
  REQUEST ALTERNATIVE; advisor resignations, firing, deaths and scandals.
- **Leader personality** (ambition, ethic, ideology, leadership) and **five threat anxieties** driving AI moves.
- **Popularity, elections, impeachment, assassination, civil war**; **federal budget**; **five-category foreign aid**.
- **War Room** combat model; **scenarios** (1990, 1962, 1983, 2025); **save slots** + autosave.
- **World Evaluation** + Presidency Summary; **City View**.
- **Retro EGA skin** alongside Modern.

### Changed
- Old saves load as one-year-per-turn games. Victory thresholds are in game years.
- Turn labels show calendar dates.

### Fixed
- The iOS target builds again (missing sources added, AppKit-only image code made cross-platform); CI builds it.
- `WarRoomView.swift` was not compiled by any target.

## [Unreleased]

### Added
- **A brain per country (PvP + PvE)** — every country can be driven by a different brain:
  `Human`, `Rule-Based AI` (default), `This Session` (live Claude Code session — true PvP),
  `Gateway-Claude` (always-on), or any local/frontier OpenAI-compatible model.
  - `Engine/AIBrain.swift` — `AIBrain` abstraction, `BrainClient` transport, vendored
    `OpenAICompatibleRequest`, `ModelRegistry.parseOllamaTags`, `LiveSessionBus`, and a
    `withMoveTimeout` guard.
  - `Engine/AIMove.swift` — pure, network-free `MoveRequest`/`MoveResponse` contract with
    `GameEngine.buildMoveRequest(for:)`, `applyMove(_:for:)`, and `legalActions(for:)`.
  - `Engine/GameEngineBrains.swift` — brain assignment map (`[countryId: AIBrain]`, defaulting
    every non-player country to `.ruleBased`) and the concurrent turn loop.
  - `Views/BrainAssignmentView.swift` — "Who plays each country?" picker.
- **Live-session PvP bus** — GTNW parks a `MoveRequest` in `nova_ops.claude_coordination`
  (via `tools/gtnw_coordination_bridge.py`) for a live session to answer, then polls for the
  `MoveResponse`. Schema: `migrations/2026-08-18_gtnw_coordination_moves.sql`.
- **Action hub** (`Views/AdvancedActionsPanel.swift`) — folds every implemented verb that
  previously lived only in the orphaned `CommandView` (SDI, cyber ops, weapons programs,
  economic diplomacy, the covert quartet) into `UnifiedCommandCenter`, grouped by category
  with proactive `.disabled` + inline reason chips ("Select a target", "Need $100B", "Unlocks 1983").
- **Turn-phase banner** — `GameEngine.TurnPhase` drives a persistent banner
  (`▶ YOUR TURN` vs `⏳ WORLD RESOLVING…`) and disables action buttons while the world resolves.
- **Reversible / real agency verbs** — `abortLaunch()` / `scheduleLaunch()` / `resolvePendingLaunch()`
  (recall a launch before it fires), `sueForPeace(from:to:)` (actually clears `activeWars`),
  `leaveAlliance(country:from:)` (mutates alliances and bumps the previously-unused
  `alliancesBroken` stat). The lying `Preemptive`/`First Strike`/`Ceasefire`/`Leave Alliance`
  Shadow-President menu labels are now wired to these real engine verbs.

### Changed
- **AI turn loop is now concurrent + non-blocking** — replaced ~195 serial LLM calls (each
  with a 200 ms main-thread sleep) with a `TaskGroup` that only calls out for non-rule-based
  countries and never blocks the main actor. Remote brains that time out fall back to rule-based AI.

## [1.6.5] - 2026-03-05

### Fixed
- **AI nuclear buildup in pre-nuclear eras** — `executeAIAction` was building 5 nukes/turn for aggressive AI countries with no era check. Iran, Afghanistan, and others were building nukes in 1837. Fixed with `gameState.currentYear >= 1945` guard.
- **Germany wrong name for pre-1871 eras** — Germany only became unified in 1871. Now correctly shows: German Confederation (pre-1871), German Empire (1871-1918), Weimar Republic (1918-1933), Nazi Germany (1933-1945), West/East Germany split (1945-1990), unified Germany (1990+)
- **Vietnam split in wrong eras** — Vietnam was split into North/South Vietnam for ALL years before 1975. Now only split for 1954-1975 (the actual historical period). Before 1954: unified Vietnam; after 1975: reunified Vietnam.

### Added
- **Action feedback with target country response** — `executeShadowPresidentAction` now logs: (1) clear ✅/❌ success/failure outcome, (2) `result.message` description, (3) target country's in-character diplomatic response based on action type, their aggressionLevel, and current relations. Response also delivered to diplomatic inbox.
- **Expanded diplomatic message actions** — `MessageCard` now shows contextual action buttons beyond Accept/Decline:
  - Alliance proposals → "Propose Non-Aggression" alternative
  - Warnings/accusations → "Issue Apology" or "Stand Firm"
  - Trade messages → "Offer Trade Deal" directly
  - War threats → "Seek Mediation"
  - Demands/statements → "Counter-Propose"
  - Accept amount uses `gameState.eraDiplomacyAmountLabel` (era-scaled)
  - Decline and Counter-Propose both generate target country responses
- **Independence Day alien invasion scenario** — `AlienInvasionScenario.swift`: rare 0.1% per-turn random event (triggerable in any era). When triggered: all wars stop, all nations temporarily allied. Five decision options: global nuclear strike, computer virus upload, communication attempt, kamikaze H-bomb, underground evacuation. Each has distinct outcomes, approval impacts, and narrative consequence text. `checkForAlienInvasion()` called from `endTurn()`. Also available as `Scenario.alienInvasion` for the What If system.

*Released by Jordan Koch*

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
