import 'package:flutter/material.dart';

class AppMotion {
  static const numbers = Duration(milliseconds: 420);
  static const chart = Duration(milliseconds: 520);
  static const bars = Duration(milliseconds: 360);
  static const progress = Duration(milliseconds: 360);

  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }

  static Curve get easeOut => Curves.easeOutCubic;
}
