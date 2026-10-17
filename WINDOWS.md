# Dragon Ball: Raging Blast 2 on Windows (x64)

A native Windows build of the Raging Blast 2 recompilation. The game's PowerPC code is
translated to C++ from **your own** `default.xex` and compiled into `rb2.exe`, running on the ReXGlue
SDK's **Direct3D 12** renderer.

**Status: experimental, untested on real hardware.** This is the first native Windows build path for
this project; nothing here has been run on a Windows machine yet. Please report what happens (open a
**Windows report** issue with your GPU, driver and the log).

No game data is included or distributed. You need your own legally obtained copy of the Xbox 360 game:
**USA, Rev 1** (title ID 4E4D0826). Your extracted `default.xex` must be 7,151,616 bytes with SHA-1
`F57B501FA2CDD309C2C56B76A5F297ACBC564FD2`. Other releases and regions are not supported.

## Easy way (nothing to install)

1. On the repository page click **Code > Download ZIP**, then unzip it to a **short folder**
   such as `C:\RB2` (long folder names break the build).
2. Make an `.iso` of **your own** Xbox 360 disc (USA, Rev 1 / v1.1) and keep it somewhere handy.
3. Double-click **`Setup-RB2-Windows.bat`**, accept Microsoft's licence terms when asked, and pick your
   `.iso` in the window that opens. That's all you do. It extracts and checks the disc image, downloads
   portable build tools into the folder (no installer, no admin rights, nothing system-wide), builds
   the game (30-90 minutes, you can walk away) and puts a **Raging Blast 2** shortcut on your desktop.
4. Double-click the shortcut to play. A controller is recommended.

If anything goes wrong the window says why in plain words; fix it and run the setup file again, it
continues where it stopped. A log is saved to `out\setup-log.txt` for bug reports. You need about
25 GB of free space and an internet connection for the first run (roughly 3 GB of downloads). To
uninstall, delete the folder, the desktop shortcut and `%LOCALAPPDATA%\RB2Recomp`.

Why can't this just be a ready-made download? The game's code has to be translated from **your own
disc** on your own PC, and nothing derived from the game may be shared, so the build step can't be
skipped. It's automated instead.

**Needs:** Windows 10 (1803 or newer) or 11, 64-bit, and a GPU with **DirectX 12** support.

## For developers (manual steps)

`tools\desktop\build_windows.ps1` does the build. It picks a toolchain automatically
(`-Toolchain Auto|VisualStudio|Portable`): an existing Visual Studio / Build Tools install that has the
*C++ Clang tools* component plus CMake and Ninja, otherwise the portable download in `out\toolchain`.
clang must target the **MSVC ABI**; MinGW will not work because the SDK exports MSVC-mangled C++.

1. **Extract your disc image** (an XISO or redump-style XGD2/XGD3 `.iso`). Without Python, the setup's
   extractor (`tools\desktop\Xiso.cs`) does it; or with Python: `python tools\xdvdfs.py disc.iso C:\rb2\game`.
   A complete extraction holds `default.xex`, `nxeart`, and in `data\X360\` six `st_pack_*_pt_x360.afs`
   packs, `st_pack_x360.dir` and `movie\*.wmv`.

2. **Build:**

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\desktop\build_windows.ps1 -GameDir C:\rb2\game
   ```

   It downloads the official ReXGlue SDK v0.10.0 win-amd64 release into `out\sdk`, runs codegen on your
   `default.xex`, builds, and stages everything in `out\rb2-windows\`. Options: `-SdkPrefix <dir>`
   (use your own SDK install), `-Config Release|RelWithDebInfo|Debug`, `-SkipCodegen`, `-Toolchain`.

3. **Run:** `out\rb2-windows\rb2.exe C:\rb2\game`. The first argument is the extracted game folder.
   Extra options are passed as `--name=value` (for example `--rb2_render_scale=75`,
   `--rb2_vsync_hz=60`, `--rb2_trace_loads=true` for debugging a failed boot).

Input comes from the SDK's SDL3 layer; a controller is recommended (keyboard mapping is untested).

Self-test for the disc extractor (no game data, synthetic images): `pwsh tools\tests\xiso_selftest.ps1`.

## Troubleshooting

- **About five seconds of black, then the game quits:** your dump is incomplete or truncated. Check
  every file in the list above is present and not zero-filled; run with `--rb2_trace_loads=true`.
- **`rexglue.exe` or codegen errors:** confirm the `default.xex` size and SHA-1 above.
- **Link error about `roundevenf`:** `desktop/game/win_math_compat.cpp` is missing from the build
  (it is part of this repository; don't remove it).
- **No win-amd64 asset found for the SDK:** build the SDK yourself, then pass `-SdkPrefix`.
- **The game starts and then fails with a graphics error:** the stock SDK renders with Direct3D 12.
  Update your GPU driver, and include your GPU model in the report. Old GPUs (roughly before 2012-2013)
  may not be supported.

### Building the SDK from source

```powershell
git clone --branch v0.10.0 --recurse-submodules https://github.com/rexglue/rexglue-sdk.git
cd rexglue-sdk
cmake --preset win-amd64
cmake --build out\build\win-amd64 --config Release --target install --parallel
# prefix: rexglue-sdk\out\install\win-amd64
```

## Notes

The build uses the **stock** ReXGlue SDK v0.10.0. The game hooks are in `src/rb2_hooks.h` and
`src/rb2_resolution.h`. If the music is quiet or only plays on one speaker, report it: a mono-music quirk
of the game's audio was seen on another platform and a workaround may be needed.

Cross-building from Linux is also supported with `tools/desktop/build_windows.sh` (the maintainer's
layout, using an xwin sysroot).

## Legal

This repository contains no game data: no disc image, `default.xex`, extracted files or recompiled
code. `out/` and `desktop/generated/` are git-ignored; never commit them or share the built
`rb2.exe` together with generated code, since that is a translation of the game's executable.
`desktop/game/win_math_compat.cpp` is vendored from Project8Recomp (BSD-3-Clause).
