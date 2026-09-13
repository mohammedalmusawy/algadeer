import 'package:flutter/material.dart';

/// شريط علوي موحّد للتطبيق:
/// - زر الرجوع على **يسار** الشاشة
/// - الإجراءات (تفضيل / مشاركة / غيره) على **اليمين**
/// مع الإبقاء على عنوان عربي باتجاه RTL.
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

    return Directionality(
      textDirection: TextDirection.ltr,
      child: AppBar(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        surfaceTintColor: surfaceTintColor,
        elevation: elevation,
        centerTitle: centerTitle,
        automaticallyImplyLeading: false,
        leading: leading ??
            (showBack
                ? IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.maybePop(context),
                  )
                : null),
        title: Directionality(
          textDirection: TextDirection.rtl,
          child: title,
        ),
        actions: actions,
        bottom: bottom,
      ),
    );
  }
}
