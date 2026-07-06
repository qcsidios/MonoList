# MonoList v0.4.9 QA 记录

## 版本选择

v0.4.9 是 patch 版本。本次只修复新增待办输入框初始高度异常，不改变任务数据、设置、安装流程或更新机制。

## 自动化检查

已运行：

```bash
MONOLIST_APP_VERSION=v0.4.9 bash scripts/build-local.sh
bash scripts/check-task-store.sh
bash scripts/check-app-launch.sh
bash scripts/check-app-settings.sh
bash scripts/check-reminder-scheduler.sh
bash scripts/check-menu-bar-bridge.sh
bash scripts/check-window-coordinator.sh
bash scripts/check-project-integrity.sh
bash scripts/check-app-updater.sh
bash scripts/check-update-installer.sh
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

## 回归覆盖

- 新增布局回归检查：空待办输入框在较高可用空间中仍保持单行高度。
- 新增长文本检查：内容超过单行宽度时，输入框可以扩展为更高的多行高度。
