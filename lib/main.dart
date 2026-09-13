import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'branding/ghadeer_brand_mark.dart';
import 'ads/admin/ads_admin_page.dart';
import 'ads/widgets/home_ad_slot.dart';
import 'core/app_config.dart';
import 'doctors/all_specialties_page.dart';
import 'doctors/app_stats_admin_page.dart';
import 'doctors/clinic_doctor_list_card.dart';
import 'doctors/doctor_absences_admin_page.dart';
import 'doctors/doctor_availability_service.dart';
import 'doctors/doctor_card_links.dart';
import 'doctors/doctor_image_bg_remover.dart';
import 'doctors/doctor_profile_page.dart';
import 'doctors/notifications_admin_page.dart';
import 'doctors/notifications_inbox_page.dart';
import 'doctors/specialty_catalog.dart';
import 'labs/admin/labs_admin_hub.dart';
import 'labs/labs_page.dart';
import 'models/doctor_item.dart';
import 'radiology/admin/radiology_admin_page.dart';
import 'radiology/radiology_page.dart';
import 'services/app_stats_service.dart';
import 'services/admin_launch_session.dart';
import 'services/admin_password_change_page.dart';
import 'services/dynamic_message_admin_page.dart';
import 'services/dynamic_message_service.dart';
import 'utils/responsive.dart';
import 'utils/dom_input_value.dart'
    if (dart.library.html) 'utils/dom_input_value_web.dart' as dom_input;
import 'widgets/clinic_app_bar.dart';
import 'widgets/dynamic_highlight_card.dart';
import 'search/smart_search_page.dart';
import 'voice/assistant_integration_page.dart';
import 'voice/voice_settings_page.dart';
import 'settings/settings_page.dart';
import 'onboarding/app_entry_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(const GhadeerClinicApp());
}

class GhadeerClinicApp extends StatefulWidget {
  const GhadeerClinicApp({super.key});

  @override
  State<GhadeerClinicApp> createState() => _GhadeerClinicAppState();
}

