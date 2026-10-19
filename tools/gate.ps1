#requires -Version 5.1
<#
.SYNOPSIS
    Stickman Pet 项目门禁：提交/合并前必须通过的静态检查。

.DESCRIPTION
    默认检查文档、链接、project.godot 不变量、发布排除规则、git 卫生。
    可选 -Full 运行 Godot 导入与测试；-ReleaseCheck 生成并校验发布 staging。

.PARAMETER Full
    运行 Godot headless 导入；若存在 tests/run_tests.gd 则运行测试。
    需要关闭编辑器或确保工程未被占用。

.PARAMETER ReleaseCheck
    运行 tools/build_release.ps1 -NoExport，并校验 staging 中无 helper / addon / tests。

.PARAMETER GodotExe
    Godot 可执行文件路径；-Full 时使用。默认尝试本机已知路径。

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools\gate.ps1 -Full -ReleaseCheck
#>
[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$ReleaseCheck,
    [string]$GodotExe = ""
)

$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

$script:Errors = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()

function Fail([string]$Message) {
    $script:Errors.Add($Message) | Out-Null
}
function Warn([string]$Message) {
    $script:Warnings.Add($Message) | Out-Null
}
function Read-Utf8([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}
function Get-Relative([string]$Path) {
    return $Path.Substring($Root.Length).TrimStart('\', '/')
}

# ---------------------------------------------------------------- 1. 必需文件
$RequiredFiles = @(
    "README.md",
    "AGENTS.md",
    "CONTRIBUTING.md",
    "CHANGELOG.md",
    "LICENSE",
    "project.godot",
    "export_presets.cfg",
    ".editorconfig",
    ".github/pull_request_template.md",
    "tools/build_release.ps1",
    "tools/gate.ps1",
    "tools/install_hooks.ps1",
    "tests/run_tests.gd",
    "assets/fonts/NotoSansSC-Variable.ttf",
    "assets/fonts/OFL.txt",
    "assets/themes/pet_theme.tres",
    "scenes/main.tscn",
    "docs/README.md",
    "docs/00-项目/01-项目目标.md",
    "docs/00-项目/02-路线图与进度.md",
    "docs/00-项目/03-风险与合规.md",
    "docs/00-项目/路线图/README.md",
    "docs/00-项目/版本迭代/README.md",
    "docs/01-总览/01-产品与边界.md",
    "docs/01-总览/02-架构与运行时.md",
    "docs/01-总览/03-Godot工程基线.md",
    "docs/01-总览/04-内容设计.md",
    "docs/01-总览/05-最终产品定义.md",
    "docs/07-AI集成/README.md",
    "docs/07-AI集成/01-控制架构与协议.md",
    "docs/00-项目/路线图/轨道A-AI控制桥接.md",
    "docs/00-项目/版本迭代/v0.5.5.md",
    "docs/02-平台/01-窗口与穿透.md",
    "docs/02-平台/02-输入屏幕与生命周期.md",
    "docs/02-平台/03-托盘与设置.md",
    "docs/03-仿真/01-骨骼与动画.md",
    "docs/03-仿真/02-物理与抓取.md",
    "docs/04-表现/01-渲染与2.5D.md",
    "docs/04-表现/03-音频与界面.md",
    "docs/04-表现/04-素材清单.md",
    "docs/04-表现/05-配色与无脸规范.md",
    "docs/05-行为/01-状态机与交互.md",
    "docs/05-行为/02-光标交互规范.md",
    "docs/05-行为/03-内置行为清单.md",
    "docs/06-工程/01-配置与持久化.md",
    "docs/06-工程/02-规范测试与发布.md",
    "docs/06-工程/03-版本控制与CI.md",
    "docs/06-工程/04-项目门禁.md",
    "docs/06-工程/05-行业实践对照.md",
    "docs/appendix/01-术语与API.md"
)
foreach ($RelPath in $RequiredFiles) {
    $FullPath = Join-Path $Root $RelPath
    if (-not (Test-Path -LiteralPath $FullPath)) {
        Fail "缺少必需文件：$RelPath"
    }
}

# ---------------------------------------------------------------- 2. Markdown
$MarkdownFiles = @()
$MarkdownFiles += Get-ChildItem -LiteralPath $Root -File -Filter "*.md"
$MarkdownFiles += Get-ChildItem -LiteralPath (Join-Path $Root "docs") -Recurse -File -Filter "*.md"

$LinkPattern = [regex]'\]\(([^)\s]+?\.md)(#[^)]*)?\)'
foreach ($File in $MarkdownFiles) {
    $Text = Read-Utf8 $File.FullName
    $FenceCount = ([regex]::Matches($Text, '(?m)^\s*```')).Count
    if (($FenceCount % 2) -ne 0) {
        Fail "代码块未闭合：$(Get-Relative $File.FullName)（``` 数量 $FenceCount）"
    }

    foreach ($Match in $LinkPattern.Matches($Text)) {
        $Target = [System.Uri]::UnescapeDataString($Match.Groups[1].Value)
        if ($Target -match '^(https?:|mailto:)') {
            continue
        }
        $Resolved = Join-Path $File.DirectoryName $Target
        if (-not (Test-Path -LiteralPath $Resolved)) {
            Fail "文档链接失效：$(Get-Relative $File.FullName) -> $Target"
        }
    }
}

# ---------------------------------------------------------------- 3. project.godot
$ProjectPath = Join-Path $Root "project.godot"
$Ini = @{}
if (Test-Path -LiteralPath $ProjectPath) {
    $CurrentSection = ""
    foreach ($Line in [System.IO.File]::ReadAllLines($ProjectPath, [System.Text.Encoding]::UTF8)) {
        $Trimmed = $Line.Trim()
        if ($Trimmed -eq "" -or $Trimmed.StartsWith(";")) {
            continue
        }
        if ($Trimmed -match '^\[(.+)\]$') {
            $CurrentSection = $Matches[1]
            continue
        }
        if ($Trimmed -match '^([^=]+)=(.*)$') {
            $Key = "$CurrentSection/$($Matches[1].Trim())"
            $Ini[$Key] = $Matches[2].Trim().Trim('"')
        }
    }
}

if ($Ini.Count -eq 0) {
    Fail "project.godot 解析失败或为空"
}

$Version = $Ini["application/config/version"]
if (-not $Version) {
    Fail "project.godot 缺少 application/config/version"
} elseif ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Fail "版本号不是语义化版本：$Version"
}

$MainScene = $Ini["application/run/main_scene"]
if (-not $MainScene) {
    Fail "project.godot 缺少 run/main_scene"
} else {
    $MainPath = Join-Path $Root ($MainScene -replace '^res://', '')
    if (-not (Test-Path -LiteralPath $MainPath)) {
        Fail "主场景不存在：$MainScene"
    }
}

$Stretch = $Ini["display/window/stretch/mode"]
if ($Stretch -and $Stretch -ne "disabled") {
    Fail "display/window/stretch/mode 必须为 disabled（当前：$Stretch），否则抓取坐标会偏移"
}

$BoolSettings = @{
    "display/window/size/transparent"              = "窗口透明"
    "display/window/per_pixel_transparency/allowed" = "per-pixel transparency"
    "display/window/size/borderless"                = "无边框"
    "display/window/size/always_on_top"             = "置顶"
    "rendering/viewport/transparent_background"     = "透明背景"
}
foreach ($Key in $BoolSettings.Keys) {
    if ($Ini[$Key] -ne "true") {
        Fail "project.godot 必须开启 $($BoolSettings[$Key])（$Key=true），当前：$($Ini[$Key])"
    }
}

$ThemePath = $Ini["gui/theme/custom"]
if (-not $ThemePath) {
    Fail "project.godot 缺少 gui/theme/custom（中文 UI 会回退到无 CJK 的默认字体）"
} else {
    $ThemeFull = Join-Path $Root ($ThemePath -replace '^res://', '')
    if (-not (Test-Path -LiteralPath $ThemeFull)) {
        Fail "主题文件不存在：$ThemePath"
    }
}

$Helper = $Ini["autoload/_mcp_game_helper"]
if ($Helper) {
    $HelperPath = Join-Path $Root (($Helper -replace '^\*', '') -replace '^res://', '')
    if (-not (Test-Path -LiteralPath $HelperPath)) {
        Fail "_mcp_game_helper autoload 指向不存在的文件：$Helper"
    }
}

# ---------------------------------------------------------------- 4. 发布排除
$PresetPath = Join-Path $Root "export_presets.cfg"
if (Test-Path -LiteralPath $PresetPath) {
    $PresetText = Read-Utf8 $PresetPath
    if ($PresetText -notmatch 'exclude_filter\s*=\s*"[^"]*addons/godot_ai') {
        Fail "export_presets.cfg 的 exclude_filter 未排除 addons/godot_ai"
    }
}

$BuildScript = Join-Path $Root "tools/build_release.ps1"
if (Test-Path -LiteralPath $BuildScript) {
    $BuildText = Read-Utf8 $BuildScript
    foreach ($Needle in @("_mcp_game_helper", "godot_ai")) {
        if ($BuildText -notmatch [regex]::Escape($Needle)) {
            Fail "tools/build_release.ps1 缺少发布剥离逻辑：$Needle"
        }
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $Root "assets/fonts/OFL.txt"))) {
    Fail "缺少字体许可证 assets/fonts/OFL.txt"
}

