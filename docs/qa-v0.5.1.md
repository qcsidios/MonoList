# MonoList v0.5.1 QA 记录

## 版本选择

v0.5.1 是 patch 版本。本次只修复 v0.5.0 的控制台版式和已完成任务筛选，不新增产品能力。

## 自动化检查

已运行：

```bash
MONOLIST_APP_VERSION=v0.5.1 bash scripts/build-local.sh
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

- 已完成任务按 `createdAt` 进入“今天”或“更早”分组。
- 昨天创建、今天完成的任务不会显示在今天已完成列表里。
- 控制台设置页可编译并保持固定高度滚动容器。
