# WhaleBar 开发总体规划

> 版本：v0.3 · 更新日期：2026-09-18 · **当前状态：v0.3 运行中**
>
> **变更记录（2026-09-18，应用户决定）**：
> 1. **移除用量明细功能**——平台会话接口（userToken）、今日/本月消费、趋势图及全部相关数据模型与设置项已删除，M2/M3 里程碑成果作废存档；WhaleBar 聚焦官方 API 余额监视。接口调研保留于 [03-API-NOTES.md](03-API-NOTES.md)，未来若恢复可参考。
> 2. 视觉调整：余额卡由亮蓝青渐变改为深海军蓝低饱和渐变（缓解晃眼），面板收窄 280pt、全局字号再上调。
> 3. 修复：设置修改即时生效（@Observable 需存储属性驱动，原「计算属性 + UserDefaults」写法不触发刷新）。

## 1. 项目定位

**WhaleBar**：一款 macOS 菜单栏工具，让 DeepSeek API 用户不用打开网页控制台，即可随时查看账户余额与消费用量。

- 技术栈：Swift 6 + SwiftUI（MenuBarExtra），原生 macOS App
- 目标系统：macOS 15+
- 性质：个人工具，本机 ad-hoc 签名分发，不上架 App Store（沙盒/上架流程不在本期范围）

## 2. 已确认的关键决策

| # | 决策项 | 结论 | 原因 |
|---|--------|------|------|
| D1 | 数据来源 | **官方 API（余额）+ 平台会话（用量明细，可选）** | 官方 API 只有余额接口；用量明细只能走平台私有接口，作为可选增强，失效时优雅降级为仅余额 |
| D2 | 最低系统版本 | **macOS 15+** | 可用 @Observable、最新 SwiftUI API，不考虑旧系统兼容 |
| D3 | API Key 数量 | **v1 仅单 Key**，数据模型预留多 Key 扩展 | 先跑通主流程 |
| D4 | 增强功能取舍 | **迷你用量趋势图纳入正式里程碑（M3）**；开机自启动、余额提醒列入 Backlog | 由用户选定 |
| D5 | 构建方案 | **Swift Package（SPM）+ 脚本组装 .app** | 本机仅有 Command Line Tools，无 xcodebuild，无法使用 .xcodeproj；SPM 可完整编译 SwiftUI App（详见架构文档） |
| D6 | 测试框架 | **自研断言检查器 `WhaleBarKitChecks`（`./Scripts/test.sh`）** | 实测本机 CLT 缺少 XCTest 与 Swift Testing 运行时，`swift test` 不可用；检查器以普通可执行 target 承载全部断言，失败非零退出 |

## 3. 范围

### v1 包含（M0–M2）

- 菜单栏图标 + 余额数字，点击弹出信息面板
- 官方 API 余额查询（总余额 / 赠送余额 / 充值余额 / 可用状态）
- 平台会话用量明细（今日消费、本月消费、按日用量），userToken 可选配置
- 设置窗口：API Key、userToken、刷新间隔、状态栏显示样式
- Keychain 安全存储凭据、本地缓存离线兜底、错误状态呈现
- 首次启动引导（凭据配置教程）

### v1 之后

- M3：近 7/30 日用量趋势图（Swift Charts），历史数据本地留存
- M4：打磨（图标资产、唤醒/睡眠处理、文档、打包）

### Backlog（不影响 v1 数据模型，暂不排期）

- 开机自启动（SMAppService）
- 余额不足阈值通知
- 多 API Key 切换 / 多账号
- 多币种切换（v1 默认取 CNY，多币种时显示余额最大者并在面板列出全部）
- Sparkle 自动更新、公证分发

## 4. 里程碑与任务拆解

> 工时为估算（人机协作开发），仅供节奏参考。每个任务的产物与涉及文档见「产出」列。

### M0 · 项目脚手架（约 0.5 天）✅ 已完成

| 任务 | 内容 | 产出 |
|------|------|------|
| T0.1 | 仓库初始化：`git init`、`.gitignore`（.build/、build/、DS_Store）、SPM `Package.swift`（targets：`WhaleBar` 可执行 + `WhaleBarKit` 库 + 测试 target，platforms `.macOS(.v15)`） | 可 `swift build` 的空工程 |
| T0.2 | `Scripts/build_app.sh`：swift build → 组装 `build/WhaleBar.app`（Contents/MacOS、Info.plist：`LSUIElement=true`、bundle id `com.heyhansir.WhaleBar`）→ ad-hoc codesign | 一键生成可运行的 .app |
| T0.3 | App 骨架：@main + MenuBarExtra（window 样式）显示占位 label 与空面板、Settings scene 挂接 | 菜单栏出现 🐋，点开有面板 |

**M0 完成标准**：`./Scripts/build_app.sh && open build/WhaleBar.app` 后菜单栏出现图标且面板可弹出。

### M1 · 余额链路（约 1 天）✅ 已完成

