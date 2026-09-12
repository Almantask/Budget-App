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
  bool _finished = false;

  @override
  void didUpdateWidget(covariant AnimatedEur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = oldWidget.value;
      _finished = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished || MediaQuery.disableAnimationsOf(context)) {
      return _AmountText(
        value: widget.value,
        signed: widget.signed,
        maxLines: widget.maxLines,
        style: widget.style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: AppMotion.of(context, AppMotion.numbers),
      curve: AppMotion.easeOut,
      onEnd: () {
        if (mounted) setState(() => _finished = true);
      },
      builder: (context, value, _) {
        return _AmountText(
          value: value,
          signed: widget.signed,
          maxLines: widget.maxLines,
          style: widget.style,
        );
      },
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({
    required this.value,
    required this.signed,
    required this.maxLines,
    required this.style,
  });

  final double value;
  final bool signed;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = signed ? formatSignedEur(value) : formatEur(value);
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
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
    return Text('${(value * 100).round()}%', style: style);
  }
}
