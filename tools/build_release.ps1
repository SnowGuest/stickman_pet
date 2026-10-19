#requires -Version 5.1
<#
.SYNOPSIS
    构建 Stickman Pet 发布包。

.DESCRIPTION
    1. 复制工程到 build/staging；
    2. 排除开发插件 addons/godot_ai、更新缓存、docs/tests/tools；
    3. 从 project.godot 移除 _mcp_game_helper 与 [editor_plugins]；
    4. 用 Godot 导出 Windows 包；
    5. 校验发布包中不含 godot_ai / _mcp_game_helper。

.PARAMETER NoExport
    只生成并校验 staging，不调用 Godot 导出（用于 CI 环境或无导出模板时）。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_release.ps1 -NoExport

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_release.ps1
#>
[CmdletBinding()]
param(
    [string]$GodotExe = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe",
    [string]$Preset = "Windows Desktop",
    [string]$OutDir = "",
    [string]$TemplateVersion = "4.7.2.stable",
    [string]$TemplateDir = "",
    [switch]$NoExport
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $Root "build\release"
}
$BuildDir = Join-Path $Root "build"
$Staging = Join-Path $BuildDir "staging"

# 让 Godot 忽略 build/，避免扫描 staging 里的 project.godot
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $BuildDir ".gdignore") | Out-Null

Write-Host "[1/5] 清理 staging: $Staging"
if (Test-Path -LiteralPath $Staging) {
    Remove-Item -LiteralPath $Staging -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $Staging | Out-Null

Write-Host "[2/5] 复制工程（排除开发资源）"
$ExcludeDirs = @(
    (Join-Path $Root ".git"),
    (Join-Path $Root ".godot"),
    (Join-Path $Root ".vscode"),
    (Join-Path $Root "build"),
    (Join-Path $Root "docs"),
    (Join-Path $Root "tests"),
    (Join-Path $Root "tools"),
    (Join-Path $Root "addons\godot_ai"),
    (Join-Path $Root "addons\.godot_ai_update")
)
$RoboArgs = @($Root, $Staging, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/XD") + $ExcludeDirs
& robocopy @RoboArgs | Out-Null
if ($LASTEXITCODE -ge 8) {
    throw "robocopy 失败，退出码 $LASTEXITCODE"
}

Write-Host "[3/5] 移除 _mcp_game_helper 与开发插件"
$ProjectFile = Join-Path $Staging "project.godot"
$Lines = Get-Content -LiteralPath $ProjectFile -Encoding utf8
$Result = [System.Collections.Generic.List[string]]::new()
$Section = ""

foreach ($Line in $Lines) {
    if ($Line -match '^\[(.+)\]\s*$') {
        $Section = $Matches[1]
        if ($Section -eq "editor_plugins") {
            continue
        }
        $Result.Add($Line)
        continue
    }
    if ($Section -eq "editor_plugins") {
        continue
    }
    if ($Section -eq "autoload" -and $Line -match '^\s*_mcp_game_helper\s*=') {
        continue
    }
    $Result.Add($Line)
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($ProjectFile, $Result, $Utf8NoBom)

$ProjectText = Get-Content -LiteralPath $ProjectFile -Raw -Encoding utf8
if ($ProjectText -match '_mcp_game_helper') {
    throw "staging/project.godot 仍包含 _mcp_game_helper"
}
if (Test-Path -LiteralPath (Join-Path $Staging "addons\godot_ai")) {
    throw "staging 仍包含 addons/godot_ai"
}
if (Test-Path -LiteralPath (Join-Path $Staging "tests")) {
    throw "staging 仍包含 tests/"
}

$SizeMB = [math]::Round(((Get-ChildItem -LiteralPath $Staging -Recurse -File | Measure-Object Length -Sum).Sum / 1MB), 2)
Write-Host "      staging 大小: $SizeMB MB"

if ($NoExport) {
    Write-Host "[4/5] -NoExport：跳过导出"
    Write-Host "[5/5] staging 校验通过（未生成 exe）"
    return
}

Write-Host "[4/5] 导出（模板需已安装）"
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "找不到 Godot：$GodotExe（用 -GodotExe 指定）"
}
if ([string]::IsNullOrWhiteSpace($TemplateDir)) {
    $TemplateDir = Join-Path (Join-Path $env:APPDATA "Godot\export_templates") $TemplateVersion
}
$TemplateExe = Join-Path $TemplateDir "windows_release_x86_64.exe"
if (-not (Test-Path -LiteralPath $TemplateExe)) {
    throw @"
导出模板未安装或版本不匹配。
期望：$TemplateExe
处理：Godot 编辑器 → 编辑器 → 管理导出模板 → 下载并安装 4.7.2。
或用 -TemplateVersion/-TemplateDir 指向已安装模板目录。
"@
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Exe = Join-Path $OutDir "StickmanPet.exe"

& $GodotExe --headless --path $Staging --import
if ($LASTEXITCODE -ne 0) {
    throw "资源导入失败，退出码 $LASTEXITCODE"
}

& $GodotExe --headless --path $Staging --export-release $Preset $Exe
if ($LASTEXITCODE -ne 0) {
    throw "导出失败，退出码 $LASTEXITCODE（请确认已安装 $Preset 导出模板）"
}
if (-not (Test-Path -LiteralPath $Exe)) {
    throw "导出未生成 $Exe"
}

Write-Host "[5/5] 校验发布包"
$Artifacts = @($Exe)
$Pck = Join-Path $OutDir "StickmanPet.pck"
if (Test-Path -LiteralPath $Pck) {
    $Artifacts += $Pck
}
foreach ($Artifact in $Artifacts) {
    $Bytes = [System.IO.File]::ReadAllBytes($Artifact)
    $Ascii = [System.Text.Encoding]::ASCII.GetString($Bytes)
    foreach ($Needle in @("godot_ai", "_mcp_game_helper")) {
        if ($Ascii.Contains($Needle)) {
            throw "$Artifact 包含禁止字符串 '$Needle'"
        }
    }
}

Copy-Item -LiteralPath (Join-Path $Root "LICENSE") -Destination $OutDir -Force
Copy-Item -LiteralPath (Join-Path $Root "assets\fonts\OFL.txt") -Destination $OutDir -Force

$ExeMB = [math]::Round((Get-Item -LiteralPath $Exe).Length / 1MB, 2)
Write-Host "完成：$Exe ($ExeMB MB)"
Write-Host "输出目录：$OutDir"
