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

- 菜单栏常驻待办列表
- 新增、编辑、完成、删除和排序
- 已完成任务历史记录与恢复
- 30 / 60 / 90 / 120 分钟轻提醒
- 开机启动与全局呼出快捷键
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
MONOLIST_APP_VERSION=v0.1.0 bash scripts/package-dmg.sh
```
