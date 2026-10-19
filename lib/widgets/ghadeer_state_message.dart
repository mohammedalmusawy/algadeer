import 'package:flutter/material.dart';

import '../theme/ghadeer_tokens.dart';

/// رسالة حالة موحّدة (Phase 5D): فراغ، خطأ، أو انقطاع نت.
///
/// أيقونة هادية + عنوان يگول شنو صار + سطر يگول شنو تسوي + زر يحلها.
/// الرسالة تنطي اتجاه، مو اعتذار — وما بيها أي كلام تقني (جداول/SQL).
class GhadeerStateMessage extends StatelessWidget {
  const GhadeerStateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.titleKey,
  });

  /// رسالة فشل التحميل — تميّز انقطاع النت عن غيره.
  factory GhadeerStateMessage.loadError({
    Key? key,
    required Object? error,
    required String what,
    required VoidCallback onRetry,
  }) {
    final offline = isOfflineError(error);
    return GhadeerStateMessage(
      key: key,
      icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
      title: offline ? 'ماكو اتصال بالإنترنت' : 'ما گدرنا نحمّل $what',
      body: offline
          ? 'تأكد من الواي فاي أو بيانات الهاتف وجرّب مرة ثانية.'
          : 'صار خلل بالاتصال بالخادم. جرّب مرة ثانية بعد شوية.',
      actionLabel: 'حاول مرة ثانية',
      onAction: onRetry,
    );
  }

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? titleKey;

  /// أخطاء الشبكة الشائعة (موبايل + ويب) بدون استيراد dart:io.
  static bool isOfflineError(Object? error) {
    if (error == null) return false;
    final s = error.toString();
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable') ||
        s.contains('Connection refused') ||
        s.contains('Connection closed') ||
        s.contains('ClientException') ||
        s.contains('XMLHttpRequest');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // قابل للسحب: إذا انحط داخل RefreshIndicator يبقى السحب يشتغل.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 0,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: GhadeerTokens.tealWash,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          icon,
                          size: 30,
                          color: GhadeerTokens.tealDeep,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        key: titleKey,
                        textAlign: TextAlign.center,
                        style: GhadeerTokens.heading,
                      ),
                      if (body != null && body!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body!,
                          textAlign: TextAlign.center,
                          style: GhadeerTokens.caption.copyWith(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: onAction,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: Text(actionLabel!),
                          style: FilledButton.styleFrom(
                            backgroundColor: GhadeerTokens.tealDeep,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(160, GhadeerTokens.touch),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                GhadeerTokens.radiusMd,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