# ---------------------------------------------------------------- 5. Git 卫生
$Tracked = @()
try {
    $Tracked = @(& git -C $Root -c core.quotepath=false ls-files 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Warn "git ls-files 失败：可能不是 git 仓库"
    }
} catch {
    Warn "无法执行 git：$($_.Exception.Message)"
}

foreach ($TrackedPath in $Tracked) {
    if ($TrackedPath -match '^\.godot/') {
        Fail "生成目录被提交：$TrackedPath"
    }
    if ($TrackedPath -match '^(build|export)/') {
        Fail "构建目录被提交：$TrackedPath"
    }
    if ($TrackedPath -match '\.(exe|pck|log|tmp)$') {
        Fail "构建产物/日志被提交：$TrackedPath"
    }
    if ($TrackedPath -match '(^|/)(\.env|\.env\..*|credentials\.json|secrets?\.(json|yaml|yml|txt))$') {
        Fail "疑似密钥文件被提交：$TrackedPath"
    }
    if ($TrackedPath -match '(^|/)export_credentials\.cfg$') {
        Fail "导出凭据文件被提交：$TrackedPath"
    }
}

$MissingUid = @()
foreach ($Gd in ($Tracked | Where-Object { $_ -like "*.gd" })) {
    $Uid = Join-Path $Root ($Gd + ".uid")
    if (-not (Test-Path -LiteralPath $Uid)) {
        $MissingUid += $Gd
    }
}
if ($MissingUid.Count -gt 0) {
    Warn ("以下 GDScript 缺少 .uid（请用编辑器保存一次）：" + ($MissingUid -join ", "))
}

