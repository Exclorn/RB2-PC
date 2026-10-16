# Dragon Ball: Raging Blast 2 on Windows (x64)

A native Windows build of the same recompilation the Android port uses. The game's PowerPC code is
translated to C++ from **your own** `default.xex` and compiled into `rb2.exe`, running on the ReXGlue
SDK's Vulkan renderer.

**Status: untested on real hardware.** The Windows target existed as a Linux-cross-compiled reference
build (see `PROGRESS.md`) and this adds a native build path for it. Nothing here has been run on a
Windows machine yet. Please report what happens (issue with your GPU, driver and the log).

No game data is included or distributed. You need your own legally obtained copy of the Xbox 360 game:
**USA, Rev 1** (title ID 4E4D0826). Your extracted `default.xex` must be 7,151,616 bytes with SHA-1
`F57B501FA2CDD309C2C56B76A5F297ACBC564FD2`. Other releases and regions are not supported.

## What you need

- Windows 10/11 x64 with a **Vulkan 1.1+** GPU driver.
- **Build Tools for Visual Studio 2022** (workload *Desktop development with C++*, which brings the
  Windows SDK). Add the *C++ Clang tools for Windows* component, or install LLVM separately.
- CMake 3.25+, Ninja, Python 3, Git:
  `winget install Kitware.CMake Ninja-build.Ninja Python.Python.3.12 Git.Git LLVM.LLVM`
- About 10 GB free, and patience: the first build compiles roughly 12,000 recompiled functions.

clang must target the **MSVC ABI** (the default for clang on Windows). MinGW will not work: the SDK
exports MSVC-mangled C++.

## Steps

1. **Extract your disc image** (an XISO or redump-style XGD2/XGD3 `.iso`):

   ```powershell
   python tools\android\xdvdfs.py C:\path\to\your-own-dump.iso C:\rb2\game
   ```

   A complete extraction holds `default.xex`, `nxeart`, and in `data\X360\` six
   `st_pack_*_pt_x360.afs` packs, `st_pack_x360.dir` and `movie\*.wmv`.

2. **Build:**

   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\desktop\build_windows.ps1 -GameDir C:\rb2\game
   ```

   The script loads the Visual Studio environment, downloads the official ReXGlue SDK v0.10.0
   win-amd64 release into `out\sdk`, runs codegen on your `default.xex`, builds, and stages
   everything in `out\rb2-windows\`. Options: `-SdkPrefix <dir>` (use your own SDK install),
   `-Config Release|RelWithDebInfo|Debug`, `-SkipCodegen` (reuse an earlier codegen).

3. **Run:**

   ```powershell
   out\rb2-windows\rb2.exe C:\rb2\game
   ```

   The first argument is the extracted game folder. Extra options are passed as `--name=value` (for example `--rb2_render_scale=75`,
   `--rb2_vsync_hz=60`, `--rb2_trace_loads=true` for debugging a failed boot).

Input comes from the SDK's SDL3 layer; a controller is recommended (keyboard mapping is untested).

## Troubleshooting

- **About five seconds of black, then the game quits:** your dump is incomplete or truncated. Check
  every file in the list above is present and not zero-filled; run with `--rb2_trace_loads=true`.
- **`rexglue.exe` or codegen errors:** confirm the `default.xex` size and SHA-1 above.
- **Link error about `roundevenf`:** `desktop/game/win_math_compat.cpp` is missing from the build
  (it is part of this repository; don't remove it).
- **No win-amd64 asset found for the SDK:** build the SDK yourself, then pass `-SdkPrefix`.

### Building the SDK from source

```powershell
git clone --branch v0.10.0 --recurse-submodules https://github.com/rexglue/rexglue-sdk.git
cd rexglue-sdk
cmake --preset win-amd64
cmake --build out\build\win-amd64 --config Release --target install --parallel
# prefix: rexglue-sdk\out\install\win-amd64
```

## Differences from the Android build

The Android port runs on a patched SDK (`patches/rexglue-sdk-android/`: Adreno/Turnip, frame
generation, power and pacing work). The Windows build uses the **stock** SDK v0.10.0, so none of
the Android-only options exist there. The game hooks (`src/rb2_hooks.h`, `src/rb2_resolution.h`) are
shared. The Android music-in-mono workaround (`--audio_force_stereo`) is an Android SDK patch and is not
in the stock SDK; if the music is quiet or missing on Windows, report it.

Cross-building from Linux is also supported with `tools/desktop/build_windows.sh` (the maintainer's
layout, using an xwin sysroot).

## Legal

This repository contains no game data: no disc image, `default.xex`, extracted files or recompiled
code. `out/` and `desktop/generated/` are git-ignored; never commit them or share the built
`rb2.exe` together with generated code, since that is a translation of the game's executable.
`desktop/game/win_math_compat.cpp` is vendored from Project8Recomp (BSD-3-Clause).
