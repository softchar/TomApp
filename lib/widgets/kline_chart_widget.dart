import 'package:flutter/material.dart';
import 'package:flutter_chen_kchart/k_chart_widget.dart';
import 'package:flutter_chen_kchart/entity/k_line_entity.dart';
import '../models/kline_data.dart';

/// K线图表组件
///
/// 使用flutter_chen_kchart库显示K线图表，支持MA、BOLL、MACD等技术指标。
/// 支持高亮标注下跌段+拉回段区域（反弹信号下钻）。
class KlineChartWidget extends StatelessWidget {
  /// K线数据列表（包含技术指标）
  final List<KlineDataWithIndicators> data;

  /// 是否为实时数据
  final bool isRealtime;

  /// 当前价格（可选）
  final double? currentPrice;

  /// 时间周期
  final String interval;

  /// 下跌段起始时间（毫秒时间戳），null 则不标注。
  final int? highlightStartMs;

  /// 拉回段结束时间（毫秒时间戳），null 则不标注。
  final int? highlightEndMs;

  const KlineChartWidget({
    super.key,
    required this.data,
    required this.isRealtime,
    this.currentPrice,
    this.interval = '1d',
    this.highlightStartMs,
    this.highlightEndMs,
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

    // 1m周期显示折线图，其他周期显示蜡烛图
    final bool isLine = interval == '1m';

    final chart = KChartWidget(
      klineData,
      // 图表样式配置
      isTrendLine: false, // 是否启用趋势线绘制
      xFrontPadding: 100, // 前端留白

      // 主图指标：MA（移动平均线）
      mainState: MainState.MA,

      // 副图指标：无（隐藏MACD）
      secondaryState: SecondaryState.NONE,

      // 是否显示成交图
      volHidden: true,

      // 是否为折线图（1m为true，其他为false）
      isLine: isLine,

      // 是否隐藏网格
      hideGrid: false,

      // 是否显示当前价格线
      showNowPrice: true,

      // 是否显示信息弹窗（长按/点击时显示OHLCV详情）
      showInfoDialog: false,

      // 是否使用Material风格的信息弹窗
      materialInfoDialog: false,

      // 是否单击显示详情数据
      isTapShowInfoDialog: false,

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

    // 如果有高亮参数，用 Stack 叠加高亮层
    if (highlightStartMs != null && highlightEndMs != null) {
      return Stack(
        children: [
          chart,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HighlightPainter(
                  startMs: highlightStartMs!,
                  endMs: highlightEndMs!,
                  klineData: data,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return chart;
  }
}

/// 反弹信号高亮标注画笔。
///
/// 在 K 线图上叠加半透明矩形标注下跌段（红色）和拉回段（绿色）。
/// 根据时间范围在数据列表中找到对应的 K 线索引，按比例映射到图表 x 轴。
class _HighlightPainter extends CustomPainter {
  final int startMs;
  final int endMs;
  final List<KlineDataWithIndicators> klineData;

  _HighlightPainter({
    required this.startMs,
    required this.endMs,
    required this.klineData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (klineData.isEmpty) return;

    // 找到 startMs 和 endMs 在数据中的索引
    int? startIdx;
    int? endIdx;
    for (var i = 0; i < klineData.length; i++) {
      final t = klineData[i].time.millisecondsSinceEpoch;
      if (startIdx == null && t >= startMs) startIdx = i;
      if (t <= endMs) endIdx = i;
    }
    if (startIdx == null || endIdx == null || startIdx >= endIdx) return;

    final totalLen = klineData.length;
    // 图表区域：KChartWidget 左侧有价标宽度约 60px，右侧有些 padding
    // 这是估算值（未精确适配 KChartWidget 内部布局）
    const chartLeft = 60.0;
    final chartRight = size.width - 8.0;
    final chartWidth = chartRight - chartLeft;

    final x1 = chartLeft + (startIdx / totalLen) * chartWidth;
    final x2 = chartLeft + ((endIdx + 1) / totalLen) * chartWidth;

    // 绘制绿色高亮区域（反弹段）
    final greenPaint = Paint()
      ..color = Colors.green.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(x1, 0, x2, size.height),
      greenPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return startMs != oldDelegate.startMs ||
        endMs != oldDelegate.endMs;
  }
}
