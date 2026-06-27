import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tomapp/models/kline_data.dart';

/// TradingView 专业 K 线图组件。
///
/// 使用 TradingView Lightweight Charts 库渲染蜡烛图 + 成交量 + 下跌/回拉段高亮标注。
/// 支持缩放拖拽、专业金融图表样式。
class TradingViewKlineWidget extends StatefulWidget {
  /// 要展示的 K 线数据。
  final List<KlineData> data;

  /// 下跌段起始索引（相对于 data），用于红色高亮。
  final int? dropStartIndex;

  /// 下跌段结束索引（swing low 位置）。
  final int? dropEndIndex;

  /// 回拉段结束索引。
  final int? recoveryEndIndex;

  const TradingViewKlineWidget({
    super.key,
    required this.data,
    this.dropStartIndex,
    this.dropEndIndex,
    this.recoveryEndIndex,
  });

  @override
  State<TradingViewKlineWidget> createState() => _TradingViewKlineWidgetState();
}

class _TradingViewKlineWidgetState extends State<TradingViewKlineWidget> {
  late final WebViewController _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoaded = true;
            });
            _updateChart();
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  @override
  void didUpdateWidget(TradingViewKlineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isLoaded &&
        (oldWidget.data != widget.data ||
            oldWidget.dropStartIndex != widget.dropStartIndex ||
            oldWidget.dropEndIndex != widget.dropEndIndex ||
            oldWidget.recoveryEndIndex != widget.recoveryEndIndex)) {
      _updateChart();
    }
  }

  void _updateChart() {
    final jsonData = _buildChartData();
    _controller.runJavaScript('updateChart($jsonData)');
  }

  String _buildChartData() {
    // 准备蜡烛数据
    final candles = widget.data
        .map((k) => {
              'time': k.time.millisecondsSinceEpoch ~/ 1000,
              'open': k.open,
              'high': k.high,
              'low': k.low,
              'close': k.close,
            })
        .toList();

    // 准备成交量数据
    final volumes = widget.data
        .asMap()
        .entries
        .map((e) => {
              'time': e.value.time.millisecondsSinceEpoch ~/ 1000,
              'value': e.value.volume,
              'color': e.value.close >= e.value.open
                  ? 'rgba(38, 166, 154, 0.5)'
                  : 'rgba(239, 83, 80, 0.5)',
            })
        .toList();

    // 准备高亮标记
    Map<String, dynamic>? markers;
    if (widget.dropStartIndex != null &&
        widget.dropEndIndex != null &&
        widget.recoveryEndIndex != null) {
      final dropStart = widget.data[widget.dropStartIndex!];
      final dropEnd = widget.data[widget.dropEndIndex!];
      final recoveryEnd = widget.data[widget.recoveryEndIndex!];

      markers = {
        'dropStartTime': dropStart.time.millisecondsSinceEpoch ~/ 1000,
        'dropEndTime': dropEnd.time.millisecondsSinceEpoch ~/ 1000,
        'recoveryEndTime': recoveryEnd.time.millisecondsSinceEpoch ~/ 1000,
      };
    }

    return jsonEncode({
      'candles': candles,
      'volumes': volumes,
      'markers': markers,
    });
  }

  String _buildHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background-color: #000000; overflow: hidden; }
    #chart-container { width: 100%; height: 100vh; }
  </style>
