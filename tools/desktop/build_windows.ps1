<#
.SYNOPSIS
  Build rb2.exe (Dragon Ball: Raging Blast 2 Recompiled) natively on Windows.

.DESCRIPTION
  1. Gets the ReXGlue SDK v0.10.0 for win-amd64 with the Vulkan renderer (downloads it, or uses -SdkPrefix).
  2. Runs codegen on YOUR extracted default.xex (nothing from the disc is ever committed or shipped).
  3. Configures and builds desktop/game with clang + Ninja, staging the SDK DLLs next to rb2.exe.

  Run from any PowerShell; the script loads the Visual Studio build environment itself.

.PARAMETER GameDir
  Folder holding your extracted disc (default.xex, data\, nxeart). Use tools\xdvdfs.py to
  extract your own ISO: python tools\xdvdfs.py my.iso C:\rb2\game

.PARAMETER SdkPrefix
  An existing SDK install prefix (the folder that contains bin\, lib\ and lib\cmake\rexglue), built
  with Vulkan on. Default: download the Vulkan build of ReXGlue v0.10.0 published by this repository.

.PARAMETER Config
  Release, RelWithDebInfo (default) or Debug.

.PARAMETER SkipCodegen
  Reuse desktop\generated from an earlier run.

.PARAMETER Toolchain
  Portable: download clang, CMake, Ninja and Microsoft's C++ headers into out\toolchain (nothing is
  installed, no admin rights needed). VisualStudio: use an existing Visual Studio / Build Tools install.
  Auto (default): Visual Studio if it has the C++ tools and clang, otherwise Portable.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\desktop\build_windows.ps1 -GameDir C:\rb2\game
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$GameDir,
  [string]$SdkPrefix = "",
  [ValidateSet("Release", "RelWithDebInfo", "Debug")][string]$Config = "RelWithDebInfo",
  [switch]$SkipCodegen,
  [ValidateSet("Auto", "VisualStudio", "Portable")][string]$Toolchain = "Auto",
  # Where the Vulkan-enabled ReXGlue SDK build is published (see .github/workflows/build-sdk.yml).
  [string]$SdkRepo = "Exclorn/RB2-PC",
  [string]$SdkReleaseTag = "sdk-v0.10.0-vulkan"
)
$ErrorActionPreference = "Stop"
# Older Windows 10 builds default to TLS versions GitHub refuses.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Desktop = Join-Path $Repo "desktop"
$Out = Join-Path $Repo "out"
$GameDir = (Resolve-Path $GameDir).Path
. (Join-Path $PSScriptRoot "toolchain.ps1")

function Step($m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "error: $m" -ForegroundColor Red; exit 1 }
function Need($exe, $hint) {
  if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { Die "'$exe' not found. $hint" }
}

if (-not (Test-Path (Join-Path $GameDir "default.xex"))) { Die "no default.xex in $GameDir" }

# --- Compiler toolchain --------------------------------------------------------------------------
function Find-VisualStudio {
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (-not (Test-Path $vswhere)) { return $null }
  $p = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
  if ($p) { return $p } else { return $null }
}
$vsPath = Find-VisualStudio
$vsHasClang = $false
if ($vsPath) {
  $vsLlvm = Join-Path $vsPath "VC\Tools\Llvm\x64\bin"
  $vsHasClang = (Test-Path (Join-Path $vsLlvm "clang.exe")) -or [bool](Get-Command clang -ErrorAction SilentlyContinue)
}
$mode = $Toolchain
if ($mode -eq "Auto") { $mode = if ($vsPath -and $vsHasClang -and (Get-Command cmake -ErrorAction SilentlyContinue) -and (Get-Command ninja -ErrorAction SilentlyContinue)) { "VisualStudio" } else { "Portable" } }

