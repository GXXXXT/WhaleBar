# DeepSeek 接口调研笔记

> 版本：v0.3 · 更新日期：2026-09-18
>
> **状态变更（v0.3）**：应用户决定，WhaleBar 已移除「用量明细」功能，§2 平台私有接口相关代码全部下线，本章保留为**调研存档**（未来若恢复用量功能可直接参考）；§1 官方余额接口为当前唯一数据源，仍在使用。
>
> ⚠️ 用量明细相关端点为**平台网页私有接口**，无官方契约。
> ✅ 响应结构已通过 CodexBar 源码（`DeepSeekUsageFetcher.swift` / `DeepSeekUsageCostParser.swift`）逐字段确认；真机 Spike（真实 userToken 实测）未执行。

## 1. 官方 API — 获取用户余额

- 端点：`GET https://api.deepseek.com/user/balance`
- 鉴权：`Authorization: Bearer <API_KEY>`（API Key 在 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 创建）
- 稳定性：官方文档化接口 → **余额主数据源**

### 响应示例

```json
{
  "is_available": true,
  "balance_infos": [
    {
      "currency": "CNY",
      "total_balance": "110.00",
      "granted_balance": "10.00",
      "topped_up_balance": "100.00"
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `is_available` | 余额是否足以支撑 API 调用 |
| `balance_infos[]` | 多币种数组；金额为字符串（注意 Decimal 解析） |
| `total_balance` | 总余额 = 赠送 + 充值 |
| `granted_balance` | 赠送（未过期赠金） |
| `topped_up_balance` | 充值余额 |

### 错误处理

- `401`：API Key 无效 → `.invalidAPIKey`
- `429`：限流 → 退避重试
- 金额字段为 string，解析用 `Decimal`，展示保留两位小数。

## 2. 平台私有接口 — 用量明细（userToken 会话）

### 通用约定

- Base：`https://platform.deepseek.com`
- 鉴权：`Authorization: Bearer <userToken>`
- 必带头：`x-client-platform: web`、`Accept: application/json`；超时 15s
- userToken 获取：登录平台后浏览器 DevTools → Application → Local Storage → `userToken`
- **会话失效**：顶层 `code` 或内层 `biz_code` 为 `40002`/`40003`，以及 HTTP 401/403 → `.sessionExpired`（余额功能不受影响）

### 信封结构（所有平台接口）

```json
{
  "code": 0, "msg": "",
  "data": { "biz_code": 0, "biz_msg": "", "biz_data": { /* 业务数据 */ } }
}
```

### 端点清单与响应结构

| 端点 | 用途 | biz_data 结构 |
|------|------|---------------|
| `GET /api/v0/users/get_user_summary` | 账户概要/钱包余额 | `{ "normal_wallets": [{balance, currency}], "bonus_wallets": [...] }`；balance 为数值或字符串 |
| `GET /api/v0/usage/by_api_key/amount?start=<unix>&end=<unix>&tz=<秒偏移>` | 按日 token 用量 | `{ "series": [{ "api_key": {name,tracking_id}\|"id", "model", "buckets": [{ "time": <unix>, "usage": { "<TYPE>": <scalar> } }] }] }` |
| `GET /api/v0/usage/by_api_key/cost?start=&end=&tz=` | 按日花费 | `{ "data": [{ "currency", "series": [{ "api_key", "model", "buckets": [{ "time", "cost": <scalar> }] }] }] }`（按币种分块） |
| `GET /api/v0/usage/amount?month=<m>&year=<y>` | 月度用量 fallback | `{ "total": [model…], "days": [{ "date": "yyyy-MM-dd", "data": [{model, usage: [{type, amount}]}] }] }` |
| `GET /api/v0/usage/cost?month=&year=` | 月度花费 fallback | 同上 + `currency` 字段，`biz_data` 为币种块数组 |

关键解析规则（已实现于 `PlatformSessionClient`）：

- 数值均为**宽松标量**（nil / String / Int / Double 统一处理），token 数取 usage 中键名含 `TOKEN` 的类别（`PROMPT_CACHE_HIT_TOKEN` + `PROMPT_CACHE_MISS_TOKEN` + `RESPONSE_TOKEN`），`REQUEST` 为请求次数不计入 token。
- 分桶 `time` 为 Unix 秒，按请求参数 `tz`（固定秒偏移）换算为 `yyyy-MM-dd` 本地日 key；amount 与 cost 合并为单条 `UsageBucket`。
- 花费币种块选择：优先 CNY → 有正向花费的 USD → 任一有正向花费 → 首块。
- `start/end` 为 Unix 秒；App 窗口取近 45 天（覆盖 30 日趋势图与当月聚合），本地缓存留存 90 天。
- 月度 fallback 仅在 by_api_key 系列失败且非会话过期时尝试。

## 3. T2.0 实测清单（需真实 userToken）

- [ ] 实测 `get_user_summary` 响应与上表一致
- [ ] 实测 `by_api_key/amount` 指定窗口的响应与上表一致（含多 model、多日数据）
- [ ] 实测 `by_api_key/cost` 响应（币种块、精度）
- [ ] 验证 40002/40003 实际触发方式（过期 token）
- [ ] 记录限流表现（连续调用 20 次观察）

## 4. 风险声明

- 私有接口可能随平台改版失效：客户端将解析失败统一映射为 `.decoding` 优雅降级，不影响余额展示。
- userToken 等同账户会话凭据：仅存 Keychain、仅发往 platform.deepseek.com、不得写入日志。

## 参考

- [DeepSeek 官方文档 — Get User Balance](https://api-docs.deepseek.com/api/get-user-balance/)（[中文版](https://api-docs.deepseek.com/zh-cn/api/get-user-balance/)）
- [CodexBar — DeepSeek 集成笔记](https://github.com/steipete/CodexBar/blob/main/docs/deepseek.md)（端点行为来源）
- [CodexBar 源码 — DeepSeekUsageFetcher / DeepSeekUsageCostParser](https://github.com/steipete/CodexBar/tree/main/Sources/CodexBarCore/Providers/DeepSeek)（响应结构逐字段确认来源）
