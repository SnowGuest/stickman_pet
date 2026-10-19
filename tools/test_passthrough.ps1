param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe",
    [int]$Runs = 50,
    [double]$Dpi = 0.0
)

$ErrorActionPreference = "Stop"

Add-Type @'
using System;
using System.Runtime.InteropServices;
public class PetHit {
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
'@

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot 不存在: $GodotExe"
}

$gameArgs = @("--path", ".")
if ($Dpi -gt 0.0) {
    $gameArgs += @("--", "--dpi=$Dpi")
}
$proc = Start-Process -FilePath $GodotExe -ArgumentList $gameArgs -PassThru
Start-Sleep -Seconds 3
if ($proc.HasExited) {
    throw "游戏进程启动失败，退出码 $($proc.ExitCode)"
}
$hwnd = $proc.MainWindowHandle
if ($hwnd -eq 0) {
    Stop-Process -Id $proc.Id -Force
    throw "找不到游戏窗口"
}
$rect = New-Object PetHit+RECT
[PetHit]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
Write-Host "window=$width x $height hwnd=$hwnd"

function Test-Point([int]$x, [int]$y) {
    $p = New-Object PetHit+POINT
    $p.X = $x
    $p.Y = $y
    $hit = [PetHit]::WindowFromPoint($p)
    $root = [PetHit]::GetAncestor($hit, 2)
    return ($root -eq $hwnd)
}

$blankPass = 0
$blankFail = 0
for ($row = 0; $row -lt 5; $row++) {
    for ($col = 0; $col -lt 10; $col++) {
        $x = [int]($width * (0.10 + 0.08 * $col))
        $y = [int]($height * (0.10 + 0.10 * $row))
        if (Test-Point $x $y) {
            $blankFail++
            Write-Host "  blank hit game at $x,$y"
        } else {
            $blankPass++
        }
    }
}

$petX = [int]($width * 0.5)
$petHit = $false
$petY = 0
for ($y = [int]($height * 0.98); $y -ge [int]($height * 0.80); $y -= 4) {
    if (Test-Point $petX $y) {
        $petHit = $true
        $petY = $y
        break
    }
}

Stop-Process -Id $proc.Id -Force
Write-Host "blank_pass=$blankPass blank_fail=$blankFail pet_hit=$petHit pet_y=$petY"
if ($blankFail -ne 0 -or -not $petHit -or $blankPass -lt $Runs) {
    throw "穿透验收失败：需要 $Runs 个空白点全部穿透，且宠物中心命中本窗口"
}
Write-Host "PASS passthrough $blankPass/$Runs blank points; pet hit at $petX,$petY"
