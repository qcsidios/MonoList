# MonoList v0.1.0 QA 记录

> 日期：2026-07-05  
> 平台：Apple Silicon，macOS 26（最低部署目标 macOS 14）

## 自动检查

| 范围 | 命令 | 结果 |
|---|---|---|
| App 结构与启动 | `bash scripts/check-app-launch.sh` | 通过 |
| 任务数据、历史和排序 | `bash scripts/check-task-store.sh` | 通过 |
| 设置默认值、保存和数据版本 | `bash scripts/check-app-settings.sh` | 通过 |
| 提醒状态机 | `bash scripts/check-reminder-scheduler.sh` | 通过 |
| 窗口尺寸和显示状态 | `bash scripts/check-window-coordinator.sh` | 通过 |
| Release 解析和版本比较 | `bash scripts/check-app-updater.sh` | 通过 |
| 更新脚本安全路径 | `bash scripts/check-update-installer.sh` | 通过 |
| 固定本地签名 | `bash scripts/check-release-signature.sh` | 通过 |
| DMG 内容与校验 | `bash scripts/check-dmg-layout.sh build/release/MonoList-v0.1.0.dmg` | 通过 |

## 核心流程

| Spec 验收范围 | 验证内容 | 结果 |
|---|---|---|
| 11.1 菜单栏与浮窗 | 无 Dock 图标；菜单栏状态项；360 × 520 pt 浮窗；原生材质；浅色模式显示 | 通过 |
| 11.2 待办 | 新增位置、编辑、排序、空白过滤、删除、清空、重启持久化 | 通过 |
| 11.3 完成与历史 | 完成、恢复、再次完成、历史稳定排序和清空 | 通过 |
| 11.4 提醒 | 空列表不计时、完整周期、睡眠唤醒、界面占用跳过、单截止点 | 通过 |
| 11.5 设置与启动 | 默认值、即时保存、全局快捷键冲突回退、登录项真实状态 | 通过 |
| 11.6 更新 | 严格版本和资源解析、固定签名、真实 `v0.0.1 → v0.1.0` 替换演练 | 通过 |
| 11.7 发布 | 三段式版本、中文说明、固定命名、Draft 后公开流程 | 通过 |
| 11.8 平台与隐私 | Apple Silicon 原生构建；业务数据不进入网络请求；用户端不展示仓库地址 | 通过 |

## 真实升级演练

1. 使用同一份 `MonoList Local Signing` 证书构建 `v0.0.1`。
2. 将 `v0.1.0` 固定签名 App 打包为 DMG。
3. 在临时安装目录运行退出后更新脚本。
4. 验证旧 App 临时备份、新 App 复制、Bundle ID、版本和签名。
5. 验证新 App 启动后删除临时备份。

结果：通过。更新后版本为 `0.1.0`，没有遗留备份。

## 发布结论

自动检查、固定签名、DMG 和真实升级演练均通过，可以发布 `v0.1.0`。