class _GhadeerClinicAppState extends State<GhadeerClinicApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        final nav = _navKey.currentState;
        if (nav == null) return;
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AdminPasswordChangePage(recoveryMode: true),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0FAFA3);

    return MaterialApp(
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      title: 'عيادة الغدير',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAFA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
        ),
      ),
      home: const AppEntryGate(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomePage(),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _logoTapCount = 0;
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> doctors = [];
  bool isLoadingDoctors = true;
  String? doctorsError;
  final Set<String> favoriteDoctorIds = <String>{};
  RealtimeChannel? _doctorsChannel;

  final _messageService = DynamicMessageService();
  DynamicMessage? _todayMessage;
  bool _todayMessageLoading = true;
  Timer? _doctorsReloadDebounce;
  String? _specialtyFilter; // null = الكل
  int _bottomNavIndex = 0;
  String _mainCategory = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();

    loadDoctors();
    _loadTodayMessage();
    _initDeepLinks();
    // تسجيل مستخدم التطبيق للإحصائية العامة (صامت عند غياب الجدول).
    AppStatsService().touchCurrentUser();

    _doctorsChannel = supabase
        .channel('doctors-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'doctors',
          callback: (payload) {
            _doctorsReloadDebounce?.cancel();
            _doctorsReloadDebounce = Timer(
              const Duration(milliseconds: 450),
              () {
                if (mounted) loadDoctors();
              },
            );
          },
        )
        .subscribe();
  }

  Future<void> _loadTodayMessage() async {
    try {
      final message = await _messageService.fetchHomeMessage(
        useEmergencyFallback: false,
      );
      if (!mounted) return;
      setState(() {
        _todayMessage = message;
        _todayMessageLoading = false;
      });
    } catch (e) {
      debugPrint('today message load failed: $e');
      if (!mounted) return;
      setState(() {
        _todayMessage = null;
        _todayMessageLoading = false;
      });
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      if (kIsWeb) {
        final id = DoctorCardLinks.parseDoctorId(Uri.base);
        if (id != null && id.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openDoctorById(id, fromDeepLink: true);
          });
        }
        return;
      }

      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        final id = DoctorCardLinks.parseDoctorId(initial);
        if (id != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _openDoctorById(id, fromDeepLink: true);
          });
        }
      }
      appLinks.uriLinkStream.listen((uri) {
        final id = DoctorCardLinks.parseDoctorId(uri);
        if (id != null) _openDoctorById(id, fromDeepLink: true);
      });
    } catch (e) {
      debugPrint('deep link init failed: $e');
    }
  }

  Future<void> _openDoctorById(String id, {bool fromDeepLink = false}) async {
    if (!mounted || id.isEmpty) return;

    Map<String, dynamic>? row;
    for (final d in doctors) {
      if (d['id']?.toString() == id) {
        row = d;
        break;
      }
    }

    if (row == null) {
      try {
        row = await supabase
            .from('doctors')
            .select()
            .eq('id', id)
            .maybeSingle();
      } catch (_) {
        row = null;
      }
    }

    if (!mounted || row == null) {
      if (fromDeepLink && mounted) {
        DoctorCardLinks.openInstallSuggestion(context);
      }
      return;
    }

    _showDoctorProfile(DoctorItem.fromMap(row), fromDeepLink: fromDeepLink);
  }

  @override
  void dispose() {
    _doctorsReloadDebounce?.cancel();
    if (_doctorsChannel != null) {
      supabase.removeChannel(_doctorsChannel!);
    }
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList('favoriteDoctorIds') ?? [];

    if (!mounted) return;

    setState(() {
      favoriteDoctorIds
        ..clear()
        ..addAll(savedIds);
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteDoctorIds', favoriteDoctorIds.toList());
  }

  void _toggleFavorite(String doctorId) {
    setState(() {
      if (favoriteDoctorIds.contains(doctorId)) {
        favoriteDoctorIds.remove(doctorId);
      } else {
        favoriteDoctorIds.add(doctorId);
      }
    });
    _saveFavorites();
  }

  Future<void> loadDoctors() async {
    try {
      debugPrint('loadDoctors: fetching from Supabase...');
      // فلترة على السيرفر: نشط أو null (للتوافق مع صفوف قديمة)
      // الترتيب حسب المشاهدات يتم محليًا حتى لا يفشل الطلب إن غاب العمود.
      List<dynamic> data;
      try {
        data = await supabase
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .order('display_order', ascending: true);
      } catch (e) {
        debugPrint('loadDoctors primary query failed, retry plain: $e');
        data = await supabase.from('doctors').select();
      }

      if (!mounted) return;

      final rows = List<Map<String, dynamic>>.from(data)
        ..sort((a, b) {
          final av = int.tryParse('${a['profile_views'] ?? 0}') ?? 0;
          final bv = int.tryParse('${b['profile_views'] ?? 0}') ?? 0;
          if (av != bv) return bv.compareTo(av);
          final ao = int.tryParse('${a['display_order'] ?? 0}') ?? 0;
          final bo = int.tryParse('${b['display_order'] ?? 0}') ?? 0;
          return ao.compareTo(bo);
        });

      setState(() {
        doctors = rows;
        isLoadingDoctors = false;
        doctorsError = null;
        // لا نترك فلتر اختصاص عالقًا يخفي القائمة بالكامل.
        if (_specialtyFilter != null && rows.isNotEmpty) {
          final matched = _filteredDoctorItems();
          if (matched.isEmpty) {
            _specialtyFilter = null;
          }
        }
      });

      debugPrint(
        'loadDoctors: fetched=${rows.length} '
        'afterFilter=${_filteredDoctorItems().length} '
        'specialtyFilter=$_specialtyFilter',
      );
    } catch (e, st) {
      debugPrint('خطأ في تحميل الأطباء: $e\n$st');

      if (!mounted) return;

      setState(() {
        isLoadingDoctors = false;
        doctorsError = 'تعذر تحميل الأطباء. اسحب للتحديث أو أعد المحاولة.';
      });
    }
  }

  Future<void> _handleLogoTap() async {
    _logoTapCount++;

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;

      // جلسة التشغيل الحالية فقط: بعد دخول ناجح مرة، لا تُطلب كلمة السر
      // حتى يُغلق التطبيق أو يُحدَّث المتصفح.
      if (AdminLaunchSession.unlocked) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminPage()),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminLoginPage()),
        );
      }
      if (mounted) {
        await loadDoctors();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // لا نغلّف IndexedStack بـ Align/ConstrainedBox للعرض —
    // ذلك كان ينهار الارتفاع إلى صفر على macOS/الديسكتوب (شاشة بيضاء).
    // التجاوب يتم عبر الأعمدة وpagePadding داخل المحتوى فقط.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: IndexedStack(
          index: _bottomNavIndex.clamp(0, 1),
          children: [
            _buildDoctorsBrowse(),
            _buildFavoritesTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const teal = Color(0xFF0FAFA3);
    const muted = Color(0xFF8A9A9E);

    Widget item({
      required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      VoidCallback? onTapOverride,
    }) {
      final active = _bottomNavIndex == index;
      return Expanded(
        child: InkWell(
          onTap: onTapOverride ?? () => setState(() => _bottomNavIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? activeIcon : icon,
                  color: active ? teal : muted,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
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

    // مهم: لا تستخدم Center داخل bottomNavigationBar —
    // Center يتمدد لارتفاع الشاشة فيسرق مساحة الـ body → شاشة بيضاء.
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'الرئيسية',
              onTapOverride: () {
                setState(() {
                  _bottomNavIndex = 0;
                  _specialtyFilter = null;
                  _mainCategory = '';
                });
              },
            ),
            item(
              index: 1,
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: 'أطبائي',
            ),
            item(
              index: 2,
              icon: Icons.more_horiz_rounded,
              activeIcon: Icons.more_horiz_rounded,
              label: 'المزيد',
              onTapOverride: _openMoreSheet,
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E4E6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('الإشعارات'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsInboxPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.biotech_outlined),
                    title: const Text('المختبرات والباقات'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LabsPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded),
                    title: const Text('الإعدادات'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    final favoriteDoctors = _sortedDoctorItems()
        .where((d) => favoriteDoctorIds.contains(d.id))
        .toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: const Text(
            'أطبائي',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF123B42),
            ),
          ),
        ),
        Expanded(
          child: favoriteDoctors.isEmpty
              ? const Center(
                  child: Text(
                    'لم تحفظ أي طبيب بعد',
                    style: TextStyle(color: Color(0xFF6B7C80)),
                  ),
                )
              : _buildDoctorCardsLayout(
                  doctors: favoriteDoctors,
                  padding: EdgeInsets.fromLTRB(
                    AppResponsive.pagePadding(context),
                    12,
                    AppResponsive.pagePadding(context),
                    24,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDoctorsBrowse() {
    return RefreshIndicator(
      color: const Color(0xFF0FAFA3),
      onRefresh: () async {
        await Future.wait([loadDoctors(), _loadTodayMessage()]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildSearchBar()),
          SliverToBoxAdapter(child: _buildMainCategories()),
          SliverToBoxAdapter(child: _buildPromoBanner()),
          const SliverToBoxAdapter(child: HomeAdSlot(placement: 'home')),
          SliverToBoxAdapter(child: _buildDoctorsSectionHeader()),
          SliverToBoxAdapter(child: _buildSpecialtyFilters()),
          SliverToBoxAdapter(child: _buildDoctors()),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleLogoTap,
            child: const GhadeerBrandMark(size: 46, backgroundColor: null),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الغدير',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF123B42),
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Al-Ghadeer Clinic',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6D8084),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'معاً لصحة أفضل',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF1197A8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsInboxPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF123B42),
            ),
          ),
        ],
      ),
    );
  }

  void _openSmartSearch({bool voice = false}) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: const Color(0xFFF7FBFC),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return ColoredBox(
            color: const Color(0xFFF7FBFC),
            child: SmartSearchPage(autoStartVoice: voice),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openSmartSearch(),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EEEE)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.045),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF0FAFA3),
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ابحث عن طبيب، اختصاص أو خدمة...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF8A9A9E),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Material(
                  color: const Color(0xFFE8F7F5),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openSmartSearch(voice: true),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.mic_none_rounded,
                        color: Color(0xFF0FAFA3),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCategories() {
    // تحت البحث: المختبرات / الأشعة / الباقات فقط
    // (الأطباء ظاهرة في الصفحة، والعروض مكررة مع الباقات)
    final items = <({String id, String title, IconData icon, String? imageAsset})>[
      (
        id: 'labs',
        title: 'المختبرات',
        icon: Icons.biotech_outlined,
        imageAsset: 'assets/labs/defaults/lab_blood_sample.jpg',
      ),
      (
        id: 'radiology',
        title: 'الأشعة',
        icon: Icons.radar_outlined,
        imageAsset: 'assets/radiology/chest_xray.png',
      ),
      (
        id: 'packages',
        title: 'الباقات',
        icon: Icons.inventory_2_outlined,
        imageAsset: 'assets/packages/gift.png',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: items.map((item) {
          final active = _mainCategory == item.id;
          return Expanded(
            child: InkWell(
              onTap: () => _onMainCategoryTap(item.id),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: item.imageAsset != null
                            ? Colors.white
                            : (active
                                ? const Color(0xFF0FAFA3)
                                : const Color(0xFFEAF6FA)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF0FAFA3)
                              : const Color(0xFFD5EAEF),
                          width: active ? 1.8 : 1,
                        ),
                        boxShadow: item.imageAsset != null
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.imageAsset != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(
                                  item.imageAsset!,
                                  fit: BoxFit.cover,
                                  alignment: const Alignment(0, -0.05),
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, _, _) => Icon(
                                    item.icon,
                                    color: active
                                        ? const Color(0xFF0FAFA3)
                                        : const Color(0xFF1197A8),
                                    size: 26,
                                  ),
                                ),
                                if (active)
                                  const ColoredBox(
                                    color: Color(0x180FAFA3),
                                  ),
                              ],
                            )
                          : Icon(
                              item.icon,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF1197A8),
                              size: 26,
                            ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: active
                            ? const Color(0xFF0FAFA3)
                            : const Color(0xFF243F44),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onMainCategoryTap(String id) {
    setState(() => _mainCategory = id);
    switch (id) {
      case 'labs':
      case 'packages':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LabsPage()),
        );
        return;
      case 'radiology':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RadiologyPage()),
        );
        return;
    }
  }

  Widget _buildPromoBanner() {
    if (_todayMessageLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        height: 112,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6FA),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    final message = _todayMessage;
    if (message == null || !message.hasContent) {
      return const SizedBox.shrink();
    }

    return DynamicHighlightCard(message: message);
  }

  Widget _buildDoctorsSectionHeader() {
    final count = doctors.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الأطباء',
                  style: TextStyle(
                    color: Color(0xFF123B42),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count > 0 ? '$count+ طبيب في خدمتكم' : 'أطباء متاحون لخدمتكم',
                  style: const TextStyle(
                    color: Color(0xFF78888B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _openAllSpecialties,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0FAFA3),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'كل الاختصاصات',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_left_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAllSpecialties() {
    final specialties = doctors
        .map((d) => d['specialty']?.toString() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllSpecialtiesPage(
          doctorSpecialties: specialties,
          onSpecialtySelected: (specialty) {
            setState(() {
              _specialtyFilter = specialty;
              _mainCategory = 'doctors';
              _bottomNavIndex = 0;
            });
          },
        ),
      ),
    );
  }

  List<DoctorItem> _sortedDoctorItems() {
    final items = <DoctorItem>[];
    for (final row in doctors) {
      try {
        final doctor = DoctorItem.fromMap(row);
        if (doctor.id.isEmpty) {
          debugPrint('loadDoctors map: skipped row without id');
          continue;
        }
        items.add(doctor);
      } catch (e, st) {
        debugPrint('loadDoctors map: skipped bad row: $e\n$st');
      }
    }
    items.sort((a, b) {
      final aLeave = DoctorLeaveDisplay.fromDoctor(a).isOnLeave;
      final bLeave = DoctorLeaveDisplay.fromDoctor(b).isOnLeave;
      if (aLeave != bLeave) return aLeave ? 1 : -1;

      int rank(DoctorItem d) {
        switch (d.bookingStatus) {
          case 'available':
            return 0;
          case 'full':
            return 1;
          case 'walk_in_only':
            return 2;
          default:
            return 3;
        }
      }

      final byStatus = rank(a).compareTo(rank(b));
      if (byStatus != 0) return byStatus;

      // الأكثر طلبًا / مشاهدة يظهر أولًا في الرئيسية.
      final byViews = b.profileViews.compareTo(a.profileViews);
      if (byViews != 0) return byViews;

      if (a.ghadeerBadge != b.ghadeerBadge) return a.ghadeerBadge ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  List<DoctorItem> _filteredDoctorItems() {
    final all = _sortedDoctorItems();
    final filter = _specialtyFilter?.trim();
    if (filter == null || filter.isEmpty) return all;

    final filterLower = filter.toLowerCase();
    final matched = SpecialtyCatalog.match(filter);

    return all.where((d) {
      final s = d.specialty.trim();
      if (s.isEmpty) return false;
      if (s.toLowerCase().contains(filterLower) ||
          filterLower.contains(s.toLowerCase())) {
        return true;
      }
      if (matched == null) return false;
      final doctorMatch = SpecialtyCatalog.match(s);
      return doctorMatch?.id == matched.id;
    }).toList();
  }

  Widget _buildSpecialtyFilters() {
    final raw = doctors
        .map((d) => d['specialty']?.toString() ?? '')
        .where((s) => s.trim().isNotEmpty);
    final shortcuts = SpecialtyCatalog.homeShortcuts(raw, limit: 8);
    final chips = <String?>[null, ...shortcuts];

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = chips[index];
                final active = value == null
                    ? _specialtyFilter == null
                    : _specialtyFilter != null &&
                          (SpecialtyCatalog.match(_specialtyFilter!)?.nameAr ==
                                  value ||
                              _specialtyFilter == value);
                final label = value == null
                    ? 'الكل'
                    : SpecialtyCatalog.shortLabel(value);
                return FilterChip(
                  selected: active,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: active ? Colors.white : const Color(0xFF456066),
                    ),
                  ),
                  selectedColor: const Color(0xFF0FAFA3),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  side: BorderSide(
                    color: active
                        ? const Color(0xFF0FAFA3)
                        : const Color(0xFFE0E8EA),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  onSelected: (_) {
                    setState(() => _specialtyFilter = value);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Material(
              color: const Color(0xFFEAF6FA),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _openAllSpecialties,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: Color(0xFF0FAFA3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctors() {
    if (isLoadingDoctors) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          children: List.generate(
            3,
            (i) => Container(
              margin: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
              height: 102,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE6EEEE)),
              ),
            ),
          ),
        ),
      );
    }

    final items = _filteredDoctorItems();
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 42,
              color: Color(0xFF9BB8B6),
            ),
            const SizedBox(height: 10),
            Text(
              doctorsError != null
                  ? doctorsError!
                  : doctors.isEmpty
                  ? 'لا يوجد أطباء حالياً'
                  : 'لم نجد طبيبًا مطابقًا لبحثك',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5B6C70),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  isLoadingDoctors = true;
                  doctorsError = null;
                  if (_specialtyFilter != null) _specialtyFilter = null;
                });
                loadDoctors();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة التحميل'),
            ),
            if (_specialtyFilter != null) ...[
              TextButton(
                onPressed: () => setState(() => _specialtyFilter = null),
                child: const Text('عرض كل الأطباء'),
              ),
            ],
          ],
        ),
      );
    }

    return _buildDoctorCardsLayout(
      doctors: items,
      padding: EdgeInsets.fromLTRB(
        AppResponsive.pagePadding(context),
        10,
        AppResponsive.pagePadding(context),
        8,
      ),
      shrinkWrap: true,
      primary: false,
    );
  }

  /// قائمة/شبكة بطاقات الأطباء حسب عرض الشاشة (موبايل عمود واحد كما هو).
  Widget _buildDoctorCardsLayout({
    required List<DoctorItem> doctors,
    required EdgeInsets padding,
    bool shrinkWrap = false,
    bool primary = true,
  }) {
    final cols = AppResponsive.doctorColumns(context);
    if (cols <= 1) {
      return ListView.separated(
        padding: padding,
        shrinkWrap: shrinkWrap,
        primary: primary,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: doctors.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _doctorCard(doctors[index]),
      );
    }

    // شبكة بدون Scrollable متداخل داخل CustomScrollView (يتفادى انهيار التخطيط).
    if (shrinkWrap) {
      return Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final itemW =
                (constraints.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final doctor in doctors)
                  SizedBox(
                    width: itemW,
                    child: _doctorCard(doctor),
                  ),
              ],
            );
          },
        ),
      );
    }

    return GridView.builder(
      padding: padding,
      primary: primary,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: doctors.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 132,
      ),
      itemBuilder: (context, index) => _doctorCard(doctors[index]),
    );
  }

  Widget _doctorCard(DoctorItem doctor) {
    return ClinicDoctorListCard(
      doctor: doctor,
      isFavorite: favoriteDoctorIds.contains(doctor.id),
      onToggleFavorite: () => _toggleFavorite(doctor.id),
      onOpenProfile: () => _showDoctorProfile(doctor),
    );
  }

  void _showDoctorProfile(DoctorItem doctor, {bool fromDeepLink = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorProfilePage(
          doctor: doctor,
          isFavorite: favoriteDoctorIds.contains(doctor.id),
          onToggleFavorite: () {
            _toggleFavorite(doctor.id);
          },
          fromDeepLink: fromDeepLink,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}

/// Alias للتوافق — البطاقة الموحدة في clinic_doctor_list_card.dart
class ClinicDoctorCard extends StatelessWidget {
  const ClinicDoctorCard({
    super.key,
    required this.doctor,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onOpenProfile,
  });

  final DoctorItem doctor;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return ClinicDoctorListCard(
      doctor: doctor,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      onOpenProfile: onOpenProfile,
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _passwordController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _hidePassword = true;
  String? _errorMessage;
  String _passwordText = '';

  Future<void> _openAdminPanel() async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminPage()),
    );
    if (!mounted) return;
    Navigator.pop(context, changed);
  }

  String get _passwordValue {
    final fromController = _passwordController.text.trim();
    if (fromController.isNotEmpty) return fromController;
    final fromState = _passwordText.trim();
    if (fromState.isNotEmpty) return fromState;
    // Flutter Web: أحياناً يبقى الـ controller فارغاً رغم وجود النص في DOM.
    return dom_input.readFirstDomInputValue()?.trim() ?? '';
  }

  Future<void> _login() async {
    if (_passwordValue.isEmpty) {
      setState(() {
        _errorMessage = 'أدخل كلمة المرور';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _supabase.auth.signInWithPassword(
        email: kAdminEmail,
        password: _passwordValue,
      );

      if (!mounted) return;

      AdminLaunchSession.markUnlocked();
      await _openAdminPanel();
    } on AuthException {
      setState(() {
        _errorMessage = 'كلمة المرور غير صحيحة';
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'حدث خطأ، حاول مرة أخرى';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _forgotPassword() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _supabase.auth.resetPasswordForEmail(
        kAdminEmail,
        redirectTo: adminPasswordResetRedirectTo(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'إن وُجد الحساب، ستصلك رسالة إعادة تعيين كلمة المرور على إيميل الإدارة.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر الإرسال: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر إرسال رابط الاستعادة، حاول من لوحة Supabase.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(title: const Text('دخول الإدارة')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, size: 70),
                  const SizedBox(height: 20),
                  const Text(
                    'إدارة عيادة الغدير',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    onSubmitted: (_) => _login(),
                    onChanged: (value) {
                      _passwordText = value;
                    },
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _hidePassword = !_hidePassword;
                          });
                        },
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const CircularProgressIndicator()
                          : const Text('دخول'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => openAdminPasswordChange(context),
                    child: const Text('تغيير كلمة المرور'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('لوحة إدارة الغدير'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _adminTile(
              icon: Icons.bar_chart_rounded,
              title: 'الإحصائيات',
              subtitle: 'مستخدمو التطبيق وزيارات الأطباء من الغدير',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AppStatsAdminPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.people_alt_rounded,
              title: 'إدارة الأطباء',
              subtitle: 'الأطباء والأقسام — التخصص يُحفظ تلقائيًا مع الطبيب',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DoctorsAdminPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.science_rounded,
              title: 'المختبرات والعروض',
              subtitle: 'إدارة المختبرات والباقات والأسعار',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LabsAdminHubPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.radar_outlined,
              title: 'إعدادات الأشعة',
              subtitle: 'إضافة وتعديل مراكز الأشعة',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RadiologyAdminPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.notifications_active_rounded,
              title: 'الإشعارات',
              subtitle: 'مركز إدارة الإشعارات — جدولة ومسودات وصلاحيات (بدون Push)',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsAdminPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.campaign_rounded,
              title: 'العبارة الديناميكية',
              subtitle: 'تعديل رسالة اليوم',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DynamicMessageAdminPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.ads_click_rounded,
              title: 'إدارة الإعلانات',
              subtitle: 'وقت، مدة، حد ظهور للمستخدم — بدون إزعاج',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdsAdminPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.record_voice_over_rounded,
              title: 'المساعد الصوتي',
              subtitle: 'صوت ولد/بنت، TTS/STT، اختبار الرد',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VoiceSettingsPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.psychology_outlined,
              title: 'اختبار AI + توجيه',
              subtitle: 'Edge Function → نص → صوت → أمان طبي',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AssistantIntegrationPage(),
                  ),
                );
              },
            ),
            _adminTile(
              icon: Icons.lock_reset_rounded,
              title: 'تغيير كلمة المرور',
              subtitle: 'تحديث كلمة سر دخول الإدارة',
              onTap: () => openAdminPasswordChange(context),
            ),
            _adminTile(
              icon: Icons.lock_outline_rounded,
              title: 'قفل لوحة الإدارة',
              subtitle: 'يطلب كلمة السر مرة أخرى حتى نهاية التشغيل الحالي',
              onTap: () {
                AdminLaunchSession.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم القفل — اضغط الشعار 5 مرات وأدخل كلمة السر'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE6F8F6),
          child: Icon(icon, color: const Color(0xFF0FAFA3)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_back_ios_new_rounded),
        onTap: onTap,
      ),
    );
  }
}

class DoctorsAdminPage extends StatefulWidget {
  const DoctorsAdminPage({super.key});

  @override
  State<DoctorsAdminPage> createState() => _DoctorsAdminPageState();
}

class _DoctorsAdminPageState extends State<DoctorsAdminPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _doctors = [];
  bool _loading = true;
  /// فلتر القسم من بيانات الأطباء — بدون حفظ منفصل.
  String? _sectionFilter;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  List<Map<String, dynamic>> get _visibleDoctors {
    final filter = _sectionFilter;
    if (filter == null) return _doctors;
    return _doctors.where((d) {
      final raw = d['specialty']?.toString().trim() ?? '';
      if (raw.isEmpty) return false;
      final matched = SpecialtyCatalog.match(raw)?.nameAr ?? raw;
      return matched == filter;
    }).toList();
  }

  List<({String name, int count})> get _sectionChips {
    final counts = SpecialtyCatalog.countBySpecialty(
      _doctors.map((d) => d['specialty']?.toString() ?? ''),
    );
    final entries = counts.entries.toList()
      ..sort((a, b) {
        if (a.value != b.value) return b.value.compareTo(a.value);
        return a.key.compareTo(b.key);
      });
    return [
      for (final e in entries) (name: e.key, count: e.value),
    ];
  }

  Future<void> _loadDoctors() async {
    setState(() => _loading = true);

    try {
      final data = await _supabase
          .from('doctors')
          .select()
          .order('display_order', ascending: true);

      if (!mounted) return;

      final rows = List<Map<String, dynamic>>.from(data);
      // إن اختفى القسم بعد تحديث البيانات، نُلغي الفلتر تلقائيًا.
      if (_sectionFilter != null) {
        final stillThere = SpecialtyCatalog.countBySpecialty(
          rows.map((d) => d['specialty']?.toString() ?? ''),
        ).containsKey(_sectionFilter);
        if (!stillThere) _sectionFilter = null;
      }

      setState(() {
        _doctors = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ في تحميل الأطباء: $e')));
    }
  }

  Future<void> _deleteDoctor(Map<String, dynamic> doctor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف الطبيب'),
          content: Text(
            'هل أنت متأكد من حذف ${doctor['doctor_name'] ?? 'هذا الطبيب'}؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('doctors').delete().eq('id', doctor['id']);

      await _loadDoctors();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف الطبيب')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حذف الطبيب: $e')));
    }
  }

  Future<void> _toggleDoctor(
    Map<String, dynamic> doctor,
    String field,
    bool value,
  ) async {
    try {
      await _supabase
          .from('doctors')
          .update({field: value})
          .eq('id', doctor['id']);

      await _loadDoctors();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حفظ التغيير: $e')));
    }
  }

  Future<void> _openDoctorForm({Map<String, dynamic>? doctor}) async {
    final changed = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => DoctorAdminFormPage(doctor: doctor),
      ),
    );

    if (changed != null) {
      final index = _doctors.indexWhere((item) => item['id'] == doctor?['id']);

      if (index != -1) {
        setState(() {
          _doctors[index] = {...?doctor, ...changed};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('إدارة الأطباء'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loadDoctors,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
          onPressed: () => _openDoctorForm(),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('إضافة طبيب'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _doctors.isEmpty
            ? const Center(child: Text('لا يوجد أطباء حاليًا'))
            : RefreshIndicator(
                onRefresh: _loadDoctors,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: _visibleDoctors.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSectionsHeader();
                    }

                    final doctor = _visibleDoctors[index - 1];

                    final name =
                        doctor['doctor_name']?.toString() ?? 'بدون اسم';

                    final specialty = doctor['specialty']?.toString() ?? '';

                    final imageUrl = GhadeerBranding.normalizeEntityImageUrl(
                      doctor['image_url']?.toString() ?? '',
                    );

                    final isActive = doctor['is_active'] as bool? ?? true;

                    final hasBadge = doctor['ghadeer_badge'] as bool? ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 70,
                                    height: 78,
                                    color: const Color(0xFFEAF4F3),
                                    child: imageUrl.trim().isNotEmpty
                                        ? GhadeerResolvedImage(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.person_rounded,
                                                    size: 42,
                                                  );
                                                },
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            size: 42,
                                            color: Color(0xFF9BB8B6),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (hasBadge)
                                            const Icon(
                                              Icons.verified_rounded,
                                              color: Colors.blue,
                                              size: 22,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        specialty,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'المشاهدات: ${doctor['profile_views'] ?? 0}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('إظهار الطبيب'),
                              subtitle: Text(
                                isActive
                                    ? 'الطبيب ظاهر للمستخدمين'
                                    : 'الطبيب مخفي',
                              ),
                              value: isActive,
                              onChanged: (value) {
                                _toggleDoctor(doctor, 'is_active', value);
                              },
                            ),

                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Verified Badge'),
                              subtitle: const Text(
                                'توثيق منفصل — ليس مجرد وجود الطبيب في المنصة',
                              ),
                              value: hasBadge,
                              onChanged: (value) {
                                _toggleDoctor(doctor, 'ghadeer_badge', value);
                              },
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openDoctorStats(doctor),
                                    icon: const Icon(Icons.bar_chart_rounded),
                                    label: const Text('الإحصائيات'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      _openDoctorForm(doctor: doctor);
                                    },
                                    icon: const Icon(Icons.edit_rounded),
                                    label: const Text('تعديل'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final id = doctor['id']?.toString() ?? '';
                                      if (id.isEmpty) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              DoctorAbsencesAdminPage(
                                                doctorId: id,
                                                doctorName: name,
                                              ),
                                        ),
                                      ).then((_) => _loadDoctors());
                                    },
                                    icon: const Icon(
                                      Icons.beach_access_outlined,
                                    ),
                                    label: const Text('إجازات'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteDoctor(doctor),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'حذف',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildSectionsHeader() {
    final chips = _sectionChips;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'الأقسام',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF123B42),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            chips.isEmpty
                ? 'تظهر الأقسام من تخصص كل طبيب — عدّلها من تعديل الطبيب.'
                : 'فلترة حسب القسم — لتعديل التصنيف افتح تعديل الطبيب.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5B6C70),
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      selected: _sectionFilter == null,
                      label: Text('الكل (${_doctors.length})'),
                      onSelected: (_) {
                        setState(() => _sectionFilter = null);
                      },
                    ),
                  ),
                  for (final chip in chips)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        selected: _sectionFilter == chip.name,
                        label: Text('${chip.name} (${chip.count})'),
                        onSelected: (_) {
                          setState(() {
                            _sectionFilter =
                                _sectionFilter == chip.name ? null : chip.name;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (_sectionFilter != null && _visibleDoctors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'لا يوجد أطباء في هذا القسم.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDoctorStats(Map<String, dynamic> doctor) async {
    final id = doctor['id']?.toString() ?? '';
    final name = doctor['doctor_name']?.toString() ?? 'الطبيب';
    if (id.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => DoctorPeriodStatsDialog(
        doctorId: id,
        doctorName: name,
      ),
    );
  }
}

class DoctorAdminFormPage extends StatefulWidget {
  final Map<String, dynamic>? doctor;

  const DoctorAdminFormPage({super.key, this.doctor});

  @override
  State<DoctorAdminFormPage> createState() => _DoctorAdminFormPageState();
}

class _DoctorAdminFormPageState extends State<DoctorAdminFormPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _locationController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _imageController;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  /// البايتات الأصلية قبل إزالة الخلفية (لإعادة التطبيق عند تبديل الخيار).
  Uint8List? _pickedImageOriginalBytes;
  bool _pickedImageBgRemoved = false;
  bool _removingImageBg = false;
  /// اختياري: إزالة الخلفية وتركيب هوية الغدير.
  bool _removeImageBackground = true;
  late final TextEditingController _shortDescriptionController;
  late final TextEditingController _bioController;
  late final TextEditingController _servicesController;
  late final TextEditingController _workingDaysController;
  late final TextEditingController _workingHoursController;
  late final TextEditingController _feeController;
  late final TextEditingController _orderController;
  late final TextEditingController _yearsController;
  late final TextEditingController _patientsController;
  late final TextEditingController _languagesController;
  late final TextEditingController _qualificationsController;
  late final TextEditingController _ageGroupController;
  late final TextEditingController _quoteController;

  bool _isActive = true;
  bool _ghadeerBadge = false;
  bool _showCallButton = true;
  bool _showWhatsAppButton = true;
  bool _showBookingButton = false;
  bool _notificationsEnabled = true;
  String _bookingStatus = 'available';
  final Map<String, bool> _workingWeek = {
    'السبت': false,
    'الأحد': false,
    'الاثنين': false,
    'الثلاثاء': false,
    'الأربعاء': false,
    'الخميس': false,
    'الجمعة': false,
  };
  final Map<String, String?> _dayExceptions = {
    'السبت': null,
    'الأحد': null,
    'الاثنين': null,
    'الثلاثاء': null,
    'الأربعاء': null,
    'الخميس': null,
    'الجمعة': null,
  };
  TimeOfDay? _defaultStartTime;
  TimeOfDay? _defaultEndTime;
  bool _saving = false;
  bool get _isEditing => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    // تهيئة نموذج إزالة الخلفية مبكرًا حتى تكون جاهزة عند اختيار الصورة.
    DoctorImageBgRemover.ensureInitialized();

    final doctor = widget.doctor;

    _nameController = TextEditingController(
      text: doctor?['doctor_name']?.toString() ?? '',
    );

    _specialtyController = TextEditingController(
      text: doctor?['specialty']?.toString() ?? '',
    );

    _locationController = TextEditingController(
      text: doctor?['clinic_location']?.toString() ?? '',
    );

    _phoneController = TextEditingController(
      text: doctor?['phone']?.toString() ?? '',
    );

    _whatsappController = TextEditingController(
      text: doctor?['whatsapp']?.toString() ?? '',
    );

    _imageController = TextEditingController(
      text: GhadeerBranding.normalizeEntityImageUrl(
        doctor?['image_url']?.toString() ?? '',
      ),
    );

    _shortDescriptionController = TextEditingController(
      text: doctor?['short_description']?.toString() ?? '',
    );
    _bioController = TextEditingController(
      text: doctor?['bio']?.toString() ?? '',
    );
    _servicesController = TextEditingController(
      text: doctor?['services']?.toString() ?? '',
    );
    _workingDaysController = TextEditingController(
      text: doctor?['working_days']?.toString() ?? '',
    );

    _workingHoursController = TextEditingController(
      text: doctor?['working_hours']?.toString() ?? '',
    );
    final savedWorkingHours = doctor?['working_hours']?.toString().trim() ?? '';

    if (savedWorkingHours.isNotEmpty) {
      final match = RegExp(
        r'(\d{1,2})[:\.]?(\d{0,2})\s*(ص|م)?\s*(?:إلى|-)\s*(\d{1,2})[:\.]?(\d{0,2})\s*(ص|م)?',
      ).firstMatch(savedWorkingHours);

      if (match != null) {
        int startHour = int.parse(match.group(1)!);
        final startMinute = (match.group(2)?.isNotEmpty ?? false)
            ? int.parse(match.group(2)!)
            : 0;
        final startPeriod = match.group(3);

        int endHour = int.parse(match.group(4)!);
        final endMinute = (match.group(5)?.isNotEmpty ?? false)
            ? int.parse(match.group(5)!)
            : 0;
        final endPeriod = match.group(6);

        if (startPeriod == 'م' && startHour < 12) startHour += 12;
        if (startPeriod == 'ص' && startHour == 12) startHour = 0;

        if (endPeriod == 'م' && endHour < 12) endHour += 12;
        if (endPeriod == 'ص' && endHour == 12) endHour = 0;

        _defaultStartTime = TimeOfDay(hour: startHour, minute: startMinute);

        _defaultEndTime = TimeOfDay(hour: endHour, minute: endMinute);
      }
    }
    final savedWorkingDays = doctor?['working_days']?.toString().trim() ?? '';

    if (savedWorkingDays.isNotEmpty) {
      if (savedWorkingDays.contains('كل أيام الأسبوع')) {
        for (final day in _workingWeek.keys) {
          _workingWeek[day] = true;
        }
      } else {
        for (final day in _workingWeek.keys) {
          _workingWeek[day] = savedWorkingDays.contains(day);
        }
      }
    }

    if (savedWorkingHours.isNotEmpty) {
      for (final day in _workingWeek.keys) {
        final match = RegExp(
          '$day\\s*:?\\s*(صباحًا ومساءً|مساءً وصباحًا|صباحًا|مساءً|عطلة)',
          unicode: true,
        ).firstMatch(savedWorkingHours);
        if (match == null) continue;
        final period = match.group(1) ?? '';
        if (period.contains('عطل')) {
          _dayExceptions[day] = 'off';
          _workingWeek[day] = false;
        } else if (period.contains('صباح') && period.contains('مساء')) {
          _dayExceptions[day] = 'both';
          _workingWeek[day] = true;
        } else if (period.contains('صباح')) {
          _dayExceptions[day] = 'morning';
          _workingWeek[day] = true;
        } else if (period.contains('مساء')) {
          _dayExceptions[day] = 'evening';
          _workingWeek[day] = true;
        }
      }
    }

    _feeController = TextEditingController(
      text: doctor?['consultation_fee']?.toString() ?? '',
    );

    _orderController = TextEditingController(
      text: doctor?['display_order']?.toString() ?? '0',
    );

    _yearsController = TextEditingController(
      text: doctor?['years_experience']?.toString() ?? '0',
    );
    _patientsController = TextEditingController(
      text: doctor?['patients_served']?.toString() ?? '0',
    );
    _languagesController = TextEditingController(
      text: doctor?['languages']?.toString() ?? 'العربية',
    );
    _qualificationsController = TextEditingController(
      text: doctor?['qualifications']?.toString() ?? '',
    );
    _ageGroupController = TextEditingController(
      text: _normalizedAgeGroup(
        doctor?['age_group']?.toString() ?? 'للكبار والصغار',
      ),
    );
    _quoteController = TextEditingController(
      text:
          doctor?['profile_quote']?.toString() ??
          'الدقة في التشخيص... خطوة أولى نحو العلاج الصحيح',
    );

    _isActive = doctor?['is_active'] as bool? ?? true;

    _ghadeerBadge = doctor?['ghadeer_badge'] as bool? ?? false;

    _showCallButton = doctor?['show_call_button'] as bool? ?? true;

    _showWhatsAppButton = doctor?['show_whatsapp_button'] as bool? ?? true;

    _showBookingButton = doctor?['show_booking_button'] as bool? ?? false;
    _notificationsEnabled = doctor?['notifications_enabled'] as bool? ?? true;
    _bookingStatus = doctor?['booking_status']?.toString() ?? 'available';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _imageController.dispose();
    _shortDescriptionController.dispose();
    _bioController.dispose();
    _servicesController.dispose();
    _workingDaysController.dispose();
    _workingHoursController.dispose();
    _feeController.dispose();
    _orderController.dispose();
    _yearsController.dispose();
    _patientsController.dispose();
    _languagesController.dispose();
    _qualificationsController.dispose();
    _ageGroupController.dispose();
    _quoteController.dispose();
    DoctorImageBgRemover.dispose();

    super.dispose();
  }

  Future<void> _pickDoctorImage() async {
    if (_removingImageBg || _saving) return;

    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      // بدون ضغط JPEG مفرط قبل إزالة الخلفية.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 95,
    );

    if (image == null) return;
    final bytes = await image.readAsBytes();

    if (!mounted) return;
    setState(() {
      _pickedImage = image;
      _pickedImageOriginalBytes = bytes;
    });
    await _applyPickedImageProcessing(bytes);
  }

  /// يطبّق إزالة الخلفية أو يبقي الأصل حسب [_removeImageBackground].
  Future<void> _applyPickedImageProcessing(Uint8List originalBytes) async {
    if (!_removeImageBackground) {
      if (!mounted) return;
      setState(() {
        _pickedImageBytes = originalBytes;
        _pickedImageBgRemoved = false;
        _removingImageBg = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الإبقاء على الصورة الأصلية.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _removingImageBg = true);

    final cutout = await DoctorImageBgRemover.removeBackground(originalBytes);
    final removed = cutout != null;
    final usedBytes = cutout ?? originalBytes;

    if (!mounted) return;
    setState(() {
      _pickedImageBytes = usedBytes;
      _pickedImageBgRemoved = removed;
      _removingImageBg = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed
              ? 'تم تجهيز صورة الطبيب بخلفية هوية الغدير.'
              : 'تعذّر معالجة الخلفية؛ تم استخدام الصورة الأصلية. أعد المحاولة بصورة أوضح للشخص.',
        ),
      ),
    );
  }

  Future<void> _onRemoveBackgroundChanged(bool value) async {
    if (_removingImageBg || _saving) return;
    setState(() => _removeImageBackground = value);
    final original = _pickedImageOriginalBytes;
    if (original == null) return;
    await _applyPickedImageProcessing(original);
  }

  Future<void> _saveDoctor() async {
    if (!_formKey.currentState!.validate()) return;
    if (_removingImageBg) return;

    setState(() => _saving = true);
    debugPrint('SESSION USER = ${_supabase.auth.currentSession?.user.email}');
    final oldImageUrl = widget.doctor?['image_url']?.toString();
    String? imageUrl = _imageController.text.trim().isEmpty
        ? null
        : _imageController.text.trim();

    if (_pickedImageBytes != null) {
      // إن كان الخيار مفعّلاً ولم تُعالَج بعد، حاول قبل الرفع مرة واحدة.
      if (_removeImageBackground &&
          !_pickedImageBgRemoved &&
          _pickedImageOriginalBytes != null) {
        final again = await DoctorImageBgRemover.removeBackground(
          _pickedImageOriginalBytes!,
        );
        if (again != null) {
          _pickedImageBytes = again;
          _pickedImageBgRemoved = true;
        }
      }

      final originalName = _pickedImage?.name ?? 'doctor.jpg';
      final extension = _pickedImageBgRemoved
          ? 'png'
          : originalName.contains('.')
          ? originalName.split('.').last.toLowerCase()
          : 'jpg';

      final safeExtension =
          ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)
          ? extension
          : 'jpg';

      final fileName =
          'doctors/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

      await _supabase.storage
          .from('clinic-media')
          .uploadBinary(
            fileName,
            _pickedImageBytes!,
            fileOptions: FileOptions(
              upsert: false,
              contentType: switch (safeExtension) {
                'png' => 'image/png',
                'webp' => 'image/webp',
                'heic' => 'image/heic',
                _ => 'image/jpeg',
              },
            ),
          );

      imageUrl = _supabase.storage.from('clinic-media').getPublicUrl(fileName);
    }

    // لو كانت صورة لوغو غدير من الإدارة → اللوغو المعتمد.
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final normalized = GhadeerBranding.normalizeEntityImageUrl(imageUrl);
      imageUrl = normalized.isEmpty ? null : normalized;
    }

    final selectedWorkingDays = _workingWeek.entries
        .where(
          (entry) => entry.value && (_dayExceptions[entry.key] ?? 'evening') != 'off',
        )
        .map((entry) => entry.key)
        .toList();

    final workingDaysText = selectedWorkingDays.length == _workingWeek.length
        ? 'كل أيام الأسبوع'
        : selectedWorkingDays.join('، ');
    String exceptionLabel(String value) {
      switch (value) {
        case 'morning':
          return 'صباحًا';
        case 'evening':
          return 'مساءً';
        case 'both':
          return 'صباحًا ومساءً';
        case 'off':
          return 'عطلة';
        default:
          return '';
      }
    }

    final baseWorkingHours =
        _defaultStartTime != null && _defaultEndTime != null
        ? '${_defaultStartTime!.format(context)} إلى ${_defaultEndTime!.format(context)}'
        : _workingHoursController.text.trim();

    // جدول البطاقة: السبت مساءً، …، الأحد عطلة، الجمعة صباحًا ومساءً
    final dayExceptionTexts = <String>[];
    final anyDayConfigured =
        _workingWeek.values.any((v) => v) ||
        _dayExceptions.values.any((v) => v != null && v.isNotEmpty);
    if (anyDayConfigured) {
      for (final day in _workingWeek.keys) {
        final enabled = _workingWeek[day] ?? false;
        final period = _dayExceptions[day] ?? (enabled ? 'evening' : 'off');
        if (!enabled || period == 'off') {
          dayExceptionTexts.add('$day عطلة');
          continue;
        }
        final label = exceptionLabel(period);
        if (label.isEmpty) continue;
        dayExceptionTexts.add('$day $label');
      }
    }

    final workingHoursText = dayExceptionTexts.isEmpty
        ? baseWorkingHours
        : baseWorkingHours.isEmpty
        ? dayExceptionTexts.join('، ')
        : '$baseWorkingHours | ${dayExceptionTexts.join('، ')}';
    final rawSpecialty = _specialtyController.text.trim();
    final smartSpecialty =
        SpecialtyCatalog.match(rawSpecialty)?.nameAr ?? rawSpecialty;
    if (smartSpecialty != rawSpecialty) {
      _specialtyController.text = smartSpecialty;
    }

    final bioText = _bioController.text.trim();
    final shortText = _shortDescriptionController.text.trim().isNotEmpty
        ? _shortDescriptionController.text.trim()
        : bioText;

    final data = <String, dynamic>{
      'doctor_name': _nameController.text.trim(),
      'specialty': smartSpecialty,
      'clinic_location': _locationController.text.trim(),
      'phone': _phoneController.text.trim(),
      'whatsapp': _whatsappController.text.trim(),
      'image_url': imageUrl,
      'short_description': shortText,
      'bio': bioText,
      'services': _servicesController.text.trim(),
      'working_days': workingDaysText,
      'working_hours': workingHoursText,
      'consultation_fee': _feeController.text.trim().isEmpty
          ? null
          : _feeController.text.trim(),
      'display_order': int.tryParse(_orderController.text.trim()) ?? 0,
      'is_active': _isActive,
      'ghadeer_badge': _ghadeerBadge,
      'show_call_button': _showCallButton,
      'show_whatsapp_button': _showWhatsAppButton,
      'show_booking_button': _showBookingButton,
      'booking_status': _bookingStatus,
      'years_experience': int.tryParse(_yearsController.text.trim()) ?? 0,
      'patients_served': int.tryParse(_patientsController.text.trim()) ?? 0,
      'languages': _languagesController.text.trim(),
      'qualifications': _qualificationsController.text.trim(),
      'age_group': _ageGroupController.text.trim(),
      'profile_quote': _quoteController.text.trim(),
      'notifications_enabled': _notificationsEnabled,
    };

    try {
      await _persistDoctorRecord(data);

      if (_isEditing &&
          _pickedImageBytes != null &&
          oldImageUrl != null &&
          oldImageUrl.isNotEmpty &&
          oldImageUrl != imageUrl) {
        try {
          final uri = Uri.parse(oldImageUrl);
          final marker = '/object/public/clinic-media/';
          final index = uri.path.indexOf(marker);

          if (index != -1) {
            final oldFilePath = Uri.decodeComponent(
              uri.path.substring(index + marker.length),
            );

            await _supabase.storage.from('clinic-media').remove([oldFilePath]);
          }
        } catch (e) {
          debugPrint('Could not delete old doctor image: $e');
        }
      }
      if (!mounted) return;

      if (_isEditing) {
        Navigator.pop(context, data);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذر حفظ بيانات الطبيب: $e')));
    }
  }

  /// يحفظ سجل الطبيب مع تجاهل الأعمدة الاختيارية غير الموجودة في Schema
  /// حتى لا يفشل تحديث الصورة وباقي الحقول الأساسية بسبب عمود واحد مفقود.
  Future<void> _persistDoctorRecord(Map<String, dynamic> raw) async {
    final payload = Map<String, dynamic>.from(raw);

    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        if (_isEditing) {
          await _supabase
              .from('doctors')
              .update(payload)
              .eq('id', widget.doctor!['id']);
        } else {
          await _supabase.from('doctors').insert(payload);
        }
        return;
      } on PostgrestException catch (e) {
        if (e.code != 'PGRST204') rethrow;
        final missing = _missingColumnFromPostgrest(e.message);
        if (missing == null || !payload.containsKey(missing)) {
          rethrow;
        }
        debugPrint(
          'Doctor save: skipping missing column "$missing" (PGRST204)',
        );
        payload.remove(missing);
      }
    }

    throw Exception('تعذر حفظ الطبيب بعد تجاهل أعمدة غير موجودة في Schema');
  }

  String? _missingColumnFromPostgrest(String message) {
    final match = RegExp(
      r"Could not find the '([^']+)' column",
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(1);
  }

  /// توحيد قيم الفئة العمرية لخيارات الإدارة الثلاث.
  static String _normalizedAgeGroup(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'للكبار والصغار';
    final n = t
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .toLowerCase();
    if (n.contains('بالغ') && !n.contains('صغ') && !n.contains('طفل')) {
      return 'للبالغين';
    }
    if ((n.contains('صغ') || n.contains('طفل') || n.contains('اطفال')) &&
        !n.contains('بالغ') &&
        !n.contains('كبار')) {
      return 'للصغار';
    }
    return 'للكبار والصغار';
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool requiredField = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        validator: requiredField
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              }
            : null,
      ),
    );
  }

  /// القسم الطبي ضمن بيانات الطبيب — قابل للتعديل والتحقق من التصنيف.
  Widget _buildSpecialtyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _specialtyController.text),
          optionsBuilder: (textEditingValue) {
            final q = textEditingValue.text.trim();
            final options = SpecialtyCatalog.namesForAdmin;
            if (q.isEmpty) return options;
            final qLower = q.toLowerCase();
            final matched = SpecialtyCatalog.match(q);
            final ranked = <String>[];
            if (matched != null) ranked.add(matched.nameAr);
            for (final o in options) {
              if (ranked.contains(o)) continue;
              if (o.toLowerCase().contains(qLower)) {
                ranked.add(o);
                continue;
              }
              final m = SpecialtyCatalog.match(o);
              if (m?.keywords.any(
                    (k) =>
                        k.toLowerCase().contains(qLower) ||
                        qLower.contains(k.toLowerCase()),
                  ) ??
                  false) {
                ranked.add(o);
              }
            }
            return ranked.isEmpty ? options : ranked;
          },
          onSelected: (value) {
            final smart = SpecialtyCatalog.match(value)?.nameAr ?? value;
            _specialtyController.text = smart;
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  onChanged: (v) {
                    _specialtyController.text = v;
                  },
                  decoration: InputDecoration(
                    labelText: 'القسم الطبي / التصنيف',
                    hintText: 'اختر أو عدّل قسم الطبيب',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'القسم الطبي مطلوب';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _specialtyController,
          builder: (context, value, _) {
            final raw = value.text.trim();
            if (raw.isEmpty) {
              return const Text(
                'أدخل القسم للتأكد من التصنيف قبل الحفظ.',
                style: TextStyle(fontSize: 12, color: Color(0xFF5B6C70)),
              );
            }
            final matched = SpecialtyCatalog.match(raw);
            if (matched != null) {
              return Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF0FAFA3),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'التصنيف المطابق: ${matched.nameAr}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF123B42),
                      ),
                    ),
                  ),
                ],
              );
            }
            return const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFE89B28),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'غير مطابق لكتالوج الغدير — سيُحفظ كنص حر، أو اختر قسمًا من القائمة.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A6A2A),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(_isEditing ? 'تعديل الطبيب' : 'إضافة طبيب'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                controller: _nameController,
                label: 'اسم الطبيب',
                icon: Icons.person_rounded,
                requiredField: true,
              ),

              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'بيانات الملف',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF123B42),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'القسم والنبذة والموقع وواتساب — راجع التصنيف وعدّله من هنا إن لزم.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6C70)),
                ),
              ),

              _buildSpecialtyField(),

              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                minLines: 4,
                maxLines: 6,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: 'نبذة عن الطبيب',
                  hintText: 'اكتب نبذة عن الطبيب، خبرته، مؤهلاته ومجالات عمله',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              _field(
                controller: _locationController,
                label: 'الموقع / عنوان العيادة',
                icon: Icons.location_on_outlined,
              ),

              _field(
                controller: _phoneController,
                label: 'رقم الاتصال',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              _field(
                controller: _whatsappController,
                label: 'رقم واتساب',
                icon: Icons.chat_outlined,
                keyboardType: TextInputType.phone,
              ),

              // أيام/ساعات التواجد النصية تُملأ من الجدول الأسبوعي عند الحفظ.
              // الحقول الزائدة تبقى قيمها في الذاكرة عند التعديل دون عرضها.
              Row(
                children: [
                  SizedBox(
                    width: 82,
                    height: 82,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: const Color(0xFFF2F6F6),
                        alignment: Alignment.center,
                        child: _pickedImageBytes != null
                            ? Image.memory(
                                _pickedImageBytes!,
                                width: 82,
                                height: 82,
                                fit: BoxFit.cover,
                              )
                            : _imageController.text.trim().isNotEmpty
                            ? GhadeerResolvedImage(
                                _imageController.text.trim(),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person_rounded,
                                    size: 42,
                                    color: Color(0xFF9BB8B6),
                                  );
                                },
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: Color(0xFF9BB8B6),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_removingImageBg || _saving)
                          ? null
                          : _pickDoctorImage,
                      icon: _removingImageBg
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(
                        _removingImageBg
                            ? 'جاري معالجة الصورة...'
                            : _pickedImageBytes != null
                            ? 'تغيير صورة الطبيب'
                            : 'اختيار صورة الطبيب',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              TextField(
                controller: _imageController,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  GhadeerBranding.applyOfficialLogoToField(
                    _imageController,
                    onApplied: () {
                      if (!mounted) return;
                      setState(() {
                        _pickedImage = null;
                        _pickedImageBytes = null;
                        _pickedImageOriginalBytes = null;
                        _pickedImageBgRemoved = false;
                      });
                    },
                  );
                  setState(() {});
                },
                decoration: const InputDecoration(
                  labelText: 'رابط الصورة أو اكتب: لوغو الغدير',
                  hintText: 'لوغو الغدير',
                  helperText:
                      'إذا كتبت «لوغو الغدير» يُستبدل تلقائيًا بالشعار المعتمد',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إزالة خلفية الصورة'),
                subtitle: const Text(
                  'عند التفعيل: خلفية هوية الغدير. عند الإيقاف: الصورة كما هي.',
                ),
                value: _removeImageBackground,
                onChanged: (_removingImageBg || _saving)
                    ? null
                    : _onRemoveBackgroundChanged,
              ),

              const SizedBox(height: 12),
              const Divider(height: 30),

              SwitchListTile(
                title: const Text('إظهار الطبيب'),
                subtitle: const Text('تشغيل أو إخفاء الطبيب من التطبيق'),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
              ),

              SwitchListTile(
                title: const Text('Verified Badge'),
                subtitle: const Text(
                  'توثيق منفصل عن عبارة «طبيب في منصة الغدير»',
                ),
                value: _ghadeerBadge,
                onChanged: (value) {
                  setState(() => _ghadeerBadge = value);
                },
              ),

              SwitchListTile(
                title: const Text('زر الاتصال'),
                value: _showCallButton,
                onChanged: (value) {
                  setState(() => _showCallButton = value);
                },
              ),

              SwitchListTile(
                title: const Text('زر واتساب'),
                subtitle: const Text(
                  'إظهار أو إخفاء زر واتساب من بطاقة الطبيب',
                ),
                value: _showWhatsAppButton,
                onChanged: (value) {
                  setState(() => _showWhatsAppButton = value);
                },
              ),

              SwitchListTile(
                title: const Text('إشعارات مرتبطة بالطبيب'),
                subtitle: const Text(
                  'السماح بإرسال إشعارات عطلة/تحديث لهذا الطبيب',
                ),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
              const SizedBox(height: 16),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '📅 جدول الدوام الأسبوعي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              _defaultStartTime ??
                              const TimeOfDay(hour: 13, minute: 0),
                        );

                        if (picked != null) {
                          setState(() {
                            _defaultStartTime = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        _defaultStartTime == null
                            ? 'من الساعة'
                            : 'من ${_defaultStartTime!.format(context)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime:
                              _defaultEndTime ??
                              const TimeOfDay(hour: 20, minute: 0),
                        );

                        if (picked != null) {
                          setState(() {
                            _defaultEndTime = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(
                        _defaultEndTime == null
                            ? 'إلى الساعة'
                            : 'إلى ${_defaultEndTime!.format(context)}',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ..._workingWeek.keys.map((day) {
                return SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    day,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    (_workingWeek[day] ?? false)
                        ? 'متواجد — اختر الفترة أدناه'
                        : 'عطلة — يظهر مقابل اليوم في البطاقة',
                  ),
                  value: _workingWeek[day] ?? false,
                  onChanged: (value) {
                    setState(() {
                      _workingWeek[day] = value;
                      if (value) {
                        if (_dayExceptions[day] == null ||
                            _dayExceptions[day] == 'off') {
                          _dayExceptions[day] = 'evening';
                        }
                      } else {
                        _dayExceptions[day] = 'off';
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 16),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '⚙️ فترة كل يوم (صباحًا / مساءً / كليهما / عطلة)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'العرض في البطاقة: عمودان + الجمعة أسفل — عطلة تظهر مقابل اليوم',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF5B6C70)),
                ),
              ),

              const SizedBox(height: 8),

              ..._workingWeek.keys.map((day) {
                final enabled = _workingWeek[day] ?? false;
                final period = enabled
                    ? (_dayExceptions[day] == 'off'
                          ? 'evening'
                          : (_dayExceptions[day] ?? 'evening'))
                    : 'off';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('period-$day-$period'),
                    initialValue: period,
                    decoration: InputDecoration(
                      labelText: '$day — الفترة',
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'morning',
                        child: Text('صباحًا'),
                      ),
                      DropdownMenuItem(
                        value: 'evening',
                        child: Text('مساءً'),
                      ),
                      DropdownMenuItem(
                        value: 'both',
                        child: Text('صباحًا ومساءً'),
                      ),
                      DropdownMenuItem(
                        value: 'off',
                        child: Text('عطلة'),
                      ),
                    ],
                    onChanged: (value) {
                      final next = value ?? 'evening';
                      setState(() {
                        _dayExceptions[day] = next;
                        _workingWeek[day] = next != 'off';
                      });
                    },
                  ),
                );
              }),

              const SizedBox(height: 12),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _bookingStatus,
                decoration: const InputDecoration(
                  labelText: 'حالة الطبيب',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_available_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'available',
                    child: Text('🟢 متاح للحجز'),
                  ),
                  DropdownMenuItem(
                    value: 'walk_in_only',
                    child: Text('🟠 حضوري فقط'),
                  ),
                  DropdownMenuItem(value: 'full', child: Text('🔴 مكتمل')),
                  DropdownMenuItem(
                    value: 'unavailable',
                    child: Text('⚪ غير متاح'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _bookingStatus = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 20),

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveDoctor,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _saving
                        ? 'جاري الحفظ...'
                        : _isEditing
                        ? 'حفظ التعديلات'
                        : 'إضافة الطبيب',
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  final List<Map<String, dynamic>> doctors;
  final void Function(String doctorId)? onRemoveFavorite;
  final void Function(DoctorItem doctor) onOpenDoctorProfile;

  const FavoritesPage({
    super.key,
    required this.doctors,
    this.onRemoveFavorite,
    required this.onOpenDoctorProfile,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late List<Map<String, dynamic>> favoriteDoctors;

  @override
  void initState() {
    super.initState();
    favoriteDoctors = List<Map<String, dynamic>>.from(widget.doctors);
  }

  void _removeFavorite(String doctorId) {
    widget.onRemoveFavorite?.call(doctorId);
    setState(() {
      favoriteDoctors.removeWhere(
        (doctor) => doctor['id']?.toString() == doctorId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('أطبائي'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: favoriteDoctors.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'لا يوجد أطباء في المفضلة',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: favoriteDoctors.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final doctor = DoctorItem.fromMap(favoriteDoctors[index]);
                  return ClinicDoctorCard(
                    doctor: doctor,
                    isFavorite: true,
                    onToggleFavorite: () => _removeFavorite(doctor.id),
                    onOpenProfile: () => widget.onOpenDoctorProfile(doctor),
                  );
                },
              ),
      ),
    );
  }
}
