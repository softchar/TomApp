/// MACD指标数据
class MACDData {
  final List<double?> dif;      // DIF线 (快线)
  final List<double?> dea;      // DEA线 (慢线)
  final List<double?> macd;     // MACD柱状图
  final List<DateTime> time;    // 时间轴

  MACDData({
    required this.dif,
    required this.dea,
    required this.macd,
    required this.time,
  });

  /// 数据长度
  int get length => time.length;

  /// 获取指定位置的MACD值
  MACDValue? getValue(int index) {
    if (index < 0 || index >= length) return null;
    if (dif[index] == null || dea[index] == null || macd[index] == null) {
      return null;
    }
    return MACDValue(
      dif: dif[index]!,
      dea: dea[index]!,
      macd: macd[index]!,
      time: time[index],
    );
  }
}

/// 单个MACD值
class MACDValue {
  final double dif;
  final double dea;
  final double macd;
  final DateTime time;

  MACDValue({
    required this.dif,
    required this.dea,
    required this.macd,
    required this.time,
  });

  /// MACD柱状图颜色 (正=红, 负=绿)
  bool get isPositive => macd >= 0;
}
