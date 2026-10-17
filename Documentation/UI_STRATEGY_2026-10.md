# GTNW UI strategy — "The Situation Room" (October 2026)

GTNW today is a WOPR-terminal game with many systems (DEFCON, 750+ crises, 132 actions, AI opponents, voice
diplomacy) spread across tabs and sheets. Shadow President (1993) did one thing GTNW doesn't: **everything happened on
one screen around a living world map**, and every decision had a face (an advisor) and a consequence you could see
(an animation, a sound, a poll, a city that got better or burned). This strategy keeps GTNW's depth and borrows that
structure.

```mermaid
flowchart TB
  subgraph TOP[Top bar]
    D[Date / turn clock] --- P[Popularity + days to election] --- DC[DEFCON] --- W[World peace level]
  end
  subgraph CENTER[Center]
    MAP[World map: real borders, hover/click countries, World / Region / Country zoom, thematic filters]
  end
  subgraph LEFT[Left rail]
    ADV[7 advisor portraits: briefing badge, mood, killed/resigned states]
  end
  subgraph RIGHT[Right rail: selected country dossier]
    G[Gauges: influence, ethic, ambition, quality of life, 5 threat anxieties] --- R[Relations, aid needed, wars]
  end
  subgraph BOTTOM[Bottom]
    ACT[Action ladder: Social / Economic / Covert / Military / Nuclear] --- NEWS[News ticker + event log]
  end
  TOP --> CENTER
  LEFT --- CENTER --- RIGHT
  CENTER --> BOTTOM
```

## Principles
1. **One home screen.** The map is always visible; actions, advisors, dossiers and news are rails and sheets around it,
   not separate tabs. Tabs remain for deep views (Budget, War Room, Factbook, Settings).
2. **Select a country, then act.** Every action starts from a country on the map; the dossier shows what you are about
   to affect and how it feels about you.
3. **Every action has a face and a consequence.** An advisor recommends (approve / caution / oppose, with a reason),
   the action plays an animation and a sound, and the result shows up as a change you can see on the map and gauges.
4. **Escalation is a ladder.** Actions are grouped Social → Economic → Covert → Military → Nuclear, left to right, so
   the player always sees how far up they are climbing (and DEFCON tracks it).
5. **Two skins, one layout.** *Modern* (the current GTNW glass/neon design system) and *Retro* (Shadow President's
   EGA palette and pixel art from the optional local Shadow Pack). A toggle switches between them.
6. **Readable at a glance.** Gauges over numbers; numbers on hover; colour = state (green calm → red crisis).

## New features (from Shadow President's systems, re-implemented in GTNW's own terms)
| Priority | Feature | Why it matters | Notes |
|---|---|---|---|
| 1 | **Real bordered world map** with hover/click, three zoom levels and ~20 thematic filters (GNP, military, nuclear, unrest, alignment, war...) | The map becomes the interface | GeoJSON borders; hit-testing via a country-id raster |
| 2 | **Advisor advice engine** wired to the existing ACCEPT / REJECT buttons; advisors can resign, be fired, be killed or face scandal | Decisions get a voice and a cost | `Advisor.generateAdvice` exists but is never called |
| 3 | **Leader personality per country**: ambition and ethic (1–6) + ideology | AI opponents behave like distinct people | Drives which actions the AI picks |
| 4 | **Five threat anxieties** per country (nuclear, military, political, economic, social) | Richer, legible AI reactions than one hostility number | Shown as dossier gauges; spikes trigger crises |
| 5 | **Popularity, polls, elections** (toggleable), impeachment and assassination endings | Domestic stakes; a reason not to nuke everyone | Ties into existing approval/Congress |
| 6 | **Five-category foreign aid with "need"** (humanitarian, economic, intelligence, military, nuclear) | Buying influence becomes a real decision | Countries react: thanks / partial / reject |
| 7 | **Federal budget** with an end-of-year cycle (taxes, defense, social, research, aid) | Money is the limiting resource | Feeds GNP growth, QoL, military power, aid pool |
| 8 | **World Evaluation**: leadership effectiveness, influence share, QoL, world peace level | Clear sense of "am I winning?" | Always-on mini gauge + globe sheet |
| 9 | **City View** for the selected country, built from tiles that grow with GNP/QoL/military and burn when nuked | Makes consequences physical | Retro tiles from the pack; modern skin can draw its own |
| 10 | **War Room**: troops by front, weekly fighting over neighbouring countries, surrender → new government | Wars become something you manage | `WarRoomView.swift` exists; needs a model |
| 11 | **Scenario loader + save/load slots** incl. a "1990" scenario (Ethiopia–Somalia war, the Iraq timeline) | Replayable setups | Event queue = dated scripted events |
| 12 | **Monthly turn mode** (optional) | Weekly combat and yearly budget fit naturally | Decision for Jordan; yearly stays default |

