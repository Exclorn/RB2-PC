# Dragon Ball: Raging Blast 2 on PC

A static recompilation of **Dragon Ball: Raging Blast 2** (Xbox 360) for **Windows (x64)**. The game's
code is translated to native C++ from *your own* disc, so it runs as a normal program instead of an
emulator.

**Status: experimental, untested on real hardware so far.**

## Quick start

1. Click **Code > Download ZIP** and unzip it to a **short folder** such as `C:\RB2`.
2. Make an `.iso` of **your own** Xbox 360 disc (USA, Rev 1 / v1.1).
3. Double-click **`Setup-RB2-Windows.bat`** and follow the prompts. It installs the tools it needs,
   checks your disc image, builds the game and adds a desktop shortcut.

Details, requirements and troubleshooting: **[WINDOWS.md](WINDOWS.md)**.

**No game data is included or downloaded.** You need your own legally obtained copy of the game. The
build happens on your own PC from your own disc, so there is no ready-made download: nothing derived
from the game may be shared. Requests for game files or ISOs will be closed without reply.

Reports from other PCs are the most useful contribution: open a **Windows report** issue.

## Developer notes

The Windows build is driven by `tools/desktop/build_windows.ps1` (see [WINDOWS.md](WINDOWS.md)); the
code that gets built is in `desktop/game` and `src/rb2_hooks.h` / `src/rb2_resolution.h`, on top of the
[ReXGlue SDK](https://github.com/rexglue/rexglue-sdk) v0.10.0. The codegen manifest is
`config/rb2_manifest.toml` (regenerated from `rb2_config.toml` with `tools/mkmanifest.py`). The repository
root also still holds the original project's build for the older SDK (`CMakeLists.txt`, `src/main.cpp`,
`src/bdengine`), kept for reference.

## Credits

- [WistfulHopes/RB2](https://github.com/WistfulHopes/RB2): the original recompilation project.
- [moddedrounds/RB2-Android](https://github.com/moddedrounds/RB2-Android): the migration to ReXGlue SDK 0.10 (codegen manifest, hooks, resolution scaling) this build is based on.
- [Project8Recomp](https://github.com/theokyr/Project8Recomp): `win_math_compat.cpp` (BSD-3-Clause).
- [ReXGlue](https://github.com/rexglue/rexglue-sdk) for the recompilation tools.
- [dlmalloc](https://gee.cs.oswego.edu/dl/html/malloc.html) for the heap allocator.
- [REBlue](https://github.com/rexglue/reblue) for the dlmalloc setup.

## Legal

This repository contains no game data: no disc image, `default.xex`, extracted files or recompiled
code. You need your own legally obtained copy of Dragon Ball: Raging Blast 2 for Xbox 360.
