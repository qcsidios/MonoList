# MonoList 本地交互与界面迭代实施计划

> **执行要求：** 使用 `executing-plans` 按任务逐项实施；功能改动遵循 TDD，完成后使用 `verification-before-completion` 和项目发布脚本验证、发布。

**目标：** 将已经确认的“今天”视图、内联草稿、当天完成项、操作区、固定控制台、Dock 常驻和正式 Logo 实现为可升级的新版本，并保持原有任务与设置文件兼容。

**架构：** 保留现有 JSON 数据结构、Bundle ID、Application Support 路径与固定本地签名，只调整任务的查询和交互呈现。草稿由窗口协调器持有在内存中；主面板根据列表内容调整高度；设置窗口继续使用 SwiftUI，但改为固定无滚动布局。

**技术栈：** Swift 6、SwiftUI、AppKit、现有 shell 构建/签名/DMG/GitHub Release 流程。

---

### 任务 1：锁定任务流转与设置默认值

**文件：**
- 修改：`Tests/TaskStoreSmoke.swift`
- 修改：`Tests/AppSettingsSmoke.swift`
- 修改：`Tests/AppLaunchSmoke.swift`
- 修改：`Tests/WindowCoordinatorSmoke.swift`
- 修改：`MonoList/Tasks/TaskStore.swift`
- 修改：`MonoList/Settings/AppSettings.swift`
- 修改：`MonoList/Reminder/ReminderPanelController.swift`
- 修改：`MonoList/App/WindowCoordinator.swift`
- 修改：`scripts/build-local.sh`

- [x] 先增加会失败的测试：当天完成、旧完成分组、恢复顺序、默认屏幕居中、默认开机启动、Dock 可见、最小动态高度。
- [x] 运行对应检查脚本，确认测试因缺少新行为而失败。
- [x] 用最小改动实现查询、默认值、屏幕居中和 Dock 配置，并保持旧 JSON 可读取。
- [x] 重新运行对应检查脚本并确认通过。

### 任务 2：实现主列表新交互

**文件：**
- 新建：`MonoList/Tasks/TaskDraftState.swift`
- 修改：`MonoList/Tasks/TaskListView.swift`
- 修改：`MonoList/Tasks/TaskRowView.swift`
- 修改：`MonoList/Tasks/HistoryView.swift`
- 修改：`MonoList/App/WindowCoordinator.swift`
- 修改：`MonoList/App/AppDelegate.swift`

- [x] 增加草稿内存状态测试，确认关闭视图不写入任务文件且同一次运行可恢复。
- [x] 实现只有 Enter 才保存的内联草稿，移除自动保存、加号和独立历史页。
- [x] 实现单击选择、双击编辑、空内容恢复、尾部固定删除区与整行拖动排序。
- [x] 实现“今天完成”始终显示、旧完成记录按日期显示/隐藏、取消完成和单条删除。
- [x] 实现顶部“更多操作/控制台”及三类清空的二次确认。
- [x] 根据内容调整 148–520 pt 面板高度，并保留 360 pt 固定宽度。
- [x] 编译并运行任务与窗口测试。

### 任务 3：实现控制台与 Logo

**文件：**
- 新建：`MonoList/Shared/MonoListLogoView.swift`
- 修改：`MonoList/Settings/SettingsView.swift`
- 修改：`MonoList/App/WindowCoordinator.swift`
- 修改：`MonoList/App/AppDelegate.swift`
- 新建：`scripts/generate-app-icon.swift`
- 修改：`scripts/build-local.sh`

- [x] 将控制台固定为 480 × 560 pt，移除内部滚动、排序说明和数据清空。
- [x] 按设计稿重做顶部 Logo、双语名称、版本与检测更新同排布局。
- [x] 将提醒、开机启动、快捷键整理为灰度卡片，快捷键默认显示“未设置”。
- [x] 生成黑底白色“双态清单”应用图标，并验证构建产物包含图标。
- [x] 验证 Dock 点击、菜单栏左/右键和控制台打开行为。

### 任务 4：完整验证、版本与发布

**文件：**
- 修改：`README.md`
- 新建：`docs/qa-v0.2.0.md`
- 新建：`release-notes/v0.2.0.md`

- [ ] 运行所有 smoke test、应用构建、签名检查和 DMG 布局检查。
- [ ] 对照设计文档逐项检查核心交互和数据兼容性。
- [ ] 采用 `v0.2.0`：本轮重做主任务流、完成记录呈现、控制台和 Dock 行为，属于明显扩展产品能力的 minor 更新。
- [ ] 编写中文 QA 记录和 Release 说明，提交全部代码和文档。
- [ ] 使用 `scripts/release.sh` 创建 tag、推送 `main`、创建并公开 GitHub Release。
