import 'package:flutter/material.dart';

class AppLayout {
  static const wideBreakpoint = 840.0;
  static const twoPaneBreakpoint = 720.0;
  static const phoneBreakpoint = 600.0;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isLandscape(BuildContext context) {
    final size = sizeOf(context);
    return size.width > size.height;
  }

  static bool isPhone(BuildContext context) =>
      sizeOf(context).shortestSide < phoneBreakpoint;

  static bool isWide(BuildContext context) =>
      sizeOf(context).width >= wideBreakpoint;

  static bool useNavigationRail(BuildContext context) {
    final size = sizeOf(context);
    return size.width >= wideBreakpoint || size.width > size.height;
  }

  static bool useTwoPane(BuildContext context) {
    final size = sizeOf(context);
    if (isPhone(context) || size.height < 560) return false;
    return size.width >= twoPaneBreakpoint;
  }

  static bool isShort(BuildContext context) => sizeOf(context).height < 520;

  static bool isCompact(BuildContext context) =>
      isLandscape(context) || isShort(context);

  static EdgeInsets pagePadding(BuildContext context) {
    final compact = isCompact(context);
    if (isPhone(context)) {
      return EdgeInsets.fromLTRB(14, compact ? 6 : 8, 14, compact ? 16 : 20);
    }
    return EdgeInsets.fromLTRB(20, compact ? 8 : 12, 20, compact ? 20 : 32);
  }

  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.all(isPhone(context) ? 14 : 20);
  }

  static double cardRadius(BuildContext context) =>
      isPhone(context) ? 16 : 20;

  static double navBarHeight(BuildContext context) {
    if (isPhone(context) || isShort(context)) return 64;
    return 72;
  }

  static double chartHeight(BuildContext context) {
    if (isShort(context)) return 120;
    if (isPhone(context)) return 156;
    if (isLandscape(context)) return 176;
    return 208;
  }

  static double appBarHeight(BuildContext context) =>
      isCompact(context) || isPhone(context) ? 48 : 56;
}
