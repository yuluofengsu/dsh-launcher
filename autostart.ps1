# autostart.ps1 - 开关 DSH 开机自启（由 dsh-autostart.bat 调用，不要直接双击）
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$startup = [Environment]::GetFolderPath('Startup')
$lnk = Join-Path $startup 'DSH AutoStart.lnk'
$ws = New-Object -ComObject WScript.Shell
if (Test-Path $lnk) {
    Remove-Item $lnk -Force
    Write-Host '已关闭开机自启：登录时不再自动启动 DSH。'
} else {
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = Join-Path $here 'dsh-launcher.bat'
    $s.Arguments = '/autostart'
    $s.WorkingDirectory = $here
    $s.WindowStyle = 7
    $s.Description = 'DeepSeek Harness auto start (headless)'
    $s.Save()
    Write-Host '已开启开机自启：登录后自动在后台启动 DSH 服务（不弹界面）。'
    Write-Host '之后点桌面「DeepSeek Harness」图标即可秒开界面。'
}
