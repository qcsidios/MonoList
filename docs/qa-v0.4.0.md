# MonoList v0.4.0 本地 QA 记录

> 测试日期：2026-07-06

## 自动化检查

| 范围 | 命令 | 结果 |
|------|------|------|
| 任务数据 | `bash scripts/check-task-store.sh` | 通过 |
| App 构建与简化图标 | `bash scripts/check-app-launch.sh` | 通过 |
| 设置数据 | `bash scripts/check-app-settings.sh` | 通过 |
| 提醒调度、锚点与测试状态 | `bash scripts/check-reminder-scheduler.sh` | 通过 |
| 版本检测 | `bash scripts/check-app-updater.sh` | 通过 |
| 应用内更新安装 | `bash scripts/check-update-installer.sh` | 通过 |
| 主窗口、顶部锚定与草稿提交 | `bash scripts/check-window-coordinator.sh` | 通过 |

## 实机检查

- 本地构建版本显示为 `0.4.0`。
- 主清单使用纯白背景，底部保留稳定空隙。
- 加号、更多操作和设置按钮均显示相同的灰色圆角背景。
- 显示历史记录时窗口由 `336 × 269 pt` 扩展为 `336 × 372 pt`，顶部坐标始终为 `(790, 35)`。
- 隐藏历史记录时窗口恢复为 `336 × 269 pt`，顶部坐标仍为 `(790, 35)`。
- 控制台窗口保持 `430 × 418 pt`。
- 提醒间隔、提醒位置和立即测试控件宽度一致，选择控件不显示箭头。
- 第一次点击“立即测试”后出现提醒窗口，第二次点击后提醒窗口关闭。
- 测试提醒与自动提醒使用同一套动画和音效入口。
- Dock 图标和控制台 Logo 均为白色圆角底、黑色圆圈对号。

## 数据与发布边界

- 测试未修改现有任务内容。
- Bundle ID、Application Support 路径、任务格式和设置格式均未改变。
- 固定本地签名和应用内更新流程未改变。
- 本轮仅完成本地版本，不创建 tag 或 GitHub Release，等待用户体验确认。
