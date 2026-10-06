import 'dart:async';

import 'package:flutter/material.dart';

/// عدّاد النقرات المتتالية. الفتح العادي يتأخر حتى تنتهي النافذة،
/// والنقرة الثالثة تلغي الفتح وتطلب كلمة المرور.
class RapidTapMachine {
  RapidTapMachine({
    this.requiredTaps = 3,
    this.window = const Duration(milliseconds: 450),
  });

  final int requiredTaps;
  final Duration window;
  int _count = 0;
  DateTime? _last;

  static const openDelay = Duration(milliseconds: 450);

  /// `true` عندما يكتمل العدد المطلوب داخل النافذة.
  bool register(DateTime now) {
    if (_last == null || now.difference(_last!) > window) {
      _count = 1;
    } else {
      _count += 1;
    }
    _last = now;
    if (_count >= requiredTaps) {
      _count = 0;
      _last = null;
      return true;
    }
    return false;
  }
}

/// سطح فتح البطاقة: نقرة واحدة تفتح الملف، وثلاث نقرات تفتح الدخول.
/// التمرير وأزرار الطفل (مثل المفضلة) تبقى على سلوكها.
class DoctorCardOpenSurface extends StatefulWidget {
  const DoctorCardOpenSurface({
    super.key,
    required this.onOpen,
    required this.onTripleTap,
    required this.borderRadius,
    required this.child,
    this.tapCount = 3,
  });

  final VoidCallback onOpen;
  final VoidCallback onTripleTap;
  final BorderRadius borderRadius;
  final Widget child;
  final int tapCount;

  @override
  State<DoctorCardOpenSurface> createState() => _DoctorCardOpenSurfaceState();
}

class _DoctorCardOpenSurfaceState extends State<DoctorCardOpenSurface> {
  late final _taps = RapidTapMachine(requiredTaps: widget.tapCount);
  Timer? _openTimer;

  @override
  void dispose() {
    _openTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    final triple = _taps.register(DateTime.now());
    _openTimer?.cancel();
    if (triple) {
      widget.onTripleTap();
      return;
    }
    _openTimer = Timer(RapidTapMachine.openDelay, () {
      if (!mounted) return;
      widget.onOpen();
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      borderRadius: widget.borderRadius,
      child: widget.child,
    );
  }
}

/// ثلاث نقرات على عنصر لا يفتح شيئًا بنقرة واحدة (اسم الطبيب داخل البطاقة).
class DoctorCardTripleTap extends StatefulWidget {
  const DoctorCardTripleTap({
    super.key,
    required this.onTripleTap,
    required this.child,
    this.tapCount = 3,
  });

  final VoidCallback onTripleTap;
  final Widget child;
  final int tapCount;

  @override
  State<DoctorCardTripleTap> createState() => _DoctorCardTripleTapState();
}

class _DoctorCardTripleTapState extends State<DoctorCardTripleTap> {
  late final _taps = RapidTapMachine(requiredTaps: widget.tapCount);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_taps.register(DateTime.now())) widget.onTripleTap();
      },
      child: widget.child,
    );
  }
}
