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

.PARAMETER PackOnly
    只导出 PCK，不生成 exe；不需要导出模板，用于验证导出预设与资源打包。

.PARAMETER TemplateVersion
    Godot 导出模板版本目录名，默认 4.7.2.stable。

.PARAMETER TemplateDir
    自定义导出模板目录；为空时使用 %APPDATA%\Godot\export_templates\<版本>。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_release.ps1 -NoExport

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\build_release.ps1 -PackOnly

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
    [switch]$NoExport,
    [switch]$PackOnly
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $Root "build\release"
}
$BuildDir = Join-Path $Root "build"
$Staging = Join-Path $BuildDir "staging"

function Build-NativeTrayHelper {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    if (-not (Test-Path -LiteralPath $csc)) {
        throw "找不到 csc.exe，无法构建原生托盘 helper"
    }
    $source = Join-Path $Root "scripts/tray/TrayHelper.cs"
    $output = Join-Path $Root "scripts/tray/tray_helper.exe"
    & $csc /nologo /codepage:65001 /target:winexe /out:$output `
        /r:System.Windows.Forms.dll /r:System.Drawing.dll $source | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output)) {
        throw "原生托盘 helper 编译失败（退出码 $LASTEXITCODE）"
    }
}

function Quote-ProcessArg {
    param([string]$Value)
    if ($Value -match '\s') {
        return '"' + $Value + '"'
    }
    return $Value
}

function Invoke-Godot {
    param(
        [string]$ProjectPath,
        [string[]]$ExtraArgs
    )
    $Args = @("--headless", "--path", (Quote-ProcessArg $ProjectPath))
    foreach ($Arg in $ExtraArgs) {
        $Args += (Quote-ProcessArg $Arg)
    }
    $Process = Start-Process -FilePath $GodotExe -ArgumentList $Args -NoNewWindow -Wait -PassThru
    return [int]$Process.ExitCode
}

function Invoke-StagingImport {
    param([string]$ProjectPath)
    for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
        $Code = Invoke-Godot -ProjectPath $ProjectPath -ExtraArgs @("--import")
        if ($Code -eq 0) {
            return
        }
        if ($Attempt -lt 3) {
            Write-Host "      导入缓存未就绪，重试（$Attempt/3）…"
        }
    }
    throw "staging 资源导入失败（已重试 3 次），退出码 $Code"
}

# 让 Godot 忽略 build/，避免扫描 staging 里的 project.godot
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $BuildDir ".gdignore") | Out-Null

Write-Host "[1/5] 清理 staging: $Staging"
Build-NativeTrayHelper
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

if ($NoExport -and $PackOnly) {
    throw "-NoExport 与 -PackOnly 不能同时使用"
}

if ($NoExport) {
    Write-Host "[4/5] -NoExport：跳过导出"
    Write-Host "[5/5] staging 校验通过（未生成 exe）"
    return
}

$RootImported = Join-Path $Root ".godot\imported"
$StagingImported = Join-Path $Staging ".godot\imported"
if (Test-Path -LiteralPath $RootImported) {
    Write-Host "      同步导入缓存（字体/图标/音效）"
    New-Item -ItemType Directory -Force -Path $StagingImported | Out-Null
    Copy-Item -Path (Join-Path $RootImported "*") -Destination $StagingImported -Recurse -Force
}

if ($PackOnly) {
    if (-not (Test-Path -LiteralPath $GodotExe)) {
        throw "找不到 Godot：$GodotExe（用 -GodotExe 指定）"
    }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $Pck = Join-Path $OutDir "StickmanPet.pck"

    Write-Host "[4/5] 导入 staging 并导出 PCK（无需模板）"
    Invoke-StagingImport -ProjectPath $Staging
    $Code = Invoke-Godot -ProjectPath $Staging -ExtraArgs @("--export-pack", $Preset, $Pck)
    if ($Code -ne 0) {
        throw "PCK 导出失败，退出码 $Code"
    }
    if (-not (Test-Path -LiteralPath $Pck)) {
        throw "PCK 导出未生成 $Pck"
    }

    Write-Host "[5/5] 校验 PCK"
    $Bytes = [System.IO.File]::ReadAllBytes($Pck)
    $Ascii = [System.Text.Encoding]::ASCII.GetString($Bytes)
    foreach ($Needle in @("godot_ai", "_mcp_game_helper")) {
        if ($Ascii.Contains($Needle)) {
            throw "$Pck 包含禁止字符串 '$Needle'"
        }
    }
    $PckMB = [math]::Round((Get-Item -LiteralPath $Pck).Length / 1MB, 2)
    Write-Host "完成（仅 PCK）：$Pck ($PckMB MB)"
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

Invoke-StagingImport -ProjectPath $Staging
$Code = Invoke-Godot -ProjectPath $Staging -ExtraArgs @("--export-release", $Preset, $Exe)
if ($Code -ne 0) {
    throw "导出失败，退出码 $Code（请确认已安装 $Preset 导出模板）"
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
