# Self-test for tools/desktop/Xiso.cs using synthetic disc images (no game data).
#   pwsh tools/tests/xiso_selftest.ps1        (or Windows PowerShell 5.1; needs python only for the images)
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("xiso-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force $tmp | Out-Null
$py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
& $py (Join-Path $here "make_test_iso.py") $tmp | Out-Null
Add-Type -Path (Join-Path $here "..\desktop\Xiso.cs")

$fail = 0
function Check($name, $cond) { if ($cond) { Write-Host "ok   $name" } else { Write-Host "FAIL $name"; $script:fail++ } }
function Expect-Error($name, $iso, $pattern) {
  $dest = Join-Path $tmp ("out-" + [Guid]::NewGuid().ToString("N"))
  try { [Xiso]::Extract($iso, $dest, $null) | Out-Null; Check "$name (should have failed)" $false }
  catch { $m = $_.Exception.Message; if ($_.Exception.InnerException) { $m = $_.Exception.InnerException.Message }
          Check "$name -> '$m'" ($m -match $pattern) }
  return $dest
}

foreach ($img in "ok.iso", "ok_xgd3.iso") {
  $dest = Join-Path $tmp ("x-" + $img)
  $last = 0
  $r = [Xiso]::Extract((Join-Path $tmp $img), $dest, [Action[long, long]] { param($d, $t) $script:last = $d })
  Check "${img}: 3 files" ($r.Files -eq 3)
  Check "${img}: default.xex content" ((Get-Item (Join-Path $dest "default.xex")).Length -eq 5000 -and ([IO.File]::ReadAllBytes((Join-Path $dest "default.xex"))[0] -eq 88))
  Check "${img}: nested file" ((Get-Item (Join-Path $dest "data\sub\b.bin")).Length -eq 100)
  Check "${img}: progress reached total" ($last -eq 8100)
}
$d1 = Expect-Error "truncated image is reported as incomplete" (Join-Path $tmp "truncated.iso") "incomplete"
$d2 = Expect-Error "booby-trapped name is refused" (Join-Path $tmp "evil.iso") "invalid file name"
$d3 = Expect-Error "non-disc file is refused" (Join-Path $tmp "notiso.iso") "not an Xbox"
Check "truncated image wrote nothing" (-not (Test-Path (Join-Path $d1 "default.xex")))
Remove-Item $tmp -Recurse -Force
if ($fail) { Write-Host "$fail check(s) failed"; exit 1 } else { Write-Host "all checks passed" }