$TextExtensions = @(".gd", ".ps1", ".sh", ".yml", ".yaml", ".json", ".cfg", ".tres", ".tscn")
$TextHygieneIssues = @()
foreach ($TrackedPath in $Tracked) {
    if ($TrackedPath -match '^addons/') {
        continue
    }
    $Ext = [System.IO.Path]::GetExtension($TrackedPath).ToLowerInvariant()
    if ($TextExtensions -notcontains $Ext) {
        continue
    }
    $FullPath = Join-Path $Root $TrackedPath
    if (-not (Test-Path -LiteralPath $FullPath)) {
        continue
    }
    $Lines = [System.IO.File]::ReadAllLines($FullPath, [System.Text.Encoding]::UTF8)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '[ \t]+$') {
            $TextHygieneIssues += "${TrackedPath}:$($i + 1) 行尾空白"
        }
        if ($Ext -eq ".gd" -and $Lines[$i].Length -gt 100) {
            $TextHygieneIssues += "${TrackedPath}:$($i + 1) 超过 100 字符"
        }
    }
}
if ($TextHygieneIssues.Count -gt 0) {
    Fail ("文本规范问题：`n" + ($TextHygieneIssues -join "`n"))
}

$HooksPath = ""
try {
    $HooksPath = (& git -C $Root config core.hooksPath 2>$null)
} catch { }
if ($HooksPath -ne ".githooks") {
    Warn "未安装本地钩子；运行 tools/install_hooks.ps1 可让门禁在提交前自动执行"
}

