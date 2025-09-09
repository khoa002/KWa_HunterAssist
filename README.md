# [KWa]HunterAssist

[KWa]HunterAssist is a World of Warcraft 1.12 (Vanilla) addon that provides quality-of-life utilities for Hunters.
This is the first module in what will become a larger suite of tools under the [KWa] namespace.

---

Compatibility

- Game client: World of Warcraft 1.12.x (Lua 5.0)
- Class: Hunter
- Works with English clients out of the box. The feed buff name can be customized for other locales or private servers.

---

Features

1. Pet Unhappiness Alerts

- Detects when your pet’s happiness drops to Unhappy.
- Alerts are OUT-OF-COMBAT ONLY to avoid noise during fights.
  • If your pet becomes Unhappy during combat, one alert is queued and shown immediately after combat ends.
  • Repeats at a configurable interval while you remain out of combat and the pet is still Unhappy.
- The alert is local only (red screen text via UIErrorsFrame) with an optional sound.

2. Feed Pet Countdown

- When you cast Feed Pet, the addon starts a visible countdown timer.
- Default duration: 20 seconds (configurable).
- The countdown stops early if:
  • The feed buff is removed, or
  • The pet enters combat, or
  • The pet is dismissed.
- Robust detection: the addon detects Feed Pet whether you click the spell, press an action bar hotkey, or use “/cast Feed Pet”.
  • Hooks CastSpell, CastSpellByName, and UseAction for reliability on 1.12 clients.

3. Debug Mode

- “/kwa ha debug on” prints internal events so you can see detection in real time.
- Optional helper to print your pet’s current buff names for localization or custom servers.

---

Commands (all under “/kwa ha”)

- /kwa ha on : Enable the addon.
- /kwa ha off : Disable the addon.
- /kwa ha test : Test both the Unhappy alert and the Feed Pet countdown.
- /kwa ha sound on : Enable the alert sound.
- /kwa ha sound off : Disable the alert sound.
- /kwa ha interval <1-60> : Set repeat interval for Unhappy alerts (seconds). Default: 5.
- /kwa ha feeddur <3-120> : Set expected Feed Pet buff duration (seconds). Default: 20.
- /kwa ha feedname <buff name> : Set the pet buff name to watch for. Default: “Feed Pet Effect”.
- /kwa ha debug on : Enable debug output.
- /kwa ha debug off : Disable debug output.
- /kwa ha dumpbuffs : Print current pet buff names (if tooltip API is available).
- /kwa ha reset : Reset all settings to defaults.
- /kwa ha help : Show a quick usage summary.

---

Configuration Defaults (SavedVariables: KWA_HunterAssist_Config)

enabled = true
sound = true
interval = 5 -- seconds between repeat Unhappy alerts (out-of-combat only)
feeddur = 20 -- seconds for the Feed Pet countdown
feedname = "Feed Pet Effect"
debug = false -- debug log off by default

Bounds and validation:

- interval clamped to 1–60 seconds
- feeddur clamped to 3–120 seconds

---

Installation

1. Download or clone this repository.
2. Copy the folder into your WoW AddOns directory:
   Interface\AddOns\KWa_HunterAssist\
3. Ensure the following files are present:
   - KWa_HunterAssist.toc
   - KWa_HunterAssist.lua
   - README.md
4. Restart WoW and enable [KWa]HunterAssist from the AddOns list.

Colored AddOn Title in the in-game list (lime green [KWa]):
TOC example:

## Interface: 11200

## Title: |cff00ff00[KWa]|r HunterAssist

## Notes: Hunter utility addon. Pet Unhappy alerts + Feed Pet countdown.

## Author: Khoa Nguyen

## SavedVariables: KWA_HunterAssist_Config

KWa_HunterAssist.lua

---

How It Works

Unhappy Alerts

- Listens for UNIT_HAPPINESS and detects transitions into the Unhappy state.
- Out-of-combat only: alerts are suppressed while you are in combat.
- If the pet became Unhappy during combat, one alert is fired when PLAYER_REGEN_ENABLED occurs.
- Uses an OnUpdate loop to repeat the alert every “interval” seconds while still Unhappy and you remain out of combat.

Feed Pet Countdown

- Detects Feed Pet via multiple cast paths: CastSpell, CastSpellByName, and UseAction.
- Waits for the pet’s UNIT_AURA change to begin the countdown for “feeddur” seconds.
- Cancels automatically if the buff disappears or if the pet enters combat.
- Uses a centered text overlay with a readable FRIZQT font so it is visible on all vanilla clients.

Events/APIs used

- UNIT_HAPPINESS, UNIT_AURA, UNIT_PET, PLAYER_ENTERING_WORLD, PLAYER_LOGIN
- SPELLCAST_START, PLAYER_REGEN_DISABLED, PLAYER_REGEN_ENABLED
- Hooks: CastSpell, CastSpellByName, UseAction
- Lua 5.0-safe functions only (no string:match or 5.1+ features).

---

Troubleshooting

- Turn on debug: “/kwa ha debug on”. You should see lines like:
  • Detected Feed Pet via UseAction slot X
  • UNIT_AURA for pet. feedPendingCast=true
  • Feed buff detected -> start countdown
- If the countdown does not start on your client, try setting the buff name:
  • /kwa ha feedname Feed Pet Effect
  • For non-English clients, set the localized buff name.
- If you use a macro, ensure it includes “/cast Feed Pet” exactly so the hooks can detect it.
- If alerts feel too frequent or too quiet, adjust:
  • /kwa ha interval 10
  • /kwa ha sound off

---

Roadmap

This is the first utility in a growing Hunter toolkit. Planned items:

- Pet health and focus indicators
- Trap timers and key cooldown tracking
- Ammo or quiver capacity reminders
- Optional screen flashes and movable frames
- Module list and dispatcher under the “/kwa” umbrella for future [KWa] tools

Contributions and suggestions are welcome.

---

Versioning

- v0.2.0 — Unhappy alerts are out-of-combat only with a queued post-combat alert. Robust Feed Pet detection via UseAction in addition to CastSpell and CastSpellByName. Added debug mode and “/kwa ha dumpbuffs”. Minor UI font improvements for visibility.
- v0.1.0 — Initial public version. Pet Unhappy alerts with repeat interval, Feed Pet countdown, settings reset, and colored [KWa] tag in the AddOns list.

---

Credits

- Author: Khoa Nguyen
- Part of the [KWa] addon suite.

---

License

MIT License. See LICENSE if included, or treat this repository as MIT by default.
