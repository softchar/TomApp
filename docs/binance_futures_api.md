# 币安 U本位合约 API 文档

> 来源: https://developers.binance.com/docs/zh-CN/derivatives/usds-margined-futures/general-info
> 
> 提取日期: 2025-04-05

---

## 基本信息

### API 基础信息

- **基础 URL**: `https://fapi.binance.com`
- **测试网 URL**: `https://testnet.binancefuture.com`

### 限制说明

1. **IP 限制**: 每 5 秒最多 2400 请求权重
2. **订单速率**: 每 10 秒最多 300 个订单
3. **WebSocket 连接**: 每个 IP 最多 300 个连接

---

## REST API

### 请求格式

所有 REST 请求都使用 HTTP GET 或 POST 方法。

**请求头**:
```
Content-Type: application/json
X-MBX-APIKEY: <api_key>
```

**签名参数**:
- `signature`: 使用 HMAC SHA256 签名
- `timestamp`: 请求时间戳（毫秒）

### 常用端点

#### 1. 服务器时间

```
GET /fapi/v1/time
```

响应:
```json
{
  "serverTime": 1581087678099
}
```

#### 2. 交易规则和交易对

```
GET /fapi/v1/exchangeInfo
```

响应包含交易对信息、数量精度、价格精度等。

#### 3. 深度信息

```
GET /fapi/v1/depth
```

参数:
- `symbol`: 交易对
- `limit`: 默认 500，最大 5000

#### 4. 近期成交

```
GET /fapi/v1/aggTrades
```

参数:
- `symbol`: 交易对
- `limit`: 默认 500，最大 1000
- `fromId`: 从此 ID 开始
- `startTime`: 开始时间
- `endTime`: 结束时间

#### 5. K 线数据

```
GET /fapi/v1/klines
```

参数:
- `symbol`: 交易对
- `interval`: 时间间隔 (1m, 3m, 5m, 15m, 30m, 1h, 2h, 4h, 6h, 8h, 12h, 1d, 3d, 1w, 1M)
- `limit`: 默认 500，最大 1500
- `startTime`: 开始时间
- `endTime`: 结束时间

#### 6. 当前持仓

```
GET /fapi/v2/positionRisk
```

需要签名。

#### 7. 账户余额

```
GET /fapi/v2/balance
```

需要签名。

#### 8. 24hr 价格变动统计

```
GET /fapi/v1/ticker/24hr
```

参数:
- `symbol`: 交易对（可选）
- `symbols`: 交易对列表（可选）

响应:
```json
{
  "symbol": "BTCUSDT",
  "priceChange": "-94.99999800",
  "priceChangePercent": "-0.380",
  "weightedAvgPrice": "25000.12345678",
  "prevClosePrice": "25000.00000000",
  "lastPrice": "24905.00000200",
  "lastQty": "0.001",
  "bidPrice": "24904.00000000",
  "bidQty": "1.000",
  "askPrice": "24905.00000000",
  "askQty": "5.000",
  "openPrice": "25000.00000000",
  "highPrice": "25100.00000000",
  "lowPrice": "24900.00000000",
  "volume": "12345.67890000",
  "quoteVolume": "308641538.87732000",
  "openTime": 1581074880000,
  "closeTime": 1581161280000,
  "firstId": 123456,
  "lastId": 123460,
  "count": 5
}
```

#### 9. 最新标记价格和资金费率

```
GET /fapi/v1/premiumIndex
```

参数:
- `symbol`: 交易对（可选）

响应:
```json
{
  "symbol": "BTCUSDT",
  "markPrice": "24905.12345678",
  "indexPrice": "24904.98765432",
  "estimatedSettlePrice": "24905.00000000",
  "lastFundingRate": "0.00010000",
  "nextFundingTime": 1581161280000,
  "interestRate": "0.00010000",
  "time": 1581087678099
}
```

#### 10. 资金费率历史

```
GET /fapi/v1/fundingRate
```

参数:
- `symbol`: 交易对
- `startTime`: 开始时间（可选）
- `endTime`: 结束时间（可选）
- `limit`: 默认 100，最大 1000

---

## WebSocket API

### 连接地址

- **现货**: `wss://stream.binance.com:9443/ws`
- **合约**: `wss://fstream.binance.com/ws`
- **组合流**: `wss://fstream.binance.com/stream`

### K 线流

```
<symbol>@kline_<interval>
```

示例: `btcusdt@kline_1m`

响应:
```json
{
  "e": "kline",
  "E": 1581087678099,
  "s": "BTCUSDT",
  "k": {
    "t": 1581087640000,
    "T": 1581087699999,
    "s": "BTCUSDT",
    "i": "1m",
    "f": 100,
    "L": 200,
    "o": "0.0010",
    "c": "0.0020",
    "h": "0.0025",
    "l": "0.0015",
    "v": "1000",
    "n": 100,
    "x": false,
    "q": "1.0000",
    "B": "0.0010"
  }
}
```

