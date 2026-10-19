param(
    [string]$IconPath,
    [string]$CommandFile,
    [int]$ParentPid
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class PetWindowStyle {
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(
        IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint flags);
}
'@

function Set-ToolWindow {
    for ($i = 0; $i -lt 15; $i++) {
        $proc = Get-Process -Id $ParentPid -ErrorAction SilentlyContinue
        if ($proc -and $proc.MainWindowHandle -ne 0) {
            $hwnd = $proc.MainWindowHandle
            $style = [PetWindowStyle]::GetWindowLong($hwnd, -20)
            $style = ($style -band (-bnot 0x00040000)) -bor 0x00000080
            [void][PetWindowStyle]::SetWindowLong($hwnd, -20, $style)
            # SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
            [void][PetWindowStyle]::SetWindowPos(
                $hwnd, [IntPtr]::Zero, 0, 0, 0, 0, 0x37)
            return
        }
        Start-Sleep -Milliseconds 200
    }
}
Set-ToolWindow

function Write-Command([string]$Command) {
    [System.IO.File]::AppendAllText($script:CommandFile, $Command + "`n")
}

$notify = New-Object System.Windows.Forms.NotifyIcon
try {
    $notify.Icon = New-Object System.Drawing.Icon($IconPath)
} catch {
    exit 1
}
$notify.Text = "Stickman Pet"
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$notify.ContextMenuStrip = $menu

$toggleItem = New-Object System.Windows.Forms.ToolStripMenuItem("显示/隐藏")
$toggleItem.add_Click({
    param($sender, $eventArgs)
    Write-Command "toggle"
})
[void]$menu.Items.Add($toggleItem)

$muteItem = New-Object System.Windows.Forms.ToolStripMenuItem("静音")
$muteItem.add_Click({
    param($sender, $eventArgs)
    Write-Command "mute"
})
[void]$menu.Items.Add($muteItem)

$topItem = New-Object System.Windows.Forms.ToolStripMenuItem("置顶")
$topItem.add_Click({
    param($sender, $eventArgs)
    Write-Command "topmost"
})
[void]$menu.Items.Add($topItem)
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$quitItem = New-Object System.Windows.Forms.ToolStripMenuItem("退出")
$quitItem.add_Click({
    param($sender, $eventArgs)
    Write-Command "quit"
    $notify.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})
[void]$menu.Items.Add($quitItem)

$notify.add_DoubleClick({
    param($sender, $eventArgs)
    Write-Command "show"
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.add_Tick({
    param($sender, $eventArgs)
    if (-not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) {
        $notify.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    }
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
$notify.Visible = $false
$notify.Dispose()
