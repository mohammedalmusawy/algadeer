import 'package:flutter/material.dart';

/// دخول صاحب البطاقة (طبيب/مختبر/صيدلية/عوينات/تجميل): قفل 🔒 ثابت
/// بالشريط العلوي جنب زر المشاركة في كل البطاقات — مكان واحد يُشرح لكل
/// أصحاب البطاقات. يفتح نفس بوابة كلمة المرور؛ النقر المتعدد على الاسم باقٍ.
abstract final class OwnerAccess {
  static const tooltip = 'لصاحب البطاقة: تعديل المعلومات';
  static const key = Key('owner-access-lock');
  static const icon = Icons.lock_outline_rounded;

  /// باهت وصغير عمداً: المريض لا ينتبه له، وصاحب البطاقة يعرف مكانه.
  static const color = Color(0x59607D8B);
  static const size = 16.0;

  /// قفل خفيف بلا دائرة ولا ظل، بمساحة لمس 38 حتى يبقى سهل الضغط.
  static Widget faint({required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        key: key,
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: size, color: color),
          ),
        ),
      ),
    );
  }
}
