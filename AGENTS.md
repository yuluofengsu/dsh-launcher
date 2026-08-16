# AGENTS.md — 给 AI 代理 / 自动化脚本的安装说明

本仓库是 **DeepSeek Harness（DSH）Web 界面的一键启动/退出插件**（Windows，纯 `bat` / `ps1` / `vbs` / `html`，无编译、无第三方运行时依赖，安装不需要管理员权限）。

如果你是一个 AI 代理，被要求"安装这个仓库"，按下面的命令执行即可。**安装是幂等的**：重复运行安全，会覆盖安装目录并重建桌面快捷方式；卸载请明确征求用户同意后再做。

## 快速安装（推荐）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 -Target "$env:LOCALAPPDATA\DSHLauncher"
```

- 退出码：`0` = 成功；非 `0` = 失败（stderr 中有原因）。
- 若输出提示缺少 Node.js / DSH，先执行依赖安装器（自动装，可能几分钟）：
  ```powershell
  .\install-harness.bat /nopause
  ```
  然后重跑上面的 install.ps1。
- 也可以用一键在线安装（直接从本仓库拉取，无需先克隆）：
  ```powershell
  irm https://raw.githubusercontent.com/yuluofengsu/dsh-launcher/main/install-online.ps1 | iex
  ```

## 验证安装

```powershell
& "$env:LOCALAPPDATA\DSHLauncher\dsh-launcher.bat" /check
```

- 输出包含 `[OK]` 项与"自检结论：环境正常"且退出码 `0` = 安装正确。
- 直接运行自检脚本也可：`powershell -NoProfile -ExecutionPolicy Bypass -File .\check-dsh.ps1`。

## 启动 / 退出（给用户）

- 启动：双击桌面「DeepSeek Harness」，或 `& "$env:LOCALAPPDATA\DSHLauncher\dsh-launcher.bat"`
- 退出：双击桌面「退出 DeepSeek Harness」（静默，完成后弹反馈框），或 `wscript "$env:LOCALAPPDATA\DSHLauncher\stop-dsh.vbs"`
- 更新到最新版：`& "$env:LOCALAPPDATA\DSHLauncher\dsh-launcher.bat" /update`（从本仓库拉取覆盖；服务运行中也能更新，下次退出+启动生效）

## 守护行为（重要，避免误判）

- 服务进程由守护进程（watchdog-dsh.ps1）监控：
  - 服务**意外退出** → 2 秒后自动重启（15 分钟内最多 3 次，防重启风暴）；
  - 服务**内存失控**（连续 3 次超阈值）→ 守护进程主动终止且**不**自动重启（避免循环），需手动启动；
  - 退出快捷方式会**先关守护进程**再停服务 → 不会误触发重启。
- 如果你发现"服务自己又起来了"，先看 `%USERPROFILE%\.dsh\launcher\restart.log`（崩溃自动重启）与 `memory.log`（内存终止记录），不要直接判定为异常。

## 卸载（仅在用户要求时）

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 -Target "$env:LOCALAPPDATA\DSHLauncher"
```
或双击 `uninstall.bat`。

## 文件一览

| 文件 | 作用 |
|---|---|
| `dsh-launcher.bat` | 启动入口（`/autostart` 无头、`/check` 自检） |
| `dsh-stopper.bat` / `stop-dsh.vbs` | 退出入口 |
| `launch-dsh.ps1` | 隐藏启动服务 + 等就绪 + 拉起内存看门狗 |
| `stop-dsh.ps1` | 可靠退出 + 反馈弹窗 + 日志 |
| `watchdog-dsh.ps1` | 守护进程（内存看门狗 + 崩溃自动重启） |
| `update-dsh.ps1` | 自更新（`dsh-launcher.bat /update`） |
| `check-dsh.ps1` | 自检 |
| `autostart.ps1` / `dsh-autostart.bat` | 开机自启开关 |
| `waiting.html` | 启动过渡页 |
| `install.ps1` / `install.bat` | 安装器（复制文件 + 建快捷方式） |
| `install-online.ps1` | 在线一键安装（下载本仓库并安装） |
| `install-harness.bat` | 依赖安装器（Node.js 20+ / DSH，`/nopause` 静默） |
| `uninstall.ps1` / `uninstall.bat` | 卸载器 |

## 注意事项

- 不要修改仓库文件来"适配"安装；安装目录可由 `-Target` 任意指定。
- 插件不写注册表、不创建 Windows 服务；运行时数据在 `%USERPROFILE%\.dsh\launcher\`。
- 依赖的 DSH 服务监听 `127.0.0.1:3080`；界面窗口使用 Edge/Chrome `--app` 隔离配置（`%LOCALAPPDATA%\DeepSeekHarness\`）。
