# MonoList v0.4.7 QA 记录

> 测试日期：2026-07-06

## 根因

- Enter 监听闭包在 `TaskListView` 首次出现时捕获了焦点状态副本；之后虽然输入框获得焦点，闭包仍可能按旧状态放行 Enter。
- 实测 `api.github.com` 出现 SSL/EOF 连接失败，而 `github.com/readercyl/MonoList/releases/latest` 和 `v0.4.6` DMG 下载地址均正常。

## 修复与验证

- 使用稳定引用类型保存当前草稿焦点和任务编辑状态，键盘监听每次读取最新值。
- 覆盖 Return、数字键盘 Enter、草稿、已有任务编辑和中文输入法 marked text。
- GitHub API 失败后自动访问最新 Release 页面，从最终跳转 URL 解析版本，并以 HEAD 请求验证 DMG。
- 在 API 实际不可用的环境中运行网络 smoke，成功检测到 `v0.4.6` 及正确 DMG 地址。
- 全部本地 smoke test、应用构建、签名和 DMG 检查通过。

## 本地文件约束

- 不覆盖或安装 `/Applications/MonoList.app`。
- 发布后只保留最新版 DMG，不保留旧 DMG、构建 App 或测试产物。