## Delivered on branch `shadow-pack` (2026-10-16 night)
- `Shared/ShadowPack/ShadowPack.swift` — optional local pack loader (images, GIF animations, WAV sounds) with fallbacks,
  Retro art / Sound toggles (Retro menu, Settings → Shadow Pack).
- Advisor portraits (7 Shadow President posts mapped onto GTNW cabinet titles), War Room title art.
- Action animations + sounds on EXECUTE (espionage, sabotage, surgical strike, assassination, negotiations, aid,
  nuclear threat) and nuclear/victory/crisis cinematic art and sound.
- `tools/build_shadow_pack.py` builds the pack locally; `.gitignore` blocks pack content from the public repo.

## Decisions (Jordan, 2026-10-17)
1. **Turn length:** a real calendar. Turns are a Day, Week, **Month (default)** or Year; 1 / 1 / 2 / 4 actions per
   turn; every per-turn rate is scaled by game time. ✅ Delivered.
2. **Game text:** all advisor, news and event text is written fresh in GTNW's voice. ✅ Delivered.
3. **Retro skin:** a full EGA-palette Retro skin for the whole UI, as a theme next to Modern. ✅ Delivered.

## Delivered on `main` (2026-10-17) — status of the feature table
| # | Feature | Status | Where |
|---|---|---|---|
| — | One home screen (map centre, advisors left, dossier right, ladder + ticker bottom, top bar) | ✅ | `Shared/Views/SituationRoom/SituationRoomView.swift` (first tab; compact layout on narrow screens) |
| 1 | Real bordered world map, hover/click, World/Region/Country zoom, thematic filters | ✅ 23 filters | `VectorWorldMap.swift`, `Shared/Resources/world_countries.json` (Natural Earth, public domain) |
| 2 | Advisor advice engine on ACCEPT / REJECT; resign / fired / killed / scandal | ✅ | `Shared/Engine/Shadow/AdviceEngine.swift`, `AdvisorViews.swift`, `AdvicePanel.swift` |
| 3 | Leader personality (ambition, ethic, ideology) | ✅ | `CountryProfile.swift` (`PersonalityAI` picks AI moves) |
| 4 | Five threat anxieties, dossier gauges, spikes → crises | ✅ | `AnxietyModel` in `CountryProfile.swift`, `ShadowSimulation.swift` |
| 5 | Popularity, polls, elections (toggle), impeachment, assassination | ✅ + civil war | `PopularityModel.swift` |
| 6 | Five-category foreign aid with need and reactions | ✅ | `EconomyModels.swift` (`AidModel`), Aid sheet |
| 7 | Federal budget with end-of-year cycle | ✅ | `EconomyModels.swift` (`BudgetModel`), Budget sheet |
| 8 | World Evaluation gauge + sheet | ✅ peace level in top bar; sheet with Presidency Summary | `WorldEvaluation.swift`, `SituationSheets.swift` |
| 9 | City View (grows with GNP/QoL, burns when nuked) | ✅ pack tiles in Retro, drawn in Modern | `SituationSheets.swift` (`CityView`) |
| 10 | War Room: fronts, weekly fighting, surrender → new government | ✅ | `CombatModel.swift`, `WarRoomView.swift` |
| 11 | Scenario loader + save/load slots incl. 1990 | ✅ 4 scenarios, 5 slots + autosave | `Scenarios.swift` |
| 12 | Calendar turn modes | ✅ Day / Week / Month / Year | `GameCalendar.swift` |
| — | Modern + Retro skins | ✅ | `Shared/Design/Theme.swift` (all colour tokens are theme-aware) |

## Known issue found along the way — fixed
The iOS target did not build (24 macOS sources missing from `GTNW_iOS`, AppKit-only image code). All shared sources
are now in both targets, images go through the cross-platform `PackPlatformImage`, and CI builds the iOS simulator
target.

## Still open / ideas
- Opening "text crawl" for scenarios, a self-running tutorial, natural disasters, the Factbook tab.
- Hand-tuned weights for `PersonalityAI` and the budget model after play-testing.
- Region zoom uses GTNW's 7 regions (Shadow President had 17).
