# MonoList v0.5.2 QA 记录

## 版本选择

v0.5.2 是 patch 版本。本次只精修 v0.5.1 控制台版式和时间下拉交互，不改变数据结构或产品能力。

## 自动化检查

已运行完整本地构建及以下检查：

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

- 控制台源码不再包含内部纵向 `ScrollView`。
- 时间选择使用 `SettingsTimeComboBox`，下拉列表最多显示 8 项并启用内部滚动。
- 提醒时段排在提醒间隔之前。
- 提醒测试按钮宽度固定为 180pt；其余普通设置控件使用相同宽度。
- 标题栏文字通过 Auto Layout 的 `centerYAnchor` 垂直居中。

## 构建环境说明

当前 CommandLineTools 的默认 Swift 6.3.3 与 macOS 26.5 SDK 6.3.2 不匹配，因此验证固定使用已安装的 macOS 15.4 SDK，并把模块缓存放在仓库 `build/`。系统 `iconutil` 同时不可用，构建阶段使用现有图标 PNG 生成标准 ICNS 容器；应用图标内容未改变。
