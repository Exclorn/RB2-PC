# Dragon Ball: Raging Blast 2 on PC and Android

A static recompilation of **Dragon Ball: Raging Blast 2** (Xbox 360). The game's code is translated to
native C++ from *your own* disc, so it runs as a normal program instead of an emulator.

| Platform | Status | Start here |
|---|---|---|
| **Windows (x64)** | Experimental, untested on real hardware so far | **[WINDOWS.md](WINDOWS.md)**: unzip to a short folder like `C:\RB2` and double-click `Setup-RB2-Windows.bat` |
| **Android (arm64)** | Playable (60 fps on Snapdragon 8 Gen 2 / 8 Elite) | **[ANDROID.md](ANDROID.md#players-start-here)** and the [APK](https://github.com/moddedrounds/RB2-Android/releases/latest/download/RB2-Android.apk) from the original port |

**No game data is included or downloaded.** You need your own legally obtained copy of the Xbox 360
game (USA, Rev 1 / v1.1). Requests for game files or ISOs will be closed without reply.

The PC build is made on your own machine from your own disc, so there is no ready-made download:
nothing derived from the game may be shared. Reports from other PCs are the most useful thing you can
contribute: open a **Windows report** issue.

The Android port is by [moddedrounds](https://github.com/moddedrounds/RB2-Android); this fork adds the
Windows build. The recompilation itself is [WistfulHopes/RB2](https://github.com/WistfulHopes/RB2).

## Developer notes (original project)

Recompiled using the [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk)

## Setup

1. Ensure REXSDK is set properly in your environment - see [ReXGlue SDK](https://github.com/rexglue/rexglue-sdk) for more info
1. Extract to `assets`
1. Run cmake configure
1. Run re2_codegen utility target from cmake
1. Run cmake build for re2
1. Launch with first argument pointing to the assets folder

## Credits

- [ReXGlue](https://github.com/rexglue/rexglue-sdk) for the recompilation tools.
- [dlmalloc](https://gee.cs.oswego.edu/dl/html/malloc.html) for the heap allocator.
- [REBlue](https://github.com/rexglue/reblue) for the dlmalloc setup.
## Legal

This repository contains no game data: no disc image, `default.xex`, extracted files or recompiled
code. You need your own legally obtained copy of Dragon Ball: Raging Blast 2 for Xbox 360.
