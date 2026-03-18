# Roblox-Dexter-Scripts

## ⚠️ Disclaimer: User Responsibility & Ban Warning ⚠️

**Use this at your own risk.**

I am not responsible for bans, account suspensions, or any penalties you may receive for using third-party scripts in Roblox. These scripts may violate the Roblox Terms of Service.

---

## 🚀 How to use

1. Open your Roblox script executor.
2. Paste this command:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HiIxX0Dexter0XxIiH/Roblox-Dexter-Scripts/main/loader.lua"))()
```

3. Select your mode (PVP/PVE) in the in-game GUI.

> If you are already in a supported place, the script will auto-detect and load the correct mode using `game.PlaceId`.

---

## 🔧 Main features in this repo

### `loader.lua`
- Detects `PlaceId` and loads corresponding mode (PVP/PVE).
- If unsupported place, shows GUI to manually choose mode.
- Loads remote mode scripts from this repo.

### `brm5-pvp/main.lua`
- Loads modules from `brm5-pvp/modules`.
- Handles config, GUI, aim, fullbright, wallhack, no recoil, config save/load.

### `brm5-pve/main.lua`
- Loads modules from `brm5-pve/modules`.
- Handles config, GUI, NPC tracking, silent aim, fullbright, no recoil.

---

## ✅ Updated repo changes

- Updated all remote links to use this repo (`Roblox-Dexter-Scripts`) instead of the old repo.
- `loader.lua` now uses updated `loadPvp` and `loadPve` URLs.
- PVP/PVE mode modules now use `GITHUB_BASE` paths for this repo.
- README updated with the correct loader command and usage guide.

---

## 🎮 Mode details

### ⚔️ PVP mode
- Aimbot
- Wallhack
- FOV
- Smooth
- Anti-recoil
- Config save/load
- Improved GUI

### 🤖 PVE mode
- Wallhack/markers
- Silent aim / target sizing
- Anti-recoil
- All firemodes
- Fullbright

---

## 📌 Quick tuning

Adjust `PVP_PLACE_IDS` and `PVE_PLACE_IDS` in `loader.lua` for your supported game places.

---

## 📁 Repo structure

- `loader.lua`
- `README.md`
- `brm5-pvp/main.lua`
- `brm5-pve/main.lua`
- `brm5-pvp/modules/`
- `brm5-pve/modules/`


