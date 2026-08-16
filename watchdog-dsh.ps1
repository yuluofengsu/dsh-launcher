# watchdog-dsh.ps1 - DSH 服务守护（内存看门狗 + 崩溃自动重启；由 launch-dsh.ps1 隐藏启动）
# 每隔 IntervalSeconds 采样服务进程：
#   - 超过 WarnMB            -> 记录提示日志；
#   - 超过 KillMB 连续 3 次   -> 终止服务并清理 pidfile（防内存泄漏拖垮整机），
#                               不自动重启（避免泄漏引发重启风暴），日志提示手动启动；
#   - 服务进程意外退出（崩溃）-> 自动重启（有限次：RestartWindowMinutes 内最多
#                               RestartCap 次，防重启风暴），重启后本看门狗退出，
#                               由新实例的看门狗接管；
#   - 退出快捷方式会先终止本看门狗再停服务，因此不会触发误重启。
param(
    [int]$ServerPid,
    [int]$WarnMB = 1536,
    [int]$KillMB = 3072,
    [int]$IntervalSeconds = 60,
    [int]$RestartCap = 3,
    [int]$RestartWindowMinutes = 15,
    [string]$LaunchScript = ''   # 测试/自定义用；默认取本目录 launch-dsh.ps1
)
$ErrorActionPreference = 'Continue'
$stateDir = Join-Path $env:USERPROFILE '.dsh\launcher'
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$memLog = Join-Path $stateDir 'memory.log'
$restartLog = Join-Path $stateDir 'restart.log'
$pidFile = Join-Path $stateDir 'dsh-web.pid'
if (-not $LaunchScript) { $LaunchScript = Join-Path $PSScriptRoot 'launch-dsh.ps1' }

function Log($msg) {
    try { Add-Content -Path $memLog -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg) -Encoding UTF8 } catch {}
}
function Log-Restart($msg) {
    try { Add-Content -Path $restartLog -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg) -Encoding UTF8 } catch {}
}

# 日志超 1MB 自动清空（防长期累积）
foreach ($f in @($memLog, $restartLog)) {
    if ((Test-Path $f) -and ((Get-Item $f).Length -gt 1MB)) {
        try { Clear-Content $f -ErrorAction Stop } catch {}
    }
}

# 最近 RestartWindowMinutes 内的重启次数（跨看门狗实例统计，防重启风暴）
function Get-RecentRestarts {
    $cut = (Get-Date).AddMinutes(-$RestartWindowMinutes)
    $n = 0
    if (Test-Path $restartLog) {
        foreach ($line in (Get-Content $restartLog -ErrorAction SilentlyContinue)) {
            if ($line -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+RESTART') {
                try {
                    $ts = [datetime]::ParseExact($line.Substring(0, 19), 'yyyy-MM-dd HH:mm:ss', $null)
                    if ($ts -ge $cut) { $n++ }
                } catch {}
            }
        }
    }
    return $n
}

# 自动重启（崩溃恢复）
function Start-AutoRestart($reason) {
    if (-not (Test-Path $LaunchScript)) {
        Log ($reason + '，但找不到启动脚本 ' + $LaunchScript + '，请手动点击启动图标')
        return
    }
    $recent = Get-RecentRestarts
    if ($recent -ge $RestartCap) {
        Log ('重启次数已达上限（' + $RestartCap + ' 次 / ' + $RestartWindowMinutes + ' 分钟），停止自动重启，请手动点击启动图标')
        return
    }
    Log ($reason + '，等待 2 秒后自动重启...')
    Start-Sleep -Seconds 2
    try {
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $LaunchScript) `
            -WindowStyle Hidden | Out-Null
        Log-Restart 'RESTART'
        Log ('已触发自动重启: ' + $LaunchScript)
    } catch {
        Log ('自动重启失败: ' + $_.Exception.Message)
    }
}

Log ("看门狗启动：监控 PID=" + $ServerPid + "，警告阈值=" + $WarnMB + "MB，终止阈值=" + $KillMB + "MB，间隔=" + $IntervalSeconds + "s，重启上限=" + $RestartCap + "次/" + $RestartWindowMinutes + "分钟")
$overCount = 0
$sampleCount = 0

while ($true) {
    $proc = Get-Process -Id $ServerPid -ErrorAction SilentlyContinue
    if (-not $proc) {
        # 看门狗还活着而服务没了 = 意外退出（退出快捷方式会先杀看门狗）
        Start-AutoRestart '检测到服务进程意外退出（疑似崩溃）'
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
            Log '已终止并清理 PID 文件。为避免泄漏引发重启风暴，不自动重启；请手动点击启动图标恢复。'
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
