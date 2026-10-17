<#
  Guided, click-through setup for Raging Blast 2 on Windows. Started by Setup-RB2-Windows.bat.

  Nothing is installed: it asks for YOUR OWN game disc image, extracts and checks it with a built-in
  extractor, downloads portable build tools into this folder (no admin rights, nothing system-wide),
  builds rb2.exe, and puts a "Raging Blast 2" shortcut on the desktop. Safe to run again: finished
  steps are skipped, so if something fails you can just double-click the setup file again.
#>
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Out = Join-Path $Repo "out"
New-Item -ItemType Directory -Force $Out | Out-Null
$LogFile = Join-Path $Out "setup-log.txt"
try { Start-Transcript -Path $LogFile -Force | Out-Null } catch {}

$GameDir = Join-Path $env:LOCALAPPDATA "RB2Recomp\game"
$XexSize = 7151616
$XexSha1 = "F57B501FA2CDD309C2C56B76A5F297ACBC564FD2"

function Say($m) { Write-Host $m }
function Title($n, $m) { Write-Host ""; Write-Host "[$n/4] $m" -ForegroundColor Cyan }
function Fail($m) {
  Write-Host ""
  Write-Host "Setup stopped: $m" -ForegroundColor Red
  Write-Host ""
  Write-Host "Nothing is broken. Fix the problem above and double-click Setup-RB2-Windows.bat again;"
  Write-Host "it picks up where it left off. If you ask for help, attach this file:"
  Write-Host "  $LogFile"
  try { Stop-Transcript | Out-Null } catch {}
  exit 1
}
function Have($exe) { return [bool](Get-Command $exe -ErrorAction SilentlyContinue) }

Clear-Host
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  Dragon Ball: Raging Blast 2 - Windows setup" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Say ""
Say "This will take a while the first time (30-90 minutes, mostly downloading and compiling) and"
Say "needs about 25 GB of free disk space and an internet connection. You only do it once."
Say "Nothing gets installed on your PC: everything stays inside this folder."
Say ""
Say "You need YOUR OWN copy of the game: an .iso made from your Xbox 360 disc"
Say "(USA, Rev 1 / v1.1). No game files are included or downloaded."
Say ""
Say "The build tools are downloaded from their official sources (LLVM, CMake, Ninja, GitHub) and"
Say "Microsoft's C++ headers and libraries from Microsoft. Using Microsoft's files means accepting"
Say "Microsoft's licence terms: https://go.microsoft.com/fwlink/?LinkId=2086102"
Say ""
$answer = Read-Host "Type Y and press Enter to accept and continue"
if ($answer -notmatch "^[Yy]") { Fail "setup was cancelled (the licence terms were not accepted)." }

# --- Sanity checks ------------------------------------------------------------------------------
if (-not [Environment]::Is64BitOperatingSystem) { Fail "this needs 64-bit Windows 10 or 11." }
if ($Repo.Length -gt 50) {
  Fail "this folder's path is too long ($Repo). Move the whole folder to something short like C:\RB2 and try again."
}
if ($Repo -match "[^\x20-\x7E]") {
  Fail "this folder's path has special characters. Move the folder to something like C:\RB2 and try again."
}
$drive = (Get-Item $Repo).PSDrive
if ($drive.Free -lt 25GB) { Fail ("not enough free space on $($drive.Name): (need about 25 GB, have {0:N0} GB)." -f ($drive.Free / 1GB)) }

