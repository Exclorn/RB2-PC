<#
  Guided, click-through setup for Raging Blast 2 on Windows. Started by Setup-RB2-Windows.bat.

  Nothing is installed. It asks for YOUR OWN game (a disc image, or a folder you already extracted),
  checks it, then gets the game program: a ready-made rb2.exe if one is available (a "prebuilt" folder
  here, or the repository's "rb2-prebuilt" release), otherwise it builds one from your game files with
  portable tools downloaded into this folder (no admin rights, nothing system-wide). Finally it puts a
  "Raging Blast 2" shortcut on the desktop. Safe to run again: finished steps are skipped.
  Set RB2_FORCE_BUILD=1 to build from source even when a prebuilt is available.
#>
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Out = Join-Path $Repo "out"
New-Item -ItemType Directory -Force $Out | Out-Null
$LogFile = Join-Path $Out "setup-log.txt"
try { Start-Transcript -Path $LogFile -Force | Out-Null } catch {}

. (Join-Path $PSScriptRoot "toolchain.ps1")   # download helper
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ReleaseRepo = "Exclorn/RB2-PC"       # GitHub redirects this if the repository is renamed
$PrebuiltTag = "rb2-prebuilt"
$GameDir = Join-Path $env:LOCALAPPDATA "RB2Recomp\game"
$GamePathFile = Join-Path $Out "game-path.txt"
if (Test-Path $GamePathFile) { $saved = (Get-Content $GamePathFile -Raw).Trim(); if ($saved -and (Test-Path $saved)) { $GameDir = $saved } }
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
Say "You need YOUR OWN copy of the game: a disc image (.iso) or a folder you already extracted,"
Say "from your Xbox 360 disc (USA, Rev 1 / v1.1). No game files are included or downloaded."
Say "Nothing gets installed on your PC: everything stays inside this folder."
Say ""
Say "Using a ready-made game program: about 10-20 minutes. If it has to be built on your PC instead:"
Say "30-90 minutes and about 25 GB of free space. You only do this once."
Say ""

# --- Sanity checks ------------------------------------------------------------------------------
if (-not [Environment]::Is64BitOperatingSystem) { Fail "this needs 64-bit Windows 10 or 11." }
if ($Repo.Length -gt 50) {
  Fail "this folder's path is too long ($Repo). Move the whole folder to something short like C:\RB2 and try again."
}
if ($Repo -match "[^\x20-\x7E]") {
  Fail "this folder's path has special characters. Move the folder to something like C:\RB2 and try again."
}
$drive = (Get-Item $Repo).PSDrive
if ($drive.Free -lt 12GB) { Fail ("not enough free space on $($drive.Name): (need about 12 GB, have {0:N0} GB)." -f ($drive.Free / 1GB)) }

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
  Say "  How do you have the game?"
  Say "    [Enter]  a disc image (.iso)"
  Say "    [F]      I already extracted it into a folder"
  $how = Read-Host "  Press Enter, or type F"
  Add-Type -AssemblyName System.Windows.Forms
  if ($how -match "^[Ff]") {
    $fd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fd.Description = "Select the folder that contains default.xex (your extracted Raging Blast 2 disc)"
    if ($fd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Fail "no folder was selected." }
    $GameDir = $fd.SelectedPath
    $problem = GameOk
    if ($problem) { Fail "that folder does not look right: $problem. Pick the folder that directly contains default.xex." }
    Say "  Your game folder checks out (it is used in place; nothing is copied)."
  } else {
    Say "  Pick your game disc image (.iso) in the window that opens."
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Select your Dragon Ball: Raging Blast 2 (Xbox 360) disc image"
    $dlg.Filter = "Disc images (*.iso)|*.iso|All files (*.*)|*.*"
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Fail "no disc image was selected." }
    $iso = $dlg.FileName
    $GameDir = Join-Path $env:LOCALAPPDATA "RB2Recomp\game"
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
  }
  Set-Content $GamePathFile $GameDir -Encoding ascii
} else {
  Say "  Game files from an earlier run are in place and verified."
}

