# MonoList v0.8.1 QA 记录

## 版本选择

v0.8.1 是 patch 版本。本次只修复 v0.8.0“今日专注”的计数语义、清空保存、专注页入口、选中颜色与测试提醒分流，不改变数据结构或产品主流程。

## 自动化检查

正式发布脚本覆盖以下检查：

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
- Release signature check passed.
- DMG layout check passed.

## 回归覆盖

- 今日专注清空后写入空记录并结束专注，不影响原待办。
- 菜单栏使用当天选择总数；部分完成不改变数字，全部完成显示勾选。
- 专注任务区域不包含系统强调色背景。
- 专注页保留控制台按钮。
- 测试提醒优先读取当前专注任务，没有专注时才使用普通测试任务。
- 设计规格、交互参考稿和 README 与修复后的语义一致。

## 发布边界

- 构建、签名与 DMG 检查只使用仓库 `build/`，不覆盖 `/Applications` 中的正式 App。
- 正式安装包继续使用固定的 `MonoList Local Signing` 本地签名。
