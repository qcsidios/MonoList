# MonoList 任务分组与提醒升级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 为 MonoList 增加短期/长期任务分组与跨组拖拽、可靠的新增行自动聚焦、倒计时和未来七天提醒、macOS 系统声音选择，并让菜单栏只统计短期任务。

**Architecture:** 在现有 `TaskItem` 上增加可向后兼容的任务分组字段，由 `TaskStore` 统一维护分组内顺序和跨组移动；SwiftUI 列表只负责呈现分组、滚动定位和拖放意图。一次性日期与倒计时继续复用 `TaskReminder.once(Date)`；声音偏好进入 `AppSettings`，由提醒面板按名称播放 `NSSound`。

**Tech Stack:** Swift、SwiftUI、AppKit、Combine、现有 `swiftc` Smoke 测试脚本。

---

### Task 1: 任务分组数据与排序

**Files:**
- Modify: `MonoList/Tasks/TaskItem.swift`
- Modify: `MonoList/Tasks/TaskStore.swift`
- Modify: `MonoList/Tasks/TaskDraftState.swift`
- Modify: `scripts/check-task-store.sh`
- Test: `Tests/TaskStoreSmoke.swift`

- [x] 写失败测试：旧数据默认短期、两组稳定排序、跨组指定位置移动、完成后恢复保持原分组，以及长期任务后新增/连续新增仍属于长期组。
- [x] 运行 `bash scripts/check-task-store.sh`，确认因分组 API 缺失而失败。
- [x] 增加 `TaskGroup.shortTerm/longTerm` 和向后兼容解码；公开 `shortTermTasks`、`longTermTasks`、分组移动 API；草稿状态同时保存目标分组与组内前置任务。
- [x] 让新增任务默认短期，组内排序与跨组插入只修改相关未完成任务的顺序。
- [x] 再运行 `bash scripts/check-task-store.sh`，确认通过。

### Task 2: 分组界面、跨组拖拽与菜单栏计数

**Files:**
- Modify: `MonoList/Tasks/TaskListView.swift`
- Modify: `MonoList/Tasks/TaskRowView.swift`
- Modify: `MonoList/App/AppDelegate.swift`
- Modify: `MonoList/App/MenuBarBridgeProtocol.swift`
- Create: `MonoList/Tasks/TaskDropCoordinator.swift`
- Modify: `scripts/check-ui-source-style.sh`
- Create: `scripts/check-task-drop-coordinator.sh`
- Test: `Tests/MenuBarBridgeSmoke.swift`
- Test: `Tests/TaskStoreSmoke.swift`
- Create: `Tests/TaskDropCoordinatorSmoke.swift`

- [x] 写失败测试：短期计数排除长期任务，跨组移动后立即变化；拖拽协调器覆盖 hover→cancel 不写入、hover→performDrop 才提交、空组和组尾落点。
- [x] 运行菜单栏、任务存储和拖拽协调器 Smoke，确认失败。
- [x] 主列表增加短期、长期分组标题和数量；组内与跨组拖拽悬停时只更新临时落点，只有 `performDrop` 才持久化；取消或移出拖拽不改数据，并支持空组与组尾落点；提供菜单切换入口。
- [x] `AppDelegate` 只发布短期未完成数量；全局轻提醒仍覆盖全部未完成任务。
- [x] 运行 `bash scripts/check-menu-bar-bridge.sh`、`bash scripts/check-task-store.sh`、`bash scripts/check-task-drop-coordinator.sh`、`bash scripts/check-ui-source-style.sh`。

### Task 3: 长列表新增行滚动与焦点回归

**Files:**
- Modify: `MonoList/Tasks/TaskListView.swift`
- Modify: `scripts/check-ui-source-style.sh`
- Test: 源码级 UI 回归检查与人工长列表验证

- [x] 先增加失败的源码检查，要求滚动列表使用稳定的草稿行 ID 和 `ScrollViewReader.scrollTo`。
- [x] 运行 `bash scripts/check-ui-source-style.sh`，确认失败。
- [x] 点击加号或连续 Enter 后，先呈现草稿行，再滚动到完整可见，最后设置输入焦点。
- [x] 运行源码检查，并在构建 App 中用超过窗口高度的任务列表人工验证。

### Task 4: 倒计时与未来七天日期提醒

**Files:**
- Modify: `MonoList/Tasks/TaskItem.swift`
- Modify: `MonoList/Tasks/TaskRowView.swift`
- Test: `Tests/TaskStoreSmoke.swift`
- Test: `Tests/ReminderSchedulerSmoke.swift`
- Modify: `scripts/check-reminder-scheduler.sh`
- Test: `scripts/check-ui-source-style.sh`

- [x] 写失败测试：倒计时换算为绝对日期，指定未来日期持久化，过去日期和未来第 7 天边界验证；调度器对一次性日期只触发一次并在触发后清除。
- [x] 运行相关测试，确认失败。
- [x] 提醒编辑器提供“倒计时 / 指定日期 / 每天”；倒计时与日期提醒都保存为 `.once(at:)`，分钟以 10 分钟递增，指定日期限制今天到未来第 7 天。
- [x] 运行任务存储和 UI 源码检查。

### Task 5: macOS 系统声音选择

**Files:**
- Modify: `MonoList/Settings/AppSettings.swift`
- Modify: `MonoList/Settings/SettingsView.swift`
- Modify: `MonoList/Reminder/ReminderPanelController.swift`
- Modify: `MonoList/App/AppDelegate.swift`
- Test: `Tests/AppSettingsSmoke.swift`
- Test: `Tests/ReminderPanelControllerSmoke.swift`
- Create: `scripts/check-reminder-panel-controller.sh`
- Test: `scripts/check-ui-source-style.sh`

- [x] 写失败测试：默认 `Glass`、关闭声音、声音名称持久化、旧布尔设置迁移；提醒面板验证选中声音、关闭声音和无效名称回退，并覆盖全局与单条提醒调用链。
- [x] 运行 `bash scripts/check-app-settings.sh` 与 `bash scripts/check-reminder-panel-controller.sh`，确认失败。
- [x] 用单一可选声音名称替代布尔开关，列出实际可用系统声音并支持选择时试听。
- [x] 提醒面板按设置播放声音；找不到已保存声音时回退 `Glass`，关闭时不播放。
- [x] 运行 `bash scripts/check-app-settings.sh`、`bash scripts/check-reminder-panel-controller.sh`、提醒调度和 UI 源码检查。

### Task 6: 集成验证与文档

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-07-11-task-groups-and-reminders.md`
- Review: `../软件产品开发原则.md`

- [x] 运行全部项目检查和本地构建。
- [x] 人工验证跨组拖拽、长列表新增聚焦、倒计时、未来日期、声音试听和菜单栏计数。
- [x] 更新 README；检查是否产生需要写入根原则文档的新通用原则。
- [x] 复核 `git diff`，只保留本需求相关修改，并记录验证证据。
