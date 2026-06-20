---
status: complete
phase: 06-event-driven
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-VERIFICATION.md]
started: 2026-06-20T14:00:00Z
updated: 2026-06-20T14:35:00Z
note: |
  Phase 06 技术验证（06-VERIFICATION.md）已 18/18 通过、lookahead-analysis UAT (BACKTEST-06) 已绿。
  本 UAT 聚焦用户可观测行为（主要来自 06-03 UI 层），并覆盖本次 code-review --fix 刚发布的
  CR-02（资金费率历史传入引擎）/ CR-03（成本 R 单位换算）修复在真机上的实际表现。
  注意：回测需联网下载 data.binance.vision 历史 K 线 + Binance REST 资金费率——若设备无网络，
  相关测试标记 blocked（非代码问题）。
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete — 8/9 passed, 1 skipped（用户后续自测错误/空状态）]

## Tests

### 1. Cold Start Smoke Test
expected: 杀掉运行中的 app，冷启动。app 正常启动无崩溃，主界面加载，ProfileScreen 可达（main.dart 新增了 BacktestProvider 注册——验证启动序列无 race/无 Provider 缺失）。
result: pass
evidence: 机器侧验证——release APK 编译成功(11.4MB)、install Success、进程 com.example.tomapp PID 26084 运行中、logcat 无 FATAL/AndroidRuntime、callbackDispatcher 已获取 628 合约价格。

### 2. 回测入口可达 + idle 状态
expected: ProfileScreen 可见「回测」入口；点击进入 BacktestScreen，显示 idle 初始状态（配置输入区可见，无报错，无残留报告）。
result: pass

### 3. 日期范围校验（T-06-06）
expected: 输入非法范围被拒绝并提示——范围 >365 天、startDate ≥ endDate、startDate < 2020-01-01 均不可运行；合法范围（如某币种近 3 个月）可进入运行。
result: pass

### 4. 运行状态反馈
expected: 点击「运行回测」后状态切到 running，界面给出加载/进度反馈，UI 不冻结；完成后进入 complete 态。
result: pass

### 5. 完成态：双权益曲线 + 资金费扣费生效（CR-02 验证）
expected: complete 态展示双权益曲线——橙色实线（零成本）+ 紫色虚线（含成本）。含成本曲线应低于零成本曲线，差额反映手续费 + 滑点 + **资金费**（本次 CR-02 修复：资金费率历史已传入引擎，持仓不再零资金费扣减）。
result: pass

### 6. 完成态：7 项统计卡
expected: 统计区 2 列 GridView 展示 7 项指标——胜率 / 平均R / 盈亏比 / 最大回撤 / 样本数 / 总PnL / 均笔R，数值合理（非全 0、非 NaN、非 infinity 异常显示）。
result: pass

### 7. 四项强制披露 + 免责声明（D-20 / D-21）
expected: complete 态底部展示 4 项带绿色勾选的强制披露项；固定免责声明文字「回测表现通常需打 30-50% 折扣作为实盘预期；本工具不构成投资建议。」存在。
result: pass

### 8. 可排序交易列表 + 下钻 KlineScreen
expected: 交易列表支持 5 列点击排序（点击列头在升序/降序间切换）；点击某行下钻到 KlineScreen 查看对应 K 线。
result: pass

### 9. 错误/空结果状态 + 零执行词（D-22）
expected: 异常路径（如取数失败）显示错误消息态；0 笔交易场景显示空结果态（非崩溃、非空白）。整个回测 UI 全文无「买入/强买/推荐」等执行性词汇。
result: skipped
reason: 用户选择后续自行测试错误/空结果状态（需构造无信号币种或断网场景）；零执行词扫描并入下次自测。

## Summary

total: 9
passed: 8
issues: 0
pending: 0
skipped: 1
blocked: 0

## Gaps

[none yet]
