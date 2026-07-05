# MonoList v0.2.0 QA 记录

> 测试日期：2026-07-06

## 自动化检查

| 检查范围 | 命令 | 结果 |
|----------|------|------|
| 任务数据与完成日期筛选 | `bash scripts/check-task-store.sh` | 通过 |
| 设置默认值与持久化 | `bash scripts/check-app-settings.sh` | 通过 |
| 提醒调度 | `bash scripts/check-reminder-scheduler.sh` | 通过 |
| GitHub Release 版本检测 | `bash scripts/check-app-updater.sh` | 通过 |
| 应用内更新安装 | `bash scripts/check-update-installer.sh` | 通过 |
| 动态窗口与内存草稿 | `bash scripts/check-window-coordinator.sh` | 通过 |
| App 构建、Dock 配置与图标 | `bash scripts/check-app-launch.sh` | 通过 |

## 数据与升级兼容

- Bundle ID 保持 `com.qingcheng.monolist.mac`。
- 数据目录保持 `~/Library/Application Support/MonoList/`。
- `tasks.json` 与 `settings.json` 的 schemaVersion 均未改变。
- 固定本地签名及应用内原子替换更新流程未改变。
- 未新增应用内版本回滚入口或仓库入口。

## 界面对照

- 主浮窗宽度保持 360 pt，空状态最小高度为 148 pt，最大高度为 520 pt。
- 今天完成记录在隐藏历史时仍显示；更早记录只在点击“显示”后出现。
- 控制台固定为 480 × 560 pt，不使用内部滚动。
- 顶部显示 `MonoList 一栏`、版本号和同排的“检测新版本”按钮。
- 正式 Logo 为黑色圆角底、白色两行清单，上方空心圆、下方带勾圆。

## 发布结论

自动化、构建、签名、DMG 和应用内更新检查全部通过后，发布 `v0.2.0`。
