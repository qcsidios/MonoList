# MonoList v0.8.0 QA 记录

## 版本选择

v0.8.0 是 minor 版本。本次新增完整的“今日专注”选择、执行、菜单栏状态与轻提醒联动能力；原有待办和设置数据格式保持兼容。

## 自动化检查

已运行完整本地构建及以下检查：

- Task store smoke passed.
- Focus store smoke passed.
- Task drop coordinator smoke passed.
- App settings smoke passed.
- UI source style check passed.
- Reminder scheduler smoke passed.
- Menu bar bridge smoke passed.
- Window coordinator smoke passed.
- Project integrity check passed.
- App updater smoke passed.
- Update installer smoke passed.
- App launch smoke passed.

## 回归覆盖

- 今日专注选择限制为 1–3 件，选择顺序可持久化并在重启后恢复。
- 点击“全部”只返回普通清单，“继续专注”可以直接回到原专注页。
- 调整取消恢复原选择；当天已完成的专注任务不能被替换移出。
- 原清单中的专注任务显示编号，新待办不会自动插入当前专注。
- 专注轻提醒只包含当前任务，显示 6 秒，单任务定时提醒触发时优先展示并重置轻提醒。
- 菜单栏显示剩余专注数量和当前任务；全部完成后显示完成状态。
- 本地时间凌晨 04:00 切换专注日期，损坏的专注记录不会影响原任务数据。
- 方向键、空格、`Command + Return` 和 `Escape` 覆盖选择与执行的主要键盘路径。

## 构建与发布边界

- 构建、签名和 DMG 检查只使用仓库 `build/` 目录，不覆盖 `/Applications` 中的正式 App。
- 正式发布使用固定的 `MonoList Local Signing` 本地签名，并通过 Bundle ID、designated requirement 和 DMG 布局检查。
