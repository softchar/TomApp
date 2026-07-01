import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tomapp/models/kline_data.dart';

/// fl_chart 原生绘制的 K 线图组件。
///
/// 蜡烛**固定粗细**、从左到右**等距**排列；支持单指水平拖动、最新价虚线、
/// 涨跌幅、右侧价格刻度、底部成交量、**MA5/MA10/MA20 均线**、**底部时间轴**。
///
/// [data] 为全量窗口（可拖动查看历史）。
/// [ma5]/[ma10]/[ma20] 为与 [data] 等长的均线序列（null = 该位置周期数据不足）；
///   可选，不传则不画均线（如反弹检测测试页的模拟数据）。
/// [interval] 用于时间轴格式（'1m'/'15m'/'1h'/'4h'/'1d'）；可选。
///
/// 实现要点：fl_chart 把 [minX, maxX] 线性映射到整宽，故令 maxX = 宽度/步长
/// （远大于最后一根索引），getPixelX(i) = i × 步长，蜡烛即固定间距、从左排列。
/// fl_chart 1.2.0 的 CandlestickChartData 未开放 extraLinesData，MA 均线、最新价
/// 虚线、成交量改用 Stack 叠加 CustomPaint 实现（与蜡烛严格对齐）。
class FlChartKlineWidget extends StatefulWidget {
  final List<KlineData> data;
  final int? dropStartIndex;
  final int? dropEndIndex;
  final int? recoveryEndIndex;

  /// MA 均线序列（全量，与 [data] 等长）。null 元素 = 该位置周期数据不足，跳过。
  final List<double?>? ma5;
  final List<double?>? ma10;
  final List<double?>? ma20;

  /// K 线周期，用于时间轴格式。
  final String? interval;

  const FlChartKlineWidget({
    super.key,
    required this.data,
    this.dropStartIndex,
    this.dropEndIndex,
    this.recoveryEndIndex,
    this.ma5,
    this.ma10,
    this.ma20,
    this.interval,
  });

  @override
  State<FlChartKlineWidget> createState() => _FlChartKlineWidgetState();
}

class _FlChartKlineWidgetState extends State<FlChartKlineWidget> {
  static const Color _upColor = Color(0xFFef5350); // 涨 = 红
  static const Color _downColor = Color(0xFF26a69a); // 跌 = 绿
  static const Color _gridColor = Color(0xFF222222); // 横向网格（略加深，可见）

  // 反弹段标记色：用对比色避免与红/绿蜡烛撞色。
  static const Color _dropMarkColor = Color(0xFFAB47BC); // 下跌段 = 紫
  // 回补段沿用 _downColor（绿）—— 回补段以红蜡烛为主，绿标记可分辨。

  /// 每根蜡烛占据的水平像素（实体 + 间隔），固定值。
  /// 蜡烛中心位置 = 索引 × [_candleStep] + [_candleStep]/2，因此从左到右等距排列。
  static const double _candleStep = 8; // 加粗（原 6），大屏显示 ~129 根、实体清晰

  /// 蜡烛实体宽度（< [_candleStep]，留出间隔）。
  static const double _bodyWidth = 6; // 加粗（原 4）

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

