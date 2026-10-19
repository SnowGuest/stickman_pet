param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot not found: $GodotExe"
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class MenuTest {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
}
'@

$base = Join-Path $env:APPDATA "Godot\app_userdata\Stickman Pet"
$targetFile = Join-Path $base "grab_target.json"
$markerFile = Join-Path $base "context_menu_open.txt"
Remove-Item $markerFile -ErrorAction SilentlyContinue

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
[MenuTest]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
[MenuTest]::SetCursorPos([int]$target.screen[0], [int]$target.screen[1]) | Out-Null
Start-Sleep -Milliseconds 300
[MenuTest]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 100
[MenuTest]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Seconds 1

$opened = Test-Path $markerFile
if ($opened) {
    Write-Host ("menu marker=" + (Get-Content -LiteralPath $markerFile -Raw))
}
Stop-Process -Id $proc.Id -Force
if (-not $opened) {
    throw "Context menu did not open on right click"
}
Write-Host "PASS context menu"
