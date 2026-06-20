/// 回测运行状态枚举，供 BacktestProvider 状态机使用。
enum BacktestStatus {
  /// 空闲——未开始或已重置
  idle,

  /// 运行中——回测引擎正在执行
  running,

  /// 已完成——回测成功结束，报告可用
  complete,

  /// 出错——回测过程中发生异常
  error,
}
