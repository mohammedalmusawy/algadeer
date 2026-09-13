import 'package:flutter/material.dart';

/// فئات عرض التطبيق للتجاوب (موبايل / تابلت / سطح مكتب).
enum ScreenType { mobile, tablet, desktop }

/// مساعد تجاوب موحّد — لا يغيّر منطق البيانات أو التنقّل.
class AppResponsive {
  AppResponsive._();

  static const double mobileMax = 600;
  static const double tabletMax = 1024;
  static const double desktopContentMax = 1320;
  static const double tabletContentMax = 920;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static ScreenType typeOf(BuildContext context) {
    final w = widthOf(context);
    if (w < mobileMax) return ScreenType.mobile;
    if (w < tabletMax) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  static bool isMobile(BuildContext context) =>
      typeOf(context) == ScreenType.mobile;

  static bool isTablet(BuildContext context) =>
      typeOf(context) == ScreenType.tablet;

  static bool isDesktop(BuildContext context) =>
      typeOf(context) == ScreenType.desktop;

  /// أقصى عرض للمحتوى المركزي (موبايل = بلا حد = عرض الشاشة).
  static double contentMaxWidth(BuildContext context) {
    switch (typeOf(context)) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.tablet:
        return tabletContentMax;
      case ScreenType.desktop:
        return desktopContentMax;
    }
  }

  /// حشو أفقي للصفحات — الموبايل يبقى 16 كما هو.
  /// على الشاشات العريضة يزيد الحشو ليحاكي توسيط المحتوى دون غلاف يكسر الارتفاع.
  static double pagePadding(BuildContext context) {
    final w = widthOf(context);
    switch (typeOf(context)) {
      case ScreenType.mobile:
        return 16;
      case ScreenType.tablet:
        final side = (w - tabletContentMax) / 2;
        return side > 24 ? side : 24;
      case ScreenType.desktop:
        final side = (w - desktopContentMax) / 2;
        return side > 32 ? side : 32;
    }
  }

  /// أعمدة بطاقات الأطباء (بطاقة أفقية — لا تُضيَّق أكثر من اللازم).
  static int doctorColumns(BuildContext context) {
    final w = widthOf(context);
    if (w < mobileMax) return 1;
    if (w < 1100) return 2;
    return 3;
  }

  /// أعمدة بطاقات المختبرات.
  static int labColumns(BuildContext context) {
    final w = widthOf(context);
    if (w < mobileMax) return 1;
    if (w < 1100) return 2;
    return 3;
  }

  /// أعمدة شبكة الاختصاصات.
  static int specialtyColumns(BuildContext context) {
    final w = widthOf(context);
    if (w < mobileMax) return 3;
    if (w < 900) return 4;
    if (w < tabletMax) return 5;
    return 6;
  }

  /// غلاف آمن للصفحات ذات الـ ListView/GridView فقط.
  /// يملأ كامل المساحة ثم يحدّ العرض — لا يستخدم Align الذي قد ينهار الارتفاع.
  static Widget constrainContent({
    required BuildContext context,
    required Widget child,
  }) {
    final maxW = contentMaxWidth(context);
    if (!maxW.isFinite) return child;
    return SizedBox.expand(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}
