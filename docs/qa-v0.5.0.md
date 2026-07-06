# MonoList v0.5.0 QA 记录

## 版本选择

v0.5.0 是 minor 版本。本次新增控制台提醒时段设置、下次提醒展示框，并优化拖拽排序动效，属于产品能力扩展；不改变任务数据或安装方式。

## 自动化检查

已运行：

```bash
MONOLIST_APP_VERSION=v0.5.0 bash scripts/build-local.sh
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

- 设置默认值：提醒时段默认 `09:00 - 22:00`。
- 设置持久化：自定义提醒时段写入后可重新读取。
- 设置兼容：旧设置文件缺失提醒时段字段时自动补默认值。
- 设置校验：结束时间早于开始时间会被拒绝。
- 调度计算：提醒落在时段前会顺延到开始时间；落在时段后会顺延到次日开始时间。
- 控制台编译：设置页接入 `TaskStore` 与 `ReminderScheduler`，可读取待办数量和下次提醒时间。
- 拖拽排序：重排时必须使用 `interactiveSpring` 动画，并保留透明拖拽预览。
