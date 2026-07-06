# MonoList v0.4.10 QA 记录

## 版本选择

v0.4.10 是 patch 版本。本次只修复新增待办与待办行之间的焦点状态，不改变任务数据、设置、安装流程或更新机制。

## 自动化检查

已运行：

```bash
MONOLIST_APP_VERSION=v0.4.10 bash scripts/build-local.sh
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

- 新增焦点回归检查：待办行点击必须走统一 `selectTask` 逻辑。
- 新增焦点回归检查：新增草稿必须走统一 `focusDraft` 逻辑。
- 保留 v0.4.9 的输入框高度回归检查：空输入框单行显示，长文本才扩展为多行。
