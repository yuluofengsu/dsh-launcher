# stop-dsh.ps1 - 可靠退出 DeepSeek Harness (DSH) Web 服务
# 由 dsh-stopper.bat 调用；不要直接双击运行。
# 退出策略（多重保障，不会出现“退不出”的情况）：
#   0) 先关内存看门狗（防误触发崩溃自动重启）；
#   1) 按启动器记录的 PID 精确终止；
#   2) 按命令行匹配所有 dsh web 服务进程（无论怎么启动的都能退出）；
#   3) 关闭 DSH 界面应用窗口（隔离 profile 的 Edge/Chrome --app 窗口）；
#   4) 顺带关闭遗留的 DSH 服务控制台窗口；
#   5) 校验端口 3080 是否已释放。
$ErrorActionPreference = 'Continue'

$stateDir = Join-Path $env:USERPROFILE '.dsh\launcher'
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$pidFile = Join-Path $stateDir 'dsh-web.pid'
$exitLog = Join-Path $stateDir 'exit.log'
$killed = New-Object 'System.Collections.Generic.List[int]'

# 静默退出时把结果写进日志，便于排查
function Log-Result($msg) {
    try { Add-Content -Path $exitLog -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg) -Encoding UTF8 } catch {}
}

# 退出完成后的反馈弹窗（3 秒自动消失，无需点击）
# $type: 64 = 信息图标, 48 = 警告图标
function Show-Popup($text, $type) {
    try {
        $ws = New-Object -ComObject WScript.Shell
        $ws.Popup($text, 3, 'DeepSeek Harness', $type) | Out-Null
    } catch {}
}

# 0) 先关内存看门狗（防它在服务退出后误触发"崩溃自动重启"）
$wdTargets = Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and $_.CommandLine -match 'watchdog-dsh\.ps1'
} | ForEach-Object { $_.ProcessId } | Sort-Object -Unique
foreach ($t in $wdTargets) {
    if ($t -eq $PID) { continue }   # 安全护栏：不杀自己
    taskkill /PID $t /T /F 2>$null | Out-Null
    $killed.Add([int]$t)
}

# 1) 按 PID 文件精确终止（由启动器启动的情况）
if (Test-Path $pidFile) {
    $val = (Get-Content $pidFile -Raw).Trim()
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    if ($val -match '^\d+$') {
        $proc = Get-Process -Id ([int]$val) -ErrorAction SilentlyContinue
        if ($proc) {
            taskkill /PID $val /T /F 2>$null | Out-Null
            $killed.Add([int]$val)
        }
    }
}

# 2) 兜底：按命令行匹配 dsh web 服务进程（node ...\dsh\lib\bin.js web）
$targets = Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" | Where-Object {
    $_.CommandLine -and $_.CommandLine -match 'bin\.js' -and $_.CommandLine -match '\bweb\b'
} | ForEach-Object { $_.ProcessId } | Sort-Object -Unique
foreach ($t in $targets) {
    if ($t -eq $PID) { continue }   # 安全护栏：不杀自己
    taskkill /PID $t /T /F 2>$null | Out-Null
    $killed.Add([int]$t)
}

# 3) 关闭 DSH 界面应用窗口（只匹配我们自己的隔离 profile，不碰日常浏览器）
$appTargets = Get-CimInstance Win32_Process | Where-Object {
    $_.CommandLine -and (
        $_.CommandLine -match 'DeepSeekHarness\\edge-app' -or
        $_.CommandLine -match 'DeepSeekHarness\\chrome-app'
    )
} | ForEach-Object { $_.ProcessId } | Sort-Object -Unique
foreach ($t in $appTargets) {
    taskkill /PID $t /T /F 2>$null | Out-Null
    $killed.Add([int]$t)
}

# 4) 顺带关闭遗留的 DSH 服务控制台窗口（旧版启动器留下的）
taskkill /FI "WINDOWTITLE eq DSH Server*" /F 2>$null | Out-Null

Start-Sleep -Milliseconds 600

# 5) 校验端口 3080 是否已释放
$still = netstat -ano | Select-String -Pattern ':3080\s+.*LISTENING'
if ($still) {
    Log-Result '警告：端口 3080 仍在监听，可能还有残留进程'
    Write-Host '警告：端口 3080 仍在监听，可能还有残留进程：'
    $still | ForEach-Object { Write-Host ('  ' + $_.Line) }
    Show-Popup '退出未完成：端口 3080 仍在监听。详情见退出日志 exit.log。' 48
    exit 2
}
if ($killed.Count -gt 0) {
    Log-Result ('已停止 ' + $killed.Count + ' 个进程：' + ($killed -join ', '))
    Write-Host ('已停止 ' + $killed.Count + ' 个进程：' + ($killed -join ', '))
    Write-Host 'DSH 服务与界面窗口已全部退出。'
    Show-Popup ('DeepSeek Harness 已完全退出（已停止 ' + $killed.Count + ' 个进程）。') 64
} else {
    Log-Result '未发现正在运行的 DSH 服务（可能本来就没有运行）'
    Write-Host '未发现正在运行的 DSH 服务（可能本来就没有运行）。'
    Show-Popup '未发现正在运行的 DSH 服务。' 64
}
exit 0