# ---------------------------------------------------------------- 6. 文档契约
$ReadmeText = Read-Utf8 (Join-Path $Root "README.md")
if ($ReadmeText -notmatch '06-工程/04-项目门禁\.md') {
    Fail "README.md 未链接项目门禁文档"
}
$DocsReadme = Read-Utf8 (Join-Path $Root "docs/README.md")
if ($DocsReadme -notmatch '06-工程/04-项目门禁\.md') {
    Fail "docs/README.md 未链接项目门禁文档"
}
$Roadmap = Read-Utf8 (Join-Path $Root "docs/00-项目/02-路线图与进度.md")
if ($Roadmap -notmatch '当前状态') {
    Fail "路线图缺少“当前状态”章节"
}
$Appendix = Read-Utf8 (Join-Path $Root "docs/appendix/01-术语与API.md")
if ($Appendix -notmatch 'v1\.20') {
    Fail "appendix 文档版本未更新到 v1.20"
}
$PaletteDoc = Read-Utf8 (Join-Path $Root "docs/04-表现/05-配色与无脸规范.md")
if ($PaletteDoc -notmatch '#FF6600' -or $PaletteDoc -notmatch '空心头') {
    Fail "配色文档缺少橙色 #FF6600 或空心头规则"
}
$Assets = Read-Utf8 (Join-Path $Root "docs/04-表现/04-素材清单.md")
if ($Assets -notmatch 'sfx_step') {
    Fail "素材清单缺少核心音效 sfx_step"
}
$AudioFiles = @(
    "assets/sfx/sfx_step_01.ogg",
    "assets/sfx/sfx_land_soft.ogg",
    "assets/sfx/sfx_wave_whoosh.ogg",
    "assets/sfx/sfx_sit.ogg",
    "assets/sfx/sfx_wave.ogg",
    "assets/sfx/sfx_clap.ogg",
    "assets/sfx/sfx_pop.ogg",
    "assets/sfx/LICENSES.md"
)
foreach ($f in $AudioFiles) {
    if (-not (Test-Path (Join-Path $Root $f))) {
        Fail "音效文件缺失：$f"
    }
}
$WaveImport = Read-Utf8 (Join-Path $Root "assets/sfx/sfx_wave.ogg.import")
if ($WaveImport -notmatch 'loop=true') {
    Fail "连续挥手 sfx_wave.ogg 未设为循环"
}
$IconFiles = @(
    "assets/icons/icon.ico",
    "assets/icons/icon_512.png",
    "assets/icons/tray.ico",
    "assets/icons/tray_16.png",
    "assets/icons/README.md"
)
foreach ($f in $IconFiles) {
    if (-not (Test-Path (Join-Path $Root $f))) {
        Fail "图标文件缺失：$f"
    }
}
$ProjectFile = Read-Utf8 (Join-Path $Root "project.godot")
if ($ProjectFile -notmatch 'assets/icons/icon_512\.png') {
    Fail "project.godot 未使用新应用图标"
}
$ExportFile = Read-Utf8 (Join-Path $Root "export_presets.cfg")
if ($ExportFile -notmatch 'assets/icons/icon\.ico') {
    Fail "export_presets.cfg 未使用新 exe 图标"
}
$RigPath = Join-Path $Root "assets/rigs/stickman.json"
if (-not (Test-Path $RigPath)) {
    Fail "骨骼数据缺失：assets/rigs/stickman.json"
}
$Rig = Get-Content -LiteralPath $RigPath -Raw | ConvertFrom-Json
if ($Rig.bones.Count -ne 13 -or $Rig.joints.Count -ne 14) {
    Fail "骨骼数据不是 13 骨 / 14 关节"
}
if ([double]$Rig.head_radius -ne 18.0) {
    Fail "骨骼 head_radius 不是 18.0"
}
$TrayDoc = Read-Utf8 (Join-Path $Root "docs/02-平台/03-托盘与设置.md")
if ($TrayDoc -notmatch 'Shell_NotifyIcon') {
    Fail "托盘文档缺少 Shell_NotifyIcon 实现方案"
}
$CursorDoc = Read-Utf8 (Join-Path $Root "docs/05-行为/02-光标交互规范.md")
if ($CursorDoc -notmatch 'GlobalMouse') {
    Fail "光标交互文档缺少 GlobalMouse 方案"
}
$ForbiddenHits = @()
$ForbiddenHits += Get-ChildItem (Join-Path $Root "docs") -Recurse -Filter *.md | Select-String -Pattern 'Minecraft|Mojang'
$ForbiddenHits += Select-String -Path (Join-Path $Root "README.md") -Pattern 'Minecraft|Mojang'
if ($ForbiddenHits.Count -gt 0) {
    Fail "文档仍包含已移除的 Minecraft/Mojang 关键词"
}
$FaceHits = @()
$FaceHits += Get-ChildItem (Join-Path $Root "docs") -Recurse -Filter *.md | Select-String -Pattern 'FaceRig|表情|眼睛|瞳孔|眉毛|眨眼|眼神'
$FaceHits += Select-String -Path (Join-Path $Root "README.md"),(Join-Path $Root "CHANGELOG.md") -Pattern 'FaceRig|表情|眼睛|瞳孔|眉毛|眨眼|眼神'
if ($FaceHits.Count -gt 0) {
    Fail "文档仍包含面部/表情相关内容"
}
$Activities = Read-Utf8 (Join-Path $Root "docs/05-行为/03-内置行为清单.md")
if ($Activities -notmatch 'B10') {
    Fail "内置行为清单缺少 B10"
}
$AiDoc = Read-Utf8 (Join-Path $Root "docs/07-AI集成/README.md")
if ($AiDoc -notmatch 'Godot 做 Server') {
    Fail "AI 集成文档缺少“Godot 做 Server”决策"
}
$RoadmapDetail = Read-Utf8 (Join-Path $Root "docs/00-项目/路线图/README.md")
if ($RoadmapDetail -notmatch '当前在哪一步') {
    Fail "路线图目录缺少“当前在哪一步”章节"
}
$Versions = Read-Utf8 (Join-Path $Root "docs/00-项目/版本迭代/README.md")
if ($Versions -notmatch '版本总览') {
    Fail "版本迭代目录缺少“版本总览”"
}
$GateDoc = Read-Utf8 (Join-Path $Root "docs/06-工程/04-项目门禁.md")
if ($GateDoc -notmatch '行业参考') {
    Fail "项目门禁文档缺少“行业参考”章节"
}
$EditorConfig = Read-Utf8 (Join-Path $Root ".editorconfig")
if ($EditorConfig -notmatch 'charset\s*=\s*utf-8') {
    Fail ".editorconfig 未声明 charset = utf-8"
}
$ChangeLog = Read-Utf8 (Join-Path $Root "CHANGELOG.md")
if ($ChangeLog -notmatch '## \[Unreleased\]') {
    Fail "CHANGELOG.md 缺少 ## [Unreleased] 章节"
}
$GitAttributes = Read-Utf8 (Join-Path $Root ".gitattributes")
if ($GitAttributes -notmatch '\* text=auto') {
    Fail ".gitattributes 缺少 * text=auto"
}

