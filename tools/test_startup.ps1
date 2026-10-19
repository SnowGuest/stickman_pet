param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe",
    [int]$LimitMs = 2000
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot not found: $GodotExe"
}

$root = (Resolve-Path ".").Path
$out = Join-Path $root "build\startup_test.out"
$err = Join-Path $root "build\startup_test.err"
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null

$proc = Start-Process -FilePath $GodotExe -ArgumentList @("--path", ".", "--quit-after", "60") `
    -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
$proc.WaitForExit(15000) | Out-Null
if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force
}

$text = Get-Content -LiteralPath $out -Raw
$match = [regex]::Match($text, "boot=(\d+)ms")
if (-not $match.Success) {
    throw "Could not find boot=...ms in startup log"
}
$boot = [int]$match.Groups[1].Value
Write-Host "boot=${boot}ms limit=${LimitMs}ms"
if ($boot -ge $LimitMs) {
    throw "Startup exceeded limit"
}
Write-Host "PASS startup"