# --- 2. The game program ---------------------------------------------------------------------------
Title 2 "Getting the game program (rb2.exe)"
$Dist = Join-Path $Out "rb2-windows"
function HaveProgram($dir) { return (Test-Path (Join-Path $dir "rb2.exe")) -and [bool](Get-ChildItem $dir -Filter "rexgpu-xenos*.dll" -ErrorAction SilentlyContinue) }
function UsePrebuilt($srcDir) {
  # A prebuilt folder must hold the exe AND the graphics plugin (or the game would draw nothing), and
  # BUILD-INFO.txt must say it was built for the exact game executable the user has (or it would crash).
  if (-not (HaveProgram $srcDir)) { return $false }
  $info = Join-Path $srcDir "BUILD-INFO.txt"
  if (-not (Test-Path $info) -or ((Get-Content $info -Raw) -notmatch [regex]::Escape($XexSha1))) {
    Say "  That ready-made game program is not marked as built for your game version; ignoring it."
    return $false
  }
  New-Item -ItemType Directory -Force $Dist | Out-Null
  Copy-Item (Join-Path $srcDir "*") $Dist -Recurse -Force
  return (HaveProgram $Dist)
}
$haveProgram = HaveProgram $Dist
$force = [bool]$env:RB2_FORCE_BUILD
if ($haveProgram) { Say "  The game program from an earlier run is in place." }
if (-not $haveProgram -and -not $force) {
  # A zip downloaded from the cloud build can just be dropped next to this setup (or into 'prebuilt'):
  # unpack it here, including the zip GitHub puts inside its own zip. Uses Windows' own tar.exe because
  # Explorer sometimes refuses these files with a bogus "password needed" message.
  $tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
  $zips = @(Get-ChildItem $Repo -Filter "*.zip" -File -ErrorAction SilentlyContinue) +
          @(Get-ChildItem (Join-Path $Repo "prebuilt") -Filter "*.zip" -File -ErrorAction SilentlyContinue)
  foreach ($z in $zips) {
    $tmp = Join-Path $Out "prebuilt-zip"
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
      & $tarExe -xf $z.FullName -C $tmp 2>$null
      for ($i = 0; $i -lt 2; $i++) {   # zip inside a zip
        foreach ($inner in (Get-ChildItem $tmp -Recurse -Filter "*.zip" -File)) {
          $dest = Join-Path $inner.DirectoryName ([IO.Path]::GetFileNameWithoutExtension($inner.Name) + "-unpacked")
          if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force $dest | Out-Null; & $tarExe -xf $inner.FullName -C $dest 2>$null }
        }
      }
    } catch { }
    $root = Get-ChildItem $tmp -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { HaveProgram $_.FullName } | Select-Object -First 1
    $dir = if (HaveProgram $tmp) { $tmp } elseif ($root) { $root.FullName } else { $null }
    if ($dir -and (UsePrebuilt $dir)) { $haveProgram = $true; Say "  Using the ready-made game program from $($z.Name)."; break }
  }
  if (Test-Path (Join-Path $Out "prebuilt-zip")) { Remove-Item (Join-Path $Out "prebuilt-zip") -Recurse -Force -ErrorAction SilentlyContinue }
}
if (-not $haveProgram -and -not $force) {
  $local = Join-Path $Repo "prebuilt"
  if (UsePrebuilt $local) { Say "  Using the ready-made game program in the 'prebuilt' folder."; $haveProgram = $true }
}
if (-not $haveProgram -and -not $force) {
  try {
    $rel = Invoke-RestMethod "https://api.github.com/repos/$ReleaseRepo/releases/tags/$PrebuiltTag" -Headers @{ "User-Agent" = "rb2-setup" }
    $asset = $rel.assets | Where-Object { $_.name -like "*prebuilt*.zip" } | Select-Object -First 1
    if ($asset) {
      Say "  Downloading the ready-made game program..."
      $tmp = Join-Path $Out "prebuilt-download"
      if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
      New-Item -ItemType Directory -Force $tmp | Out-Null
      $zip = Join-Path $tmp $asset.name
      Get-PortableFile $asset.browser_download_url $zip
      & (Join-Path $env:SystemRoot "System32\tar.exe") -xf $zip -C $tmp
      $root = if (HaveProgram $tmp) { $tmp } else { (Get-ChildItem $tmp -Directory | Where-Object { HaveProgram $_.FullName } | Select-Object -First 1).FullName }
      if ($root -and (UsePrebuilt $root)) { $haveProgram = $true; Say "  Ready-made game program installed." }
      else { Say "  The download was not usable; building from your game files instead." }
      Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch { }   # no prebuilt published (404) or offline: build from source below
}
if (-not $haveProgram) {
  Say "  No ready-made game program available: building it on your PC from your game files."
  Say "  This is the long part (30-90 minutes, about 25 GB free space, ~3 GB of downloads)."
  Say ""
  Say "  The build tools come from their official sources (LLVM, CMake, Ninja on GitHub) and Microsoft's"
  Say "  C++ headers and libraries from Microsoft. Using Microsoft's files means accepting Microsoft's"
  Say "  licence terms: https://go.microsoft.com/fwlink/?LinkId=2086102"
  Say ""
  $answer = Read-Host "  Type Y and press Enter to accept and continue"
  if ($answer -notmatch "^[Yy]") { Fail "setup was cancelled (the licence terms were not accepted)." }
  if ($drive.Free -lt 25GB) { Fail ("not enough free space for the build on $($drive.Name): (need about 25 GB, have {0:N0} GB)." -f ($drive.Free / 1GB)) }
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo "tools\desktop\build_windows.ps1") -GameDir $GameDir -Config Release -Toolchain Portable
  if ($LASTEXITCODE -ne 0) { Fail "the build failed (details above and in the log)." }
  if (-not (HaveProgram $Dist)) { Fail "the build finished but rb2.exe or the graphics plugin was not produced." }
}

# --- 3. Launcher + shortcut -----------------------------------------------------------------------
Title 3 "Creating your shortcut"
$play = Join-Path $Dist "Play Raging Blast 2.bat"
$GameDir = $GameDir.TrimEnd("\")   # a trailing backslash would swallow the closing quote
Set-Content $play "@echo off`r`ncd /d `"%~dp0`"`r`nstart `"`" `"%~dp0rb2.exe`" --game_data_root=`"$GameDir`"`r`n" -Encoding ascii
try {
  $desktop = [Environment]::GetFolderPath("Desktop")
  $ws = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut((Join-Path $desktop "Raging Blast 2.lnk"))
  $lnk.TargetPath = Join-Path $Dist "rb2.exe"
  $lnk.Arguments = "--game_data_root=`"$GameDir`""
  $lnk.WorkingDirectory = $Dist
  $lnk.Save()
  Say "  Added 'Raging Blast 2' to your desktop."
} catch {
  Say "  Could not create a desktop shortcut; use 'Play Raging Blast 2.bat' in:"
  Say "  $Dist"
}

# --- 4. Done ---------------------------------------------------------------------------------------
Title 4 "All done"
Write-Host ""
Write-Host "Double-click 'Raging Blast 2' on your desktop to play." -ForegroundColor Green
Say "A controller is recommended. If you see a black screen for about 5 seconds and the game closes,"
Say "your disc image was incomplete: make a fresh dump and run setup again."
Say "Please tell us how it went (GPU, Windows version, what worked or not): this build has not been tested much yet."
try { Stop-Transcript | Out-Null } catch {}
