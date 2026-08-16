# watchdog-dsh.ps1 - DSH 服务内存看门狗（由 launch-dsh.ps1 隐藏启动）
# 每隔 IntervalSeconds 采样服务进程 RSS：
#   - 超过 WarnMB -> 记录提示日志；
#   - 超过 KillMB 连续 3 次 -> 终止服务并清理 pidfile（防内存泄漏拖垮整机）；
#   - 服务进程退出 -> 看门狗自动退出（不留孤儿进程）。
param(
    [int]$ServerPid,
    [int]$WarnMB = 1536,
    [int]$KillMB = 3072,
    [int]$IntervalSeconds = 60
)
$ErrorActionPreference = 'Continue'
$stateDir = Join-Path $env:USERPROFILE '.dsh\launcher'
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$memLog = Join-Path $stateDir 'memory.log'
$pidFile = Join-Path $stateDir 'dsh-web.pid'

function Log($msg) {
    try { Add-Content -Path $memLog -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg) -Encoding UTF8 } catch {}
}

# 日志超 1MB 自动清空（防长期累积）
if ((Test-Path $memLog) -and ((Get-Item $memLog).Length -gt 1MB)) {
    try { Clear-Content $memLog -ErrorAction Stop } catch {}
}

Log ("看门狗启动：监控 PID=" + $ServerPid + "，警告阈值=" + $WarnMB + "MB，终止阈值=" + $KillMB + "MB，间隔=" + $IntervalSeconds + "s")
$overCount = 0
$sampleCount = 0

while ($true) {
    $proc = Get-Process -Id $ServerPid -ErrorAction SilentlyContinue
    if (-not $proc) {
        Log '服务进程已退出，看门狗退出。'
        exit 0
    }
    $rssMB = [math]::Round($proc.WorkingSet64 / 1MB, 1)
    $sampleCount++

    if ($sampleCount % 10 -eq 0) {
        Log ("采样: RSS=" + $rssMB + " MB")
    }

    if ($rssMB -ge $KillMB) {
        $overCount++
        Log ("警告: RSS=" + $rssMB + "MB 超过终止阈值（" + $KillMB + "MB），连续第 " + $overCount + "/3 次")
        if ($overCount -ge 3) {
            Log ("内存失控，终止服务进程 PID=" + $ServerPid + " 以释放内存")
            taskkill /PID $ServerPid /T /F 2>$null | Out-Null
            try { Remove-Item $pidFile -Force -ErrorAction Stop } catch {}
            Log '已终止，并已清理 PID 文件。重新点击桌面启动图标即可恢复。'
            exit 2
        }
    } elseif ($rssMB -ge $WarnMB) {
        Log ("提示: RSS=" + $rssMB + "MB 已超过警告阈值（" + $WarnMB + "MB）")
        $overCount = 0
    } else {
        $overCount = 0
    }

    Start-Sleep -Seconds $IntervalSeconds
}