if ($mode -eq "VisualStudio") {
  Step "Using Visual Studio's build environment"
  if (-not $vsPath) { Die "Visual Studio with the C++ x64 tools was not found. Use -Toolchain Portable." }
  $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
  cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match "^([^=]+)=(.*)$") { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], "Process") }
  }
  $vsLlvm = Join-Path $vsPath "VC\Tools\Llvm\x64\bin"
  if ((-not (Get-Command clang -ErrorAction SilentlyContinue)) -and (Test-Path $vsLlvm)) { $env:PATH = "$vsLlvm;$env:PATH" }
  Need clang "Add the 'C++ Clang tools for Windows' Visual Studio component, or use -Toolchain Portable."
  Need cmake "Install CMake 3.25+, or use -Toolchain Portable."
  Need ninja "Install Ninja, or use -Toolchain Portable."
  $cmakeCompilerArgs = @("-DCMAKE_C_COMPILER=clang", "-DCMAKE_CXX_COMPILER=clang++",
    "-DCMAKE_C_FLAGS=-march=x86-64-v2", "-DCMAKE_CXX_FLAGS=-march=x86-64-v2")
} else {
  Step "Preparing the portable build tools (downloads once; nothing is installed)"
  try { Use-PortableToolchain -Root (Join-Path $Out "toolchain") } catch { Die $_.Exception.Message }
  $cmakeCompilerArgs = Get-PortableCMakeArgs
  if ($Config -eq "Debug") { Write-Host "note: Debug needs Microsoft's debug runtime; using RelWithDebInfo instead."; $Config = "RelWithDebInfo" }
}
Write-Host (& clang --version | Select-Object -First 1)

# --- SDK -----------------------------------------------------------------------------------------
# The game renders with Vulkan. On Windows the stock ReXGlue SDK release is built with Direct3D 12 only
# (Vulkan is a build-time option there, off by default), so this uses an unmodified ReXGlue v0.10.0 built
# with Vulkan on and D3D12 off, published as a release of this repository by build-sdk.yml.
if (-not $SdkPrefix) {
  $sdkRoot = Join-Path $Out "sdk"
  $SdkPrefix = Join-Path $sdkRoot "win-amd64"
  if (-not (Test-Path (Join-Path $SdkPrefix "bin\rexglue.exe"))) {
    Step "Downloading the ReXGlue SDK (Vulkan build, $SdkReleaseTag)"
    New-Item -ItemType Directory -Force $sdkRoot | Out-Null
    try {
      $rel = Invoke-RestMethod "https://api.github.com/repos/$SdkRepo/releases/tags/$SdkReleaseTag" -Headers @{ "User-Agent" = "rb2-build" }
    } catch {
      Die "The Vulkan SDK build '$SdkReleaseTag' was not found in $SdkRepo. The repository owner needs to run the 'Build SDK (Vulkan)' workflow once (Actions tab), or you can build the SDK yourself (see WINDOWS.md) and pass -SdkPrefix."
    }
    $asset = $rel.assets | Where-Object { $_.name -like "*vulkan*win-amd64*.zip" } | Select-Object -First 1
    if (-not $asset) { Die "Release $SdkReleaseTag has no Vulkan win-amd64 zip." }
    $zip = Join-Path $sdkRoot $asset.name
    Get-PortableFile $asset.browser_download_url $zip
    & (Join-Path $env:SystemRoot "System32\tar.exe") -xf $zip -C $sdkRoot
    if ($LASTEXITCODE -ne 0) { Die "could not unpack the SDK download." }
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
  @cmakeCompilerArgs `
  "-DCMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO=Release" "-DCMAKE_MAP_IMPORTED_CONFIG_DEBUG=Release" `
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
# The renderer is a separate plugin file. Without it the game opens a window and draws nothing, so
# refuse to call the build finished if it is missing.
if (-not (Get-ChildItem $dist -Filter "rexgpu-xenos*.dll" -ErrorAction SilentlyContinue)) {
  Die "rexgpu-xenos*.dll (the graphics plugin) was not produced next to rb2.exe. The SDK build in use may lack it; see WINDOWS.md."
}
Write-Host ""
Write-Host "Built: $dist\rb2.exe" -ForegroundColor Green
Write-Host "Run:   $dist\rb2.exe `"$GameDir`""
