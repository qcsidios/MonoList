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

## 功能

- Dock 与菜单栏同时常驻
- 按 Enter 或点击空白处保存的内联待办输入
- 双击编辑、整行拖动排序、单条删除
- 当天完成任务保留在底部，较早记录可显示或隐藏
- 30 / 60 / 90 / 120 分钟轻提醒
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
MONOLIST_APP_VERSION=v0.4.0 bash scripts/package-dmg.sh
```
