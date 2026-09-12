import 'package:flutter/material.dart';

class AppMotion {
  static const numbers = Duration(milliseconds: 900);
  static const chart = Duration(milliseconds: 1150);
  static const bars = Duration(milliseconds: 780);
  static const progress = Duration(milliseconds: 700);

  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }

  static Curve get easeOut => Curves.easeOutCubic;
}
