# Golden fixtures for GTNW Lite

GTNW Lite is a browser port of GTNW. To check it against the real game, GTNW's test suite can export
**golden fixtures**: a few seeded games played with fixed orders, written as JSON turn by turn (the orders given and
the key state that resulted). A port loads the same seed, gives the same orders and compares its state.

The exporter is test-only (`GTNWTests/GoldenExportTests.swift`) and writes only when asked.

## Generating

```bash
TEST_RUNNER_GTNW_EXPORT_GOLDEN=/absolute/path/to/fixtures \
xcodebuild test -project GTNW.xcodeproj -scheme GTNW_macOS -destination 'platform=macOS' \
  -only-testing:GTNWTests/GoldenExportIntegrationTests
```

`xcodebuild` passes `TEST_RUNNER_`-prefixed variables to the test host without the prefix, so the test sees
`GTNW_EXPORT_GOLDEN`. Without it the test is skipped. The directory is created if needed; the exporter writes
`manifest.json` and one `game-<year>-<seed>.json` per game into it and nothing anywhere else.

## How the games are played

Each game is the real game loop (`GameEngine.startNewGame(seed:)` then `endTurn()`, including the computer's moves),
on Normal difficulty, as the United States, with monthly turns. Every turn, in this order:

1. If a decision (crisis card) is waiting, choose its first option (`crisisOption: 0`).
2. Give the turn's order: `orders[t % orders.count]` (Situation Room actions, listed in the manifest), aimed at
   `ids[(t * 7) % ids.count]`, where `ids` are the ids of the live nations not run by the player, sorted by
   code-point order and `t` counts from 0.
3. End the turn and let the computer's moves finish, then record the state.

The exported games: 1789, 1962 and 2025, seed equal to the year, 12 turns each (fewer if the game ends).

## Randomness

All gameplay randomness comes from one generator per game, `GameRNG`: SplitMix64 (Steele, Lea and Flood, 2014).
State starts at the seed; each draw does

```
state = state + 0x9E3779B97F4A7C15            (mod 2^64)
z = state
z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9      (mod 2^64)
z = (z ^ (z >> 27)) * 0x94D049BB133111EB      (mod 2^64)
return z ^ (z >> 31)
```

Doubles and bounded integers come from Swift's standard conversions (`Double.random(in:using:)`,
`Int.random(in:using:)`). `manifest.rngVectors` holds the first eight raw outputs, unit doubles and 1…100 integers
from seed 42 so a port can check its generator and its conversions before comparing games. Expect exact state
agreement only as far as a port reproduces the same rules and the same order of draws; the per-turn `rngState`
shows where the draw counts part company.

## Format

All numbers are JSON numbers except 64-bit values (seeds, RNG states and raw outputs), which are 16 lowercase hex
digits as strings, because JavaScript numbers cannot hold them. Keys are sorted.

### `manifest.json`

| Key | Type | Meaning |
|-----|------|---------|
| `format` | string | Always `"gtnw-golden"` |
| `version` | int | Format version, `1` |
| `generator` | string | `"GTNW <version>"` that wrote the files |
| `orders` | [string] | The order cycle, as Situation Room action names (`"Send Ambassador"`, …) |
| `rngVectors` | object | `seed`, `next` (8 hex strings), `unitDoubles` (8 numbers in 0..<1), `d100` (8 ints in 1…100) |
| `games` | [GameInfo] | One per game file |

`GameInfo`: `file`, `year`, `seed` (hex), `player` (`"USA"`), `difficulty` (`"Normal"`), `turnLength` (`"month"`),
`turns` (turns actually played).

### `game-<year>-<seed>.json`

| Key | Type | Meaning |
|-----|------|---------|
| `format`, `version` | | As in the manifest |
| `game` | GameInfo | This game |
| `initial` | State | The board after `startNewGame`, before turn 1 (`turn` 0) |
| `turns` | [Turn] | One per turn played |

`Turn`: `turn` (the turn number after it ended, from 1), `input`, `state`.

`input`:

| Key | Type | Meaning |
|-----|------|---------|
| `action` | string | The order given, or `"none"` if no target existed |
| `target` | string? | The target nation's id |
| `crisisOption` | int? | `0` if a waiting decision was answered first, absent otherwise |

`State`:

| Key | Type | Meaning |
|-----|------|---------|
| `turn` | int | Turn number |
| `date` | string | Game date after the turn, e.g. `"Feb 20, 1789"` |
| `defcon` | int | DEFCON 5 (peace) … 1 (war) |
| `radiation` | int | Global radiation |
| `casualties` | int | Total casualties |
| `popularity` | number | The President's popularity, 0–100, two decimals |
| `gameOver` | bool | Whether the game has ended |
| `rngState` | string | `GameRNG` state after the turn (hex) |
| `wars` | [string] | Active wars as `"AGGRESSOR>DEFENDER"`, sorted |
| `nations` | [Nation] | Every nation on the board, sorted by id |

`Nation`: `id`, `warheads`, `military` (0–100), `stability` (0–100), `approval` (0–100), `destroyed`, `atWarWith`
(sorted ids), and `relationToPlayer` (−100…100; absent for the player's own nation and where no relation exists).

## Caveats

- The fixtures follow the game. A rules change in GTNW changes them; regenerate and commit them on the port's side.
- Within one GTNW build the export is reproducible: the same seed and orders give the same files.
