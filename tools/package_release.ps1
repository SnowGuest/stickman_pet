param(
    [string]$Version = "0.1.0"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Release = Join-Path $Root "build/release"
$Exe = Join-Path $Release "StickmanPet.exe"
if (-not (Test-Path -LiteralPath $Exe)) {
    throw "Missing release exe: $Exe; run tools/build_release.ps1 first"
}

$PackageRoot = Join-Path $Root "build/package"
$Dest = Join-Path $PackageRoot "StickmanPet-$Version"
if (Test-Path -LiteralPath $Dest) {
    Remove-Item -LiteralPath $Dest -Recurse -Force
}
New-Item -ItemType Directory -Path $Dest -Force | Out-Null

Copy-Item -LiteralPath $Exe -Destination (Join-Path $Dest "StickmanPet.exe")
foreach ($Rel in @("LICENSE", "README.md", "assets/fonts/OFL.txt")) {
    $Source = Join-Path $Root $Rel
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Missing release file: $Rel"
    }
    Copy-Item -LiteralPath $Source -Destination (Join-Path $Dest (Split-Path -Leaf $Rel))
}

$Readme = @(
    "Stickman Pet $Version",
    "=====================",
    "",
    "Windows desktop pet: transparent, always-on-top, click-through.",
    "No mouse interaction. It plays idle/walk/wave autonomously.",
    "",
    "Run: StickmanPet.exe",
    "",
    "License: see LICENSE and OFL.txt (Noto Sans SC).",
    "Package does not include Godot AI helper, tests, or addons."
) -join "`n"
Set-Content -LiteralPath (Join-Path $Dest "README.txt") -Value $Readme -Encoding UTF8

$Zip = Join-Path $Release "StickmanPet-$Version.zip"
if (Test-Path -LiteralPath $Zip) {
    Remove-Item -LiteralPath $Zip -Force
}
Compress-Archive -Path (Join-Path $Dest "*") -DestinationPath $Zip -CompressionLevel Optimal

$Hash = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash
$HashFile = "$Zip.sha256"
Set-Content -LiteralPath $HashFile -Value "$Hash  $(Split-Path -Leaf $Zip)" -Encoding ASCII

Write-Host "Done: $Zip"
Write-Host "SHA256: $Hash"
