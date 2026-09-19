import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/user_profile_service.dart';
import '../voice/startup_greeting.dart';

/// شريط ترحيب شخصي خفيف أعلى الرئيسية.
class HomeWelcomeBanner extends StatefulWidget {
  const HomeWelcomeBanner({
    super.key,
    this.onAskHelp,
  });

  final VoidCallback? onAskHelp;

  @override
  State<HomeWelcomeBanner> createState() => _HomeWelcomeBannerState();
}

class _HomeWelcomeBannerState extends State<HomeWelcomeBanner> {
  static const _dismissDayKey = 'home_welcome_dismiss_day';

  String? _name;
  bool _ready = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = UserProfileService();
    final name = await profile.getDisplayName();
    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    final dismissed = prefs.getString(_dismissDayKey) == today;
    if (!mounted) return;
    setState(() {
      _name = name;
      _hidden = dismissed;
      _ready = true;
    });
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _dismissForToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissDayKey, _dayKey(DateTime.now()));
    if (!mounted) return;
    setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _hidden) return const SizedBox.shrink();

    // نفس مصدر الاسم + نفس نموذج الترحيب المستخدم للنطق.
    final greeting = PersonalizedGreeting.fromDisplayName(_name);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: const Color(0xFFE8F7F5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onAskHelp,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: Color(0xFF0FAFA3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting.displayGreeting,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF123B42),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        greeting.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5B6C70),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إخفاء اليوم',
                  onPressed: _dismissForToday,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: const Color(0xFF5B6C70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
