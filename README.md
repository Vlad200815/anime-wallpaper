# Anime Wallpaper

An animated, interactive macOS desktop wallpaper built on the [Rive](https://rive.app) runtime.
The anime girl on your desktop turns her head to follow your mouse cursor — anywhere on the screen,
even while you work in other apps.

- 🎞 Live vector animation, crisp on Retina at any size
- 🖱 Follows the cursor across the whole screen (no Accessibility permission needed)
- 🧩 Lives in the menu bar (✨), no Dock icon
- 🔍 Four sizes: whole figure, medium, close, fill the screen
- 🙈 Optionally hides desktop icons and widgets so only the animation is visible
- 🖥 Can stay on one desktop (Space) only, so other desktops keep your normal wallpaper
- 🔋 Pauses itself when the desktop is covered, on another Space, or the screen sleeps

## Requirements

- macOS 14 Sonoma or newer
- Xcode or the Xcode Command Line Tools (Swift 5.9+) to build it

## Install

```bash
git clone https://github.com/Vlad200815/anime-wallpaper.git
cd anime-wallpaper
./build_app.sh
cp -R AnimeWallpaper.app /Applications/
open /Applications/AnimeWallpaper.app
```

The first build downloads the Rive runtime through Swift Package Manager (about 150 MB), so it takes a
minute. After that, find the app with Spotlight (⌘ Space → "Anime") or in Launchpad.

**Start at login:** System Settings → General → Login Items → **+** → `AnimeWallpaper`.

## Using it

Everything is in the ✨ menu in the menu bar:

| Menu item | What it does |
|---|---|
| **View Wallpaper** | Shows the animation on top of everything. Press Esc or click to go back. |
| **Size** | Whole figure, Medium (default), Close, or Fill the screen (close-up, top and bottom cropped). |
| **Show on All Desktops** | Untick it while on a desktop to keep the wallpaper only on that desktop. |
| **Hide Icons & Widgets** | Covers desktop icons and widgets; app windows still stay on top. Clicks on the bare wallpaper do nothing while it is on, so you can't drag an invisible file. |
| **Quit Anime Wallpaper** | Closes it; your normal wallpaper comes back. |

Settings are remembered between launches.

### A clean desktop just for the animation

1. Open Mission Control (F3 or swipe up with three fingers) and click **+** to add a desktop.
2. Switch to it, open ✨ and untick **Show on All Desktops**.
3. Keep **Hide Icons & Widgets** on.

That desktop now shows only the animation; the others keep your usual wallpaper.

## Use your own Rive file

Any Rive file whose state machine reacts to pointer movement (a "Pointer Move" listener) works.

1. Replace `Sources/AnimeWallpaper/Resources/anime-girl.riv` with your file, keeping the name
   (or change `riveName` in `main.swift` and the resource name in `Package.swift`).
2. Run `./build_app.sh` again.

Portrait files look best in the Medium and Whole figure sizes; the sides are filled with a blurred,
dimmed copy of the same animation.

## How it works

- A borderless, full-screen window per display sits at the desktop window level, under icons and every
  app (or just above icons and widgets when **Hide Icons & Widgets** is on).
- [`RiveRuntime`](https://github.com/rive-app/rive-ios) renders the `.riv` with Metal.
- A desktop-level window receives no mouse events, so the app reads the cursor position 60 times a
  second (`NSEvent.mouseLocation`), maps the whole screen onto the whole artboard and passes it to the
  state machine as a pointer move. Reading the cursor position needs no extra permissions.

## Credits and license

- **Animation:** [Anime Girl](https://rive.app/marketplace/6421-12447-anime-girl/) by **3dfactor**, a
  remix of *Anime Girl* by **xandercorp**, licensed under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). It is included unmodified in
  `Sources/AnimeWallpaper/Resources/anime-girl.riv`.
- **Runtime:** [rive-ios](https://github.com/rive-app/rive-ios) (MIT), downloaded at build time.
- **Code:** MIT, see [LICENSE](LICENSE). The MIT license covers the code only, not the animation.

---

## 🇺🇦 Коротко українською

Анімовані шпалери для macOS: аніме-дівчина на робочому столі повертає голову за курсором.

```bash
git clone https://github.com/Vlad200815/anime-wallpaper.git
cd anime-wallpaper
./build_app.sh
cp -R AnimeWallpaper.app /Applications/
open /Applications/AnimeWallpaper.app
```

Потрібні macOS 14+ і Xcode (або Command Line Tools). Усі налаштування в меню ✨ у рядку меню:
розмір, режим перегляду, приховування іконок і віджетів, показ лише на одному робочому столі.
Автозапуск: «Системні параметри → Загальні → Об'єкти входу» → **+** → `AnimeWallpaper`.
