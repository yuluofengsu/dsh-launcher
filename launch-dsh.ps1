param(
    [int]$TimeoutSeconds = 90
)
# 启动 DeepSeek Harness (DSH) Web 服务（隐藏窗口）并等待 HTTP 就绪。
# 由 dsh-launcher.bat 调用；不要直接双击运行。
# 退出码：0 = 已就绪 / 已在运行；1 = 启动失败或等待超时。
$ErrorActionPreference = 'Stop'
$url = 'http://127.0.0.1:3080/'

$stateDir = Join-Path $env:USERPROFILE '.dsh\launcher'
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$pidFile = Join-Path $stateDir 'dsh-web.pid'
$logFile = Join-Path $stateDir 'dsh-web.log'
$errLog  = Join-Path $stateDir 'dsh-web.err.log'

# 直连本机，不走系统代理（避免 VPN/代理把 127.0.0.1 转发走）
[System.Net.WebRequest]::DefaultWebProxy = $null

# HTTP 就绪探测：带显式超时，未就绪时快速放弃（不干等）
function Test-HttpReady {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Timeout = 500
    $req.ReadWriteTimeout = 500
    try {
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        return $code -lt 500
    } catch {
        return $false
    }
}

# 端口是否在监听（用于区分“另一个实例正在启动”与“真的失败了”）
function Test-PortListening {
    try {
        $port = ([Uri]$url).Port
        return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop | Select-Object -First 1)
    } catch {
        return $false
    }
}

# 防御：若端口上已经能响应，直接视为已就绪
if (Test-HttpReady) {
    Write-Host '服务已在运行。'
    exit 0
}

$node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
if (-not $node) { throw '找不到 node.exe，请确认 Node.js 已安装并加入 PATH。' }

$cmd = (Get-Command dsh.cmd -ErrorAction SilentlyContinue).Source
if (-not $cmd) { $cmd = (Get-Command dsh.ps1 -ErrorAction SilentlyContinue).Source }
if (-not $cmd) { throw '找不到 dsh 命令，请确认 DeepSeek Harness 已安装。' }
$npmRoot = Split-Path -Parent $cmd
$bin = Join-Path $npmRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'
if (-not (Test-Path $bin)) { throw "找不到 DSH 入口文件: $bin" }

# ---- 内存上限（按物理内存分档）----
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
if ($ramGB -ge 16) {
    $heapCapMB = 3072; $warnMB = 2048; $killMB = 4096
} elseif ($ramGB -ge 8) {
    $heapCapMB = 2048; $warnMB = 1536; $killMB = 3072
} else {
    $heapCapMB = 1024; $warnMB = 768; $killMB = 1536
}
Write-Host ("内存策略: V8堆上限=" + $heapCapMB + "MB，看门狗警告=" + $warnMB + "MB / 终止=" + $killMB + "MB")

# 启动前：日志超过 1MB 自动清空（防止长期累积）
foreach ($f in @($logFile, $errLog)) {
    if ((Test-Path $f) -and ((Get-Item $f).Length -gt 1MB)) {
        try { Clear-Content $f -ErrorAction Stop } catch {}
    }
}

# 启动服务：隐藏窗口，输出重定向到日志文件，并设置 V8 堆内存上限
$proc = Start-Process -FilePath $node `
    -ArgumentList @('--max-old-space-size=' + $heapCapMB, '"' + $bin + '"', 'web') `
    -WorkingDirectory $env:USERPROFILE `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError $errLog `
    -PassThru

Set-Content -Path $pidFile -Value $proc.Id -Encoding Ascii
Write-Host ('服务进程 PID: ' + $proc.Id)

# 启动内存看门狗（隐藏，服务退出后自动退出）
try {
    $wd = Join-Path $PSScriptRoot 'watchdog-dsh.ps1'
    if (Test-Path $wd) {
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', $wd, '-ServerPid', $proc.Id, '-WarnMB', $warnMB, '-KillMB', $killMB) `
            -WindowStyle Hidden | Out-Null
        Write-Host '内存看门狗已启动。'
    }
} catch {
    Write-Host '内存看门狗启动失败（不影响服务）。'
}
Write-Host '正在等待服务就绪...'

# 等待 HTTP 就绪；若服务进程提前退出则立即报错
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$ready = $false
$lastTick = -1
while ((Get-Date) -lt $deadline) {
    if (-not (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue)) {
        # 本实例的进程退出了
        if (Test-HttpReady) {
            Write-Host '服务已就绪（可能由其他实例启动）。'
            exit 0
        }
        if (Test-PortListening) {
            # 端口已被占用：另一个实例正在启动，继续等它就绪
            Write-Host '检测到其他实例正在启动，继续等待...'
        } else {
            Write-Host '启动失败：服务进程提前退出。'
            if (Test-Path $errLog) {
                $tail = Get-Content $errLog -Tail 8 -ErrorAction SilentlyContinue
                if ($tail) {
                    $clean = ($tail | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' | '
                    if ($clean) { Write-Host ('错误日志（尾部）：' + $clean) }
                }
            }
            exit 1
        }
    }
    if (Test-HttpReady) {
        $ready = $true
        break
    }
    $el = [int]$sw.Elapsed.TotalSeconds
    if ($el -gt $lastTick -and ($el % 5) -eq 0) {
        Write-Host ("等待服务就绪... 已用 $el 秒")
        $lastTick = $el
    }
    Start-Sleep -Milliseconds 500
}

if (-not $ready) {
    Write-Host ("等待超时（$TimeoutSeconds 秒），服务未就绪。")
    Write-Host ("请查看日志：$errLog")
    exit 1
}
Write-Host ("服务已就绪（用时 $([int]$sw.Elapsed.TotalSeconds) 秒），界面将自动打开。")
exit 0
