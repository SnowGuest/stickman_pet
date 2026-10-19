param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot not found: $GodotExe"
}

$proc = Start-Process -FilePath $GodotExe -ArgumentList @("--path", ".") -PassThru
Start-Sleep -Seconds 3
if ($proc.HasExited) {
    throw "Game exited before test"
}

$commandFile = Join-Path $env:TEMP "stickman_tray_cmd.txt"
"quit" | Set-Content -LiteralPath $commandFile
$proc.WaitForExit(5000) | Out-Null
$exited = $proc.HasExited
if (-not $exited) {
    Stop-Process -Id $proc.Id -Force
}

Start-Sleep -Milliseconds 800
$listeners = @(Get-NetTCPConnection -LocalPort 42871 -State Listen -ErrorAction SilentlyContinue)
$helpers = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*stickman_tray*' -and $_.CommandLine -notlike '*Get-CimInstance*' })

Write-Host "exited=$exited listeners=$($listeners.Count) helpers=$($helpers.Count)"
if (-not $exited -or $listeners.Count -ne 0 -or $helpers.Count -ne 0) {
    throw "Exit cleanup failed"
}
Write-Host "PASS exit cleanup"
