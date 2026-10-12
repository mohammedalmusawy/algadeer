import 'package:flutter/material.dart';

import '../widgets/app_slot_icon.dart';
import 'app_shell_bridge.dart';
import 'ghadeer_home_colors.dart';

/// شريط التبويبات الرئيسي الوحيد — نفس المظهر في الغلاف وصفحات التفاصيل.
class AppShellBottomNav extends StatelessWidget {
  const AppShellBottomNav({
    super.key,
    this.activeIndex = -1,
    this.onSelect,
    this.wrapSafeArea = true,
  });

  /// `-1` = لا تبويب نشط (صفحة داخلية فوق الغلاف).
  final int activeIndex;

  /// إن وُجد يُستدعى بدل [AppShellBridge.goToTab].
  final ValueChanged<int>? onSelect;

  /// عند الدمج فوق واتساب يُلغى SafeArea الداخلي لتجنّب تداخل الحشوات.
  final bool wrapSafeArea;

  @override
  Widget build(BuildContext context) {
    const teal = GhadeerHomeColors.primary;
    const muted = Color(0xFF8A9A9E);

    Widget item({
      required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      required String navSlot,
    }) {
      final active = activeIndex == index;
      return Expanded(
        child: InkWell(
          key: Key('app_shell_nav_$navSlot'),
          onTap: () {
            if (onSelect != null) {
              onSelect!(index);
            } else {
              AppShellBridge.goToTab(index);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: active
                        ? teal.withValues(alpha: 0.12)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: AppSlotIcon(
                    slotId: 'nav.$navSlot',
                    fallback: active ? activeIcon : icon,
                    size: 22,
                    color: active ? teal : muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? teal : muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final row = Row(
      children: [
        item(
          index: 0,
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'الرئيسية',
          navSlot: 'home',
        ),
        item(
          index: 1,
          icon: Icons.search_rounded,
          activeIcon: Icons.search_rounded,
          label: 'البحث',
          navSlot: 'search',
        ),
        item(
          index: 2,
          icon: Icons.favorite_border_rounded,
          activeIcon: Icons.favorite_rounded,
          label: 'المفضلة',
          navSlot: 'favorites',
        ),
        item(
          index: 3,
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          label: 'حسابي',
          navSlot: 'account',
        ),
      ],
    );

    final bar = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: wrapSafeArea
          ? SafeArea(top: false, child: row)
          : row,
    );
    return bar;
  }
}

/// واتساب فوق شريط الغلاف مع SafeArea ومنع التداخل.
class PackageWhatsAppAboveShell extends StatelessWidget {
  const PackageWhatsAppAboveShell({
    super.key,
    required this.onPressed,
    required this.enabled,
    this.label = 'أرسل تفاصيل الباقة عبر واتساب',
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final String label;

  static const Color green = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  key: const Key('package_whatsapp_above_shell'),
                  onPressed: enabled ? onPressed : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB7DCC4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const AppShellBottomNav(activeIndex: -1, wrapSafeArea: false),
          ],
        ),
      ),
    );
  }
}
