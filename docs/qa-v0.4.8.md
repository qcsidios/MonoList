# MonoList v0.4.8 QA 记录

> 测试日期：2026-07-06

## Enter 根因与修复

前几版仍通过窗口级键盘监听判断草稿焦点，状态同步存在时序差异。现在草稿和已有任务编辑统一使用 `TaskTextEditor`，底层 `NSTextView.doCommand` 直接拦截 Enter。

自动化测试直接向真实文本编辑器发送 `insertNewline`：

- 加号或双击空白创建的草稿被保存。
- 草稿保持显示并清空，形成下一条输入。
- 再输入并按 Enter，会再次保存并继续下一条。
- 已有任务编辑使用同一提交入口。

## 更新检测

- 网络测试记录全部请求 host，确认不存在 `api.github.com`。
- `github.com/readercyl/MonoList/releases/latest` 跳转到版本页后解析版本号。
- 对 `MonoList-vX.Y.Z.dmg` 执行 HEAD 验证，存在安装包才显示升级。

## 完整验证

- 任务、设置、窗口、提醒、菜单栏、更新和安装器 smoke test 全部通过。
- 应用构建、签名和 DMG 布局检查通过。
- 发布后只保留最新版 DMG，不保留旧 DMG、构建 App 或测试产物。