  /// 时间轴格式：日级周期显 MM/DD，小时级显 MM/DD HH:MM，分钟级显 HH:MM。
  String _fmtTime(DateTime t) {
    final interval = widget.interval;
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    if (interval == '1d' || interval == '1w') return '$mm/$dd';
    final hh = t.hour.toString().padLeft(2, '0');
    final min = t.minute.toString().padLeft(2, '0');
    if (interval == '1h' || interval == '4h') return '$mm/$dd $hh:$min';
    return '$hh:$min';
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
    final minEdge = n <= capacity ? maxEdge : (capacity - 1).toDouble();
    setState(() {
      if (d.focalPointDelta.dx != 0) {
        const idxPerPx = 1 / _candleStep;
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
          final endIdx = _cl(_rightEdge, 0, (n - 1).toDouble()).round();
          final startIdx = (endIdx - capacity + 1).clamp(0, endIdx < 0 ? 0 : endIdx);
          final maxX = (chartW / _candleStep).clamp(1.0, 1e9).toDouble();

          // 收集可见蜡烛 + 成交量 + 价格极值 + 可见 MA 点
          double dataMin = double.infinity;
          double dataMax = double.negativeInfinity;
          double maxVol = 0;
          final spots = <CandlestickSpot>[];
          final vols = <double>[];
          final volColors = <Color>[];
          final ma5Vis = <FlSpot>[];
          final ma10Vis = <FlSpot>[];
          final ma20Vis = <FlSpot>[];
          for (var i = startIdx; i <= endIdx; i++) {
            final k = data[i];
            final rel = (i - startIdx).toDouble();
            spots.add(CandlestickSpot(
              x: rel,
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
            // MA 点：纳入极值计算，保证均线在 Y 范围内
            final m5 = _maAt(widget.ma5, i);
            final m10 = _maAt(widget.ma10, i);
            final m20 = _maAt(widget.ma20, i);
            if (m5 != null) {
              ma5Vis.add(FlSpot(rel, m5));
              if (m5 < dataMin) dataMin = m5;
              if (m5 > dataMax) dataMax = m5;
            }
            if (m10 != null) {
              ma10Vis.add(FlSpot(rel, m10));
              if (m10 < dataMin) dataMin = m10;
              if (m10 > dataMax) dataMax = m10;
            }
            if (m20 != null) {
              ma20Vis.add(FlSpot(rel, m20));
              if (m20 < dataMin) dataMin = m20;
              if (m20 > dataMax) dataMax = m20;
            }
          }

          // Y 范围：跟随可见蜡烛 + MA 极值，最小半宽 = 中心价 ±8%。
          final center = (dataMin + dataMax) / 2;
          final dataHalf = (dataMax - dataMin) / 2;
          final minHalf = center.abs() * 0.08;
          final half = dataHalf > minHalf ? dataHalf : minHalf;
          final yMin = center - half;
          final yMax = center + half;

          final priceH = c.maxHeight * 0.85;
          final yRange = yMax - yMin;
          final lastClose = data[endIdx].close;
          final prevClose = endIdx >= 1 ? data[endIdx - 1].close : lastClose;
          final isUp = lastClose >= prevClose;
          final priceColor = isUp ? _upColor : _downColor;
          final closeY = priceH * (yMax - lastClose) / yRange;
          final changePct =
              prevClose != 0 ? (lastClose - prevClose) / prevClose * 100 : 0.0;
          final changeText =
              '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(2)}%';

          // 右侧价格刻度（5 档）
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

          // 底部时间轴（4 档）
          final timeLabels = <Widget>[];
          const timePositions = [0.0, 0.34, 0.67, 1.0];
          final maxLeft = chartW > 44 ? chartW - 44 : 0.0;
          for (final p in timePositions) {
            final idx = (startIdx + (endIdx - startIdx) * p)
                .round()
                .clamp(startIdx, endIdx < 0 ? 0 : endIdx);
            final x = chartW * p;
            timeLabels.add(Positioned(
              left: (x - 22).clamp(0.0, maxLeft),
              bottom: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                color: Colors.black54,
                child: Text(_fmtTime(data[idx].time),
                    style: const TextStyle(color: Colors.grey, fontSize: 9)),
              ),
            ));
          }

          final hasMa = widget.ma5 != null ||
              widget.ma10 != null ||
              widget.ma20 != null;

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
                      // MA 均线（叠加在蜡烛上，与蜡烛同 X/Y 坐标）
                      if (hasMa)
                        Positioned(
                          left: 0,
                          top: 0,
                          right: _priceAxisWidth,
                          bottom: 0,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _MaPainter(
                                step: _candleStep,
                                ma5: ma5Vis,
                                ma10: ma10Vis,
                                ma20: ma20Vis,
                                yMin: yMin,
                                yMax: yMax,
                                priceH: priceH,
                              ),
                            ),
                          ),
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
                      // MA 图例（左上角）
                      if (hasMa)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            color: Colors.black54,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MaLegend(
                                    color: Color(0xFFFFC107), label: 'MA5'),
                                SizedBox(width: 6),
                                _MaLegend(
                                    color: Color(0xFFFF9800), label: 'MA10'),
                                SizedBox(width: 6),
                                _MaLegend(
                                    color: Color(0xFF26C6DA), label: 'MA20'),
                              ],
                            ),
                          ),
                        ),
                      // 底部时间轴
                      ...timeLabels,
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

  /// 安全取 MA 序列第 i 个值（越界/空序列返回 null）。
  double? _maAt(List<double?>? ma, int i) {
    if (ma == null || i < 0 || i >= ma.length) return null;
    return ma[i];
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

    // 反弹段半透明背景标记：全量索引 → 相对可见窗口 X。
    // - 三索引齐全：下跌段紫 + 回补段绿（对比色，避免与红绿蜡烛撞色）。
    // - 仅 dropStart + recoveryEnd（dropEnd 缺失，如 backtest 持仓区间）：整段标绿。
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
    if (widget.dropEndIndex != null) {
      addRange(widget.dropStartIndex, widget.dropEndIndex,
          _dropMarkColor.withValues(alpha: 0.35));
      addRange(widget.dropEndIndex, widget.recoveryEndIndex,
          _downColor.withValues(alpha: 0.35));
    } else {
      addRange(widget.dropStartIndex, widget.recoveryEndIndex,
          _downColor.withValues(alpha: 0.35));
    }

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

/// MA 均线图例（小色块 + 标签）。
class _MaLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _MaLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 2),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 9)),
      ],
    );
  }
}

/// MA 均线 painter：在蜡烛区叠加画 MA5/MA10/MA20 折线。
///
/// X = relIndex × step + step/2（与蜡烛中心对齐）；
/// Y = 价格按 [yMin,yMax] 线性映射到 [0, priceH]（与蜡烛同坐标系）。
class _MaPainter extends CustomPainter {
  final double step;
  final List<FlSpot> ma5;
  final List<FlSpot> ma10;
  final List<FlSpot> ma20;
  final double yMin;
  final double yMax;
  final double priceH;

  _MaPainter({
    required this.step,
    required this.ma5,
    required this.ma10,
    required this.ma20,
    required this.yMin,
    required this.yMax,
    required this.priceH,
  });

  void _drawLine(Canvas canvas, List<FlSpot> pts, Color color) {
    if (pts.length < 2) return; // 少于 2 点不画
    final range = yMax - yMin;
    if (range <= 0 || priceH <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = pts[i].x * step + step / 2;
      final y = priceH * (yMax - pts[i].y) / range;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawLine(canvas, ma5, const Color(0xFFFFC107)); // MA5 黄
    _drawLine(canvas, ma10, const Color(0xFFFF9800)); // MA10 橙
    _drawLine(canvas, ma20, const Color(0xFF26C6DA)); // MA20 青
  }

  @override
  bool shouldRepaint(covariant _MaPainter old) =>
      old.ma5 != ma5 ||
      old.ma10 != ma10 ||
      old.ma20 != ma20 ||
      old.yMin != yMin ||
      old.yMax != yMax ||
      old.priceH != priceH ||
      old.step != step;
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
