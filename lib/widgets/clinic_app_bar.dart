import 'package:flutter/material.dart';

import 'entity_contact_actions.dart';

/// شريط علوي موحّد للتطبيق:
/// - زر الرجوع أعلى **اليمين** في الواجهة العربية (RTL)
/// - الإجراءات (تفضيل / مشاركة / غيره) على اليسار
/// - لا يظهر الرجوع إن لم يكن هناك صفحة للرجوع إليها (مثل تبويبات الشريط السفلي)
class ClinicAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClinicAppBar({
    super.key,
    required this.title,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor,
    this.elevation,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.bottom,
  });

  final Widget title;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final bottomH = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + bottomH);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBack = automaticallyImplyLeading && canPop && leading == null;

    // RTL: leading على اليمين = زر الرجوع أعلى اليمين.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        surfaceTintColor: surfaceTintColor,
        elevation: elevation,
        centerTitle: centerTitle,
        automaticallyImplyLeading: false,
        leading:
            leading ??
            (showBack
                ? const Center(
                    child: GhadeerBackButton(key: Key('clinic_app_bar_back')),
                  )
                : null),
        title: title,
        actions: actions,
        bottom: bottom,
      ),
    );
  }
}
