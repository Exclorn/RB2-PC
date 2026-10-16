<#
.SYNOPSIS
  Build rb2.exe (Dragon Ball: Raging Blast 2 Recompiled) natively on Windows.

.DESCRIPTION
  1. Gets the ReXGlue SDK v0.10.0 for win-amd64 (downloads the official release, or uses -SdkPrefix).
  2. Runs codegen on YOUR extracted default.xex (nothing from the disc is ever committed or shipped).
  3. Configures and builds desktop/game with clang + Ninja, staging the SDK DLLs next to rb2.exe.

  Run from any PowerShell; the script loads the Visual Studio build environment itself.

.PARAMETER GameDir
  Folder holding your extracted disc (default.xex, data\, nxeart). Use tools\xdvdfs.py to
  extract your own ISO: python tools\xdvdfs.py my.iso C:\rb2\game

.PARAMETER SdkPrefix
  An existing SDK install prefix (the folder that contains bin\, lib\ and lib\cmake\rexglue).
  Default: download the v0.10.0 win-amd64 release into out\sdk.

.PARAMETER Config
  Release, RelWithDebInfo (default) or Debug.

.PARAMETER SkipCodegen
  Reuse desktop\generated from an earlier run.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\desktop\build_windows.ps1 -GameDir C:\rb2\game
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$GameDir,
  [string]$SdkPrefix = "",
  [ValidateSet("Release", "RelWithDebInfo", "Debug")][string]$Config = "RelWithDebInfo",
  [switch]$SkipCodegen
)
$ErrorActionPreference = "Stop"
$SdkTag = "v0.10.0"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Desktop = Join-Path $Repo "desktop"
$Out = Join-Path $Repo "out"
$GameDir = (Resolve-Path $GameDir).Path

function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "error: $m" -ForegroundColor Red; exit 1 }
function Need($exe, $hint) {
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { Die "'$exe' not found. $hint" }
}

if (-not (Test-Path (Join-Path $GameDir "default.xex"))) { Die "no default.xex in $GameDir" }

# --- Visual Studio environment (Windows SDK + MSVC CRT/STL that clang targets) -----------------
Step "Loading the Visual Studio build environment"
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
  Die "Visual Studio Build Tools not found. Install 'Build Tools for Visual Studio 2022' with the 'Desktop development with C++' workload (includes the Windows SDK and 'C++ Clang tools')."
}
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { Die "No Visual Studio install with the C++ x64 tools was found." }
$vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
  if ($_ -match "^([^=]+)=(.*)$") { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process") }
}
# The LLVM that ships with Visual Studio, if the standalone one is not installed.
$vsLlvm = Join-Path $vsPath "VC\Tools\Llvm\x64\bin"
if ((-not (Get-Command clang -ErrorAction SilentlyContinue)) -and (Test-Path $vsLlvm)) {
  $env:PATH = "$vsLlvm;$env:PATH"
}
Need clang "Install LLVM (winget install LLVM.LLVM) or the 'C++ Clang tools for Windows' VS component."
Need cmake "Install CMake 3.25+ (winget install Kitware.CMake)."
Need ninja "Install Ninja (winget install Ninja-build.Ninja)."
$clangVer = (& clang --version | Select-Object -First 1)
Write-Host $clangVer

