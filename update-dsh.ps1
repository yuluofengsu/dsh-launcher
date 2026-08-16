# update-dsh.ps1 - 自更新（由 dsh-launcher.bat /update 调用）
# 从 GitHub 仓库拉取最新版本并覆盖本目录（保持运行中的服务不受影响，
# 下次退出+启动后完全生效）。
param(
    [string]$Dir = ''
)
$ErrorActionPreference = 'Stop'
if (-not $Dir) { $Dir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$ownerRepo = 'yuluofengsu/dsh-launcher'
$branch = 'main'

$cur = '0.0.0'
$curFile = Join-Path $Dir 'VERSION'
if (Test-Path $curFile) { $cur = (Get-Content $curFile -Raw).Trim() }

function Compare-Version($a, $b) {
    $aa = $a.Split('.'); $bb = $b.Split('.')
    for ($i = 0; $i -lt [Math]::Max($aa.Count, $bb.Count); $i++) {
        $x = if ($i -lt $aa.Count) { [int]$aa[$i] } else { 0 }
        $y = if ($i -lt $bb.Count) { [int]$bb[$i] } else { 0 }
        if ($x -gt $y) { return 1 }
        if ($x -lt $y) { return -1 }
    }
    return 0
}

Write-Host ('当前版本: ' + $cur)
try {
    $latest = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$ownerRepo/$branch/VERSION" -UseBasicParsing -TimeoutSec 15).Content.Trim()
} catch {
    Write-Host '无法连接 GitHub 获取最新版本（网络或代理问题），本次未更新。'
    exit 1
}
Write-Host ('最新版本: ' + $latest)

if ((Compare-Version $latest $cur) -le 0) {
    Write-Host '已是最新版本，无需更新。'
    exit 0
}

Write-Host ('发现新版本 ' + $latest + '，正在下载更新...')
$tmp = Join-Path $env:TEMP ('dsh-update-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    $zip = Join-Path $tmp 'repo.zip'
    Invoke-WebRequest -Uri ("https://codeload.github.com/$ownerRepo/zip/refs/heads/$branch") -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp
    $src = Join-Path $tmp 'dsh-launcher-main'
    if (-not (Test-Path $src)) { throw '下载内容结构异常，请重试' }

    $copied = 0
    Get-ChildItem $src -File | ForEach-Object {
        Copy-Item $_.FullName (Join-Path $Dir $_.Name) -Force
        $copied++
    }
    Write-Host ("已更新 $copied 个文件，当前版本: " + $latest)
    Write-Host '正在运行的服务不受影响；下次退出+启动后完全生效。'
    exit 0
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