字段说明:
- `t`: K 线开始时间
- `T`: K 线结束时间
- `s`: 交易对
- `i`: 时间间隔
- `o`: 开盘价
- `c`: 收盘价
- `h`: 最高价
- `l`: 最低价
- `v`: 成交量
- `x`: 此 K 线是否完结（true 表示完结）

### 24hr 统计流

```
<symbol>@ticker
```

示例: `btcusdt@ticker`

### 全部市场迷你ticker

```
!ticker@arr
```

### 深度信息流

```
<symbol>@depth<levels>
```

- `depth@100`: 实时推送深度信息
- `depth@1000ms`: 每 1000ms 推送深度快照

---

## HTTP 返回码

| HTTP 状态码 | 说明 |
|------------|------|
| 200 | 成功 |
| 400 | 错误的请求 |
| 401 | 未授权 |
| 403 | 禁止访问 |
| 404 | 未找到 |
| 429 | 请求过多（限流） |
| 418 | IP 被封禁 |
| 500 | 内部服务器错误 |
| 503 | 服务不可用 |

---

## 错误码

| 错误码 | 说明 |
|-------|------|
| -1100 | 参数非法 |
| -1101 | 参数过多 |
| -1102 | 必须传参数 |
| -1103 | 未知参数 |
| -1104 | 参数格式错误 |
| -1021 | 时间戳超出接收窗口 |
| -1022 | 签名无效 |
| -1112 | 无此交易对 |
| -2008 | 订单过多 |

---

## 频率限制

### IP 限制

- **请求权重限制**: 每 5 秒 2400 请求权重
- **订单速率限制**: 每 10 秒 300 个订单请求（含 OCO）
- **原始订单限制**: 每 10 秒 100 个订单请求（不含 OCO）

### 访问频率限制（UID）

- **现货/杠杆账户**: 每 1 天 100,000 请求权重
- **期货账户**: 每 1 天 240,000 请求权重

---

## 身份验证

### API Key 类型

1. **只读 API Key**: 只能访问 GET 端点
2. **交易 API Key**: 可以交易和访问 GET 端点

### 签名生成

```
signature = HMAC-SHA256(secretKey, queryString)
```

示例 (JavaScript):
```javascript
const crypto = require('crypto');
const signature = crypto
  .createHmac('sha256', secretKey)
  .update(queryString)
  .digest('hex');
```

---

## SDK 示例

### Python SDK

```python
from binance.client import Client

# 初始化客户端
client = Client(api_key, api_secret)

# 获取 K 线数据
klines = client.futures_klines(
    symbol='BTCUSDT',
    interval='1m',
    limit=500
)

# 获取资金费率
premium_index = client.futures_mark_price(
    symbol='BTCUSDT'
)
```

### JavaScript SDK

```javascript
const Binance = require('binance-api-node').default;

// 初始化客户端
const client = Binance({
  apiKey: 'your_api_key',
  apiSecret: 'your_api_secret'
});

// 获取 K 线数据
client.futures.candles({
  symbol: 'BTCUSDT',
  interval: '1m',
  limit: 500
}).then(candles => console.log(candles));

// 获取资金费率
client.futures.markPrice({
  symbol: 'BTCUSDT'
}).then(result => console.log(result));
```

---

## 过滤规则

### 交易对过滤

- **U 本位合约**: 交易对以 `USDT` 结尾
- **币本位合约**: 交易对以 `USD` 结尾（如 BTCUSD）
- **交割合约**: 合约名包含日期（如 BTCUSD 250328）

### 交易量过滤

通常过滤低交易量的合约：
- 最小 24 小时交易量：1,000,000 USDT

---

## 本项目已使用的端点

| 端点 | 用途 |
|------|------|
| `/fapi/v1/ticker/price` | 获取所有合约价格 |
| `/fapi/v1/ticker/24hr` | 获取 24 小时统计（涨幅排行） |
| `/fapi/v1/fundingInfo` | 获取资金费率 |
| `/fapi/v1/klines` | 获取 K 线数据 |
| `/fapi/v1/premiumIndex` | 获取资金费率历史 |
| `/futures/data/globalLongShortAccountRatio` | 获取多空比 |

---

## 注意事项

1. **时间同步**: 请确保本地时间与服务器时间同步（误差不超过 1000ms）
2. **限流处理**: 建议实现指数退避策略处理 429 错误
3. **WebSocket 重连**: 实现自动重连机制
4. **错误处理**: 检查所有 API 响应的错误码

---

*文档自动提取自币安官方 API 文档*
