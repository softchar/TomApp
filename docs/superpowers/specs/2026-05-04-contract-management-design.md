# 合约管理功能设计文档

**日期:** 2026-05-04
**状态:** 已批准

## 概述

在"我的"页面添加"合约信息管理"功能，允许用户开启/关闭自动同步币安合约信息。同步的数据将存储到SQLite数据库，支持后续查询和分析。

## 功能需求

1. 在ProfileScreen添加"合约信息管理"Section
2. 添加开关控制自动同步（默认关闭）
3. 开启后每小时自动获取所有合约信息
4. 数据存储到SQLite数据库，已存在则更新，不存在则新增

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                     ProfileScreen                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         合约信息管理 (新增Section)                     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Switch: 自动同步合约信息                        │  │  │
│  │  │  默认关闭                                        │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  ContractSyncSettings                       │
│  - autoSyncEnabled: bool (SharedPreferences)                │
│  - 控制同步开关状态                                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 ContractSyncService                         │
│  - 启动/停止定时器（每小时）                                 │
│  - 调用ExchangeInfoService获取数据                          │
│  - 调用ContractInfoService存储到SQLite                      │
└─────────────────────────────────────────────────────────────┘
            │                           │
            ▼                           ▼
┌───────────────────────────┐  ┌───────────────────────────┐
│   ExchangeInfoService     │  │   ContractInfoService     │
│   (现有，复用)            │  │   (新增)                  │
│   - 获取合约数据          │  │   - SQLite CRUD           │
│   - 缓存到SharedPreferences│  │   - 表: futures_symbols  │
└───────────────────────────┘  └───────────────────────────┘
```

## 组件设计

### 新增文件

| 文件 | 职责 |
|------|------|
| `lib/services/contract_info_service.dart` | SQLite数据库操作，管理futures_symbols表 |
| `lib/services/contract_sync_settings.dart` | 同步开关设置管理（SharedPreferences） |
| `lib/services/contract_sync_service.dart` | 同步服务，定时调用ExchangeInfoService并存储 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `lib/services/database_helper.dart` | 添加futures_symbols表（数据库版本升级到3） |
| `lib/screens/profile_screen.dart` | 添加"合约信息管理"Section和开关 |

## 数据库设计

### 表名: `futures_symbols`

| 字段名 | 类型 | 说明 |
|--------|------|------|
| symbol | TEXT | 交易对（主键） |
| base_asset | TEXT | 标的资产 |
| quote_asset | TEXT | 报价资产 |
| status | TEXT | 合约状态（TRADING/DELIVERING等） |
| contract_type | TEXT | 合约类型（PERPETUAL/CURRENT_QUARTER等） |
| onboard_date | INTEGER | 上线日期时间戳 |
| delivery_date | INTEGER | 交割日期时间戳 |
| price_precision | INTEGER | 价格精度 |
| quantity_precision | INTEGER | 数量精度 |
| updated_at | INTEGER | 本地更新时间戳 |

### 索引
- `idx_status`: status字段索引（用于筛选可交易合约）
- `idx_updated_at`: updated_at索引（用于排序）

### 数据库版本
- 升级到 v3

## 数据流

### 开启同步流程

```
用户打开开关
    │
    ▼
ContractSyncSettings保存设置
    │
    ▼
ContractSyncService.startSync()
    │
    ├─ 立即执行一次同步
    │  │
    │  ▼
    │  ExchangeInfoService.fetchExchangeInfo()
    │  │
    │  ▼
    │  获取到symbols列表
    │  │
    │  ▼
    │  ContractInfoService.upsertSymbols(symbols)
    │  │
    │  ▼
    │  SQLite: INSERT OR REPLACE
    │
    └─ 启动定时器（每小时）
```

### 关闭同步流程

```
用户关闭开关
    │
    ▼
ContractSyncSettings保存设置
    │
    ▼
ContractSyncService.stopSync()
    │
    ▼
取消定时器
```

## UI设计

```dart
// 合约信息管理部分
_buildSectionHeader('合约信息管理'),
Card(
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: SwitchListTile(
    title: const Text('自动同步合约信息'),
    subtitle: Text(enabled ? '每小时自动同步' : '已关闭'),
    value: enabled,
    onChanged: (value) {
      ContractSyncSettings().setAutoSyncEnabled(value);
      if (value) {
        ContractSyncService().startSync();
      } else {
        ContractSyncService().stopSync();
      }
    },
  ),
),
```

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| 网络请求失败 | 记录日志，下次定时器触发时重试 |
| 数据库存储失败 | 记录日志，保留现有数据 |
| 解析JSON失败 | 跳过该条记录，记录日志 |
| 定时器启动失败 | 显示错误提示给用户 |

## API参考

- **接口:** GET /fapi/v1/exchangeInfo
- **文档:** docs/币安接口文档/3.U本位合约/4.获取交易规则和交易对.md
- **请求权重:** 1
- **请求限制:** 每分钟2400次（REQUEST_WEIGHT）

## 依赖服务

- **ExchangeInfoService:** 现有服务，复用其获取合约信息的能力
- **DatabaseHelper:** 现有数据库辅助类，需要升级版本

## 非功能需求

- **性能:** SQLite批量操作使用事务处理
- **可靠性:** 网络失败时自动重试
- **兼容性:** 数据库升级需要处理旧版本迁移
