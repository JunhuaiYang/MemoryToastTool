# Memory Toast Tool

[中文](#中文) | [English](#english)

## 中文

### 项目简介

Memory Toast Tool 是一个原生 macOS 菜单栏应用，用来持续检测系统内存状态，并在物理内存可用量过低、Swap 过高或内存压力达到阈值时，提示你优先处理最占内存的进程。

它的目标不是“清理内存垃圾”，而是用更可信、更可控的方式，帮助你在系统内存紧张时快速定位问题 App，并安全地执行退出操作。

### 核心能力

- 菜单栏常驻运行，支持手动检测和周期性检测
- 检测周期可配置，支持手动输入秒数
- 支持按可用内存、Swap、内存压力等条件触发告警
- 告警面板展示当前系统内存指标、命中规则和可折叠进程树
- 同时统计应用进程和后台进程，子进程内存会向上聚合到最上层可见根进程
- 默认勾选聚合后内存占用最高的前 `N` 个根进程，`N` 可在设置中配置
- 进程树支持展开查看全部子进程，也支持单独勾选某个子进程关闭
- 点击 `Quit Selected` 后，先尝试正常退出
- 同一面板内显示倒计时进度，倒计时期间持续刷新进程存活状态和内存用量
- 倒计时结束后，只对仍然存活的已选进程显示 `Force Quit Selected`
- 可选为正常退出成功的 App 自动重新打开，重开延迟可配置，默认 `5` 秒
- `Settings` 作为主窗口使用，并且顶部可以手动打开当前告警面板
- 默认支持简体中文和 English，并可在设置中切换语言

### 安全边界

- 不会自动强制退出任何 App
- 强制退出按钮只会在倒计时结束后出现，且必须由用户手动点击
- 被强杀的 App 不会自动重新打开
- 不会把 `launchd`、`kernel_task` 这类系统根进程作为可关闭目标
- 不提供“释放缓存”“清理内存垃圾”这类不可靠的伪优化功能

### 基本使用

#### 1. 首次启动

- 启动应用后，它会以菜单栏应用形式常驻运行
- 首次启动会弹出安全说明窗口，确认后才进入正常使用
- `Settings` 是主窗口；打开时会临时作为 App 主界面出现
- 关闭 `Settings` 后，应用继续在菜单栏常驻，Dock 不保留驻留图标
- 默认检测周期为 `30` 秒

#### 2. 查看当前状态

- 点击菜单栏图标可以查看当前内存摘要
- 菜单中只显示已用内存、可用内存、Swap 和内存压力
- 命中规则和详细进程信息统一放在告警面板中显示

#### 3. 配置检测规则

在主窗口 `Settings` 中可以配置：

- 检测周期（秒）
- 默认勾选的 App 数量
- 正常退出后的自动重开延迟
- 强杀按钮出现前的倒计时时间
- 可用内存告警阈值
- Swap 告警阈值
- 语言
- 并且可以在顶部直接手动打开当前告警面板

#### 4. 处理告警

当系统达到阈值时，会弹出统一告警面板：

- 面板顶部会显示当前内存摘要和命中的规则
- 面板主体会显示可折叠的进程树
- 根进程显示聚合内存，子进程显示自身内存
- 默认勾选最占内存的前几个根进程
- 你可以在倒计时开始前调整勾选项、展开子进程并单独选择某个子进程、以及设置是否自动重开
- 点击 `Quit Selected` 后，面板进入倒计时状态
- 倒计时期间，列表会实时刷新，已成功退出的进程会立即从树中消失
- 倒计时期间勾选框会被置灰，不能再修改
- 倒计时结束后，如果仍有目标进程存活，才会显示 `Force Quit Selected`

#### 5. 面板关闭条件

告警面板会在以下任一条件满足时关闭：

- 勾选的目标进程已经全部退出
- 用户手动点击系统关闭按钮

### 构建与运行

#### 使用 Xcode

```bash
open MemoryToastTool.xcodeproj
```

然后选择 `MemoryToastTool` scheme 直接构建运行。

#### 使用命令行

```bash
swift test
xcodebuild -project MemoryToastTool.xcodeproj -scheme MemoryToastTool -destination 'platform=macOS,arch=arm64' build
```

### 当前版本范围

已支持：

- 原生 macOS 菜单栏应用
- 主窗口式 Settings 面板
- 实时内存采样与规则判断
- 全进程采样与父子进程聚合
- 树形告警面板和安全退出流程
- 正常退出后的可选自动重开
- 忽略一次、稍后提醒、默认忽略列表
- 中文 / English 双语

暂未提供：

- 历史趋势图和长期统计
- 导出 / 导入设置
- 非 macOS 平台支持
- 任意形式的“自动清内存”或系统级内存操作

---

## English

### Overview

Memory Toast Tool is a native macOS menu bar app that monitors system memory usage and prompts you to act on memory-heavy processes when available memory gets too low, swap usage gets too high, or memory pressure crosses a configured threshold.

Its goal is not to "clean memory." The app is designed to help you identify the right apps to close, then guide you through a safer and more explicit quit flow.

### Core Features

- Persistent macOS menu bar app with manual checks and periodic monitoring
- Configurable detection interval with direct numeric input
- Alert rules based on available memory, swap usage, and memory pressure
- Unified alert panel showing current system memory metrics, matched rules, and a collapsible process tree
- Includes both app processes and background processes, with child-process memory aggregated into the topmost visible root process
- Default selection of the top `N` memory-consuming root processes, configurable in settings
- The tree can be expanded to inspect child processes, and individual child processes can be selected directly
- `Quit Selected` always tries normal app termination first
- A live countdown in the same panel, with real-time process and memory updates
- `Force Quit Selected` appears only after the countdown, and only for still-running selected processes
- Optional auto relaunch for apps that exited normally, with configurable delay and a default of `5` seconds
- `Settings` acts as the app's main window and can manually open the current alert panel
- Built-in Simplified Chinese and English support

### Safety Constraints

- The app never force quits automatically
- Force quit is only exposed after the countdown and still requires an explicit user click
- Force-quit apps are never auto relaunched
- System-root owners such as `launchd` and `kernel_task` are not presented as closable targets
- The app does not claim to free memory through fake cache cleaning or "memory junk" cleanup

### Basic Usage

#### 1. First Launch

- Launch the app and it stays in the macOS menu bar
- On first launch, a safety guide window is shown once before normal use
- `Settings` is the main window; when it is closed, the app remains in the menu bar and does not keep a persistent Dock presence
- The default detection interval is `30` seconds

#### 2. Check Current Status

- Click the menu bar icon to inspect the current memory summary
- The menu shows used memory, available memory, swap, and memory pressure only
- Matched rules and detailed process information are shown in the alert panel instead of the menu bar

#### 3. Configure Settings

In the main `Settings` window, you can configure:

- detection interval in seconds
- default selected app count
- auto relaunch delay after a successful normal quit
- countdown duration before force quit is exposed
- available memory alert threshold
- swap alert threshold
- language
- and manually open the current alert panel from the top of the window

#### 4. Handle an Alert

When a configured threshold is reached, the app presents a unified alert panel:

- the header shows the current memory summary and matched rule reasons
- the body shows a collapsible process tree
- root rows show aggregate memory, while child rows show their own memory
- the highest-memory root processes are selected by default
- before the countdown starts, you can adjust selection, inspect child processes, and change auto relaunch choices
- after clicking `Quit Selected`, the panel enters countdown mode
- during the countdown, the tree keeps updating and exited processes disappear immediately
- selection controls are disabled during the countdown
- when the countdown ends, `Force Quit Selected` is shown only if selected target processes are still alive

#### 5. When the Panel Closes

The alert panel closes when either condition is met:

- all selected target processes have exited
- the user manually closes the window

### Build and Run

#### With Xcode

```bash
open MemoryToastTool.xcodeproj
```

Then select the `MemoryToastTool` scheme and run the app.

#### With the Command Line

```bash
swift test
xcodebuild -project MemoryToastTool.xcodeproj -scheme MemoryToastTool -destination 'platform=macOS,arch=arm64' build
```

### Current Scope

Included today:

- native macOS menu bar app shell
- main-window style Settings surface
- real-time memory sampling and local rule evaluation
- full-process sampling with parent/child aggregation
- single tree-based alert panel with a safer quit flow
- optional auto relaunch after normal quit
- ignore once, snooze, and default ignore list behavior
- Chinese / English localization

Not included:

- historical trend charts or long-term analytics
- settings import / export
- non-macOS support
- any "auto clean memory" or privileged system memory operations
