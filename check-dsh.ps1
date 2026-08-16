# check-dsh.ps1 - DeepSeek Harness 启动器自检（由 dsh-launcher.bat /check 调用）
$ErrorActionPreference = 'Continue'
$script:ok = $true

function Check($name, $cond, $detail) {
    if ($cond) { Write-Host ("  [OK]   " + $name) }
    else { Write-Host ("  [FAIL] " + $name + ($(if ($detail) { '  -> ' + $detail } else { '' }))); $script:ok = $false }
}
function Info($name, $detail) { Write-Host ("  [info] " + $name + ": " + $detail) }

Write-Host 'DeepSeek Harness 启动器自检'
Write-Host '============================'

# ---- 环境依赖（关键项）----
$node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
Check 'Node.js' ([bool]$node) ($node)
$cmd = (Get-Command dsh.cmd -ErrorAction SilentlyContinue).Source
if (-not $cmd) { $cmd = (Get-Command dsh.ps1 -ErrorAction SilentlyContinue).Source }
$bin = $null
if ($cmd) { $bin = Join-Path (Split-Path -Parent $cmd) 'node_modules\@deepseek-ai\dsh\lib\bin.js' }
Check 'DSH CLI (dsh.cmd)' ([bool]$cmd) ($cmd)
Check 'DSH 入口 bin.js' ([bool]$bin -and (Test-Path $bin)) ($bin)
Check 'curl.exe（就绪探测）' (Test-Path (Join-Path $env:SystemRoot 'System32\curl.exe')) ''
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
Check 'Edge / Chrome' ((Test-Path $edge) -or (Test-Path $chrome)) ''

# ---- 运行状态（参考项）----
$stateDir = Join-Path $env:USERPROFILE '.dsh\launcher'
Check '状态目录存在' (Test-Path $stateDir) ($stateDir)

$pidFile = Join-Path $stateDir 'dsh-web.pid'
$svcPid = $null
if (Test-Path $pidFile) {
    $val = (Get-Content $pidFile -Raw).Trim()
    if ($val -match '^\d+$') {
        $p = Get-Process -Id ([int]$val) -ErrorAction SilentlyContinue
        if ($p) { $svcPid = $val } else { Info 'PID 文件' ('记录 PID=' + $val + ' 但进程已不存在（过期）') }
    }
}
if ($svcPid) { Info '服务进程' ('PID=' + $svcPid + ' 存活') } else { Info '服务进程' '未运行' }

$listening = netstat -ano | Select-String ':3080\s+.*LISTENING'
if ($listening) { Info '端口 3080' (($listening.ToString().Trim() -split '\s+' | Where-Object { $_ } | Select-Object -Last 1)) } else { Info '端口 3080' '未监听' }

$http200 = $false
try {
    [System.Net.WebRequest]::DefaultWebProxy = $null
    $req = [System.Net.HttpWebRequest]::Create('http://127.0.0.1:3080/')
    $req.Timeout = 1500
    $req.ReadWriteTimeout = 1500
    $resp = $req.GetResponse()
    $http200 = ([int]$resp.StatusCode) -lt 500
    $resp.Close()
} catch {}
Info 'HTTP 界面就绪' $(if ($http200) { '是（可直接打开）' } else { '否（服务未启动或启动中）' })

$appWin = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and ($_.CommandLine -match 'DeepSeekHarness\\edge-app' -or $_.CommandLine -match 'DeepSeekHarness\\chrome-app') }).Count
Info 'DSH 界面应用窗口' ("" + $appWin + ' 个相关进程')

# ---- 内存防护状态 ----
$svcProc = if ($svcPid) { Get-Process -Id ([int]$svcPid) -ErrorAction SilentlyContinue } else { $null }
if ($svcProc) {
    Info '服务内存 RSS' ([string][math]::Round($svcProc.WorkingSet64 / 1MB, 1) + ' MB（V8堆上限+看门狗终止阈值按内存分档）')
} else {
    Info '服务内存 RSS' '未运行'
}
$wd = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -match 'watchdog-dsh\.ps1' }).Count
Info '内存看门狗' $(if ($wd -gt 0) { '运行中（防泄漏，超阈值自动终止并记录）' } else { '未运行' })
$memLog = Join-Path $stateDir 'memory.log'
if (Test-Path $memLog) {
    Info ('日志 memory.log') ([string][math]::Round((Get-Item $memLog).Length / 1KB, 1) + ' KB')
    Get-Content $memLog -Tail 3 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ('      ' + $_) }
}
$restartLog = Join-Path $stateDir 'restart.log'
if (Test-Path $restartLog) {
    $rt = @(Get-Content $restartLog -ErrorAction SilentlyContinue | Where-Object { $_ -match 'RESTART' }).Count
    if ($rt -gt 0) {
        Info '自动重启记录 restart.log' ($rt + ' 次')
        Get-Content $restartLog -Tail 3 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host ('      ' + $_) }
    }
}

foreach ($f in @('dsh-web.log', 'dsh-web.err.log', 'exit.log')) {
    $fp = Join-Path $stateDir $f
    if (Test-Path $fp) { Info ('日志 ' + $f) ([string][math]::Round((Get-Item $fp).Length / 1KB, 1) + ' KB') }
}

Write-Host ''
if ($script:ok) { Write-Host '自检结论：环境正常，插件可用。'; exit 0 }
Write-Host '自检结论：存在 [FAIL] 项，请按提示处理。'; exit 1
