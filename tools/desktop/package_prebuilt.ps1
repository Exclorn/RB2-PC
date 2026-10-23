<#
.SYNOPSIS
  Package the rb2.exe you built into a zip that Setup-RB2-Windows.bat can use instead of compiling.

.DESCRIPTION
  Takes out\rb2-windows (made by the setup or build_windows.ps1) and writes out\rb2-windows-prebuilt.zip
  containing only rb2.exe, the DLLs (graphics plugin included) and BUILD-INFO.txt. No game data.
  Put the zip next to the setup as a folder named "prebuilt" (unzipped), or upload it as an asset of a
  GitHub release tagged "rb2-prebuilt"; the setup picks either up automatically.

  LEGAL: rb2.exe is a translation of the game's own executable (default.xex). Handing it to other people
  is distributing a derivative of a copyrighted program, which is a legal risk for whoever shares it.
  This script only packages; whether to share the result is your decision. For your own use you never
  need to share anything: the setup builds the same program on your PC.
#>
[CmdletBinding()]
param([switch]$Yes)
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Dist = Join-Path $Repo "out\rb2-windows"
$XexSha1 = "F57B501FA2CDD309C2C56B76A5F297ACBC564FD2"

if (-not (Test-Path (Join-Path $Dist "rb2.exe"))) { throw "rb2.exe is missing from $Dist. Build first (Setup-RB2-Windows.bat)." }
if (-not (Get-ChildItem $Dist -Filter "rexgpu-xenos*.dll" -ErrorAction SilentlyContinue)) { throw "the graphics plugin (rexgpu-xenos*.dll) is missing from $Dist. Build first (Setup-RB2-Windows.bat)." }
Write-Host "rb2.exe is a translation of the game's executable. Sharing it is a legal risk for you (see the notes in this script)."
if (-not $Yes) {
  $a = Read-Host "Type YES to create the package anyway"
  if ($a -ne "YES") { Write-Host "Cancelled."; exit 1 }
}
$stage = Join-Path $Repo "out\prebuilt-stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null
# Only the program and its libraries: no batch files (they hold your folder paths), logs or game files.
Get-ChildItem $Dist -File | Where-Object { $_.Extension -in ".exe", ".dll" } | Copy-Item -Destination $stage
$commit = ""
try { $commit = (& git -C $Repo rev-parse HEAD 2>$null) } catch {}
@(
  "Raging Blast 2 Windows program (rb2.exe) built from the game's own default.xex.",
  "xex_sha1=$XexSha1",
  "built=$([DateTime]::UtcNow.ToString('s'))Z",
  "source_commit=$commit",
  "Contains no game data (no disc files); it is a translation of the game's executable."
) | Set-Content (Join-Path $stage "BUILD-INFO.txt") -Encoding ascii
$zip = Join-Path $Repo "out\rb2-windows-prebuilt.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
Remove-Item $stage -Recurse -Force
Write-Host "Wrote $zip ($([int]((Get-Item $zip).Length / 1MB)) MB)"
