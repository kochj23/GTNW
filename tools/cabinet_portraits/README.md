# Cabinet portraits

Builds `Shared/Assets.xcassets/Portraits` — one period portrait per historical advisor — from public-domain images on
Wikimedia Commons. Credits for every image: `Documentation/PORTRAIT_CREDITS.md`.

| Step | Tool | What it does |
|---|---|---|
| 1 | `fetch.py advisors.tsv raw` | Finds each person's Wikipedia page and picks a **public-domain/CC0** Commons image dated as close as possible to the years they served (Nixon as VP is 1953 Nixon). Writes `sources.json`. |
| 2 | `fix.py sources.json raw` | Replaces picks that are documents, group photos or the wrong person with the page's lead portrait, plus explicit per-person overrides. |
| 3 | `swiftc -O -o faces faces.swift && ./faces raw/* > faces.tsv` | Vision face rectangle + foreground mask (`*.mask.png`) per image. |
| 4 | `stylize.py sources.json faces.tsv out` | Crops to head-and-shoulders, blacks out the background, and renders `svga` (298×228, 256-colour adaptive palette, Floyd–Steinberg) and `ega` (149×114, 4 greys, Shadow-President-era) variants with the red/yellow frame and role tag. The game ships the SVGA set. |

`advisors.tsv` is `admin, years, id, name, title`. Ids that two administrations share get the asset key
`<id>--<name slug>` (e.g. `vance--jdvance`); `CabinetPortraits.image(id:name:)` tries that key first.

Only public-domain and CC0 images are accepted. Review the contact sheet before committing: automated picks can land on
the wrong person.
