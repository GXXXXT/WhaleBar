# WhaleBar 技术架构

> 版本：v0.1 · 更新日期：2026-09-17 · 配套：[00-PLAN.md](00-PLAN.md) / [02-UX.md](02-UX.md) / [03-API-NOTES.md](03-API-NOTES.md)

## 1. 技术选型

| 项 | 选择 | 说明 |
|----|------|------|
| UI 框架 | SwiftUI `MenuBarExtra`（`.window` 样式）+ `Settings` scene | macOS 15 目标下能力完整；无 Dock 图标由 Info.plist `LSUIElement=true` 保证 |
| 状态管理 | `@Observable`（SwiftUI 新范式）+ `@MainActor` | D2 决策允许 |
| 网络 | URLSession async/await，协议抽象便于 mock | 无第三方依赖，保持零依赖 |
| 并发 | Swift 6 语言模式优先；结构化并发（Task/TaskGroup） | 遇阻可降级 language mode 5（见 PLAN 风险表） |
| 凭据存储 | Keychain GenericPassword | API Key / userToken 均不落 UserDefaults |
| 本地缓存 | Application Support 下 JSON 文件 | 余额快照 + 按日用量 bucket |
| 图表（M3） | Swift Charts | 系统框架 |
| 构建分发 | SPM + `Scripts/build_app.sh` + ad-hoc codesign | 见 §5 |

## 2. 工程结构

```
WhaleBar/
├── Package.swift                  # platforms: .macOS(.v15); swift-tools 6.x
├── Sources/
│   ├── WhaleBarKit/               # 纯逻辑库（可测试、无 UI 依赖）
│   │   ├── Models/
│   │   │   ├── BalanceInfo.swift          # 余额（币种、总额、赠送、充值、is_available）
│   │   │   ├── UsageBucket.swift          # 按日用量（日期、tokens、花费、币种）
│   │   │   └── AccountSnapshot.swift      # 聚合快照（余额 + 用量 + 时间戳 + 数据源状态）
│   │   ├── Networking/
│   │   │   ├── HTTPClient.swift           # URLSession 封装（协议化，可注入 mock）
│   │   │   ├── DeepSeekBalanceClient.swift # 官方 GET /user/balance
│   │   │   └── PlatformSessionClient.swift # 平台私有接口（summary/usage）
│   │   ├── Storage/
│   │   │   ├── KeychainStore.swift
│   │   │   └── CacheStore.swift           # Application Support JSON 读写
│   │   └── Core/
│   │       ├── AppState.swift             # @MainActor @Observable 全局状态
│   │       ├── RefreshScheduler.swift     # 周期刷新 + 退避重试 + 手动节流
│   │       └── AppSettings.swift          # 用户设置（间隔/显示样式），UserDefaults 存储
│   └── WhaleBar/                  # App 可执行 target（仅 UI）
│       ├── WhaleBarApp.swift              # @main、MenuBarExtra、Settings scene
│       ├── Views/
│       │   ├── StatusLabelView.swift      # 菜单栏 label（图标+数字）
│       │   ├── PanelView.swift            # 下拉面板（余额卡/用量卡/底栏）
│       │   ├── UsageCardView.swift
│       │   ├── TrendChartView.swift       # M3
│       │   └── Settings/
│       │       ├── SettingsView.swift
│       │       ├── CredentialSection.swift
│       │   └── OnboardingView.swift       # 首启动引导
├── Checks/WhaleBarKitChecks/      # 自研断言检查器（本机 CLT 无 XCTest/Testing）
│   ├── ChecksMain.swift                   # 入口：跑全部套件，失败非零退出
│   ├── Harness.swift                      # 断言助手 + URLProtocol stub
│   ├── BalanceChecks.swift                # 官方余额客户端
│   ├── PlatformChecks.swift               # 平台会话客户端（分桶/信封/错误码）
│   └── CacheAndThrottleChecks.swift       # 缓存往返 / 节流
├── Scripts/
│   ├── build_app.sh               # swift build → 组装 .app → ad-hoc 签名
│   └── test.sh                    # swift run WhaleBarKitChecks
├── Resources/Info.plist
└── docs/
```

分层原则：`WhaleBar`（UI 层）只依赖 `WhaleBarKit`；Kit 内 Networking 不感知 UI；所有全局可变状态收敛到 `AppState`。

## 3. 核心数据流

```
                    ┌────────────────────────────┐
                    │ RefreshScheduler           │
                    │  · 定时（默认 5min，可配）   │
                    │  · 手动刷新（节流 ≥5s）      │
                    │  · 失败指数退避（封顶 30min）│
                    └──────────┬─────────────────┘
                               │ Task { }
              ┌────────────────┴────────────────┐
              ▼                                 ▼
 ┌─────────────────────────┐      ┌──────────────────────────────┐
 │ DeepSeekBalanceClient    │      │ PlatformSessionClient（可选） │
 │ api.deepseek.com         │      │ platform.deepseek.com        │
 │ 凭据: API Key (Keychain) │      │ 凭据: userToken (Keychain)   │
 │ → BalanceInfo            │      │ → [UsageBucket] / summary    │
 └────────────┬────────────┘      └──────────────┬───────────────┘
              │           并发合并                │
              ▼                                  ▼
        ┌───────────────────────────────────────────┐
        │ AppState (@MainActor @Observable)          │
        │  snapshot / loadState / lastUpdated / err  │
        └───────┬───────────────────────┬───────────┘
                ▼                       ▼
        MenuBarExtra label        CacheStore（JSON 持久化）
        + PanelView（SwiftUI）     （离线时反向注入 AppState）
```

