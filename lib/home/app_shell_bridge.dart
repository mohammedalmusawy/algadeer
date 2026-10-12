import 'package:flutter/material.dart';

/// جسر للتنقل من الصفحات الداخلية إلى تبويبات غلاف الرئيسية بدون تكديس HomePage.
class AppShellBridge {
  AppShellBridge._();

  static GlobalKey<NavigatorState>? navigatorKey;
  static void Function(int navIndex)? _selectTab;
  static Future<void> Function({bool voice})? _openSearch;

  static void bindNavigator(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
  }

  static void bindHomeHandlers({
    required void Function(int navIndex) selectTab,
    required Future<void> Function({bool voice}) openSearch,
  }) {
    _selectTab = selectTab;
    _openSearch = openSearch;
  }

  static void unbindHomeHandlers() {
    _selectTab = null;
    _openSearch = null;
  }

  /// يرجع لجذر التطبيق ثم يختار التبويب (أو يفتح البحث).
  static Future<void> goToTab(int navIndex) async {
    final nav = navigatorKey?.currentState;
    if (nav != null) {
      nav.popUntil((route) => route.isFirst);
    }
    if (navIndex == 1) {
      await _openSearch?.call(voice: false);
      return;
    }
    _selectTab?.call(navIndex);
  }
}
