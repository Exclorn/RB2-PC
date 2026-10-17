<#
  Portable build tools for the Windows build: no installer, no admin rights, nothing outside the
  repository folder. Dot-source this file and call Use-PortableToolchain.

    . tools\desktop\toolchain.ps1
    Use-PortableToolchain -Root C:\RB2\out\toolchain

  Everything is downloaded from the projects' official release pages (GitHub) and Microsoft, pinned by
  SHA-256 where the file is fixed, into <Root>, and put on PATH / INCLUDE / LIB for the current
  PowerShell session only:
    LLVM 20.1.8   clang-cl + lld-link (Apache-2.0 with LLVM exception)
    CMake 3.31.8, Ninja 1.12.1
    xwin 0.6.5    fetches Microsoft's C++ headers/libraries (CRT + Windows SDK) from Microsoft
  Using Microsoft's headers and libraries means accepting Microsoft's licence terms:
  https://go.microsoft.com/fwlink/?LinkId=2086102
#>

$script:PortableTools = @(
  @{ Name = "LLVM 20.1.8 (clang-cl, lld)"; Dir = "llvm"; Marker = "bin\clang-cl.exe"; Strip = 1
     Url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-20.1.8/clang+llvm-20.1.8-x86_64-pc-windows-msvc.tar.xz"
     Sha256 = "f229769f11d6a6edc8ada599c0cda964b7dee6ab1a08c6cf9dd7f513e85b107f"; File = "llvm-20.1.8.tar.xz" },
  @{ Name = "CMake 3.31.8"; Dir = "cmake"; Marker = "bin\cmake.exe"; Strip = 1
     Url = "https://github.com/Kitware/CMake/releases/download/v3.31.8/cmake-3.31.8-windows-x86_64.zip"
     Sha256 = "81aa9964dbabd71fe02e7ec50472fd3ad56138c49944515ece9001efbff8d719"; File = "cmake-3.31.8.zip" },
  @{ Name = "Ninja 1.12.1"; Dir = "ninja"; Marker = "ninja.exe"; Strip = 0
     Url = "https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip"
     Sha256 = "f550fec705b6d6ff58f2db3c374c2277a37691678d6aba463adcbb129108467a"; File = "ninja-1.12.1.zip" },
  @{ Name = "xwin 0.6.5"; Dir = "xwin"; Marker = "xwin.exe"; Strip = 1
     Url = "https://github.com/Jake-Shadle/xwin/releases/download/0.6.5/xwin-0.6.5-x86_64-pc-windows-msvc.tar.gz"
     Sha256 = "1e711b754207d41bbac1533b5c05e22fe6ee71f9f480346c7a2b0542ff1e4f2d"; File = "xwin-0.6.5.tar.gz" }
)

function Get-PortableFile($url, $dest) {
  # curl.exe ships with Windows 10 1803+ and resumes broken downloads; fall back to Invoke-WebRequest.
  $curl = Join-Path $env:SystemRoot "System32\curl.exe"
  if (Test-Path $curl) {
    & $curl -L --fail --retry 5 --retry-delay 3 -C - -# -o $dest $url
    if ($LASTEXITCODE -ne 0) { throw "download failed: $url" }
  } else {
    $old = $ProgressPreference; $ProgressPreference = "SilentlyContinue"
    try { Invoke-WebRequest $url -OutFile $dest -UseBasicParsing } finally { $ProgressPreference = $old }
  }
}

