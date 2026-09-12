import 'dart:math' as math;
import 'dart:ui' show FontFeature, PathMetric;

import 'package:flutter/material.dart';

import '../../models/notice.dart';
import '../layout.dart';
import '../motion.dart';
import '../theme.dart';

class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.months,
    required this.weeks,
    required this.weekly,
    required this.onWeeklyChanged,
  });

  final List<MonthPoint> months;
  final List<WeekPoint> weeks;
  final bool weekly;
  final ValueChanged<bool> onWeeklyChanged;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  _ChartGeometry? _geometry;
  Size? _lastSize;
  Color? _lastLabelColor;
  int _dataStamp = 0;

  List<double> get _expenses => widget.weekly
      ? widget.weeks.map((p) => p.expenses).toList(growable: false)
      : widget.months.map((p) => p.expenses).toList(growable: false);

  List<double> get _gains => widget.weekly
      ? widget.weeks.map((p) => p.gains).toList(growable: false)
      : widget.months.map((p) => p.gains).toList(growable: false);

  List<double> get _net => widget.weekly
      ? widget.weeks.map((p) => p.net).toList(growable: false)
      : widget.months.map((p) => p.net).toList(growable: false);

  List<String> get _labels => widget.weekly
      ? widget.weeks.map((p) => p.label).toList(growable: false)
      : widget.months.map((p) => p.label).toList(growable: false);

  int _stampFor(TrendChart chart) => Object.hashAll([
        chart.weekly,
        ...chart.weekly
            ? chart.weeks.map((p) => Object.hash(p.key, p.expenses, p.gains, p.net))
            : chart.months
                .map((p) => Object.hash(p.month, p.expenses, p.gains, p.net)),
      ]);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.chart);
    _progress = CurvedAnimation(parent: _controller, curve: AppMotion.easeOut);
    _dataStamp = _stampFor(widget);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    _controller.duration = reduce ? Duration.zero : AppMotion.chart;
    if (reduce && _controller.value < 1) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant TrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stamp = _stampFor(widget);
    if (stamp != _dataStamp) {
      _dataStamp = stamp;
      _geometry?.dispose();
      _geometry = null;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _geometry?.dispose();
    _controller.dispose();
    super.dispose();
  }

  _ChartGeometry _geometryFor(Size size, Color labelColor) {
    final cached = _geometry;
    if (cached != null &&
        _lastSize == size &&
        _lastLabelColor == labelColor) {
      return cached;
    }
    cached?.dispose();
    _lastSize = size;
    _lastLabelColor = labelColor;
    _geometry = _ChartGeometry.build(
      size: size,
      expenses: _expenses,
      gains: _gains,
      net: _net,
      labels: _labels,
      labelColor: labelColor,
    );
    return _geometry!;
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.none,
      child: Padding(
        padding: AppLayout.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Išlaidos ir pajamos per laiką',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Mėnesiais')),
                  ButtonSegment(value: true, label: Text('Savaitėmis')),
                ],
                selected: {widget.weekly},
                onSelectionChanged: (value) =>
                    widget.onWeeklyChanged(value.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: AppLayout.chartHeight(context),
              child: labels.isEmpty
                  ? const Center(child: Text('Trūksta duomenų grafikui.'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.biggest;
                        final geometry = _geometryFor(
                          size,
                          scheme.onSurfaceVariant,
                        );
                        return RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _progress,
                            builder: (context, _) {
                              return CustomPaint(
                                size: size,
                                painter: _TrendPainter(
                                  geometry: geometry,
                                  progress: _progress.value,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _ChartLegend(color: AppColors.income, label: 'Įplaukos'),
                _ChartLegend(color: AppColors.expense, label: 'Sąnaudos'),
                _ChartLegend(color: AppColors.net, label: 'Grynasis'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SeriesPaths {
  _SeriesPaths({
    required this.line,
    required this.area,
    required this.fill,
    required this.stroke,
  }) : metric = line.computeMetrics().toList(growable: false);

  final Path line;
  final Path area;
  final Paint fill;
  final Paint stroke;
  final List<PathMetric> metric;
}

class _LabelSlot {
  const _LabelSlot(this.painter, this.offset);
  final TextPainter painter;
  final Offset offset;
}

class _ChartGeometry {
  _ChartGeometry({
    required this.chart,
    required this.gains,
    required this.expenses,
    required this.net,
    required this.netStroke,
    required this.netMetrics,
    required this.xLabels,
    required this.yMax,
    required this.yMaxOffset,
  });

  final Rect chart;
  final _SeriesPaths gains;
  final _SeriesPaths expenses;
  final Path net;
  final Paint netStroke;
  final List<PathMetric> netMetrics;
  final List<_LabelSlot> xLabels;
  final TextPainter yMax;
  final Offset yMaxOffset;

  void dispose() {
    for (final slot in xLabels) {
      slot.painter.dispose();
    }
    yMax.dispose();
  }

  static _ChartGeometry build({
    required Size size,
    required List<double> expenses,
    required List<double> gains,
    required List<double> net,
    required List<String> labels,
    required Color labelColor,
  }) {
    const top = 18.0;
    const right = 8.0;
    const left = 40.0;
    const bottom = 26.0;
    final chart = Rect.fromLTWH(
      left,
      top,
      math.max(8, size.width - left - right),
      math.max(8, size.height - top - bottom),
    );
    final maxValue = [
      ...expenses,
      ...gains,
      ...net.map((v) => v.abs()),
    ].fold<double>(1, (m, v) => v > m ? v : m);

    final gainPaths = _series(chart, gains, maxValue, AppColors.income);
    final expensePaths = _series(chart, expenses, maxValue, AppColors.expense);
    final netLine = _smoothLine(_points(chart, net, maxValue));
    final netMetrics = netLine.computeMetrics().toList(growable: false);
    final netStroke = Paint()
      ..color = AppColors.net
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final textStyle = TextStyle(
      color: labelColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final step = labels.length <= 6 ? 1 : (labels.length / 6).ceil();
    final xLabels = <_LabelSlot>[];
    for (var i = 0; i < labels.length; i += step) {
      final x = labels.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (labels.length - 1);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 72);
      var dx = x - tp.width / 2;
      dx = dx.clamp(0.0, math.max(0.0, size.width - tp.width));
      xLabels.add(_LabelSlot(tp, Offset(dx, chart.bottom + 6)));
    }

    final yMax = TextPainter(
      text: TextSpan(text: _axis(maxValue), style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: left - 4);
    final yMaxOffset = Offset(0, math.max(0, chart.top - 2));

    return _ChartGeometry(
      chart: chart,
      gains: gainPaths,
      expenses: expensePaths,
      net: netLine,
      netStroke: netStroke,
      netMetrics: netMetrics,
      xLabels: xLabels,
      yMax: yMax,
      yMaxOffset: yMaxOffset,
    );
  }

  static String _axis(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return formatEur(value).replaceAll('\u00A0', ' ').split(',').first;
  }

  static List<Offset> _points(Rect chart, List<double> values, double maxValue) {
    if (values.isEmpty) return const [];
    final n = values.length;
    return [
      for (var i = 0; i < n; i++)
        Offset(
          n == 1 ? chart.center.dx : chart.left + chart.width * i / (n - 1),
          chart.bottom -
              chart.height * (values[i] / maxValue).clamp(0.0, 1.0),
        ),
    ];
  }

  static _SeriesPaths _series(
    Rect chart,
    List<double> values,
    double maxValue,
    Color color,
  ) {
    final points = _points(chart, values, maxValue);
    final line = _smoothLine(points);
    final area = Path.from(line);
    if (points.isNotEmpty) {
      area
        ..lineTo(points.last.dx, chart.bottom)
        ..lineTo(points.first.dx, chart.bottom)
        ..close();
    }
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.34),
          color.withValues(alpha: 0.06),
        ],
      ).createShader(chart)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    return _SeriesPaths(line: line, area: area, fill: fill, stroke: stroke);
  }

  static Path _smoothLine(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;
    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.geometry,
    required this.progress,
  });

  final _ChartGeometry geometry;
  final double progress;

  static final _gridPaint = Paint()
    ..color = AppColors.grid
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;

  static final _dotStroke = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = geometry.chart;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), _gridPaint);
    }

    final reveal = Rect.fromLTWH(
      chart.left,
      chart.top - 3,
      chart.width * progress.clamp(0.0, 1.0),
      chart.height + 6,
    );
    canvas.save();
    canvas.clipRect(reveal);
    canvas.drawPath(geometry.gains.area, geometry.gains.fill);
    canvas.drawPath(geometry.gains.line, geometry.gains.stroke);
    canvas.drawPath(geometry.expenses.area, geometry.expenses.fill);
    canvas.drawPath(geometry.expenses.line, geometry.expenses.stroke);
    canvas.drawPath(geometry.net, geometry.netStroke);
    canvas.restore();

    if (progress > 0.04) {
      _dot(canvas, geometry.gains.metric, geometry.gains.stroke.color);
      _dot(canvas, geometry.expenses.metric, geometry.expenses.stroke.color);
      _dot(canvas, geometry.netMetrics, geometry.netStroke.color);
    }

    for (final slot in geometry.xLabels) {
      slot.painter.paint(canvas, slot.offset);
    }
    geometry.yMax.paint(canvas, geometry.yMaxOffset);
  }

  void _dot(Canvas canvas, List<PathMetric> metrics, Color color) {
    final fill = Paint()..color = color;
    for (final metric in metrics) {
      if (metric.length == 0) continue;
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent == null) continue;
      canvas.drawCircle(tangent.position, 3.6, fill);
      canvas.drawCircle(tangent.position, 3.6, _dotStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        !identical(oldDelegate.geometry, geometry);
  }
}
