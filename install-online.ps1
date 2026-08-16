# install-online.ps1 - 在线一键安装 DeepSeek Harness 启动器（傻瓜式）
# 直接从 GitHub 拉取仓库、自动补齐依赖（Node.js/DSH）、安装插件并创建桌面快捷方式。
#
# 用法一（一行命令，PowerShell 5.1+ / 7）:
#   irm https://raw.githubusercontent.com/yuluofengsu/dsh-launcher/main/install-online.ps1 | iex
# 用法二（下载后本地运行，可带参数）:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install-online.ps1 -Destination D:\tools\DSHLauncher
#
# 参数:
#   -Destination   安装目录（默认 %LOCALAPPDATA%\DSHLauncher）
#   -DesktopDir    快捷方式桌面目录（默认当前用户桌面；测试用）
#   -SkipShortcuts 跳过创建快捷方式（测试用）
param(
    [string]$Destination = '',
    [string]$DesktopDir = '',
    [switch]$SkipShortcuts
)
$ErrorActionPreference = 'Stop'
$ownerRepo = 'yuluofengsu/dsh-launcher'
$branch = 'main'
if (-not $Destination) { $Destination = Join-Path $env:LOCALAPPDATA 'DSHLauncher' }
$tmp = Join-Path $env:TEMP ('dsh-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Write-Host ('[1/4] 正在从 GitHub 下载 ' + $ownerRepo + ' ...')
    $zip = Join-Path $tmp 'repo.zip'
    Invoke-WebRequest -Uri ("https://codeload.github.com/$ownerRepo/zip/refs/heads/$branch") -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp
    $src = Join-Path $tmp 'dsh-launcher-main'
    if (-not (Test-Path $src)) { throw '下载内容结构异常，请重试' }

    Write-Host '[2/4] 检查依赖 (Node.js 20+ / DSH)...'
    $need = @()
    if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { $need += 'Node.js' }
    if (-not (Get-Command dsh.cmd -ErrorAction SilentlyContinue)) { $need += 'DSH CLI' }
    if ($need.Count -gt 0) {
        Write-Host ('      缺少 ' + ($need -join ', ') + '，自动运行依赖安装器（可能需几分钟）...')
        & (Join-Path $src 'install-harness.bat') /nopause
        if ($LASTEXITCODE -ne 0) { throw '依赖安装失败，请手动安装 Node.js 20+ 与 DSH 后重试' }
        # 刷新 PATH（依赖安装器可能修改了它）
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:Path
        if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { throw 'Node.js 安装后仍不可用，请手动安装' }
    }
    Write-Host '[3/4] 安装插件...'
    $installArgs = @('-Target', $Destination)
    if ($DesktopDir) { $installArgs += @('-DesktopDir', $DesktopDir) }
    if ($SkipShortcuts) { $installArgs += '-SkipShortcuts' }
    & (Join-Path $src 'install.ps1') @installArgs
    if ($LASTEXITCODE -ne 0) { throw '插件安装失败' }

    Write-Host '[4/4] 完成'
    Write-Host ('  安装目录: ' + $Destination)
    Write-Host '  桌面快捷方式: 「DeepSeek Harness」启动 / 「退出 DeepSeek Harness」退出'
    Write-Host '  自检: ' + (Join-Path $Destination 'dsh-launcher.bat') + ' /check'
    exit 0
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
