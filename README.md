# DeepSeek Harness 一键启动 / 退出插件

[![version](https://img.shields.io/badge/version-1.1.0-blue)]()
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![platform](https://img.shields.io/badge/platform-Windows%2010%2F11-lightgrey)]()

为 [DeepSeek Harness](https://www.npmjs.com/package/@deepseek-ai/dsh)（DSH）Web 界面打造的一键启动 / 一键退出插件：双击即启动服务并打开应用窗口，退出完全静默并带反馈弹窗，内置内存防泄漏看门狗。纯脚本（`bat` + `ps1` + `vbs` + `html`），零第三方依赖，**安装不需要管理员权限**。

## 🚀 一键安装（傻瓜式）

**方式 A — 在线安装（推荐，一行命令）**：打开 PowerShell，粘贴回车：

```powershell
irm https://raw.githubusercontent.com/yuluofengsu/dsh-launcher/main/install-online.ps1 | iex
```

脚本会自动：从本仓库拉取 → 检查 / 自动安装依赖（Node.js 20+ 与 DSH，若缺失）→ 安装插件到 `%LOCALAPPDATA%\DSHLauncher` → 创建桌面快捷方式。

**方式 B — 下载安装包**：

1. 下载本仓库 zip（绿色 Code → Download ZIP）并解压到任意目录
2. 双击 `install.bat`
3. 若提示缺少依赖，先双击 `install-harness.bat`（自动装 Node.js/DSH），再运行 `install.bat`

安装完成后桌面会出现两个快捷方式：「DeepSeek Harness」启动、「退出 DeepSeek Harness」退出。

## 🤖 AI / 自动安装

本仓库含 `AGENTS.md`，AI 代理（或任何自动化脚本）可直接读取并按命令安装：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Target "$env:LOCALAPPDATA\DSHLauncher"
```

- 幂等：重复运行安全；退出码 `0` = 成功
- 验证：`& "$env:LOCALAPPDATA\DSHLauncher\dsh-launcher.bat" /check`（输出"自检结论：环境正常"且退出码 0）
- 卸载：`.\uninstall.ps1 -Target "$env:LOCALAPPDATA\DSHLauncher"`

## ✨ 功能特性

- ⚡ **一键启动**：服务未运行 → 立刻弹出带转圈动画的加载窗口，后台**隐藏**启动服务，就绪后自动切换界面；服务已在运行 → 直接打开
- 🖥️ **应用窗口**：无地址栏 / 标签页的独立窗口（Edge/Chrome `--app` + 独立配置目录，与日常浏览器互不干扰），默认最大化、自带图标标题；重复点击不堆叠
- 🤫 **一键退出**：完全静默（无控制台弹窗），完成后弹约 3 秒反馈框；结果写入 `exit.log`
- 🛡️ **内存防泄漏**：服务以 V8 堆上限启动；内存看门狗每 60 秒采样，连续 3 次超限自动终止并记录，防止拖垮整机
- 🔄 **健壮性**：已处理幽灵 PID、双开竞态、启动中重复点击、服务异常退出；挂掉后点启动图标即恢复
- 🚀 **可选开机自启**：登录时后台预热服务，之后点图标秒开界面
- 🔍 **自带自检**：`dsh-launcher.bat /check` 一键检查环境、服务、端口、看门狗与日志

## 📁 目录结构

| 文件 | 作用 |
|---|---|
| `install-online.ps1` | 在线一键安装（拉取仓库 + 装依赖 + 安装） |
| `install.bat` / `install.ps1` | 安装器（复制文件 + 建快捷方式，`/silent` 静默） |
| `install-harness.bat` | 依赖安装器（Node.js 20+ / DSH，`/nopause` 静默） |
| `uninstall.bat` / `uninstall.ps1` | 卸载器（删快捷方式 + 安装目录） |
| `dsh-launcher.bat` | 启动入口（`/autostart` 无头、`/check` 自检） |
| `dsh-stopper.bat` / `stop-dsh.vbs` | 退出入口（VBS 隐藏启动） |
| `launch-dsh.ps1` | 隐藏启动服务 + 等 HTTP 就绪 + 拉起看门狗 |
| `stop-dsh.ps1` | 可靠退出（PID + 命令行匹配 + 关界面窗口）+ 反馈弹窗 + 日志 |
| `watchdog-dsh.ps1` | 内存看门狗（防泄漏，服务退出后自动退出） |
| `check-dsh.ps1` | 自检脚本 |
| `autostart.ps1` / `dsh-autostart.bat` | 开机自启开关 |
| `waiting.html` | 启动过渡页（就绪后自动切换） |
| `AGENTS.md` | AI 代理 / 自动化安装说明 |
| `DeepSeekHarness-WhaleGirl.ico` | 快捷方式图标 |
| `VERSION` | 版本号 |

## 💻 使用

| 操作 | 方式 |
|---|---|
| 打开 DSH 界面 | 双击桌面「DeepSeek Harness」 |
| 退出 DSH | 双击桌面「退出 DeepSeek Harness」（静默 + 反馈弹窗） |
| 开机自启开关 | 双击安装目录里 `dsh-autostart.bat`（再点一次关闭） |
| 一键自检 | `dsh-launcher.bat /check` |
| 卸载 | `uninstall.bat`（或 `uninstall.ps1 -Target <目录>`） |

运行状态与日志保存在 `%USERPROFILE%\.dsh\launcher\`：`dsh-web.pid`（服务 PID）、`dsh-web.log` / `dsh-web.err.log`（服务日志，超 1MB 自动清空）、`exit.log`（退出记录）、`memory.log`（内存看门狗记录）。

## 🛡️ 内存保护

服务进程实测基线约 **350MB**（界面窗口为浏览器进程，退出时一并关闭释放）。上限按物理内存自动分档：

| 物理内存 | V8 堆上限 | 看门狗警告 | 看门狗终止（连续 3 次采样） |
|---|---|---|---|
| ≥ 16GB | 3072MB | 2048MB | 4096MB |
| ≥ 8GB | 2048MB | 1536MB | 3072MB |
| 其它 | 1024MB | 768MB | 1536MB |

看门狗每 60 秒采样，只有持续超限（约 3 分钟）才终止并清理 PID 文件；服务正常退出后看门狗自动退出。

## ❓ 常见问题

- **启动后界面打不开** → 看 `dsh-web.err.log`，或运行 `/check` 检查依赖
- **服务突然停止** → 看 `memory.log`（看门狗终止记录）或 `dsh-web.err.log`（崩溃记录）
- **退出后端口仍占用** → 再点一次退出，或看 `exit.log` 里的残留 PID
- **界面窗口没反应** → 服务在跑时直接打开 `http://127.0.0.1:3080`，或点启动快捷方式聚焦已有窗口
- **在线安装被安全软件拦截** → 用方式 B（下载 zip + install.bat）

## 🖥️ 兼容性

- Windows 10 / 11（x64）
- 浏览器优先 Microsoft Edge，缺失时自动回退 Chrome
- Node.js 20+（由 DSH 决定）

## 📄 许可

[MIT License](LICENSE) © 2026 wenfan (yuluofengsu)
