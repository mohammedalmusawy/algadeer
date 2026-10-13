import 'package:flutter/material.dart';

import '../doctors/doctor_card_tap.dart';

/// دخول صاحب البطاقة (طبيب/مختبر/صيدلية/عوينات/تجميل): قفل 🔒 ثابت
/// بالشريط العلوي جنب زر المشاركة في كل البطاقات — مكان واحد يُشرح لكل
/// أصحاب البطاقات. يفتح نفس بوابة كلمة المرور؛ النقر المتعدد على الاسم باقٍ.
/// يحتاج ثلاث نقرات متتالية حتى لا يفتحه المريض بالغلط.
abstract final class OwnerAccess {
  static const tooltip = 'لصاحب البطاقة: تعديل المعلومات';
  static const key = Key('owner-access-lock');
  static const icon = Icons.lock_outline_rounded;

  /// باهت وصغير عمداً: المريض لا ينتبه له، وصاحب البطاقة يعرف مكانه.
  static const color = Color(0x59607D8B);
  static const size = 16.0;

  /// عدد النقرات المطلوبة على القفل.
  static const requiredTaps = 3;

  /// مهلة بين النقرة والثانية (أوسع من نقر الاسم لأن القفل صغير).
  static const tapWindow = Duration(milliseconds: 700);

  /// قفل خفيف بلا دائرة ولا ظل، بمساحة لمس 38 حتى يبقى سهل الضغط.
  static Widget faint({required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: _TripleTapLock(key: key, onTripleTap: onTap),
    );
  }
}

class _TripleTapLock extends StatefulWidget {
  const _TripleTapLock({super.key, required this.onTripleTap});

  final VoidCallback onTripleTap;

  @override
  State<_TripleTapLock> createState() => _TripleTapLockState();
}

class _TripleTapLockState extends State<_TripleTapLock> {
  final _taps = RapidTapMachine(
    requiredTaps: OwnerAccess.requiredTaps,
    window: OwnerAccess.tapWindow,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: const CircleBorder(),
        // بلا وميض: النقرة الوحدة ما تبيّن إن هنا شي.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: () {
          if (_taps.register(DateTime.now())) widget.onTripleTap();
        },
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(
            OwnerAccess.icon,
            size: OwnerAccess.size,
            color: OwnerAccess.color,
          ),
        ),
      ),
    );
  }
}
