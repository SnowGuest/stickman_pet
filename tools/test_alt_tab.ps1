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
public class AltTabStyle {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
}
'@

$proc = Start-Process -FilePath $GodotExe -ArgumentList @("--path", ".") -PassThru
Start-Sleep -Seconds 3
if ($proc.HasExited) {
    throw "Game exited before window check"
}
$hwnd = $proc.MainWindowHandle
$style = [AltTabStyle]::GetWindowLong($hwnd, -20)
$toolWindow = (($style -band 0x00000080) -ne 0)
$appWindow = (($style -band 0x00040000) -ne 0)
Write-Host ("hwnd=0x{0:X} exstyle=0x{1:X} toolwindow={2} appwindow={3}" -f `
    $hwnd, $style, $toolWindow, $appWindow)
Stop-Process -Id $proc.Id -Force
if (-not $toolWindow -or $appWindow) {
    throw "Window is still visible in Alt+Tab"
}
Write-Host "PASS alt-tab hidden"
