import 'package:flutter/material.dart';
import 'package:flutter_chen_kchart/k_chart_widget.dart';
import 'package:flutter_chen_kchart/entity/k_line_entity.dart';
import '../models/kline_data.dart';

/// K线图表组件
///
/// 使用flutter_chen_kchart库显示K线图表，支持MA、BOLL、MACD等技术指标
class KlineChartWidget extends StatelessWidget {
  /// K线数据列表（包含技术指标）
  final List<KlineDataWithIndicators> data;

  /// 是否为实时数据
  final bool isRealtime;

  /// 当前价格（可选）
  final double? currentPrice;

  const KlineChartWidget({
    super.key,
    required this.data,
    required this.isRealtime,
    this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    // 如果没有数据，显示提示信息
    if (data.isEmpty) {
      return const Center(
        child: Text('暂无数据'),
      );
    }

    // 转换数据格式为KLineEntity
    final klineData = data.map((e) {
      return KLineEntity.fromCustom(
        open: e.data.open,
        close: e.data.close,
        high: e.data.high,
        low: e.data.low,
        vol: e.data.volume,
        time: e.data.time.millisecondsSinceEpoch,
        amount: null, // 成交额，暂不需要
        change: null, // 涨跌额，库会自动计算
        ratio: null, // 涨跌幅，库会自动计算
      );
    }).toList();

    return KChartWidget(
      klineData,
      // 图表样式配置
      isTrendLine: false, // 是否启用趋势线绘制
      xFrontPadding: 100, // 前端留白

      // 主图指标：MA（移动平均线）
      mainState: MainState.MA,

      // 副图指标：MACD
      secondaryState: SecondaryState.MACD,

      // 是否显示成交图
      volHidden: false,

      // 是否为折线图（false为K线图）
      isLine: false,

      // 是否隐藏网格
      hideGrid: false,

      // 是否显示当前价格线
      showNowPrice: currentPrice != null,

      // 是否显示信息弹窗（长按/点击时显示OHLCV详情）
      showInfoDialog: true,

      // 是否使用Material风格的信息弹窗
      materialInfoDialog: true,

      // 是否单击显示详情数据
      isTapShowInfoDialog: true,

      // 是否中文界面
      isChinese: true,

      // 小数点保留位数
      fixedLength: 2,

      // MA周期配置
      maDayList: const [5, 10, 20],

      // 时间格式
      timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,

      // 主题系统
      enableTheme: true,

      // 缩放配置
      minScale: 0.5,
      maxScale: 3.0,
      scaleSensitivity: 2.5,

      // 是否启用双指缩放
      enablePinchZoom: true,

      // 是否启用滚轮缩放（桌面端）
      enableScrollZoom: true,

      // 是否启用震动反馈（移动端）
      enableHapticFeedback: true,
    );
  }
}