# ---------------------------------------------------------------- 7. 可选：Godot
if ($Full) {
    if (-not $GodotExe) {
        $Candidate = "C:\Users\16225\Desktop\Godot_v4.7.2-stable_win64.exe"
        if (Test-Path -LiteralPath $Candidate) {
            $GodotExe = $Candidate
        }
    }
    if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe)) {
        Warn "-Full 已跳过：找不到 Godot 可执行文件"
    } else {
        Write-Host "[gate] Godot 导入…"
        $OldEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $ImportOutput = & $GodotExe --headless --path $Root --import 2>&1
        $ImportCode = $LASTEXITCODE
        $ErrorActionPreference = $OldEap
        $ImportOutput | Out-Null
        if ($ImportCode -ne 0) {
            Fail "Godot --import 失败（退出码 $ImportCode）"
        }

        $TestScript = Join-Path $Root "tests/run_tests.gd"
        if ((Test-Path -LiteralPath $TestScript) -and $ImportCode -eq 0) {
            Write-Host "[gate] Godot 测试…"
            $ErrorActionPreference = "Continue"
            $TestOutput = & $GodotExe --headless --path $Root --script "res://tests/run_tests.gd" 2>&1
            $TestCode = $LASTEXITCODE
            $ErrorActionPreference = $OldEap
            $TestOutput | Out-Null
            if ($TestCode -ne 0) {
                Fail "Godot 测试失败（退出码 $TestCode）"
            }
        } elseif (-not (Test-Path -LiteralPath $TestScript)) {
            Warn "-Full：tests/run_tests.gd 不存在，跳过测试"
        }

        Write-Host "[gate] 启动冒烟…"
        $ErrorActionPreference = "Continue"
        $SmokeOutput = & $GodotExe --headless --path $Root --quit-after 2 2>&1
        $SmokeCode = $LASTEXITCODE
        $ErrorActionPreference = $OldEap
        $SmokeOutput | Out-Null
        if ($SmokeCode -ne 0) {
            Fail "主场景启动冒烟失败（退出码 $SmokeCode）"
        }
    }
}

