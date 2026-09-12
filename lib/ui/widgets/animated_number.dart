import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

class AnimatedEur extends StatefulWidget {
  const AnimatedEur({
    super.key,
    required this.value,
    this.style,
    this.signed = false,
    this.maxLines = 1,
  });

  final double value;
  final TextStyle? style;
  final bool signed;
  final int maxLines;

  @override
  State<AnimatedEur> createState() => _AnimatedEurState();
}

class _AnimatedEurState extends State<AnimatedEur> {
  double _from = 0;

  @override
  void didUpdateWidget(covariant AnimatedEur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = oldWidget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: AppMotion.of(context, AppMotion.numbers),
      curve: AppMotion.easeOut,
      builder: (context, value, _) {
        final text = widget.signed ? formatSignedEur(value) : formatEur(value);
        return Text(
          text,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      },
    );
  }
}

class AnimatedPercent extends StatelessWidget {
  const AnimatedPercent({
    super.key,
    required this.value,
    this.style,
  });

  final double value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppMotion.of(context, AppMotion.numbers),
      curve: AppMotion.easeOut,
      builder: (context, value, _) {
        return Text('${(value * 100).round()}%', style: style);
      },
    );
  }
}
