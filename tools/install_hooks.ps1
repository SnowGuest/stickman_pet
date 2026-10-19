#requires -Version 5.1
<#
.SYNOPSIS
    安装本仓库的 Git 钩子（core.hooksPath = .githooks）。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$HooksDir = Join-Path $Root ".githooks"

if (-not (Test-Path -LiteralPath (Join-Path $HooksDir "pre-commit"))) {
    throw "找不到 .githooks/pre-commit"
}

& git -C $Root config core.hooksPath ".githooks"
if ($LASTEXITCODE -ne 0) {
    throw "设置 core.hooksPath 失败（退出码 $LASTEXITCODE）"
}

Write-Host "已安装 Git 钩子：core.hooksPath=.githooks"
Write-Host "  pre-commit  -> tools/gate.ps1"
Write-Host "  commit-msg  -> Conventional Commits 校验"
