# TTS bottcg Deck Builder

A [Tabletop Simulator](https://www.tabletopsimulator.com/) object script that
builds a deck from a text decklist, pulling card art straight from
`cdn.bottcg.com`. Paste a `[DECK BUILDER #nnn]` export, click a button, get a
**Main Deck** and a **Life Cards** deck on the table.

## Files

| File | What it is |
|------|------------|
| [`deck-builder.lua`](deck-builder.lua) | The mod. Paste into an object's Lua script. |
| [`vanguard-deck-builder.lua`](vanguard-deck-builder.lua) | Same idea for **Cardfight!! Vanguard**: give it a [Decklog](https://decklog-en.bushiroad.com/) deck code, it fetches the list and spawns the decks. |
| [`measure-card.lua`](measure-card.lua) | Helper: prints the size of a hovered card, for matching `CARD_SCALE`. |
| [`rainbow-dice.lua`](rainbow-dice.lua) | Fun: paste into any object to make it flash rainbow while rolling/held. |

## Install

1. In TTS, spawn any object (a Block works). Right-click it → **Scripting**.
2. Select-all, delete, paste the contents of `deck-builder.lua`. Click **Save & Play**.
3. The object gets a **text field** and a **Build Deck** button.

## Use

1. Click the text field, paste your decklist, click away to commit it.
   The edited text is saved with the game.
2. Click **Build Deck**.
   - `# Main Deck` spawns beside the object.
   - `# Life Cards` spawns next to it (with its own card back).

Decklist format (the `[DECK BUILDER]` export works as-is):

```
# [DECK BUILDER #161] deck name here
# Main Deck
2x BT01-038-SCR
1x BT01-041-UR
...
# Life Cards
1x KD02-023-C
```

- `# [DECK BUILDER #nnn] <name>` → deck name.
- Every other `# Heading` → its own deck, spawned left to right.
- `Nx CODE` → N copies.
- Duplicate images are downloaded once (shared `CustomDeck` entry).

## Card codes → CDN URLs

`<set>-<number>-<rarity>` maps to `https://cdn.bottcg.com/cards/<set>-<number>.png`,
with these rules (all in `DeckBuilder.config`):

- **Rarity stripped** by default: `BT11-041-C` → `.../BT11-041.png`
- **Rarity kept** for `keepRarity` suffixes: `BT01-038-SCR` → `.../BT01-038-SCR.png`
  (currently `SCR`, `PR`, `CBR`)
- **Sub-folder** for sets in `setPath`: `SD09-004-CBR` → `.../123v1k1/SD09-004-CBR.png`

Add entries to `keepRarity` / `setPath` as you find more exceptions.

## Config knobs

Near the bottom of `deck-builder.lua`:

| Constant | Meaning |
|----------|---------|
| `CARD_SCALE` | Card size. `2.67` matches a standard bottcg card. |
| `SPAWN_OFFSET` | Where the first deck lands, relative to the script object. |
| `SPAWN_GAP` | Spacing between decks. |

In `DeckBuilder.config`: `backURL`, `sectionBack` (per-section card backs),
`sectionNamePrefix` (per-section card name prefix, e.g. Life Cards are named
`ไม่นะ! <code>`), `faceBaseURL`.

## Cardfight!! Vanguard (`vanguard-deck-builder.lua`)

A separate script that builds from a [Decklog](https://decklog-en.bushiroad.com/)
deck instead of a text list.

1. Paste `vanguard-deck-builder.lua` into an object, **Save & Play**. The object
   gets a text **field** and a **Build Deck** button.
2. Put a Decklog code in the field (the last path segment of a shared deck URL —
   `https://decklog-en.bushiroad.com/view/1TGCD` → `1TGCD`; the whole URL works
   too). Click away to commit.
3. Click **Build Deck**. The script `POST`s to
   `decklog-en.bushiroad.com/system/app/api/view/<code>` and spawns, left to right:
   - **Ride Deck** — the grade 0–3 first vanguards (`p_list`)
   - **Main Deck** — the 50-card deck (`list`)
   - **G Zone** — only if the deck has one (`sub_list`)

Card art comes from `en.cf-vanguard.com` (the `img` path in each card entry).
That CDN serves a fake 404 to TTS's downloader (it filters on the
`UnityPlayer/…` user-agent) and there's no official mirror with the same paths,
so **faces are fetched through the `wsrv.nl` image CDN** (`FACE_CDN` constant —
set it to `""` if you repoint `IMG_BASE` at a host TTS can read directly). The
card back is a direct JPG from `images.vanguardcard.io`.

### If Build Deck comes back empty

Decklog's API only answers requests that carry a `Referer` header pointing at
decklog. Some TTS builds silently drop that header (a Unity limitation), and
then the API returns nothing. No proxy needed — feed the script the JSON directly:

1. Open the deck in a browser: `https://decklog-en.bushiroad.com/view/<code>`
2. Dev-tools Console (F12) →
   ```js
   fetch('/system/app/api/view/<code>',{method:'POST'}).then(r=>r.text()).then(t=>copy(t))
   ```
3. Paste the copied blob into the field (in place of the code) and click
   **Build Deck**. A value starting with `{` is treated as deck JSON and no web
   request is made.

Config constants (top of the file): `DECK_CODE` (field default), `FACE_CDN`,
`API_HEADERS`, `CARD_BACK`, `CARD_SCALE`, `SPAWN_OFFSET`, `SPAWN_GAP`.

## Matching an existing card's size

1. Paste `measure-card.lua` into the Global script (Modding → Scripting → Global), Save & Play.
2. Options → Game Keys → bind **"Print card size"**.
3. Hover the reference card, press the key, read the **unrotated size** from the log (`~`).
4. If it differs from what you get, tweak `CARD_SCALE`.

## Notes

- Images load live from the CDN the first time a deck renders — expect a moment
  of blank cards. A card that stays blank = wrong code or missing from the CDN.
- Clear old decks/cards off the table before rebuilding.
- Uploading to the Steam Workshop bakes nothing; art is always pulled from the CDN.

## License

MIT — see [LICENSE](LICENSE).
