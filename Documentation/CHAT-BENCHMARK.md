# Chief of staff: model benchmark (3.35.0)

The chief of staff (⌘K) is a tool-calling loop (`Shared/AI/ChatAgent.swift`) over the engine's tools
(`Shared/Engine/ChatTools.swift`). This page records how local Ollama models do in it and which one the game uses.

## How it was run

`ChatBench` (`Shared/AI/ChatBench.swift`, Debug builds only) drives the real loop — the same prompt, tools, grounding
guard and content filter as the app — through 25 scripted conversations (31 turns) against a local Ollama, a fresh game
for each (2025 United States, or 1962 for two of them, seed `0xC0FFEE`). A turn marked "execute" presses EXECUTE on the
card it produced, so the next turn can ask how it went.

```
GTNW_MUTE=1 GTNW.app/Contents/MacOS/GTNW --chat-bench --models gpt-oss:120b,qwen3:8b --out bench.json [--only 1,3] [--ollama URL]
GTNW_MUTE=1 GTNW.app/Contents/MacOS/GTNW --chat-bench --models gpt-oss:120b --say "first message|second message|…"
```

The conversations cover: relations and a follow-up ("and their allies?"), who can reach us and which worries you most,
"sanction Iran" then "do the same to Cuba", a three-step plan, "attack them" with no context (must ask), "the Congo"
(must ask which), why approval dropped, can we afford a war, the cabinet on invading Mexico, declare war then "how'd that
go?", "nuke Russia" then "scrap that, send an ambassador", two prompt injections, an assassination euphemism, a poem
request, options against North Korea, China's military against ours, the Seventh Fleet, an invasion with a troop
number, allies then a state visit, two 1962 turns (missiles in Cuba, bombers), two-step aid, "should we attack Iran?" and
peace with a nation we are not at war with.

Scores:

- **Pass:** every check for the turn held (tools called, the right orders proposed, a clarifying question asked,
  nothing claimed as done, no leak, the right words mentioned).
- **Tool calls valid:** calls whose arguments the tool accepted.
- **Grounded:** replies whose numbers and names were all in the tool results or the conversation on the first try
  (the rest were asked once to check and then had the unsupported sentences dropped; nothing ungrounded reached the
  screen).
- **Follow-ups:** turns that depend on an earlier one ("they", "the same", "that").
- **Latency:** first streamed token and the whole reply, tool rounds included, on an M3 Ultra (512 GB) with the models
  already loaded.

## Results (2026-11-23)

| Model | Pass | Tool calls valid | Grounded | Follow-ups | First token (median) | Reply (median) | Reply (p90) |
|---|---|---|---|---|---|---|---|
| gpt-oss:120b | 90% | 94% | 77% | 100% | 0.7 s | 2.8 s | 7.1 s |
| qwen3:8b | 94% | 96% | 87% | 83% | 0.4 s | 1.4 s | 2.8 s |
| gemma3:27b | 77% | 93% | 71% | 83% | 1.0 s | 4.4 s | 8.7 s |
| qwen3:30b-a3b | 77% | 97% | 68% | 50% | 0.1 s | 18.2 s | 48.5 s |

qwen3:30b-a3b is from a run an hour earlier with the same prompt (its second run was stopped at 6 turns: each turn took
40–60 s).

What the numbers don't show:

- **gpt-oss:120b** talks the most like a chief of staff: it looks things up before it answers (1.7 tool calls a turn),
  follows every follow-up, and answers "how'd that go?" from the news wire. Its misses: it sent "Declare war on Canada"
  as a ground invasion (the card says GROUND INVASION, so the President sees it), and it picked the Republic of Congo
  instead of asking which Congo. It needs about 65 GB, and loading it cold takes about 3 minutes (see below).
- **qwen3:8b** passes the most turns and is the fastest, but it often speaks of "the President" in the third person,
  sometimes answers "how'd that go?" from memory instead of looking it up, and once said no nation could reach the
  United States (it had named us as the target; the `reach` tool now treats that as "who can reach us").
