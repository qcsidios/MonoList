# MonoList v0.4.6 QA 记录

> 测试日期：2026-07-06

## 根因

- 纵向 SwiftUI `TextField` 会自行处理 Return，`.onSubmit` 并不能覆盖所有输入状态。
- SwiftUI `Menu` 会重新布局自定义 label，导致手工放在尾部的箭头仍出现在文字左侧。

## 修复与验证

- 清单级键盘监听统一识别 Return（36）和数字键盘 Enter（76）。
- 草稿焦点下提交并继续草稿；已有待办编辑状态下保存并在该任务后插入新草稿。
- 中文输入法存在 marked text 时不抢占 Enter。
- 下拉框直接使用 `NSPopUpButton`，实测渲染中箭头位于 116 pt 灰色按钮最右侧，文字位于内容区中央。
- 任务、设置、菜单栏、窗口、提醒、更新和安装器 smoke test 全部通过。

## 本地文件约束

- 不覆盖或安装 `/Applications/MonoList.app`。
- 发布后只保留最新版本 DMG，不保留旧 DMG、构建 App 或测试产物。
