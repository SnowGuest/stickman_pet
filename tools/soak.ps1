param(
    [int]$Seconds = 60
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Exe = Join-Path $Root "build/release/StickmanPet.exe"
if (-not (Test-Path -LiteralPath $Exe)) {
    throw "Missing release exe: $Exe"
}

$Process = Start-Process -FilePath $Exe -PassThru
Start-Sleep -Seconds 2
$StartMemory = $Process.WorkingSet64
$Samples = @()
for ($i = 0; $i -lt $Seconds; $i++) {
    if ($Process.HasExited) {
        throw "Process exited during soak at ${i}s"
    }
    $Process.Refresh()
    $Samples += [PSCustomObject]@{
        Second = $i
        WorkingSetMB = [math]::Round($Process.WorkingSet64 / 1MB, 1)
        Handles = $Process.HandleCount
    }
    Start-Sleep -Seconds 1
}
$Process.Refresh()
$EndMemory = $Process.WorkingSet64
$Process.CloseMainWindow() | Out-Null
Start-Sleep -Seconds 2
if (-not $Process.HasExited) {
    Stop-Process -Id $Process.Id -Force
}
$Growth = if ($StartMemory -gt 0) {
    (($EndMemory - $StartMemory) / $StartMemory) * 100.0
} else { 0.0 }
Write-Host ("Soak {0}s: start={1:N1}MB end={2:N1}MB growth={3:N2}%" -f `
    $Seconds, ($StartMemory / 1MB), ($EndMemory / 1MB), $Growth)
$Samples | Select-Object -Last 5 | Format-Table -AutoSize
if ([math]::Abs($Growth) -gt 5.0) {
    throw "Memory growth exceeded 5%"
}
