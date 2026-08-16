# DeepSeek Harness 一键启动 / 退出插件

为 [DeepSeek Harness](https://github.com/deepseek-ai)（DSH）Web 界面打造的一键启动 / 一键退出插件：双击即启动服务并打开应用窗口，退出完全静默并带反馈弹窗，内置内存防泄漏看门狗。

> 纯脚本插件（bat + ps1 + vbs + html），零依赖第三方库，手动放置即可使用。

## 功能特性

- ⚡ **一键启动**：服务未运行 → 立刻弹出带转圈动画的加载窗口，后台**隐藏**启动服务，就绪后自动切换到界面；服务已在运行 → 直接打开
- 🖥️ **应用窗口**：无地址栏 / 标签页的独立窗口（Edge/Chrome `--app` 模式 + 独立配置目录，与日常浏览器互不干扰），默认最大化、自带图标标题；重复点击不堆叠窗口
- 🤫 **一键退出**：完全静默（无控制台弹窗），完成后弹出约 3 秒的反馈提示框（正常退出 / 未发现服务 / 端口占用警告），结果同时写入 `exit.log`
- 🛡️ **内存防泄漏**：服务以 V8 堆上限（`--max-old-space-size`）启动；内存看门狗每 60 秒采样，连续 3 次超过终止阈值即自动终止并记录，防止泄漏拖垮整机
- 🔄 **健壮性**：已处理幽灵 PID、双开竞态、启动中途重复点击、服务异常退出等边界情况；服务挂掉后点启动图标即可恢复
- 🚀 **可选开机自启**：登录时后台预热服务，之后点桌面图标即秒开界面
- 🔍 **自带自检**：`dsh-launcher.bat /check` 一键检查环境依赖、服务进程、端口、内存看门狗与日志

## 目录结构

| 文件 | 作用 |
|---|---|
| `dsh-launcher.bat` | 启动入口（支持 `/autostart` 无头模式、`/check` 自检） |
| `dsh-stopper.bat` / `stop-dsh.vbs` | 退出入口（VBS 隐藏启动，桌面快捷方式实际指向 vbs） |
| `launch-dsh.ps1` | 隐藏启动服务 + 等待 HTTP 就绪 + 拉起看门狗 |
| `stop-dsh.ps1` | 可靠退出（PID + 命令行匹配 + 关界面窗口）+ 反馈弹窗 + 日志 |
| `watchdog-dsh.ps1` | 内存看门狗（防泄漏，服务退出后自动退出） |
| `check-dsh.ps1` | 自检脚本 |
| `autostart.ps1` / `dsh-autostart.bat` | 开机自启开关 |
| `waiting.html` | 启动过渡页（转圈动画，就绪后自动切换） |
| `DeepSeekHarness-WhaleGirl.ico` | 快捷方式图标 |
| `VERSION` | 版本号 |

## 安装

1. 下载 / 克隆本仓库到任意目录（路径建议不含中文）
2. 前置依赖：**Node.js 20+** 与 **DSH CLI**（`npm i -g @deepseek-ai/dsh`），启动器会自动探测，缺失时会在控制台给出明确提示
3. 创建两个桌面快捷方式（PowerShell 一行脚本，把 `$dir` 改成你的实际路径）：

```powershell
$ws = New-Object -ComObject WScript.Shell
$dir = 'D:\tools\dsh-launcher'   # ← 改成你的实际路径
$s1 = $ws.CreateShortcut("$env:USERPROFILE\Desktop\DeepSeek Harness.lnk")
$s1.TargetPath = "$dir\dsh-launcher.bat"; $s1.WorkingDirectory = $dir
$s1.IconLocation = "$dir\DeepSeekHarness-WhaleGirl.ico,0"; $s1.Save()
$s2 = $ws.CreateShortcut("$env:USERPROFILE\Desktop\退出 DeepSeek Harness.lnk")
$s2.TargetPath = "$dir\stop-dsh.vbs"; $s2.WorkingDirectory = $dir
$s2.IconLocation = "$dir\DeepSeekHarness-WhaleGirl.ico,0"; $s2.Save()
```

## 使用

| 操作 | 方式 |
|---|---|
| 打开 DSH 界面 | 双击桌面「DeepSeek Harness」 |
| 退出 DSH | 双击桌面「退出 DeepSeek Harness」（静默 + 反馈弹窗） |
| 开机自启开关 | 双击 `dsh-autostart.bat`（开启 / 再点一次关闭） |
| 一键自检 | `dsh-launcher.bat /check` |
| 无头启动（自启用） | `dsh-launcher.bat /autostart` |

运行状态与日志保存在 `%USERPROFILE%\.dsh\launcher\`：

| 文件 | 内容 |
|---|---|
| `dsh-web.pid` | 服务进程 PID |
| `dsh-web.log` / `dsh-web.err.log` | 服务标准输出 / 错误日志（超 1MB 自动清空） |
| `exit.log` | 每次退出的结果记录 |
| `memory.log` | 内存采样与看门狗动作记录 |

## 内存保护

服务进程实测基线约 **350MB**（界面窗口为浏览器进程，退出时一并关闭释放）。上限按物理内存自动分档：

| 物理内存 | V8 堆上限 | 看门狗警告 | 看门狗终止（连续 3 次采样） |
|---|---|---|---|
| ≥ 16GB | 3072MB | 2048MB | 4096MB |
| ≥ 8GB | 2048MB | 1536MB | 3072MB |
| 其它 | 1024MB | 768MB | 1536MB |

看门狗每 60 秒采样一次，只有**持续超限**（约 3 分钟）才终止服务并清理 PID 文件，正常波动不会误杀；服务正常退出后看门狗自动退出，不留孤儿进程。

## 常见问题

- **启动后界面打不开** → 看 `dsh-web.err.log`，或运行 `/check` 检查依赖
- **服务突然停止** → 看 `memory.log`（看门狗终止记录）或 `dsh-web.err.log`（崩溃记录）
- **退出后端口仍占用** → 再点一次退出快捷方式，或查看 `exit.log` 里的残留 PID
- **界面窗口没反应** → 服务在跑时直接打开 `http://127.0.0.1:3080`，或点启动快捷方式（会聚焦已有窗口）

## 兼容性

- Windows 10 / 11（x64）
- 浏览器优先 Microsoft Edge，缺失时自动回退 Chrome
- Node.js 20+（服务端由 DSH 决定）

## 许可

本项目未附带开源许可，仅作为个人工具发布；如需商用 / 二次分发请先联系作者。