# ---------------------------------------------------------------- 8. 可选：发布 staging
if ($ReleaseCheck) {
    Write-Host "[gate] 生成发布 staging…"
    $BuildScriptPath = Join-Path $Root "tools/build_release.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BuildScriptPath -NoExport 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Fail "build_release.ps1 -NoExport 失败（退出码 $LASTEXITCODE）"
    } else {
        $Staging = Join-Path $Root "build/staging"
        $StagingProject = Join-Path $Staging "project.godot"
        if (-not (Test-Path -LiteralPath $StagingProject)) {
            Fail "发布 staging 未生成 project.godot"
        } else {
            $StagingText = Read-Utf8 $StagingProject
            if ($StagingText -match '_mcp_game_helper') {
                Fail "发布 staging 仍包含 _mcp_game_helper"
            }
            if ($StagingText -match 'editor_plugins') {
                Fail "发布 staging 仍包含 [editor_plugins]"
            }
        }
        if (Test-Path -LiteralPath (Join-Path $Staging "addons/godot_ai")) {
            Fail "发布 staging 仍包含 addons/godot_ai"
        }
        if (Test-Path -LiteralPath (Join-Path $Staging "tests")) {
            Fail "发布 staging 仍包含 tests/"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Staging "assets/fonts/OFL.txt"))) {
            Fail "发布 staging 缺少字体许可证"
        }
    }
}

# ---------------------------------------------------------------- 9. 结果
Write-Host ""
if ($script:Warnings.Count -gt 0) {
    Write-Host "警告（$($script:Warnings.Count)）：" -ForegroundColor Yellow
    foreach ($Warning in $script:Warnings) {
        Write-Host "  - $Warning" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($script:Errors.Count -gt 0) {
    Write-Host "GATE FAILED（$($script:Errors.Count) 项）：" -ForegroundColor Red
    foreach ($ErrorItem in $script:Errors) {
        Write-Host "  - $ErrorItem" -ForegroundColor Red
    }
    exit 1
}

Write-Host "GATE PASS" -ForegroundColor Green
Write-Host "  文档 / 工程设置 / 发布规则 / git 卫生检查通过"
if ($Full) { Write-Host "  -Full：Godot 导入与测试已执行" }
if ($ReleaseCheck) { Write-Host "  -ReleaseCheck：发布 staging 已校验" }
exit 0
