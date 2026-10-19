param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe",
    [double]$LimitPx = 2.0
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot not found: $GodotExe"
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GrabPointTest {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
}
'@

$base = Join-Path $env:APPDATA "Godot\app_userdata\Stickman Pet"
$targetFile = Join-Path $base "grab_target.json"
$resultFile = Join-Path $base "grab_result.json"
Remove-Item $targetFile, $resultFile -ErrorAction SilentlyContinue

$proc = Start-Process -FilePath $GodotExe `
    -ArgumentList @("--path", ".", "--", "--pet-grab-probe") -PassThru
Start-Sleep -Seconds 3
for ($i = 0; $i -lt 20 -and -not (Test-Path $targetFile); $i++) {
    Start-Sleep -Milliseconds 200
}
if (-not (Test-Path $targetFile)) {
    Stop-Process -Id $proc.Id -Force
    throw "grab_target.json not produced"
}

$target = Get-Content -LiteralPath $targetFile -Raw | ConvertFrom-Json
for ($i = 0; $i -lt 25 -and -not (Test-Path $resultFile); $i++) {
    Start-Sleep -Milliseconds 200
}
if (-not (Test-Path $resultFile)) {
    Stop-Process -Id $proc.Id -Force
    throw "grab_result.json not produced"
}
$result = Get-Content -LiteralPath $resultFile -Raw | ConvertFrom-Json
$distance = [double]$result.distance
Write-Host ("joint={0} distance={1}px limit={2}px" -f `
    $result.joint, $distance, $LimitPx)
Stop-Process -Id $proc.Id -Force
if ($distance -gt $LimitPx) {
    throw "Grab point error exceeded limit"
}
Write-Host "PASS grab point"
