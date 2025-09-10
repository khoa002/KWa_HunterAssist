# [KWa]HunterAssist

**[KWa]HunterAssist** is a World of Warcraft 1.12 (Vanilla) addon that provides quality-of-life utilities for Hunters.  
This is the first module in a growing suite under the `[KWa]` namespace.

---

## Compatibility

- Client: World of Warcraft 1.12.x (Lua 5.0)
- Class: Hunter
- Locale: English by default. The feed buff name can be customized for other locales or private servers.

---

## Features

### 🐺 Pet Unhappiness Alerts

- Detects when your pet becomes **Unhappy**.
- Alerts are **out of combat only** to keep fights clean.
    - If the pet becomes Unhappy during combat, one alert is queued and shown immediately after combat ends.
    - While you remain out of combat and the pet is still Unhappy, the alert repeats at a configurable interval.
- Alerts are **local only**: red screen text (UIErrorsFrame) plus optional sound.

### 🍖 Feed Pet Countdown

- When you cast **Feed Pet**, a visible countdown appears.
- Default duration: **20 seconds** (configurable).
- The countdown ends early if:
    - The feed buff ends, or
    - The pet enters combat, or
    - The pet is dismissed.
- Robust detection for 1.12:
    - Hooks `CastSpell`, `CastSpellByName`, and `UseAction` so it works from spellbook, macros, or action bar.

### 🔫 Low Ammo Warning

- Checks your equipped ammo count when leaving combat or when visiting a merchant that sells ammo.
- Alerts if the count falls below a configurable threshold (default 200), optionally plays a sound.

### 🧪 Debug Mode

- Debug mode prints detection steps so you can see what the addon is doing.
- Optional helper prints your pet’s current buff names for localization or custom servers.
- Enable via the configuration window (`/kwa config`).

---

## Configuration

Open the configuration window with `/kwa config`.

---

## Configuration Defaults

SavedVariables: `KWA_HunterAssist_Config`

    enabled  = true
    sound    = true
    interval = 5      -- seconds between repeat Unhappy alerts (out of combat only)
    feeddur  = 20     -- seconds for the Feed Pet countdown
    feedname = "Feed Pet Effect"
    ammo     = 200    -- ammo warning threshold
    ammoSound = true  -- play sound on low ammo (requires sound=true)
    merchant = true   -- alert when opening a merchant
    debug    = false  -- debug log off by default

Bounds and validation:

- `interval` is clamped to 1–60 seconds.
- `feeddur` is clamped to 3–120 seconds.

---

## Installation

1. Download or clone the repository.
2. Copy the folder into your WoW AddOns directory:

   Interface\AddOns\KWa_HunterAssist\

3. Ensure these files exist:

   KWa_HunterAssist.toc
   KWa_HunterAssist.lua
   README.md

4. Restart WoW and enable **[KWa]HunterAssist** in the AddOns list.

---

## How It Works

### Unhappy Alerts

- Listens for `UNIT_HAPPINESS` and detects transitions into Unhappy.
- Suppresses alerts while you are in combat.
- If the pet became Unhappy during combat, one alert fires on `PLAYER_REGEN_ENABLED`.
- Uses an `OnUpdate` loop to repeat the alert every `interval` seconds while still Unhappy and you remain out of combat.

### Feed Pet Countdown

- Detects casts through `CastSpell`, `CastSpellByName`, and `UseAction`.
- Waits for `UNIT_AURA` on the pet to confirm the buff, then starts a countdown for `feeddur` seconds.
- Cancels if the buff ends or the pet enters combat.
- Draws a centered text overlay using the FRIZQT font for reliable visibility on vanilla clients.

**Events and hooks used:**

- `UNIT_HAPPINESS`, `UNIT_AURA`, `UNIT_PET`, `PLAYER_ENTERING_WORLD`, `PLAYER_LOGIN`
- `SPELLCAST_START`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`
- Hooks: `CastSpell`, `CastSpellByName`, `UseAction`
- Lua 5.0 friendly. No `string:match` or other 5.1+ features.

---

## Troubleshooting

- Turn on debug in the configuration window (`/kwa config`).
    - You should see lines like:
        - `Detected Feed Pet via UseAction slot X`
        - `UNIT_AURA for pet. feedPendingCast=true`
        - `Feed buff detected -> start countdown`
- If the countdown does not start, set the buff name to `Feed Pet Effect` in the configuration window.
    - For non-English clients, set the localized buff name shown by the helper.
- If you use a macro, include `/cast Feed Pet` exactly.
- If alerts are too frequent or too quiet, adjust the interval or sound in the configuration window.

---

## Versioning

- **v0.2.0**: Unhappy alerts are out of combat only with a queued post-combat alert. Robust Feed Pet detection via
  `UseAction` in addition to `CastSpell` and `CastSpellByName`. Added debug mode and a pet buff dump helper. Font
  improvements for visibility.
- **v0.1.0**: Initial public version. Unhappy alerts with repeat interval, Feed Pet countdown, settings reset, and
  colored `[KWa]` tag in the AddOns list.

---

## Credits

- Author: Khoa Nguyen
- Part of the **[KWa]** addon suite.

---

## License

MIT License. If no license file is present, treat this repository as MIT by default.
