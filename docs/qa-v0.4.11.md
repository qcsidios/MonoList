# MonoList v0.4.11 QA 记录

## 版本选择

v0.4.11 是 patch 版本。本次只修复拖拽排序时的视觉重影，不改变任务数据、设置、安装流程或更新机制。

## 自动化检查

已运行：

```bash
MONOLIST_APP_VERSION=v0.4.11 bash scripts/build-local.sh
bash scripts/check-task-store.sh
bash scripts/check-app-launch.sh
bash scripts/check-app-settings.sh
bash scripts/check-reminder-scheduler.sh
bash scripts/check-menu-bar-bridge.sh
bash scripts/check-window-coordinator.sh
bash scripts/check-project-integrity.sh
bash scripts/check-app-updater.sh
bash scripts/check-update-installer.sh
bash scripts/check-window-coordinator.sh
MONOLIST_APP_VERSION=v0.4.11 bash scripts/release.sh --dry-run
```

结果：

- Task store smoke passed.
- App launch smoke passed.
- App settings smoke passed.
- Reminder scheduler smoke passed.
- Menu bar bridge smoke passed.
- Window coordinator smoke passed.
- Project integrity check passed.
- App updater smoke passed.
- Update installer smoke passed.
- Release dry run passed: v0.4.11.

## 回归覆盖

- 新增拖拽预览回归检查：待办行拖拽必须使用 `TaskDragPreview()`，避免系统复制整行造成重影。
- 保留 v0.4.10 的焦点回归检查。
- 保留 v0.4.9 的输入框高度回归检查。
