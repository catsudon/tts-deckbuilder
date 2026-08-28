# TTS bottcg Deck Builder

A [Tabletop Simulator](https://www.tabletopsimulator.com/) object script that
builds a deck from a text decklist, pulling card art straight from
`cdn.bottcg.com`. Paste a `[DECK BUILDER #nnn]` export, click a button, get a
**Main Deck** and a **Life Cards** deck on the table.

## Files

| File | What it is |
|------|------------|
| [`deck-builder.lua`](deck-builder.lua) | The mod. Paste into an object's Lua script. |
| [`measure-card.lua`](measure-card.lua) | Helper: prints the size of a hovered card, for matching `CARD_SCALE`. |

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
`faceBaseURL`.

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
