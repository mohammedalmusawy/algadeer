import 'package:flutter/material.dart';

/// هوية الغدير — «الماي الصافي».
///
/// الغدير = ماي هادي جاري. الواجهة هادئة: خلفية ضبابية، حبر فيروزي غامق
/// للنصوص، فيروزي الغدير للأفعال، وحدود رفيعة بدل الظلال الثقيلة.
/// كل الألوان والمسافات تجي من هنا حتى يبقى التطبيق شكل واحد.
abstract final class GhadeerTokens {
  // ── الخط ─────────────────────────────────────────────────
  /// خط الغدير الموحّد على كل الأجهزة (مضاف بـ pubspec.yaml).
  static const fontFamily = 'IBMPlexSansArabic';

  // ── الألوان ────────────────────────────────────────────────
  /// حبر النصوص الرئيسي (تباين عالي على الأبيض والضباب).
  static const ink = Color(0xFF0E2A30);

  /// نص ثانوي — تباين ≥ 4.5:1 على الأبيض.
  static const inkMuted = Color(0xFF55696E);

  /// نص خافت للتلميحات فقط (مو للمعلومة المهمة).
  /// غمّقناه شوية (Phase 5D) حتى يوصل ٤٫٥:١ على الأبيض وينقرا بالشمس.
  static const inkFaint = Color(0xFF66787C);

  /// أقصى تكبير خط نسمح بيه من إعدادات الهاتف.
  static const double maxTextScale = 1.35;

  /// خلفية الصفحات: ضباب ماي هادي.
  static const mist = Color(0xFFF3F7F7);

  /// سطح البطاقات.
  static const surface = Color(0xFFFFFFFF);

  /// حد رفيع للبطاقات والحقول.
  static const line = Color(0xFFE2EBEC);

  /// فيروزي الغدير — الأزرار والأفعال.
  static const teal = Color(0xFF0FAFA3);

  /// فيروزي غامق — نص فيروزي على خلفية فاتحة، وحالة الضغط.
  static const tealDeep = Color(0xFF0A7C74);

  /// صبغة فيروزية خفيفة للخلفيات والشارات.
  static const tealWash = Color(0xFFE3F5F3);

  /// ماي غامق — رأس الرئيسية وغلاف صفحة الطبيب.
  static const deepWater = Color(0xFF0D3B42);

  /// رمل دافي — لمسة دافئة واحدة (بطاقة اسأل الغدير).
  static const sand = Color(0xFFF6EFE3);
  static const sandInk = Color(0xFF6B4E1F);

  /// حالات.
  static const ok = Color(0xFF0B7A55);
  static const okWash = Color(0xFFE2F4EC);
  static const warn = Color(0xFF8A5300);
  static const warnWash = Color(0xFFFDF0DC);
  static const danger = Color(0xFFB3261E);
  static const dangerWash = Color(0xFFFCE8E6);

  /// أخضر الواتساب (بدرجة أهدأ من الأصلي وبتباين جيد مع الأبيض).
  static const whatsapp = Color(0xFF1E9E57);

  // ── الأشكال ────────────────────────────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;

  // ── المسافات ───────────────────────────────────────────────
  static const double gutter = 16;
  static const double gap = 12;

  /// أقل حجم لزر يُلمس (كبار السن).
  static const double touch = 48;

  // ── الكتابة ────────────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: ink,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: ink,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: ink,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: ink,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: ink,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: inkMuted,
  );

  /// حد البطاقة الهادئ.
  static BoxDecoration card({
    Color color = surface,
    double radius = radiusLg,
    Color border = line,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
  );

  /// الثيم العام للتطبيق.
  static ThemeData theme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
          brightness: Brightness.light,
        ).copyWith(
          onPrimary: Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: inkMuted,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: surface,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: const Color(0xFFF1F5F5),
          surfaceContainerHighest: const Color(0xFFE6EDEE),
          primaryContainer: tealWash,
          onPrimaryContainer: tealDeep,
          secondaryContainer: const Color(0xFFEFF4F4),
          outline: const Color(0xFFC9D6D8),
          outlineVariant: line,
          error: danger,
        );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMd),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      canvasColor: mist,
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: mist,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, touch),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, touch),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(64, touch),
          side: const BorderSide(color: line),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tealDeep,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: inkFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: teal, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: teal,
        side: const BorderSide(color: line),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: teal),
    );
  }
}
