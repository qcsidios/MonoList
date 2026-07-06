# MonoList v0.3.0 QA 记录

> 测试日期：2026-07-06

## 自动化检查

| 范围 | 命令 | 结果 |
|------|------|------|
| 任务数据 | `bash scripts/check-task-store.sh` | 通过 |
| 设置默认值、旧位置迁移 | `bash scripts/check-app-settings.sh` | 通过 |
| 提醒调度与测试示例 | `bash scripts/check-reminder-scheduler.sh` | 通过 |
| 版本检测 | `bash scripts/check-app-updater.sh` | 通过 |
| 应用内更新安装 | `bash scripts/check-update-installer.sh` | 通过 |
| 主窗口、草稿与滚动边界 | `bash scripts/check-window-coordinator.sh` | 通过 |
| App 构建与 Dock 图标安全区 | `bash scripts/check-app-launch.sh` | 通过 |

## 手动检查

- 菜单栏入口连续执行 20 轮打开和关闭，全部成功。
- 从其他前台应用点击菜单栏入口，清单可靠显示。
- 窗口初次显示贴合菜单栏，拖动后位置可以改变。
- 使用真实全局鼠标事件点击窗口外部，清单立即关闭。
- 有正式任务时默认不显示输入行；点击加号后只出现一条输入行。
- 空输入行点击空白处取消；未修改现有任务数据。
- 对已保存任务执行真实双击，文本编辑框正确出现。
- 6 条任务时窗口高度跟随内容增长，未出现内部滚动和底部大片空白。
- 控制台实际窗口尺寸为 430 × 418 pt，无内部滚动。
- 控制台仅显示两个提醒位置，并提供等宽的提醒控件和提醒测试按钮。
- 提醒测试可直接显示提醒窗口。
- Dock 图标视觉尺寸与系统应用保持一致。

## 数据兼容

- Bundle ID、Application Support 数据目录和任务 schema 均未改变。
- v0.2 的旧提醒位置能够读取并迁移，不会触发设置恢复错误。
- 旧全局快捷键字段仍可读取，但不再注册或生效。
- 固定本地签名与原子替换更新流程保持不变。

## 发布结论

完整测试、正式签名、DMG 和远端 Release 核验通过后发布 `v0.3.0`。