function Use-PortableToolchain {
  param([Parameter(Mandatory = $true)][string]$Root)
  $Root = [IO.Path]::GetFullPath($Root)
  $dl = Join-Path $Root "downloads"
  New-Item -ItemType Directory -Force $Root, $dl | Out-Null
  # System tar (bsdtar, in Windows 10+): reads .zip, .tar.gz and .tar.xz. Not whatever 'tar' is on PATH:
  # GNU tar from Git for Windows mistakes "C:\..." for a remote host.
  $tar = Join-Path $env:SystemRoot "System32\tar.exe"
  if (-not (Test-Path $tar)) { throw "Windows' built-in tar.exe is missing; this needs Windows 10 (1803) or newer." }

  foreach ($t in $script:PortableTools) {
    $dir = Join-Path $Root $t.Dir
    if (Test-Path (Join-Path $dir $t.Marker)) { continue }
    Write-Host "  Downloading $($t.Name)..."
    $file = Join-Path $dl $t.File
    if (-not (Test-Path $file) -or ((Get-FileHash $file -Algorithm SHA256).Hash -ne $t.Sha256.ToUpper())) {
      if (Test-Path $file) { Remove-Item $file -Force }
      Get-PortableFile $t.Url $file
      $got = (Get-FileHash $file -Algorithm SHA256).Hash
      if ($got -ne $t.Sha256.ToUpper()) {
        Remove-Item $file -Force
        throw "$($t.Name): the download is corrupt or has been tampered with (SHA-256 mismatch). Run setup again."
      }
    }
    Write-Host "  Unpacking $($t.Name)..."
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    New-Item -ItemType Directory -Force $dir | Out-Null
    $tarArgs = @("-xf", $file, "-C", $dir)
    if ($t.Strip -gt 0) { $tarArgs += "--strip-components=$($t.Strip)" }
    & $tar @tarArgs
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $dir $t.Marker))) {
      if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
      throw "$($t.Name): unpacking failed."
    }
  }

  # Microsoft's C++ headers + libraries, via xwin (downloads ~1.5 GB from Microsoft, once).
  $sysroot = Join-Path $Root "winsdk"
  if (-not (Test-Path (Join-Path $sysroot "crt\include\vcruntime.h")) -or
      -not (Test-Path (Join-Path $sysroot "sdk\include\um\Windows.h"))) {
    Write-Host "  Downloading Microsoft's C++ headers and libraries (large, one time)..."
    if (Test-Path $sysroot) { Remove-Item $sysroot -Recurse -Force }
    $xwin = Join-Path $Root "xwin\xwin.exe"
    $cache = Join-Path $Root "xwin-cache"
    & $xwin --accept-license --timeout 900s --cache-dir $cache --arch x86_64 --disable-symlinks splat --output $sysroot
    if ($LASTEXITCODE -ne 0) { throw "could not fetch Microsoft's C++ headers and libraries (check your internet connection and run setup again)." }
    if (Test-Path $cache) { Remove-Item $cache -Recurse -Force }   # several GB of packages no longer needed
    if (-not (Test-Path (Join-Path $sysroot "crt\include\vcruntime.h"))) { throw "Microsoft's headers were not unpacked as expected." }
  }

  # Session environment: tools on PATH; clang-cl and lld-link read INCLUDE / LIB like they would under Visual Studio.
  $bins = @("llvm\bin", "cmake\bin", "ninja") | ForEach-Object { Join-Path $Root $_ }
  $env:PATH = ($bins -join ";") + ";" + $env:PATH
  $inc = @("crt\include", "sdk\include\ucrt", "sdk\include\um", "sdk\include\shared", "sdk\include\winrt") |
    ForEach-Object { Join-Path $sysroot $_ }
  $env:INCLUDE = $inc -join ";"
  $lib = @("crt\lib\x86_64", "sdk\lib\ucrt\x86_64", "sdk\lib\um\x86_64") | ForEach-Object { Join-Path $sysroot $_ }
  $env:LIB = $lib -join ";"
}

# CMake arguments for building with the portable clang-cl toolchain (the same ones the game build and
# tools\tests\toolchain_smoke.ps1 use, so the smoke test checks exactly what the build does).
# clang-cl in the MSVC-compatible driver mode, as Project8Recomp's Windows build does. The SDK passes
# GNU-style flags that clang-cl ignores (-Wno-unknown-argument keeps that from being an error).
function Get-PortableCMakeArgs {
  $flags = "--target=x86_64-pc-windows-msvc -fuse-ld=lld -march=x86-64-v2 /MD /Zc:char8_t- -Wno-unknown-argument -Wno-unused-command-line-argument"
  return @("-DCMAKE_C_COMPILER=clang-cl", "-DCMAKE_CXX_COMPILER=clang-cl",
    "-DCMAKE_LINKER=lld-link", "-DCMAKE_AR=llvm-lib", "-DCMAKE_RC_COMPILER=llvm-rc", "-DCMAKE_MT=llvm-mt",
    "-DCMAKE_C_FLAGS=$flags", "-DCMAKE_CXX_FLAGS=$flags",
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreadedDLL",   # the debug CRT is not redistributable, so never requested
    "-DCMAKE_EXE_LINKER_FLAGS=dxgi.lib")
}
