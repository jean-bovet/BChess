# APP-6 — A computer's row says its level once

Revision 2 (2026-10-23).

- Revision 1: initial plan.
- Revision 2: Codex plan round 1 (1 SHOULD-FIX accepted): the named-computer check uses the same trimmed name as `GameText.name`, shared through one helper; a whitespace-only name gets the bare colour, tested.

Jean's request (agreed before planning): on the game screen a computer's row reads "Casual Player"
with "Black · Casual" under it, so the level appears twice. Below Maximum the line under a
computer's name shows only the colour ("Black"); at Maximum ("Full Engine") it keeps "Black · 10 s",
because the thinking time is not in the name.

The honest size: a few lines in one function, its doc comment, and the tests that pin the old text.

## 1. Problem, with evidence

- APP-3 D1 made the level the computer's name: `EngineStrength.computerName`
  (`Shared/Model/GameState.swift:30-33`), used by `GameText.name` (`Shared/Model/GameText.swift:19`).
- APP-3 also kept the level in the row detail (`planning/APP-3-strength-levels.md:490-491`):
  `GameText.sideDetail` (`Shared/Model/GameText.swift:33-37`) appends `strength.displayName` for any
  computer below Maximum. `PlayerRow` (`Shared/Views/PlayerRow.swift:33-35, 44-52`) shows name and
  detail side by side, so the row reads "Casual Player  Black · Casual".
- `sideDetail` has one caller, `PlayerRow`, which both apps use (no macOS- or iOS-specific copy).

Other places checked, no redundancy:

- `GameText.status` (`GameText.swift:49-89`) names the player once ("Casual Player is thinking…").
- `GameText.title` ("You vs Casual Player") names each player once.
- `NewGame` (`Shared/Model/NewGame.swift:28, 72`): the ladder row's name is `displayName` and the
  button is "Play the Casual Player"; neither repeats the level.
- `BChessUITests` does not read the row detail (no "·", "Club" or "Casual" text matched there; it
  only reads the `new-game-opponent-club` identifier).

## 2. Design

In `GameText.sideDetail`, the computer branch becomes:

- a computer with no given name, below Maximum: the bare colour ("Black");
- at Maximum: unchanged, "Black · 10 s" (`Int(player.thinkingTime)`);
- a computer **with a given name** (the name wins in `GameText.name`, so the level is not shown
  anywhere else): unchanged, "Black · Casual". See D1.

The rule in one sentence, for the doc comment: the detail adds the level only when the name does not
already say it. "Has a given name" must mean exactly what `GameText.name` means by it — the name
trimmed of whitespace (`GameText.swift:14`) — or `GamePlayer(name: "   ", computer: true, level: 1)`,
named "Casual Player", would get "Black · Casual" back. So the trimming moves into one private helper
in `GameText` (`givenName(of:) -> String?`, nil when empty after trimming), called by both `name` and
`sideDetail`: two callers, one rule. Update the doc comment of `sideDetail` (`GameText.swift:31-32`), which today
cites "Black · Club".

## 3. Alternatives rejected

- **Drop the level from the name instead** (back to "Computer" + "Black · Casual"): reverses APP-3 D1,
  which Jean chose; the title and status line would lose the level.
- **Drop the detail for every computer, Maximum included**: loses the thinking time, which appears
  nowhere else on the game screen.

## 4. Test plan

In `BChessTests/GameTextTests.swift`, written first and failing against today's code:

- `computerNamesAndDetails` (`:36-50`): the detail column becomes the full expected string —
  "Black"/"White" for levels 0–3, "Black · 5 s" … "White · 30 s" for 4–6 — and both `sideDetail`
  expectations (`:45-46`) compare to it. Fails today on levels 0–3 ("Black · Beginner" ≠ "Black").
  Add: a named computer (`ann`, already built at `:48`) keeps the level,
  `sideDetail(of: ann, …) == "Black · <displayName>"` for levels 0–3 (D1).
  And a whitespace-only name (`GamePlayer(name: "   ", computer: true, level:)`) is named
  "<Level> Player" and gets the bare colour for levels 0–3 — proves the shared trimming (a raw
  `name.isEmpty` check fails it).
- `sideDetails` (`:52-57`): the Club computer line (`:56`) expects "Black".

Gallery: cards that show a default Club computer change from "Black · Club" to "Black" — "Game screen
· Tall", "Game screen · Wide", "Game screen · Analyze", "Game screen · Train", "Game screen · Rotated"
and "Player row · Captures" (`BChessGalleryTests/GalleryScenarios.swift:145-172`; they use the default
players, black = Club computer). No scenario is added (the screen already has cards); the gallery gate
applies (`/preview-gallery`, `CHECK OK`, and a look at those cards).

## 5. Steps

1. **Row detail without the level** — failing `GameTextTests` changes first, then the `sideDetail`
   change and its doc comment; step gates plus the gallery.

## 6. Invariants

- I1 Files keep opening — not applicable (display text only; no format change).
- I2 Search results — not applicable.
- I3 Engine portable — not applicable.
- I4 UCI tool — not applicable.
- I5 Private and offline — not applicable.

## 7. Risks and rollout

- File-format compatibility: none, text only.
- Real device: none needed; owed only the visual check of the gallery cards above.
- Supersedes the APP-3 line "`sideDetail` for a computer is 'Black · Club'" (`APP-3-strength-levels.md:490`);
  APP-3's plan is history and is not edited.

## 8. Decision for Jean

- **D1 — a computer with a given name.** New Game never names a computer (only
  `GameState.swift:82`, `name: ""`, creates one), but a hand-edited or older `.json` file can carry a
  computer with a name; then `GameText.name` shows that name and the level would appear nowhere.
  Recommended: such a row keeps "Black · Casual" (one extra condition, tested). Alternative: always
  the bare colour below Maximum (simpler, the level is lost for that rare file).

**Decided by Jean, 2026-10-23: D1 as recommended.** A computer with its own (non-blank) name keeps "Black · <Level>".