# --- SDK -----------------------------------------------------------------------------------------
if (-not $SdkPrefix) {
  $sdkRoot = Join-Path $Out "sdk"
  $SdkPrefix = Join-Path $sdkRoot "win-amd64"
  if (-not (Test-Path (Join-Path $SdkPrefix "bin\rexglue.exe"))) {
    Step "Downloading ReXGlue SDK $SdkTag (win-amd64)"
    New-Item -ItemType Directory -Force $sdkRoot | Out-Null
    $rel = Invoke-RestMethod "https://api.github.com/repos/rexglue/rexglue-sdk/releases/tags/$SdkTag" `
      -Headers @{ "User-Agent" = "rb2-build" }
    $asset = $rel.assets | Where-Object { $_.name -like "*win-amd64*.zip" } | Select-Object -First 1
    if (-not $asset) {
      Die "Release $SdkTag has no win-amd64 zip. Build the SDK yourself (see WINDOWS.md, 'Building the SDK from source') and pass -SdkPrefix."
    }
    $zip = Join-Path $sdkRoot $asset.name
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip -Headers @{ "User-Agent" = "rb2-build" }
    Expand-Archive $zip -DestinationPath $sdkRoot -Force
  }
}
$SdkPrefix = (Resolve-Path $SdkPrefix).Path
$rexglue = Join-Path $SdkPrefix "bin\rexglue.exe"
if (-not (Test-Path $rexglue)) {
  # Some layouts nest the prefix one level down.
  $found = Get-ChildItem $SdkPrefix -Recurse -Filter rexglue.exe -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { $rexglue = $found.FullName; $SdkPrefix = Split-Path (Split-Path $rexglue) } else { Die "rexglue.exe not found under $SdkPrefix" }
}
Write-Host "SDK prefix: $SdkPrefix"

# --- Codegen -------------------------------------------------------------------------------------
$cfgDir = Join-Path $Desktop "config"
New-Item -ItemType Directory -Force $cfgDir | Out-Null
if (-not $SkipCodegen) {
  Step "Translating your default.xex (codegen, a few seconds)"
  $manifest = Get-Content (Join-Path $Repo "config\rb2_manifest.toml") -Raw
  # TOML wants forward slashes (backslashes are escapes inside basic strings).
  $manifest = $manifest.Replace("REPLACE_ME", ($GameDir -replace "\\", "/"))
  # UTF-8 without a BOM (Windows PowerShell 5.1's -Encoding utf8 would add one).
  [IO.File]::WriteAllText((Join-Path $cfgDir "rb2_manifest.local.toml"), $manifest, (New-Object Text.UTF8Encoding($false)))
  Push-Location $cfgDir
  try {
    $env:PATH = "$(Split-Path $rexglue);$env:PATH"
    & $rexglue codegen rb2_manifest.local.toml
    if ($LASTEXITCODE -ne 0) { Die "codegen failed (exit $LASTEXITCODE). Is default.xex the supported release? See WINDOWS.md for the expected size and SHA-1." }
  } finally { Pop-Location }
}
if (-not (Test-Path (Join-Path $Desktop "generated\default\sources.cmake"))) {
  Die "desktop\generated\default\sources.cmake is missing: codegen did not produce output."
}

# --- Build ---------------------------------------------------------------------------------------
$build = Join-Path $Desktop "build-win"
Step "Configuring ($Config)"
& cmake -S (Join-Path $Desktop "game") -B $build -G Ninja `
  "-DCMAKE_BUILD_TYPE=$Config" `
  "-DCMAKE_C_COMPILER=clang" "-DCMAKE_CXX_COMPILER=clang++" `
  "-DCMAKE_C_FLAGS=-march=x86-64-v2" "-DCMAKE_CXX_FLAGS=-march=x86-64-v2" `
  "-DCMAKE_PREFIX_PATH=$SdkPrefix"
if ($LASTEXITCODE -ne 0) { Die "cmake configure failed" }

Step "Building (the recompiled code is large: expect a long first build)"
& cmake --build $build --parallel
if ($LASTEXITCODE -ne 0) { Die "build failed" }

# --- Stage ---------------------------------------------------------------------------------------
$dist = Join-Path $Out "rb2-windows"
Step "Staging $dist"
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item (Join-Path $build "rb2.exe") $dist -Force
Get-ChildItem $build -Filter *.dll | Copy-Item -Destination $dist -Force
Write-Host ""
Write-Host "Built: $dist\rb2.exe" -ForegroundColor Green
Write-Host "Run:   $dist\rb2.exe `"$GameDir`""
