# WhaleBar 🐋

macOS 菜单栏（Status Bar）的 DeepSeek 余额监视工具。原生 SwiftUI 开发，常驻菜单栏，一眼查看 API 账户余额。

## 功能

- **菜单栏余额**：实时显示 DeepSeek API 账户总余额，样式（图标+数字/仅数字/仅图标）可在设置中切换，修改即时生效
- **下拉面板**：深海军蓝渐变余额卡，大字号展示总额、赠送/充值构成、多币种明细、可用状态
- **数据来源**：官方 API `GET /user/balance`（稳定，凭 API Key）
- **安全**：API Key 仅存 macOS Keychain；本地缓存不含凭据
- **健壮性**：失败指数退避（封顶 30 分钟）、离线缓存兜底、睡眠暂停/唤醒补偿刷新、手动刷新节流

> 历史：v0.2 及之前版本曾提供用量明细（今日/本月消费、趋势图，走平台网页私有接口），v0.3 起按用户决定移除，产品聚焦余额监视。调研存档见 [docs/03-API-NOTES.md](docs/03-API-NOTES.md)。

## 快速开始

```bash
# 构建并生成 WhaleBar.app（本机仅需 Command Line Tools，无需完整 Xcode）
./Scripts/build_app.sh

# 构建并直接启动
./Scripts/build_app.sh --open

# 运行断言检查器（单测）
./Scripts/test.sh

# 清理
./Scripts/build_app.sh --clean
```

产物：`build/WhaleBar.app`（ad-hoc 签名，本机使用）。若已复制到 `/Applications`，重新构建后需再次覆盖复制。

### 配置步骤

1. 首次启动会自动弹出设置窗口（也可点击菜单栏「🐋 开始使用」→ 设置）
2. 在 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 创建 API Key，粘贴后「验证并保存」，余额即上屏

## 开发

- 技术栈：Swift 6 + SwiftUI（MenuBarExtra / @Observable），零第三方依赖
- 目标系统：macOS 15+
- 构建链：SPM + `Scripts/build_app.sh`（手工组装 bundle + ad-hoc 签名）
- 测试：自研断言检查器 `WhaleBarKitChecks`（本机 CLT 无 XCTest/Swift Testing 运行时）

| 文档 | 内容 |
|------|------|
| [docs/00-PLAN.md](docs/00-PLAN.md) | 总体规划：决策记录、里程碑任务与进度、变更记录、风险 |
| [docs/01-ARCHITECTURE.md](docs/01-ARCHITECTURE.md) | 技术架构：模块划分、数据流、构建方案 |
| [docs/02-UX.md](docs/02-UX.md) | UX 设计：状态栏、下拉面板、设置窗口、状态反馈矩阵 |
| [docs/03-API-NOTES.md](docs/03-API-NOTES.md) | DeepSeek 接口调研（余额现行；平台接口为存档） |
