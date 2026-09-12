import 'package:flutter/material.dart';

import '../../models/notice.dart';
import '../theme.dart';

class TrendChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final expenses = weekly
        ? weeks.map((p) => p.expenses).toList()
        : months.map((p) => p.expenses).toList();
    final gains = weekly
        ? weeks.map((p) => p.gains).toList()
        : months.map((p) => p.gains).toList();
    final net = weekly
        ? weeks.map((p) => p.net).toList()
        : months.map((p) => p.net).toList();
    final labels = weekly
        ? weeks.map((p) => p.label).toList()
        : months.map((p) => p.label).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Išlaidos ir pajamos per laiką',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Mėnesiais')),
                ButtonSegment(value: true, label: Text('Savaitėmis')),
              ],
              selected: {weekly},
              onSelectionChanged: (value) => onWeeklyChanged(value.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: labels.isEmpty
                  ? const Center(child: Text('Trūksta duomenų grafikui.'))
                  : CustomPaint(
                      painter: _TrendPainter(
                        expenses: expenses,
                        gains: gains,
                        net: net,
                        labels: labels,
                        labelColor:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _ChartLegend(color: Color(0xFF1B7F5A), label: 'Įplaukos'),
                _ChartLegend(color: Color(0xFFC9783A), label: 'Sąnaudos'),
                _ChartLegend(color: Color(0xFFC9A227), label: 'Grynasis'),
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

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.expenses,
    required this.gains,
    required this.net,
    required this.labels,
    required this.labelColor,
  });

  final List<double> expenses;
  final List<double> gains;
  final List<double> net;
  final List<String> labels;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;
    const left = 36.0;
    const bottom = 22.0;
    final chart = Rect.fromLTWH(
      left,
      8,
      size.width - left - 8,
      size.height - bottom - 8,
    );
    final maxValue = [
      ...expenses,
      ...gains,
      ...net.map((v) => v.abs()),
    ].fold<double>(1, (m, v) => v > m ? v : m);

    final grid = Paint()
      ..color = const Color(0xFFE8E2D6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
    }

    _area(canvas, chart, gains, maxValue, const Color(0xFF1B7F5A));
    _area(canvas, chart, expenses, maxValue, const Color(0xFFC9783A));
    _line(canvas, chart, net, maxValue, const Color(0xFFC9A227));

    final textStyle = TextStyle(color: labelColor, fontSize: 10);
    final step = labels.length <= 6 ? 1 : (labels.length / 6).ceil();
    for (var i = 0; i < labels.length; i += step) {
      final x = labels.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (labels.length - 1);
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 64);
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 4));
    }

    final maxLabel = TextPainter(
      text: TextSpan(text: _axis(maxValue), style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    maxLabel.paint(canvas, Offset(0, chart.top - 2));
  }

  String _axis(double value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return formatEur(value).replaceAll('\u00A0', ' ').split(',').first;
  }

  void _area(
    Canvas canvas,
    Rect chart,
    List<double> values,
    double maxValue,
    Color color,
  ) {
    if (values.isEmpty) return;
    final path = Path();
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final offset = _point(chart, i, values.length, values[i], maxValue);
      if (i == 0) {
        path.moveTo(offset.dx, chart.bottom);
        path.lineTo(offset.dx, offset.dy);
        line.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
        line.lineTo(offset.dx, offset.dy);
      }
    }
    path.lineTo(
      _point(chart, values.length - 1, values.length, 0, maxValue).dx,
      chart.bottom,
    );
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _line(
    Canvas canvas,
    Rect chart,
    List<double> values,
    double maxValue,
    Color color,
  ) {
    if (values.isEmpty) return;
    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final offset = _point(chart, i, values.length, values[i], maxValue);
      if (i == 0) {
        line.moveTo(offset.dx, offset.dy);
      } else {
        line.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  Offset _point(Rect chart, int i, int n, double value, double maxValue) {
    final t = n == 1 ? 0.5 : i / (n - 1);
    final x = chart.left + chart.width * t;
    final y = chart.bottom - chart.height * (value / maxValue).clamp(0.0, 1.0);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.expenses != expenses ||
        oldDelegate.gains != gains ||
        oldDelegate.net != net ||
        oldDelegate.labels != labels;
  }
}
