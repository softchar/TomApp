import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tomapp/models/kline_data.dart';

/// fl_chart 原生绘制的 K 线图组件（对比 TradingView WebView 版本用）。
///
/// 接口与 TradingViewKlineWidget 一致（data / dropStartIndex / dropEndIndex /
/// recoveryEndIndex）。**data 为全量窗口**（可拖动查看历史）。
///
/// 蜡烛**固定粗细**、从左到右**等距**排列：每根蜡烛占据固定像素宽度
/// （[_candleStep]），数据不足时右侧留白，不再把少量蜡烛撑满整行。
/// 支持**单指水平拖动**查看更早的历史蜡烛；默认跟随最新 K线（贴右端）。
///
/// 实现要点：fl_chart 会把 [minX, maxX] 线性映射到整宽，因此令 maxX = 宽度/步长
/// （远大于最后一根的索引），getPixelX(i) = i × 步长，蜡烛即固定间距、从左排列。
///
/// 注：fl_chart 1.2.0 的 CandlestickChartData 未开放 extraLinesData，
/// 最新价虚线、成交量改用 Stack 叠加 CustomPaint 实现（与蜡烛严格对齐）。
class FlChartKlineWidget extends StatefulWidget {
  final List<KlineData> data;
  final int? dropStartIndex;
  final int? dropEndIndex;
  final int? recoveryEndIndex;

  const FlChartKlineWidget({
    super.key,
    required this.data,
    this.dropStartIndex,
    this.dropEndIndex,
    this.recoveryEndIndex,
  });

  @override
  State<FlChartKlineWidget> createState() => _FlChartKlineWidgetState();
}

class _FlChartKlineWidgetState extends State<FlChartKlineWidget> {
  static const Color _upColor = Color(0xFFef5350); // 涨 = 红
  static const Color _downColor = Color(0xFF26a69a); // 跌 = 绿
  static const Color _gridColor = Color(0xFF1a1a1a);

  /// 每根蜡烛占据的水平像素（实体 + 间隔），固定值。
  /// 蜡烛中心位置 = 索引 × [_candleStep] + [_candleStep]/2，因此从左到右等距排列，
  /// 与数据量无关 —— 少量蜡烛不会被拉散撑满整行。
  static const double _candleStep = 6;

  /// 蜡烛实体宽度（< [_candleStep]，留出间隔），固定值 → 粗细恒定、偏细。
  static const double _bodyWidth = 4;

  /// 右侧价格刻度区宽度（像素）。
  static const double _priceAxisWidth = 46;

  double _rightEdge = 0; // 可见窗口右端的数据索引（浮点，便于平滑拖动）
  bool _followLatest = true; // 是否跟随最新 K线

