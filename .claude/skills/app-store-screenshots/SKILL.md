---
name: app-store-screenshots
description: Render BChess's iPhone App Store screenshots (tilted phones, a headline in each store language, pairs of screenshots sharing one phone) from the preview-gallery captures with the `app-store-screenshots` command, review them, and upload them once approved. Use when Jean asks for new or updated App Store screenshots, to change a headline, a slide or a phone's angle, or when `/release` says the screenshots must be retaken.
allowed-tools: Read, Edit, Bash, AskUserQuestion
---

# /app-store-screenshots: marketing screenshots from the gallery captures

The screenshots are rendered, never hand-made: the app's preview gallery captures every screen, and the
`app-store-screenshots` command (on PATH) lays the captures out on slides described in
the repo's `AppStore/screenshots.json`, renders each store language with headless Chromium, and writes a review page.
A public repo names the command, never where it comes from.

The app: BChess, App Store product `BChess (iOS)` (`--app "BChess (iOS)"`). The captures come from
`scripts/snapshot-gallery.sh` (the `/preview-gallery` skill) and land in `previews/iphone/` (the iPhone pass) and
`previews/duo/` (`--device duo`). The slides file covers the iPhone 6.9" set (`APP_IPHONE_67`, 1320 x 2868), rendered
with `app-store-screenshots --captures previews/iphone`. The store languages are en-US, fr-FR, de-DE, it, ar-SA and he (the
Swiss four, then Arabic and Hebrew, which read right to left; the other reach languages come later); the app ships the
same six, so every language has its own captures (below). The iPad 13" set (`AppStore/screenshots-ipad.json`, 2064 x 2752) now comes from the iPad pass (`scripts/snapshot-gallery.sh
--device ipad`, captures in `previews/ipad/ipad/`, rendered with `--config AppStore/screenshots-ipad.json --captures previews/ipad/ipad`).
The Mac set (`AppStore/screenshots-mac.json`, 2880 x 1800) comes from the Mac pass (`scripts/snapshot-mac.sh`, captures in
`previews/mac/mac/`, rendered with `app-store-screenshots --config AppStore/screenshots-mac.json --captures previews/mac/mac`
into `.build/app-store-screenshots-mac/`). Upload with `app-store screenshots --display-type APP_IPAD_PRO_3GEN_129` / `--platform MAC_OS --display-type APP_DESKTOP`.
The iPhone Duo sets come from the `--device duo` pass (`previews/duo/`): the inner set (`AppStore/screenshots-duo-inner.json`,
2853 x 2007, `"device": "duo"`, rendered with `--captures previews/duo/duo-inner`) and the outer set
(`AppStore/screenshots-duo-outer.json`, 1398 x 2034, `"device": "duo-outer"`, `--captures previews/duo/iphone`).

## 1. Captures

Refresh the captures first when the UI changed since the last gallery run: the slides use the gallery's PNGs by
name (`"capture": "<slug>"` or `"<slug>.dark"`). A slide that needs a screen state the gallery does not have gets a
new gallery scenario (the `/preview-gallery` rules), never a hand-made capture. When the store pages show the app in
each language, re-render the slides' captures in those languages too (`--only` and `--lang`, see the slides file
below): stale localized captures show an older UI than the English one. A localized capture that is missing falls
back to English silently: before rendering, list every slide capture missing from each language folder.

The slides' captures in each language (run right before rendering, one per device pass; the review set of
`/preview-gallery` is a superset, so a language run for review serves too):

```sh
scripts/snapshot-gallery.sh --no-open --only "game-screen-engine-on,new-game-club,games-list-four-games" --lang fr,de,it,he,ar
scripts/snapshot-gallery.sh --no-open --device ipad --only "game-screen-engine-on,new-game-club,games-list-four-games,game-screen-wide" --lang fr,de,it,he,ar
scripts/snapshot-gallery.sh --no-open --device duo --only "game-screen-engine-on,new-game-club,games-list-four-games,duo-inner-landscape-game-screen" --lang fr,de,it,he,ar
scripts/snapshot-mac.sh --no-open --lang fr,de,it,he,ar
```

The dark captures (`<slug>.dark`) come with each run. The captures land in `previews/<platform>/<lang>/` where the renderer
looks (iPhone `previews/iphone/fr/`, iPad `previews/ipad/ipad/fr/`, Duo inner `previews/duo/duo-inner/fr/`, outer
`previews/duo/iphone/fr/`, Mac `previews/mac/mac/fr/`); the locale codes of the slides files are the store's (`fr-FR`,
`de-DE`, `it`, `ar-SA`, `he`), the folders' the app's (`fr`, `de`, `it`, `ar`, `he`).

Hebrew and Arabic are right to left, and the renderer lays their headlines out right to left (letter-spacing off, joined
letters). Whether their storefronts show a locale's screenshots right to left too is unverified until the first upload:
open the live page on a device set to Hebrew, then Arabic. BChess has no two-panel pair, so no caption swap is needed;
if the carousel's order looks wrong, report it to Jean.

## 2. Render

```sh
app-store-screenshots --captures previews/iphone                  # every language -> .build/app-store-screenshots/<locale>/NN-<slide>.png
app-store-screenshots --captures previews/iphone --locale fr-FR   # one language
```

It checks the slides first and stops with one line per problem: a language without text, captions that do not match a
slide's panels, a missing capture, more than the App Store's 10 screenshots. It reports a headline shrunk to fit.

## 3. Review

The review page (`.build/app-store-screenshots/index.html`) opens with one row per language, in store order. Look at
the PNGs yourself first (Read a few, the longest language above all): the headline reads, a phone is not cut where it
should not be, a pair's two halves line up. Then show Jean and wait for his go. Never upload what he has not seen.

## 4. Upload

Only inside `/release`, or when Jean asks: one call per language and display type, the files in their numbered order
(a pair's two halves must stay neighbours):

```sh
app-store screenshots --app <product> --version <v> --locale <locale> --display-type <type> \
  .build/app-store-screenshots/<locale>/*.png
```

The two iPhone Duo sets go through the App Asset Library, not a display type: one
call per locale with both sets' files in page order (the inner display's slides, then the outer's; at most 10
together, PNG without alpha at 2853 x 2007 / 2007 x 2853 / 1398 x 2034 / 2034 x 1398). It replaces the locale's Duo
placements and reuses an image the library already holds, so a rerun with the same files only redoes the order:

```sh
app-store screenshots --app "BChess (iOS)" --version <v> --locale en-US --display-class IPHONE_DUO \
  .build/app-store-screenshots-duo-inner/en-US/*.png .build/app-store-screenshots-duo-outer/en-US/*.png
```

`app-store check` then lists them as `IPHONE_DUO: <n> (asset library)`. Sizes, badge and the April 2027 deadline:
`docs/iphone-duo.md`, next to the tools the global working agreement names.

After the upload, `app-store check --version <v> --families <families>` must report 0 problems: here
`app-store check --app "BChess (iOS)" --platform IOS --version <v> --families iphone,ipad` (and `--platform MAC_OS
--families mac` after a Mac set).

## The slides file (`AppStore/screenshots.json`)

- `displayType`, `width`, `height`: the App Store set it renders (iPhone 6.9": `APP_IPHONE_67`, 1320 x 2868).
- `locales`: the store languages, in store order.
- `slides`: in display order. Each has an `id`, a CSS `background`, `phones` (a `capture` and a CSS `style` that places
  and tilts it: `left`, `top`, `transform: perspective(...) rotateX/Y/Z(...) scale(...)`) and `text`: per locale, one
  `{ "title", "sub" }` per panel; `\n` breaks the title.
- Captures in the app's own languages: a capture `X` (or `dir/X`) shows as `<locale>/X` or `<language>/X` (`dir/fr/X`)
  in the locale that has one; a locale without one shows the English capture. The gallery itself stays English: render
  only the slides' captures in each other store language, right before rendering the slides (`scripts/snapshot-gallery.sh
  --only <the slides' captures> --lang fr,de`, the same for each device family). Never a full gallery in another
  language.
- `"device"` per phone: `"iphone"` (the default), `"ipad"` (a thin uniform bezel, no island: the iPad set, 2048 x 2732,
  `APP_IPAD_PRO_3GEN_129`, from an iPad gallery pass), `"duo"` (the iPhone Duo's inner display: an open book with a thin
  bezel and a hinge line, no island; the inner set, 2853 x 2007, from a `--device duo` gallery pass), `"duo-outer"` (its
  outer display: the iPhone rim with the Duo's asymmetric corners, no island; the outer set, 1398 x 2034, from the
  phone-sized captures of that pass) or `"window"` (a Mac window capture shown at its natural size with
  a shadow, no frame: the Mac set, 2880 x 1800, `APP_DESKTOP`). A config-level `"textStyle"` adds CSS to every headline
  block (e.g. centred above a Mac window). One slides file per set; upload each with its own `--display-type` (the Mac
  set with `--platform MAC_OS`; the two Duo sets together with `--display-class IPHONE_DUO`, §4).
- A phone can also carry its device chrome: `"statusBar": "dark"` or `"light"` (9:41, signal, Wi-Fi and battery in the
  color the screen under them needs) and `"buttons": true` (action, volume and side buttons).
- `"panels": 2` makes a pair: one canvas two screenshots wide, cut in two, so one phone can lie across the seam. Its
  two titles read as one sentence ("A trillion times deeper" / "and every detail stays sharp").

## The product page header and the search results asset

On iOS 27 and later the App Store shows a creative asset at the top of the product page and in search results
(without one, it falls back to screenshots and previews). PNG, no alpha, one per placement and localization. Either one
**universal** image serves both (5244 x 2950, 16:9), or each gets its own: the **header** 3840 x 1646 (21:9) and the
**search results** asset 3:2 (1920 x 1280 to 3840 x 2560). Each image has its own slides file, rendered by the same
command into `.build/app-store-<slides file name>/`:

```sh
app-store-screenshots --config AppStore/header.json            # e.g. one per placement
app-store-screenshots --config AppStore/search-results.json
```

- Keep it simple, as Apple asks: `"max": 1`, one slide, no `text` (a text-less image serves every language), a plain
  field with one motif and, where a phone shows the app, one upright phone with its device chrome (no tilt), the way
  Apple's own examples look. The iPhone product page keeps only the middle of the header: centre the motif there.
- `"backgroundImage"` names a full-size render among the captures (e.g. `artwork/<name>`, rendered at the asset's exact
  size): never upscale a screen capture. `"guides"` draw the art safe area from Apple's templates on the review page:
  universal x 1921..3323, y 660..1622; header x 1097..2743, y 493..1154; search results x 836..3004, y 765..1795.
- Upload: `app-store creative --placement header|search|both FILE` (`both` = the universal image) puts it in the app's
  asset library (reused when the same file is already there); with `--version <v>` (an editable version) it is also
  placed on every locale, replacing the previous one. It goes through App Review with that version.

## Rules

- The screenshots must show the app's real UI (App Review): tilted is fine, a mock-up of a screen the app does not have
  is not. Keep the tilt moderate so the UI stays readable.
- Headlines in every store language, written in the tone of that language's store description (formal or informal
  address as it does). Keep claims to what the description already says.
- No Apple product artwork in the repo: the phone is drawn in CSS by the renderer.
- The output (`.build/`) and the captures are not committed; the slides file is.

The slides tell: the game screen with the engine readout on (hero, and again in dark), the five computer strengths of the
New Game sheet, and the Games list (no variations slide: the app never creates variations by play, so it would mislead). The captures are 2x
(804 x 1748 px, the hosting iPhone's screen at 2x); `launch-empty-library` carries the real navigation and bottom bars,
the other game cards mount the game screen without the shell.
