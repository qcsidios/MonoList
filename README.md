# MonoList 一栏

MonoList 是一款常驻 macOS 菜单栏的轻量待办工具。

## 开发环境

- macOS 14 或更高版本
- Apple Command Line Tools
- Swift 6

无需安装完整 Xcode。

## 本地构建

```bash
bash scripts/build-local.sh
bash scripts/check-app-launch.sh
open build/local/MonoList.app
```

构建产物统一存放在：

```text
build/
├── local/MonoList.app
└── release/MonoList-vX.Y.Z.dmg
```

发布后执行 `scripts/cleanup-build.sh`，自动删除测试产物和 DMG
暂存目录，只保留最新本地 App 与安装包。

## 功能

- Dock 与菜单栏同时常驻
- 新增待办按 Enter 保存并自动继续下一行，点击空白处保存并结束输入
- 双击清单空白处新增待办；编辑已有待办按 Enter 保存并在下方新增
- 未完成待办分为短期与长期两组，支持组内排序、拖入另一分组和右键切换；菜单栏用 Logo 显示入口，数字只统计短期任务
- 长列表新增待办时会自动滚动并聚焦到正在输入的行
- 双击编辑、整行拖动排序、单条删除
- 当天完成任务保留在底部，较早记录可显示或隐藏
- 30 / 60 / 90 / 120 分钟轻提醒，可单独关闭提醒声音
- 单条待办支持 10 分钟递增的倒计时、未来七天指定日期时间和每日提醒
- 轻提醒与单条提醒可选择 macOS 系统声音，并可在设置时试听
- 菜单栏稳定显示未完成任务数量
- 可选开机启动与轻提醒测试
- GitHub Release 应用内检测和升级

任务、历史记录和设置仅保存在：

```text
~/Library/Application Support/MonoList/
```

除版本检测和下载安装包外，MonoList 不会主动联网。

## 发布说明

正式版本使用固定的 `MonoList Local Signing` 本地签名，不使用 Apple
Developer ID、不进行 Apple 公证，也不上架 App Store。首次运行时 macOS
可能显示 Gatekeeper 提示。

构建发布包：

```bash
MONOLIST_APP_VERSION=v0.4.2 bash scripts/package-dmg.sh
```