  /// 类型安全的 clamp（num.clamp 赋给 double 会类型错）。
  double _cl(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  /// 价格格式化：≥100 两位小数，≥1 三位，否则五位（适配不同量级币价）。
  String _fmtPrice(double p) {
    if (p >= 100) return p.toStringAsFixed(2);
    if (p >= 1) return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }

  @override
  void initState() {
    super.initState();
    final n = widget.data.length;
    _rightEdge = n > 0 ? (n - 1).toDouble() : 0;
  }

  @override
  void didUpdateWidget(covariant FlChartKlineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.data.length;
    if (n == 0) return;
    if (_followLatest) {
      _rightEdge = (n - 1).toDouble(); // 跟随最新 → 钉到右端
    } else {
      _rightEdge = _cl(_rightEdge, 0, (n - 1).toDouble()); // 停在历史位置
    }
  }

  /// 水平拖动查看历史。右拖(dx>0) → 右端减小 → 看更早的蜡烛。
  void _onScaleUpdate(ScaleUpdateDetails d, double width) {
    final n = widget.data.length;
    if (n == 0 || width <= 0) return;
    final capacity = (width / _candleStep).floor();
    if (capacity < 1) return;
    final maxEdge = (n - 1).toDouble();
    // 右端最小值：窗口左端贴到数据起点（startIdx=0）时 rightEdge = capacity-1。
    // 数据少于容量时已全部显示，右端就是最后一根。
    final minEdge = n <= capacity ? maxEdge : (capacity - 1).toDouble();
    setState(() {
      if (d.focalPointDelta.dx != 0) {
        final idxPerPx = 1 / _candleStep; // 每像素 = 1/步长 根蜡烛
        _rightEdge = _cl(
            _rightEdge - d.focalPointDelta.dx * idxPerPx, minEdge, maxEdge);
      }
      _followLatest = (_rightEdge >= maxEdge - 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }
    final data = widget.data;
    final n = data.length;
    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (ctx, c) {
          final width = c.maxWidth;
          final chartW = width - _priceAxisWidth; // 蜡烛区宽度（右侧留价格刻度）
          final capacity = (chartW / _candleStep).floor().clamp(1, 1 << 30);
          // 可见窗口 [startIdx, endIdx]（相对全量 data）
          final endIdx = _cl(_rightEdge, 0, (n - 1).toDouble()).round();
          final startIdx = (endIdx - capacity + 1).clamp(0, endIdx < 0 ? 0 : endIdx);
          // X 轴：minX=0，maxX=蜡烛区宽度/步长 → getPixelX(i)=i×步长，固定间距。
          final maxX = (chartW / _candleStep).clamp(1.0, 1e9).toDouble();

          // 收集可见蜡烛 + 成交量 + 价格极值
          double dataMin = double.infinity;
          double dataMax = double.negativeInfinity;
          double maxVol = 0;
          final spots = <CandlestickSpot>[];
          final vols = <double>[];
          final volColors = <Color>[];
          for (var i = startIdx; i <= endIdx; i++) {
            final k = data[i];
            spots.add(CandlestickSpot(
              x: (i - startIdx).toDouble(),
              open: k.open,
              high: k.high,
              low: k.low,
              close: k.close,
            ));
            if (k.low < dataMin) dataMin = k.low;
            if (k.high > dataMax) dataMax = k.high;
            if (k.volume > maxVol) maxVol = k.volume;
            vols.add(k.volume);
            volColors.add(k.close >= k.open ? _downColor : _upColor);
          }

          // Y 范围：跟随可见蜡烛极值，但最小半宽 = 中心价 ±10%。
          // 波动小→撑到 ±10%（1% 涨幅不显高）；波动大→跟随极值（V 型下跌不裁剪）；
          // 以极值中点为基准，仅创新高/低才变，不每根跳。
          final center = (dataMin + dataMax) / 2;
          final dataHalf = (dataMax - dataMin) / 2;
          final minHalf = center.abs() * 0.10;
          final half = dataHalf > minHalf ? dataHalf : minHalf;
          final yMin = center - half;
          final yMax = center + half;

          // 「当前价」= 可见最后一根收盘；涨跌幅相对其前一根（跟随可见窗口）。
          final priceH = c.maxHeight * 0.85;
          final yRange = yMax - yMin;
          final lastClose = data[endIdx].close;
          final prevClose = endIdx >= 1 ? data[endIdx - 1].close : lastClose;
          final isUp = lastClose >= prevClose;
          final priceColor = isUp ? _upColor : _downColor;
          final closeY = priceH * (yMax - lastClose) / yRange;
          // 涨跌幅文字（右上角）
          final changePct =
              prevClose != 0 ? (lastClose - prevClose) / prevClose * 100 : 0.0;
          final changeText =
              '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%';
          // 右侧价格刻度（5 档，均分固定范围 [yMin, yMax]）
          final priceTicks = <Widget>[];
          for (var i = 0; i <= 4; i++) {
            final p = yMin + (yMax - yMin) * i / 4;
            final y = priceH * (yMax - p) / yRange;
            priceTicks.add(Positioned(
              right: 2,
              top: y - 8,
              child: Text(_fmtPrice(p),
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ));
          }

          return GestureDetector(
            onScaleUpdate: (d) => _onScaleUpdate(d, width),
            child: Column(
              children: [
                Expanded(
                  flex: 85,
                  child: Stack(
                    children: [
                      // 蜡烛图：右侧留出 _priceAxisWidth 给价格刻度
                      Padding(
                        padding: const EdgeInsets.only(right: _priceAxisWidth),
                        child: _buildCandlestick(
                            maxX, spots, startIdx, endIdx, yMin, yMax),
                      ),
                      // 最新价水平虚线（仅在蜡烛区）
                      Positioned(
                        top: _cl(closeY, 0, priceH),
                        left: 0,
                        right: _priceAxisWidth,
                        child: CustomPaint(
                          painter: _HDashPainter(color: priceColor),
                          child: const SizedBox(
                              height: 1, width: double.infinity),
                        ),
                      ),
                      // 右侧价格刻度（5 档数字）
                      ...priceTicks,
                      // 当前价标签（虚线右端，醒目底色）
                      Positioned(
                        right: 2,
                        top: _cl(closeY, 0, priceH) - 9,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 1),
                          color: priceColor,
                          child: Text(_fmtPrice(lastClose),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                      // 涨跌幅（蜡烛区右上角）
                      Positioned(
                        right: _priceAxisWidth + 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: priceColor, width: 1),
                          ),
                          child: Text(changeText,
                              style: TextStyle(
                                  color: priceColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 15,
                  child: Padding(
                    padding: const EdgeInsets.only(right: _priceAxisWidth),
                    child: CustomPaint(
                      painter: _VolumePainter(
                        step: _candleStep,
                        barWidth: _bodyWidth,
                        vols: vols,
                        colors: volColors,
                        maxVol: maxVol,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCandlestick(
    double maxX,
    List<CandlestickSpot> spots,
    int startIdx,
    int endIdx,
    double minY,
    double maxY,
  ) {
    if (spots.isEmpty) return const SizedBox();
    final n = widget.data.length;
    final count = endIdx - startIdx + 1;

    // ② 反弹段半透明背景标记：把全量索引转成相对可见窗口的 X。
    final ranges = <VerticalRangeAnnotation>[];
    void addRange(int? absA, int? absB, Color color) {
      if (absA == null || absB == null) return;
      if (absA >= n || absB >= n) return;
      final a = (absA - startIdx).toDouble();
      final b = (absB - startIdx).toDouble();
      if (b < 0 || a > count - 1) return; // 与可见窗口无交集
      ranges.add(VerticalRangeAnnotation(
        x1: _cl(a, 0, (count - 1).toDouble()),
        x2: _cl(b, 0, (count - 1).toDouble()),
        color: color,
      ));
    }
    addRange(widget.dropStartIndex, widget.dropEndIndex,
        _upColor.withValues(alpha: 0.50));
    addRange(widget.dropEndIndex, widget.recoveryEndIndex,
        _downColor.withValues(alpha: 0.50));

    return CandlestickChart(
      CandlestickChartData(
        candlestickSpots: spots,
        candlestickPainter: DefaultCandlestickPainter(
          candlestickStyleProvider: (spot, _) {
            final c = spot.isUp ? _upColor : _downColor;
            return CandlestickStyle(
              lineColor: c,
              lineWidth: 1,
              bodyStrokeColor: c,
              bodyStrokeWidth: 0,
              bodyFillColor: c,
              bodyWidth: _bodyWidth,
              bodyRadius: 0,
            );
          },
        ),
        candlestickTouchData: CandlestickTouchData(enabled: false),
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        backgroundColor: Colors.black,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: _gridColor, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        rangeAnnotations:
            RangeAnnotations(verticalRangeAnnotations: ranges),
      ),
    );
  }
}

/// 水平虚线 painter（最新价标示）。
class _HDashPainter extends CustomPainter {
  final Color color;
  _HDashPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 5.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dash).clamp(0.0, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HDashPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 成交量 painter：固定宽度、从左到右，与蜡烛严格对齐（第 i 根中心在 i×step + step/2）。
class _VolumePainter extends CustomPainter {
  final double step;
  final double barWidth;
  final List<double> vols;
  final List<Color> colors;
  final double maxVol;

  _VolumePainter({
    required this.step,
    required this.barWidth,
    required this.vols,
    required this.colors,
    required this.maxVol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (maxVol <= 0 || vols.isEmpty) return;
    final h = size.height;
    final paint = Paint();
    for (var i = 0; i < vols.length; i++) {
      final cx = i * step + step / 2;
      final barH = (vols[i] / maxVol) * h;
      paint.color = colors[i];
      canvas.drawRect(
        Rect.fromLTWH(cx - barWidth / 2, h - barH, barWidth, barH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VolumePainter old) =>
      old.vols != vols ||
      old.colors != colors ||
      old.maxVol != maxVol ||
      old.step != step;
}
