param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot 不存在: $GodotExe"
}

$first = Start-Process -FilePath $GodotExe -ArgumentList @("--path", ".") -PassThru
Start-Sleep -Seconds 2
if ($first.HasExited) {
    throw "第一个实例启动失败"
}

$second = Start-Process -FilePath $GodotExe -ArgumentList @("--path", ".") -PassThru
$second.WaitForExit(5000) | Out-Null
$exited = $second.HasExited
if (-not $exited) {
    Stop-Process -Id $second.Id -Force
}

if (-not $first.HasExited) {
    Stop-Process -Id $first.Id -Force
}

Write-Host "second_exited=$exited first_pid=$($first.Id) second_pid=$($second.Id)"
if (-not $exited) {
    throw "双开未被拒绝"
}
Write-Host "PASS single instance"