要点：

- **数据源合并规则**：余额以官方 API 为主数据源；仅当未配置 API Key 但配置了 userToken 时，余额改由平台 summary 接口提供（降级链路）。用量明细仅来自平台接口。
- **失败隔离**：两类请求独立 try，余额成功 + 用量失败 → 面板显示余额 + 用量区标记「暂时不可用/会话过期」，状态栏数值保持余额。
- **离线兜底**：启动时先读缓存渲染，再发起刷新；网络失败时保留缓存数据并显示「最后更新时间」。

## 4. 关键设计细节

### 4.1 凭据（Keychain）

- service 统一 `com.heyhansir.WhaleBar`；account 分别为 `apiKey`、`userToken`。
- 读取失败/不存在 → 视为「未配置」，驱动首启动引导。
- 日志与错误信息中一律不输出凭据明文。
- ad-hoc 签名保证 Keychain 访问归属稳定；若更换 bundle id 需重新授权。

### 4.2 刷新策略（RefreshScheduler）

- 间隔档位：1 / 5 / 15 / 30 分钟（默认 5）。
- 使用 `Task` + `Task.sleep(for:)` 循环；设置变更时取消重建。
- 失败退避：连续失败按 ×2 退避，封顶 30 分钟；成功后恢复配置间隔。
- 手动刷新节流：距上次成功刷新 < 5s 时忽略。
- M4 增强：监听 `NSWorkspace.willSleepNotification/didWakeNotification`，睡眠暂停、唤醒立即补偿刷新。

### 4.3 时区与「今日/本月」（M2/M3）

- 平台 by_api_key 接口以「固定 UTC 偏移的格里高利日」分桶，请求参数 `tz` 为秒偏移；App 统一传当前本地时区偏移，保证「今日」与用户直觉一致。
- 本地缓存按 `YYYY-MM-DD`（本地日）为 key 聚合；跨月汇总在客户端按日累加，monthly 接口仅作 fallback。

### 4.4 错误模型（WhaleBarKit 统一 `AppError`）

| 错误 | 触发 | UI 呈现 |
|------|------|---------|
| `.notConfigured` | 无凭据 | 首启动引导 |
| `.invalidAPIKey` | 官方接口 401 | 横幅 + 跳设置 |
| `.sessionExpired` | 平台接口 40002/40003 | 横幅 + 教程指引（余额不受影响） |
| `.network` | 超时/断网 | 横幅 + 保留缓存 |
| `.rateLimited` | 429 | 退避提示 |
| `.decoding` | 响应结构变化（私有接口风险） | 上报「接口可能变更」文案 |

## 5. 构建方案（无完整 Xcode 环境）

本机仅有 Command Line Tools（`/Library/Developer/CommandLineTools`），无 `xcodebuild`：

1. `swift build -c release` 编译可执行文件（CLT 的 macOS SDK 含 SwiftUI，可完整编译）。
2. `Scripts/build_app.sh` 组装 bundle：

```
build/WhaleBar.app/
└── Contents/
    ├── Info.plist          # CFBundleName/Identifier=com.heyhansir.WhaleBar,
    │                       # LSUIElement=true, LSMinimumSystemVersion=15.0,
    │                       # CFBundleExecutable=WhaleBar, NSPrincipalClass=NSApplication
    ├── MacOS/WhaleBar      # swift build 产物拷贝
    └── Resources/          # Assets.car / 图标（M4）
```

3. `codesign --force --sign - build/WhaleBar.app`（ad-hoc，本机使用）。
4. 脚本同时提供 `--open` 快捷启动与 `--clean`。

> 备注：未来若需公证（notarization）或上架，需安装完整 Xcode，届时可按需引入 XcodeGen 生成 .xcodeproj，SPM 目标结构无需变动。

## 6. 测试策略

> 环境实测：本机 CLT 缺少 XCTest 与 Swift Testing 运行时（`no such module 'XCTest'`），故 `swift test` 不可用。测试改由自研断言检查器承载：`./Scripts/test.sh`（内部 `swift run WhaleBarKitChecks`），通过 55 项断言、失败非零退出。

- **检查范围**：
  - `DeepSeekBalanceClient`：响应解析（CNY 优先/最大币种/缺失字段回落）、401/429/非法 JSON 映射、请求头与路径。
  - `PlatformSessionClient`：amount+cost 分桶合并（跨 model 累加 token、REQUEST 不计）、本地日 key 换算（tz）、请求参数与平台头、顶层 code 与 biz_code 的 40002/40003 会话过期映射、多币种块 CNY 优先、钱包概要聚合。
  - `CacheStore`：读写往返、损坏文件容错、空目录。
  - `RefreshThrottle`：force 放行、间隔内拦截/外放行。
  - 底层传输：URLProtocol stub 注入假响应，不依赖真实网络。
- **手动验收清单**：跟随各里程碑「完成标准」执行（见 00-PLAN）。
- 备注：检查器以普通 `import WhaleBarKit` 引用公开 API（release 构建不支持 `@testable`），跨 target 复用的解析入口（如 `mergeDailyBuckets`）已声明为 public。
