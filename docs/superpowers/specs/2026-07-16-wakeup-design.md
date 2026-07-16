# WakeUp — 防休眠 + 假屏保 macOS App 设计文档

日期：2026-07-16
状态：已确认

## 目标

一个原生 macOS 应用，一键进入「工作模式」：阻止电脑休眠，同时全屏显示一个仿 macOS
时钟屏保的遮罩，让 AI agent（纯命令行/后台进程，如 Claude Code）在后台不受打扰地
持续工作，旁人看到的只是一台"在屏保中"的电脑。

## 需求确认

- **Agent 类型**：纯命令行/后台进程，不需要看屏幕或操作 GUI → 假屏保可以全屏遮盖。
- **交互形态**：普通 App，带主窗口（控制/设置界面）。
- **退出方式**：任意鼠标移动或键盘按键退出屏保（与真屏保行为一致）。
  鼠标移动加约 10px 阈值防误触。
- **屏保样式**：仿 macOS 锁屏前的时钟屏保——黑底 + 大号细体时钟（HH:mm）+ 日期。

## 技术选型

Swift + SwiftUI 原生 App，无第三方依赖。

- 防休眠用 IOKit 电源断言（`IOPMAssertionCreateWithName`），macOS 官方机制。
- 遮罩用 borderless `NSWindow`，层级高于 Dock/菜单栏。
- 备选方案 Electron/Tauri（体积大、绕路）与 shell 脚本 + caffeinate（不成 App、
  多屏和退出逻辑脆弱）均被否决。

## 架构

四个模块，单一职责，互相通过明确接口通信：

### 1. 主窗口（ContentView）

- 大按钮「开始工作模式」：一键激活防休眠 + 假屏保。
- 状态显示:是否正在阻止休眠、工作模式已持续时间。
- 可选延时启动（如 5 秒倒计时后进入屏保，给用户时间松开鼠标）。

### 2. SleepPreventer（防休眠模块）

- `start()`：创建两个 IOPM 断言：
  - `PreventUserIdleSystemSleep` — 阻止系统休眠。
  - `PreventUserIdleDisplaySleep` — 阻止显示器熄屏（屏保需要一直可见）。
- `stop()`：释放断言，恢复正常电源策略。
- 断言随进程退出自动释放，App 崩溃不会永久影响电源策略。

### 3. ScreensaverOverlay（假屏保模块）

- 为每个接入的显示器创建一个 borderless、黑色背景的 `NSWindow`，
  `window.level` 高于 Dock 与菜单栏，`collectionBehavior` 覆盖所有 Space。
- 内容视图（SwiftUI）：白色大号细体时钟 HH:mm + 日期行，居中；
  每分钟轻微随机位移防烧屏。
- 激活时隐藏鼠标指针（`NSCursor.hide()`），退出时恢复。
- 监听屏幕配置变化（`NSApplication.didChangeScreenParametersNotification`），
  插拔显示器时动态增删遮罩窗口。

### 4. 退出监控（ExitMonitor）

- 屏保激活后用 `NSEvent` 全局 + 本地监听：鼠标移动、鼠标点击、任意按键。
- 鼠标移动累计超过约 10px 阈值才触发（防桌面震动误退）；点击和按键立即触发。
- 触发后：关闭全部遮罩窗口 → 释放电源断言 → 恢复鼠标指针 → 回到主窗口。

## 数据流

```
主窗口「开始」→（可选倒计时）→ SleepPreventer.start()
                             → ScreensaverOverlay.show()
                             → ExitMonitor.arm()
用户动鼠标/按键 → ExitMonitor 触发 → Overlay.hide() → SleepPreventer.stop()
                                   → 主窗口显示"已结束，本次持续 X 分钟"
```

## 边界情况

- **合盖**：电源断言无法阻止合盖休眠（macOS 系统限制）。README 中说明需保持开盖，
  主界面提示一句。
- **多显示器插拔**：屏保激活期间监听屏幕变化，动态调整窗口。
- **App 意外退出**：IOPM 断言随进程消亡自动释放，无残留。
- **系统真屏保/锁屏**：防显示器熄屏断言同时抑制系统空闲屏保；用户手动锁屏不干预。

## 测试策略

- SleepPreventer：单元级验证——启动后 `pmset -g assertions` 能看到本 App 的两条断言，
  停止后消失。
- Overlay/退出逻辑：手动验证——多屏全覆盖、鼠标/键盘退出、指针隐藏恢复、
  插拔显示器不崩溃。
- 构建产物：`xcodebuild`（或 SwiftPM bundle）产出可双击运行的 .app。
