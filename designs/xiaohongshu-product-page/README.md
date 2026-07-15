# MonoList 小红书商品详情页

当前版本：`v2`

建议商品标题：`Mac菜单栏待办工具 MonoList｜随手记·轻提醒·本地保存`

兼容性：Apple 芯片 Mac（M1 或后续型号），macOS 14.0 及以上版本。

## 交付结构

- `01-1x1.png`：商品列表与购物车主图。
- `01-3x4.png`：轮播第一张，与商品主图共享同一视觉概念。
- `02.png`–`09.png`：其余 3:4 轮播图。
- `10.png`：长详情页。
- `versions/v2/full.html`：无外部依赖、可单独发送的完整 HTML。
- `versions/v2/preview.html`：手机端与小尺寸主图预览。

## 版本记录

- `v1`：首版完整商品详情页。
- `v2`：1:1 与 3:4 首图改为独立构图；控制台按代码中的 430 pt 固定宽度重新绘制。

## 产品事实来源

- `README.md`、`PRODUCT.md`
- `MonoList/Tasks/TaskListView.swift`
- `MonoList/Tasks/TaskRowView.swift`
- `MonoList/Settings/SettingsView.swift`
- `MonoList/Reminder/ReminderView.swift`
- `MonoList/App/WindowCoordinator.swift`
- `release-notes/v0.7.10.md`

设计不复用 ShotLens 的视觉样式，仅复用已验证的文件、版本和导出流程。