</head>
<body>
  <div id="chart-container"></div>
  <script src="https://unpkg.com/lightweight-charts@4.1.3/dist/lightweight-charts.standalone.production.js"></script>
  <script>
    let chart;
    let candleSeries;
    let volumeSeries;
    let markers = [];

    function initChart() {
      const container = document.getElementById('chart-container');
      chart = LightweightCharts.createChart(container, {
        width: container.clientWidth,
        height: container.clientHeight,
        layout: {
          background: { type: 'solid', color: '#000000' },
          textColor: '#999999',
          padding: { left: 0, right: 0, top: 0, bottom: 0 },
        },
        grid: {
          vertLines: { color: '#1a1a1a' },
          horzLines: { color: '#1a1a1a' },
        },
        crosshair: {
          mode: LightweightCharts.CrosshairMode.Normal,
          vertLine: {
            color: '#555555',
            width: 1,
            style: LightweightCharts.LineStyle.Dashed,
            labelBackgroundColor: '#333333',
          },
          horzLine: {
            color: '#555555',
            width: 1,
            style: LightweightCharts.LineStyle.Dashed,
            labelBackgroundColor: '#333333',
          },
        },
        rightPriceScale: {
          borderColor: '#333333',
          scaleMargins: { top: 0.05, bottom: 0.15 },
        },
        timeScale: {
          borderColor: '#333333',
          timeVisible: true,
          secondsVisible: false,
          barSpacing: 6,
          minBarSpacing: 6,
          lockVisibleTimeRangeOnResize: false,
          shiftVisibleRangeOnNewBar: true,
        },
        localization: {
          locale: 'zh-CN',
          timeFormatter: (time) => {
            const d = new Date(time * 1000);
            const mm = String(d.getMonth() + 1).padStart(2, '0');
            const dd = String(d.getDate()).padStart(2, '0');
            const hh = String(d.getHours()).padStart(2, '0');
            const min = String(d.getMinutes()).padStart(2, '0');
            return `\${mm}-\${dd} \${hh}:\${min}`;
          },
          priceFormatter: (price) => {
            return price.toLocaleString('zh-CN', {
              minimumFractionDigits: 2,
              maximumFractionDigits: 2,
            });
          },
        },
      });

      // 蜡烛图系列
      candleSeries = chart.addCandlestickSeries({
        upColor: '#ef5350',
        downColor: '#26a69a',
        borderUpColor: '#ef5350',
        borderDownColor: '#26a69a',
        wickUpColor: '#ef5350',
        wickDownColor: '#26a69a',
      });

      // 成交量系列
      volumeSeries = chart.addHistogramSeries({
        color: '#26a69a',
        priceFormat: { type: 'volume' },
        priceScaleId: 'volume',
      });

      chart.priceScale('volume').applyOptions({
        scaleMargins: { top: 0.85, bottom: 0 },
      });

      // 响应窗口大小变化
      window.addEventListener('resize', () => {
        chart.applyOptions({
          width: container.clientWidth,
          height: container.clientHeight,
        });
      });
    }

    function updateChart(data) {
      if (!chart) {
        initChart();
      }

      // 更新蜡烛数据
      candleSeries.setData(data.candles);

      // 更新成交量数据
      volumeSeries.setData(data.volumes);

      // 清除旧标记
      markers.forEach(m => m.remove());
      markers = [];

      // 添加高亮区域
      if (data.markers) {
        addHighlightAreas(data.markers);
      }

      // 设置固定的蜡烛宽度
      chart.timeScale().applyOptions({
        barSpacing: 6,
      });

      // 滚动到最新数据
      chart.timeScale().scrollToRealTime();
    }

    function addHighlightAreas(markerData) {
      // 下跌段高亮（红色半透明）
      const dropArea = candleSeries.createPriceLine({
        price: 0,
        color: 'transparent',
        lineWidth: 0,
        lineStyle: LightweightCharts.LineStyle.Solid,
        axisLabelVisible: false,
        title: '',
      });
      markers.push(dropArea);

      // 使用标记点来高亮区域
      const dropMarker = {
        time: markerData.dropStartTime,
        position: 'aboveBar',
        color: '#ef5350',
        shape: 'circle',
        text: 'D',
      };

      const lowMarker = {
        time: markerData.dropEndTime,
        position: 'belowBar',
        color: '#ef5350',
        shape: 'arrowUp',
        text: 'L',
      };

      const recoveryMarker = {
        time: markerData.recoveryEndTime,
        position: 'aboveBar',
        color: '#26a69a',
        shape: 'circle',
        text: 'R',
      };

      candleSeries.setMarkers([dropMarker, lowMarker, recoveryMarker]);
    }

    // 初始化
    initChart();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_isLoaded)
          const Center(
            child: CircularProgressIndicator(color: Colors.grey),
          ),
      ],
    );
  }
}