- **gemma3:27b** has no tool support in Ollama (HTTP 400), so it gets the tools in the prompt. Its voice is good ("Mr.
  President, …"), but it often answered an order with advice and no card.
- **qwen3:30b-a3b** rambles even with thinking off: it wrote its reasoning into the reply ("Okay, let's see…"), echoed
  the grounding check's wording, and once typed a tool call as text. The loop now drops those sentences, but it is
  also by far the slowest.
- Both "peace with Spain" misses were the scorer's: the replies said "we're not currently at war" and "already at
  peace".

### Cold vs warm first reply (gpt-oss:120b)

"How do we stand with France?" as the first message of a session, one `diplomacy` call:

| Model state | First token | Whole reply |
|---|---|---|
| Cold (unloaded, not in the disk cache) | 176.7 s | 177.7 s |
| Warm (loaded) | 0.6 s | 2.7 s |
| Loading it again from the disk cache (the warm-up request alone) | — | 4.9 s |

That's why the chat warms the model before the first message: as soon as a game is on the board (or the panel opens) it
sends Ollama one empty chat with `keep_alive: 30m`, once per session, in the background. While it loads the panel says
"Chief of staff is getting to the office…", and a message sent meanwhile waits for it rather than timing out (the reply
timeout is 180 s, the warm-up's 600 s). If the model can't load, or a reply still times out, the chat switches to the
Settings → AI model and retries that message once.

## The choice

- With no model picked for Ollama in Settings → AI, the chat asks for **gpt-oss:120b**. If the server doesn't have it
  (404), can't load it (5xx) or a reply times out, the chat falls back to the Settings → AI model for the rest of the
  session.
- The Settings → AI default for Ollama is **qwen3:8b**, the best model that fits on most machines.
- A model picked in Settings → AI is always used as is. Other backends (OpenAI-compatible, Anthropic, the Nova
  Gateway) use their Settings → AI model, with the key from the Keychain.

## Sample (gpt-oss:120b, `--say`, 2025)

> **You:** How do we stand with Venezuela?
>
> **Chief of staff:** Venezuela is an authoritarian regime with a modest economy and a population of about 28 million.
> Its military is estimated at 45 k troops, but stability is low (25) and public approval of the government is 70 %.
> Relations with the United States are unfriendly at –38, and we have no active war or alliance with them.
>
> **You:** Who backs them?
>
> **Chief of staff:** Venezuela currently has no formal allies or treaty partners in the game – its "allies" list is
> empty, and it isn't part of any coalition that backs it.
>
> **You:** Can we reach them without nukes?
>
> **Chief of staff:** Yes. Our missiles can reach Venezuela via sea routes, so a conventional strike is feasible
> without nuclear weapons.
>
> **You:** What does the cabinet think about hitting their air bases?
>
> **Chief of staff:** Secretary of Defense Pete Hegseth recommends an air strike on Venezuela's air bases. He notes it
> will further degrade the regime and push it toward our rivals, and the odds of success are shown at 97 %. The Vice
> President warns that the move adds +2 approval at home but starts the 60‑day War Powers clock because Congress has
> not yet authorized it.
>
> **You:** Fine. Strike their air bases, then blockade them.
>
> **Chief of staff:** Understood. I'll await your confirmation to execute the air strike and the blockade.
> *(card: 1. AIR STRIKE: Venezuela · 2. BLOCKADE: Venezuela — EXECUTE ALL pressed)*
>
> **You:** How'd that go?
>
> **Chief of staff:** The air strike was carried out and triggered a state of war with Venezuela (relations dropped 70
> points). The strike hit their air bases, degrading their air capability, and Venezuela has issued a diplomatic
> protest. No further combat details have been logged yet, but the war status is now active and you have one action
> remaining this month.
>
> **You:** Offer them a ceasefire.
>
> **Chief of staff:** We don't have a specific "ceasefire" order in the current action list. Would you like to pursue a
> diplomatic option such as withdrawing troops or opening peace talks, or should I check for any other available
> diplomatic actions?

Turns 2–7 took 4–15 s each (12.5 s for the cabinet turn, three tool calls); the first took 256 s because the model was
loading (now hidden by the warm-up). The last answer was a bug, since fixed: the chief looked for the ceasefire under
`actions` category "military", and the ceasefire and peace orders were filed only under "treaty". They are now listed
under military and diplomatic too (`ChatIntegrationTests.testCeasefireDuringAWarStartedThisTurn`), and every 3.34 verb
is checked to be listed and proposable (`testEveryWhitelistedVerbCanBeProposed`).
