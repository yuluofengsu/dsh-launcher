# install.ps1 - DeepSeek Harness 启动器安装脚本（由 install.bat 调用）
# 复制插件文件到目标目录并创建桌面快捷方式。
# 用法: install.ps1 [-Target 安装目录] [-DesktopDir 桌面目录(测试用)] [-SkipShortcuts]
param(
    [string]$Target = '',
    [string]$DesktopDir = '',
    [switch]$SkipShortcuts
)
$ErrorActionPreference = 'Stop'
$src = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Target) { $Target = Join-Path $env:LOCALAPPDATA 'DSHLauncher' }
if (-not $DesktopDir) { $DesktopDir = [Environment]::GetFolderPath('Desktop') }

Write-Host '===== DeepSeek Harness 启动器安装 ====='

# ---- 前置检查 ----
$missing = @()
if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { $missing += 'Node.js' }
if (-not (Get-Command dsh.cmd -ErrorAction SilentlyContinue)) { $missing += 'DSH CLI (dsh)' }
if ($missing.Count -gt 0) {
    Write-Host ('缺少依赖: ' + ($missing -join ', '))
    Write-Host '提示: 可先运行本目录下的 install-harness.bat 自动安装 Node.js 与 DSH。'
    exit 1
}
Write-Host '依赖检查通过 (Node.js + DSH)。'

# ---- 复制文件 ----
New-Item -ItemType Directory -Path $Target -Force | Out-Null
$files = @(
    'dsh-launcher.bat', 'dsh-stopper.bat', 'dsh-autostart.bat',
    'stop-dsh.vbs', 'launch-dsh.ps1', 'stop-dsh.ps1', 'check-dsh.ps1',
    'watchdog-dsh.ps1', 'autostart.ps1', 'waiting.html',
    'install-harness.bat', 'DeepSeekHarness-WhaleGirl.ico'
)
$copied = 0
foreach ($f in $files) {
    $s = Join-Path $src $f
    if (Test-Path $s) {
        Copy-Item $s (Join-Path $Target $f) -Force
        $copied++
    } else {
        Write-Host ('警告: 源目录缺少文件 ' + $f)
    }
}
# 说明文档：README.md 或 README-launcher.txt 任一存在即复制
foreach ($doc in @('README.md', 'README-launcher.txt')) {
    $s = Join-Path $src $doc
    if (Test-Path $s) {
        Copy-Item $s (Join-Path $Target $doc) -Force
        $copied++
        break
    }
}
Write-Host ("已复制 $copied 个文件到: " + $Target)

# ---- 桌面快捷方式 ----
if (-not $SkipShortcuts) {
    if (-not (Test-Path $DesktopDir)) { New-Item -ItemType Directory -Path $DesktopDir -Force | Out-Null }
    $ws = New-Object -ComObject WScript.Shell
    $shortcuts = @(
        @{ Name = 'DeepSeek Harness.lnk';       Target = 'dsh-launcher.bat'; Icon = 'DeepSeekHarness-WhaleGirl.ico'; Desc = '一键启动 DeepSeek Harness 并打开界面' },
        @{ Name = '退出 DeepSeek Harness.lnk';  Target = 'stop-dsh.vbs';       Icon = 'DeepSeekHarness-WhaleGirl.ico'; Desc = '一键退出 DeepSeek Harness（静默）' }
    )
    foreach ($sc in $shortcuts) {
        $p = Join-Path $DesktopDir $sc.Name
        if (Test-Path $p) { Remove-Item $p -Force }
        $s = $ws.CreateShortcut($p)
        $s.TargetPath = Join-Path $Target $sc.Target
        $s.WorkingDirectory = $Target
        $s.IconLocation = (Join-Path $Target $sc.Icon) + ',0'
        $s.Description = $sc.Desc
        $s.Save()
    }
    Write-Host '桌面快捷方式已创建（启动 / 退出）。'
}

Write-Host '安装完成。'
Write-Host ('提示: 可选开机自启，双击 ' + $Target + '\dsh-autostart.bat 开启。')
Write-Host ('提示: 运行 ' + $Target + '\dsh-launcher.bat /check 可自检。')
exit 0