| 任务 | 内容 | 产出 |
|------|------|------|
| T1.1 | `WhaleBarKit`：余额数据模型 + `DeepSeekBalanceClient`（async/await URLSession，Bearer 鉴权，错误映射 401/网络/解析），URLProtocol mock 单测 | 官方余额接口可用且有测试 |
| T1.2 | `KeychainStore`：GenericPassword 增删读，API Key 存取 | 凭据安全落地 |
| T1.3 | `AppState`（@MainActor @Observable）+ `RefreshScheduler`：可配置间隔的 Task 循环、手动刷新节流、last-updated 时间、失败重试退避 | 刷新引擎 |
| T1.4 | UI：菜单栏 label 显示余额（🐋 + 数字），面板余额卡（总/赠送/充值、可用状态、更新时间、刷新按钮） | 余额可视化 |
| T1.5 | 设置窗口 v1：API Key SecureField + 「验证并保存」（立即调一次 balance 验证）；首启动无凭据时自动弹出引导 | 完整配置闭环 |

**M1 完成标准**：配置 API Key 后，菜单栏实时显示余额，断网/错 Key 有清晰错误提示。

### M2 · 用量明细（约 1–1.5 天）✅ 已完成（T2.0 真机实测待验证）

| 任务 | 内容 | 产出 |
|------|------|------|
| T2.0 | **Spike（先行）**：用真实 userToken 以 curl 验证平台接口（summary / usage by_api_key amount+cost / monthly fallback）的真实响应结构，回填 [03-API-NOTES.md](03-API-NOTES.md) | 确认字段 schema |
| T2.1 | `PlatformSessionClient`：`x-client-platform: web` 头、amount/cost 并发请求、monthly fallback、错误码 40002/40003 → 会话过期语义 | 平台用量接口可用 |
| T2.2 | 用量数据模型 + 本地缓存（Application Support 下 JSON，按日 bucket 持久化），离线时展示缓存 | 数据层 |
| T2.3 | UI：面板用量卡（今日消费、本月消费、tokens）；未配置 userToken 时显示引导入口 | 用量可视化 |
| T2.4 | 设置窗口 userToken 区（SecureField + 获取教程折叠说明）；会话过期横幅与重新配置引导 | 会话管理闭环 |

**M2 完成标准**：配置 userToken 后，面板展示今日/本月消费与 token 用量；userToken 失效时有明确指引且不影响余额显示。

### M3 · 迷你用量趋势图（约 0.5–1 天）✅ 已完成

| 任务 | 内容 | 产出 |
|------|------|------|
| T3.1 | Swift Charts 近 7/30 日柱状图（消费金额 / Token 两个维度可切换），嵌入面板用量卡下方 | 趋势图 |
| T3.2 | 历史留存策略：按本地日聚合存储、时区（tz offset 秒）一致性处理、数据清理上限（如保留 90 天） | 历史数据层 |

### M4 · 打磨与发布准备（约 0.5 天）✅ 已完成（自定义图标资产暂用 🐋 emoji，见 Backlog）

| 任务 | 内容 | 产出 |
|------|------|------|
| T4.1 | 视觉：自定义鲸鱼菜单栏模板图（Template Image，自动适配深浅色）、面板细节、About 信息 | 成品观感 |
| T4.2 | 稳定性：睡眠/唤醒时暂停与立即补偿刷新、错误重试边界、内存与电量自查 | 稳定常驻 |
| T4.3 | 发布：README 完善（含 userToken 获取教程截图位）、构建 zip、（可选）公证流程说明文档 | 可分发包 |

## 5. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| 平台私有接口无契约，DeepSeek 改版即失效 | 用量明细不可用（余额不受影响） | 全部隔离在 `PlatformSessionClient` 单一模块；UI 层按「数据源缺失」设计，可降级为仅余额 |
| userToken 获取有门槛（浏览器 DevTools 操作） | 部分用户配不上用量功能 | App 内置分步图文教程；引导文案放面板空态 |
| 本机无完整 Xcode | 无法用 .xcodeproj；未来如需公证/上架需装 Xcode | SPM + 脚本构建已覆盖当前需求；公证作为 M4 可选项，届时再装 Xcode |
| Swift 6 严格并发与 SwiftUI 混用的摩擦 | 编译期报错增多 | 首选 Swift 6 语言模式；若迭代受阻，允许降级 language mode 5（记录于架构文档决策节） |
| 余额接口多币种 | 显示歧义 | v1 规则固定：优先 CNY，否则取余额最大币种，面板列出全部币种明细 |

## 6. 对应文档索引

- 技术方案与模块设计 → [01-ARCHITECTURE.md](01-ARCHITECTURE.md)
- 界面与交互 → [02-UX.md](02-UX.md)
- 接口契约与调研 → [03-API-NOTES.md](03-API-NOTES.md)
- 本文件为唯一任务进度真源，任务完成后在表格中勾注（✅）。