# --- 2. The game disc -----------------------------------------------------------------------------
Title 1 "Getting your game files ready"
function GameOk() {
  $x = Join-Path $GameDir "default.xex"
  if (-not (Test-Path $x)) { return "default.xex is missing" }
  if ((Get-Item $x).Length -ne $XexSize) { return "default.xex has the wrong size (this is not the supported USA Rev 1 / v1.1 disc)" }
  if ((Get-FileHash $x -Algorithm SHA1).Hash -ne $XexSha1) { return "default.xex is not the supported release (USA, Rev 1 / v1.1)" }
  $packs = @(Get-ChildItem (Join-Path $GameDir "data\X360") -Filter "st_pack_*_pt_x360.afs" -ErrorAction SilentlyContinue)
  if ($packs.Count -lt 6) { return "some game data files are missing (the disc image looks incomplete)" }
  if (-not (Test-Path (Join-Path $GameDir "data\X360\st_pack_x360.dir"))) { return "st_pack_x360.dir is missing (the disc image looks incomplete)" }
  foreach ($f in $packs) { if ($f.Length -lt 1MB) { return "$($f.Name) is far too small (the disc image looks incomplete or damaged)" } }
  return $null
}
$problem = GameOk
if ($problem) {
  Say "  Pick your game disc image (.iso) in the window that opens."
  Add-Type -AssemblyName System.Windows.Forms
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Title = "Select your Dragon Ball: Raging Blast 2 (Xbox 360) disc image"
  $dlg.Filter = "Disc images (*.iso)|*.iso|All files (*.*)|*.*"
  if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Fail "no disc image was selected." }
  $iso = $dlg.FileName
  Say "  Extracting (about 5-15 minutes, nothing is uploaded anywhere)..."
  if (Test-Path $GameDir) { Remove-Item $GameDir -Recurse -Force }
  New-Item -ItemType Directory -Force $GameDir | Out-Null
  try {
    Add-Type -Path (Join-Path $PSScriptRoot "Xiso.cs")
    $script:lastPct = -1
    [void][Xiso]::Extract($iso, $GameDir, [Action[long, long]] {
      param($done, $total)
      $pct = if ($total -gt 0) { [int](100 * $done / $total) } else { 100 }
      if ($pct -ne $script:lastPct) { $script:lastPct = $pct; Write-Progress -Activity "Extracting your disc image" -Status "$pct %" -PercentComplete $pct }
    })
    Write-Progress -Activity "Extracting your disc image" -Completed
  } catch {
    $m = $_.Exception.Message
    if ($_.Exception.InnerException) { $m = $_.Exception.InnerException.Message }
    Fail $m
  }
  $problem = GameOk
  if ($problem) { Fail "$problem." }
  Say "  Your disc image checks out. You can delete the .iso afterwards if you want the space back."
} else {
  Say "  Game files from an earlier run are in place and verified."
}

# --- 3. Build -------------------------------------------------------------------------------------
Title 2 "Building the game (this is the long part - you can leave it running)"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo "tools\desktop\build_windows.ps1") -GameDir $GameDir -Config Release -Toolchain Portable
if ($LASTEXITCODE -ne 0) { Fail "the build failed (details above and in the log)." }
$Dist = Join-Path $Out "rb2-windows"
if (-not (Test-Path (Join-Path $Dist "rb2.exe"))) { Fail "the build finished but rb2.exe was not produced." }

# --- 4. Launcher + shortcut -----------------------------------------------------------------------
Title 3 "Creating your shortcut"
$play = Join-Path $Dist "Play Raging Blast 2.bat"
Set-Content $play "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"`" `"%~dp0rb2.exe`" `"$GameDir`"`r`n" -Encoding ascii
try {
  $desktop = [Environment]::GetFolderPath("Desktop")
  $ws = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut((Join-Path $desktop "Raging Blast 2.lnk"))
  $lnk.TargetPath = Join-Path $Dist "rb2.exe"
  $lnk.Arguments = "`"$GameDir`""
  $lnk.WorkingDirectory = $Dist
  $lnk.Save()
  Say "  Added 'Raging Blast 2' to your desktop."
} catch {
  Say "  Could not create a desktop shortcut; use 'Play Raging Blast 2.bat' in:"
  Say "  $Dist"
}

# --- 5. Done ---------------------------------------------------------------------------------------
Title 4 "All done"
Write-Host ""
Write-Host "Double-click 'Raging Blast 2' on your desktop to play." -ForegroundColor Green
Say "A controller is recommended. If you see a black screen for about 5 seconds and the game closes,"
Say "your disc image was incomplete: make a fresh dump and run setup again."
Say "Please tell us how it went (GPU, Windows version, what worked or not): this build has not been tested much yet."
try { Stop-Transcript | Out-Null } catch {}
