import 'package:flutter/material.dart';

class AppLayout {
  static const wideBreakpoint = 840.0;
  static const twoPaneBreakpoint = 720.0;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isLandscape(BuildContext context) {
    final size = sizeOf(context);
    return size.width > size.height;
  }

  static bool isWide(BuildContext context) =>
      sizeOf(context).width >= wideBreakpoint;

  static bool useNavigationRail(BuildContext context) {
    final size = sizeOf(context);
    return size.width >= wideBreakpoint || size.width > size.height;
  }

  static bool useTwoPane(BuildContext context) {
    final size = sizeOf(context);
    if (size.height < 560) return false;
    return size.width >= twoPaneBreakpoint;
  }

  static bool isShort(BuildContext context) => sizeOf(context).height < 520;

  static EdgeInsets pagePadding(BuildContext context) {
    final compact = isLandscape(context) || isShort(context);
    return EdgeInsets.fromLTRB(20, compact ? 8 : 12, 20, compact ? 20 : 32);
  }
}
