# uninstall.ps1 - 卸载 DeepSeek Harness 启动器（由 uninstall.bat 调用）
# 删除桌面快捷方式与安装目录（仅当目录确属本插件时）。
param(
    [string]$Target = '',
    [string]$DesktopDir = ''
)
$ErrorActionPreference = 'Continue'
if (-not $Target) { $Target = Join-Path $env:LOCALAPPDATA 'DSHLauncher' }
if (-not $DesktopDir) { $DesktopDir = [Environment]::GetFolderPath('Desktop') }

Write-Host '===== DeepSeek Harness 启动器卸载 ====='

# 安全标记：目标目录必须包含 dsh-launcher.bat 才删除
if (Test-Path (Join-Path $Target 'dsh-launcher.bat')) {
    Remove-Item $Target -Recurse -Force
    Write-Host ('已删除安装目录: ' + $Target)
} else {
    Write-Host ('未删除 ' + $Target + '（不是本插件的安装目录或已不存在）')
}

foreach ($name in @('DeepSeek Harness.lnk', '退出 DeepSeek Harness.lnk')) {
    $p = Join-Path $DesktopDir $name
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host ('已删除快捷方式: ' + $name) }
}

Write-Host '卸载完成。'
exit 0
