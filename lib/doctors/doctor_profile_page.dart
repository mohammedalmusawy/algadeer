import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../labs/lab_card_links.dart';
import '../models/doctor_item.dart';
import '../services/app_stats_service.dart';
import '../companion/personal_companion_profile_service.dart';
import '../settings/whatsapp_message_settings.dart';
import '../settings/whatsapp_templates.dart';
import '../theme/ghadeer_tokens.dart';
import '../utils/contact_launch.dart';
import '../utils/ghadeer_haptics.dart';
import '../voice/voice_response_controller.dart';
import '../widgets/entity_contact_actions.dart';
import '../widgets/entity_optional_logo.dart';
import '../widgets/entity_social_sheet.dart';
import 'doctor_availability_service.dart';
import 'doctor_card_gate.dart';
import 'doctor_card_links.dart';
import 'doctor_card_tap.dart';
import 'doctor_engagement_service.dart';
import 'doctor_gender.dart';
import 'doctor_today_status.dart';
import 'doctor_week_schedule.dart';
import '../widgets/owner_access_link.dart';
import '../settings/whatsapp_contact_flow.dart';

export 'doctor_week_schedule.dart'
    show DoctorWeekDayEntry, doctorWeekDayOrder, parseDoctorWeekSchedule;

/// بطاقة الطبيب الرقمية / الملف الشخصي — تصميم Premium مطابق للمرجع البصري.
/// البيانات ديناميكية من [DoctorItem] / Supabase لكل طبيب.
class DoctorProfilePage extends StatefulWidget {
  const DoctorProfilePage({
    super.key,
    required this.doctor,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.fromDeepLink = false,
  });

  final DoctorItem doctor;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool fromDeepLink;

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  final _engagement = DoctorEngagementService();
  final _stats = AppStatsService();
  final _profileService = PersonalCompanionProfileService();
  final _voice = VoiceResponseController();
  late bool _favorite;
  DoctorItem? _edited;
  DoctorRatingSummary _rating = const DoctorRatingSummary();
  int? _myRating;
  bool _ratingBusy = false;
  bool _bioSpeechBusy = false;

  // هوية الغدير الطبية — Accent وليس إغراقًا.
  static const _navy = GhadeerTokens.ink;
  static const _actionBlue = GhadeerTokens.tealDeep;
  static const _muted = GhadeerTokens.inkMuted;
  static const _pageBg = GhadeerTokens.mist;

  @override
  void initState() {
    super.initState();
    _favorite = widget.isFavorite;
    _engagement.recordProfileView(widget.doctor.id);
    _loadRatings();
    if (widget.fromDeepLink && kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        DoctorCardLinks.openInstallSuggestion(context);
      });
    }
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _voice.dispose();
    super.dispose();
  }

  Future<void> _stopSpeechAndPop() async {
    await _voice.stop();
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// نص النطق: نبذة قصيرة أولًا، وإلا مقتطف من bio — بدون تعديل إعدادات الصوت.
  String get _bioSpeechText {
    final short = doctor.shortDescription.trim();
    final bio = doctor.bio.trim();
    var body = short.isNotEmpty ? short : bio;
    if (body.isEmpty) return '';

    // حد معقول حتى لا يطول النطق على النبذة الطويلة.
    const maxLen = 420;
    if (body.length > maxLen) {
      final cut = body.substring(0, maxLen);
      final lastStop = cut.lastIndexOf(RegExp(r'[.。!؟\n]'));
      body = (lastStop > 80 ? cut.substring(0, lastStop + 1) : cut).trim();
      if (!body.endsWith('.') && !body.endsWith('。') && !body.endsWith('!')) {
        body = '$body…';
      }
    }

    final name = _doctorProfileDisplayName(doctor.name).trim();
    final specialty = doctor.specialty.trim();
    final head = [
      if (name.isNotEmpty) name,
      if (specialty.isNotEmpty) 'اختصاص $specialty',
    ].join('، ');
    if (head.isEmpty) return body;
    return '$head. $body';
  }

  Future<void> _toggleBioSpeech() async {
    // أثناء التشغيل: الضغطة الثانية = إيقاف فورًا (لا تُحجب بـ busy).
    if (_voice.isSpeaking || _bioSpeechBusy) {
      await _voice.stop();
      _bioSpeechBusy = false;
      return;
    }

    final text = _bioSpeechText;
    if (text.isEmpty) {
      _showMessage('لا توجد نبذة صوتية لهذا الطبيب حاليًا.');
      return;
    }

    _bioSpeechBusy = true;
    try {
      // speak فقط — لا يغيّر جنس الصوت ولا التشغيل التلقائي في الإعدادات.
      await _voice.speak(text);
    } finally {
      _bioSpeechBusy = false;
    }
  }

  DoctorItem get doctor => _edited ?? widget.doctor;

  Future<void> _openCardAccess() async {
    final result = await openDoctorCardAccess(context, doctor);
    if (!mounted || result == null) return;
    if (result.deleted) {
      Navigator.pop(context);
      return;
    }
    if (result.doctor != null) {
      setState(() => _edited = result.doctor);
    }
  }

  /// مصدر صورة الـ Hero الحالي.
  /// حالياً: image_url فقط (غالباً بوستر ترويجي في البيانات الحالية).
  /// عند إضافة portrait نظيف لاحقاً: غيّر هذا الـ getter فقط دون إعادة تصميم الـ Hero.
  String get _heroPortraitUrl => doctor.imageUrl;

  DoctorLeaveDisplay get _leave => DoctorLeaveDisplay.fromDoctor(doctor);

  bool get _onLeave => _leave.isOnLeave;

  bool get _actionsEnabled {
    final status = doctor.bookingStatus.trim().toLowerCase();
    // حالة الحجز (حضوري / مكتمل / غير متاح للموعد) والإجازة لا تمنعان الاتصال أو واتساب.
    // قد يرد السكرتير. الإجازة تُوضَّح عند زر الموعد وفي مربع التواجد.
    if (status == 'walk_in_only' ||
        status == 'full' ||
        status == 'unavailable') {
      return true;
    }
    return doctor.available;
  }

  bool get _canContact => _actionsEnabled;

  /// الويب: طبيب «حضوري فقط» ما يطلعله اتصال ولا واتساب (المراجعة بالحضور).
  bool get _walkInOnlyNoContact =>
      DoctorItem.walkInBlocksContact(doctor.bookingStatus);

  Future<void> _loadRatings() async {
    final summaryFuture = _engagement.fetchRatingSummary(widget.doctor.id);
    final mineFuture = _engagement.fetchMyRating(widget.doctor.id);
    final summary = await summaryFuture;
    final mine = await mineFuture;
    if (!mounted) return;
    setState(() {
      _rating = summary;
      _myRating = mine;
    });
  }

  Future<void> _submitRating(int value) async {
    if (_ratingBusy) return;
    setState(() => _ratingBusy = true);
    try {
      final summary = await _engagement.submitRating(
        doctorId: widget.doctor.id,
        rating: value,
      );
      if (!mounted) return;
      setState(() {
        _rating = summary;
        _myRating = value;
        _ratingBusy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حفظ تقييمك بنجاح')));
    } catch (e, st) {
      debugPrint(
        'Doctor rating save failed doctor_id=${widget.doctor.id} '
        'rating=$value: $e\n$st',
      );
      if (!mounted) return;
      setState(() => _ratingBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التقييم. حاول مرة أخرى.')),
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _onBookingPressed() {
    if (_onLeave) {
      _showMessage(DoctorGender.onLeaveNow(doctor.gender));
      return;
    }
    switch (doctor.bookingStatus) {
      case 'full':
        _showMessage(DoctorGender.bookingFull(doctor.gender));
        return;
      case 'walk_in_only':
        _showMessage(DoctorGender.walkInOnly(doctor.gender));
        return;
      case 'unavailable':
        _showMessage(DoctorGender.currentlyUnavailable(doctor.gender));
        return;
      default:
        _showMessage('يمكنك الحجز عبر الاتصال أو واتساب حسب حالة الطبيب');
    }
  }

  void _share() {
    DoctorCardLinks.shareDoctorCard(
      doctorId: doctor.id,
      doctorName: doctor.name,
    );
  }

  void _showDigitalCard() {
    DoctorCardLinks.showDigitalDoctorCard(
      context,
      doctorId: doctor.id,
      doctorName: doctor.name,
      specialty: doctor.specialty,
      imageUrl: doctor.imageUrl,
      verified: doctor.ghadeerBadge,
    );
  }

  /// سطر داعم قصير تحت الاختصاص — من بيانات حقيقية فقط.
  String get _heroSupportLine {
    final short = doctor.shortDescription.trim();
    if (short.isNotEmpty && !_sameText(short, doctor.specialty)) return short;
    final quote = doctor.profileQuote.trim();
    if (quote.isNotEmpty) return quote;
    return '';
  }

  /// نفس الكلام؟ (نتجاهل المسافات والتشكيل) — حتى ما يتكرر الاختصاص مرتين.
  static bool _sameText(String a, String b) {
    String n(String x) => x
        .replaceAll(RegExp(r'[\s\.\u064B-\u0652…]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا');
    final x = n(a);
    final y = n(b);
    if (x.isEmpty || y.isEmpty) return false;
    return x == y || x.startsWith(y) || y.startsWith(x);
  }

  /// رسالة إجازة الطبيب (فترة من–إلى) للعرض تحت الكتابة.
  String get _leaveMessage {
    if (!_onLeave) return '';
    final from = _leave.from;
    final to = _leave.to;
    if (from != null && to != null) {
      final f = '${from.day}/${from.month}/${from.year}';
      final t = '${to.day}/${to.month}/${to.year}';
      if (from == to) return DoctorGender.onLeaveToday(doctor.gender, f);
      return DoctorGender.onLeaveRange(doctor.gender, f, t);
    }
    return DoctorGender.onLeaveOrAway(doctor.gender);
  }

  double _profileMaxWidthFor(double screenWidth) {
    if (screenWidth >= 1100) return 720;
    if (screenWidth >= 800) return 660;
    if (screenWidth >= 600) return 600;
    return screenWidth;
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final maxW = _profileMaxWidthFor(screenW);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // أي رجوع (زر النظام أو المسار) يوقف الصوت فورًا.
        unawaited(_voice.stop());
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _pageBg,
          body: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildHero()),
                        SliverToBoxAdapter(child: _buildEngagementRow()),
                        if (doctor.showBookingButton)
                          SliverToBoxAdapter(child: _buildBookingButton()),
                        SliverToBoxAdapter(child: _buildAddressCard()),
                        SliverToBoxAdapter(child: _buildAboutCard()),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: _buildBottomBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── الهوية (الشكل المعتمد): صورة كبيرة يمين، والاسم والشعار والدوام يسار ──

  Widget _heroIconBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: GhadeerTokens.surface,
        shape: const CircleBorder(side: BorderSide(color: GhadeerTokens.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: color ?? GhadeerTokens.ink),
          ),
        ),
      ),
    );
  }

  /// حالة اليوم على الصورة — نفس منطق بطاقة القائمة (عطلة اليوم، الفترة…).
  ({String text, Color color}) _status() {
    if (_onLeave) {
      return (text: 'في إجازة', color: GhadeerTokens.warn);
    }
    final s = doctorTodayStatus(doctor);
    return (text: s.text, color: s.color);
  }

  Widget _buildHero() {
    final status = _status();
    final weekDays = parseDoctorWeekSchedule(
      workingDays: doctor.workingDays,
      workingHours: doctor.workingHours,
    );
    final leaveMessage = _leaveMessage;
    final showPresencePanel = leaveMessage.isNotEmpty || weekDays.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusXl),
            border: Border.all(color: GhadeerTokens.line),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), _heroBase],
            ),
            boxShadow: [
              BoxShadow(
                color: GhadeerTokens.deepWater.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final innerW = constraints.maxWidth;
              // الصورة بإطار خاص يمين، والكتابة بعمود مستقل يسار — ماكو تداخل.
              final photoW = (innerW * 0.42).clamp(124.0, 200.0);
              final photoH = photoW * 1.32;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildHeroTextColumn()),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: photoW,
                          height: photoH,
                          child: _buildHeroPhoto(status),
                        ),
                      ],
                    ),
                  ),
                  if (showPresencePanel) ...[
                    const SizedBox(height: 12),
                    _HeroPresencePanel(
                      leaveMessage: leaveMessage,
                      weekDays: weekDays,
                      today: _todayName(DateTime.now()),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// عمود الكتابة: المفضلة والمشاركة → شارة المنصة → شعار الغدير → الاسم.
  Widget _buildHeroTextColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _heroIconBtn(
              icon: _favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: _favorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
              color: _favorite ? const Color(0xFFE25555) : GhadeerTokens.ink,
              onTap: () {
                ghadeerToggleFeedback();
                setState(() => _favorite = !_favorite);
                widget.onToggleFavorite();
              },
            ),
            const SizedBox(width: 8),
            _heroIconBtn(
              icon: Icons.ios_share_rounded,
              label: 'مشاركة البطاقة',
              onTap: _share,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (doctor.ghadeerBadge) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: _GhadeerVerifiedPill(),
          ),
          const SizedBox(height: 8),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: GhadeerBrandHeaderRow(logoSize: 40),
        ),
        const SizedBox(height: 6),
        const Text(
          'التشخيص قبل كل شيء',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.left,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: GhadeerTokens.tealDeep,
          ),
        ),
        if (doctor.logoUrl.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: EntityOptionalLogo(url: doctor.logoUrl),
          ),
        ],
        const SizedBox(height: 14),
        DoctorCardTripleTap(
          onTripleTap: () => unawaited(_openCardAccess()),
          child: _HeroDoctorNameSpecialty(
            key: const Key('hero_doctor_name_specialty'),
            name: _doctorProfileDisplayName(doctor.name),
            specialty: doctor.specialty,
            supportLine: _heroSupportLine,
          ),
        ),
      ],
    );
  }

  /// الصورة كاملة بشاشة غامقة، تتكبّر بالأصابع.
  void _openPhoto() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: GhadeerResolvedImage(
                    _heroPortraitUrl,
                    fit: BoxFit.contain,
                    cacheWidth: 1400,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 12,
              right: 16,
              child: GhadeerBackButton(
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// إطار الصورة: الرجوع فوق يمين، وحالة اليوم تحت.
  Widget _buildHeroPhoto(({String text, Color color}) status) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // الضغط على الصورة يكبّرها (بعض الصور بوسترات بيها كتابة).
          GestureDetector(
            key: const Key('doctor_photo_open'),
            onTap: _heroPortraitUrl.trim().isEmpty ? null : _openPhoto,
            child: _HeroDoctorImage(imageUrl: _heroPortraitUrl),
          ),
          // الرجوع أعلى اليمين — موحّد بكل التطبيق.
          Positioned(
            top: 8,
            right: 8,
            child: GhadeerBackButton(
              onPressed: () => unawaited(_stopSpeechAndPop()),
            ),
          ),
          Positioned(
            top: 8 + 44 + 6,
            right: 8,
            child: OwnerAccess.faint(onTap: () => unawaited(_openCardAccess())),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: _HeroStatusChip(text: status.text, color: status.color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── التقييم ومواقع التواصل ───────────────────────────────────────────

  Widget _buildEngagementRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: GhadeerTokens.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                side: const BorderSide(color: GhadeerTokens.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
                onTap: () => showEntitySocialSheet(
                  context,
                  links: doctor.social,
                  title: 'مواقع تواصل ${doctor.name}',
                ),
                child: const SizedBox(
                  height: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color: GhadeerTokens.tealDeep,
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'مواقع التواصل',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: GhadeerTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CompactRatingAction(
              average: _rating.average,
              count: _rating.count,
              myRating: _myRating,
              busy: _ratingBusy,
              onRate: _submitRating,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: const Key('doctor-booking-button'),
          onPressed: _onBookingPressed,
          icon: const Icon(Icons.event_available_rounded, size: 18),
          label: const Text('حجز موعد'),
          style: OutlinedButton.styleFrom(
            foregroundColor: GhadeerTokens.tealDeep,
            backgroundColor: GhadeerTokens.surface,
            side: const BorderSide(color: GhadeerTokens.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
            ),
          ),
        ),
      ),
    );
  }

  // ── بطاقات المحتوى ───────────────────────────────────────────────────

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: GhadeerTokens.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GhadeerTokens.heading),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  /// اسم اليوم الحالي بنفس صيغة الجدول — لتمييزه بمربع الدوام.
  static String _todayName(DateTime now) => switch (now.weekday) {
    DateTime.saturday => 'السبت',
    DateTime.sunday => 'الأحد',
    DateTime.monday => 'الاثنين',
    DateTime.tuesday => 'الثلاثاء',
    DateTime.wednesday => 'الأربعاء',
    DateTime.thursday => 'الخميس',
    _ => 'الجمعة',
  };

  // ── العنوان ─────────────────────────────────────────────────────────

  Widget _buildAddressCard() {
    final location = doctor.location.trim();
    if (location.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: GhadeerTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          side: const BorderSide(color: GhadeerTokens.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusLg),
          onTap: () => LabCardLinks.openMapUrl(location),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: GhadeerTokens.tealWash,
                    borderRadius: BorderRadius.circular(GhadeerTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: GhadeerTokens.tealDeep,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('عنوان العيادة', style: GhadeerTokens.caption),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: GhadeerTokens.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'الخريطة',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: GhadeerTokens.tealDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── النبذة والخدمات ─────────────────────────────────────────────────

  Widget _buildAboutCard() {
    final bio = doctor.bio.trim();
    return _section(
      title: 'نبذة عن الطبيب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _voice,
            builder: (context, _) {
              final speaking = _voice.isSpeaking;
              final canSpeak = _bioSpeechText.isNotEmpty;
              return Material(
                color: speaking
                    ? GhadeerTokens.tealWash
                    : GhadeerTokens.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: canSpeak
                        ? _actionBlue.withValues(alpha: 0.35)
                        : GhadeerTokens.line,
                  ),
                ),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: canSpeak ? () => unawaited(_toggleBioSpeech()) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          speaking
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 18,
                          color: canSpeak ? _actionBlue : _muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          speaking ? 'إيقاف' : 'اسمع النبذة',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: canSpeak ? _navy : _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            bio.isNotEmpty ? bio : 'لم تتم إضافة نبذة عن الطبيب حتى الآن.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.8,
              fontWeight: FontWeight.w400,
              color: bio.isNotEmpty ? _navy : _muted,
            ),
          ),
          if (doctor.services.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('الخدمات الطبية', style: GhadeerTokens.heading),
            const SizedBox(height: 8),
            Text(
              doctor.services.trim(),
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.7,
                fontWeight: FontWeight.w400,
                color: _navy,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── الشريط الثابت تحت: اتصال · واتساب · QR ───────────────────────────

  Widget _buildBottomBar() {
    final actions = <Widget>[];
    if (_walkInOnlyNoContact) {
      actions.add(
        Expanded(
          child: Container(
            key: const Key('doctor-walk-in-only-note'),
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: GhadeerTokens.mist,
              borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
              border: Border.all(color: GhadeerTokens.line),
            ),
            child: Text(
              '${DoctorGender.walkInOnly(doctor.gender)} — بدون حجز بالهاتف',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GhadeerTokens.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
    if (doctor.showCallButton && !_walkInOnlyNoContact) {
      actions.add(
        Expanded(
          flex: 2,
          child: _BarAction(
            key: const Key('doctor-call-button'),
            icon: Icons.phone_in_talk_rounded,
            label: 'اتصال',
            color: GhadeerTokens.teal,
            onTap: (!_canContact || doctor.phone.trim().isEmpty)
                ? null
                : () {
                    _stats.recordCallTap(doctor.id);
                    launchClinicCall(doctor.phone);
                  },
          ),
        ),
      );
    }
    if (doctor.showWhatsAppButton && !_walkInOnlyNoContact) {
      if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
      actions.add(
        Expanded(
          flex: 2,
          child: _BarAction(
            key: const Key('doctor-whatsapp-button'),
            icon: Icons.chat_rounded,
            label: 'واتساب',
            color: GhadeerTokens.whatsapp,
            onTap: (!_canContact || doctor.whatsapp.trim().isEmpty)
                ? null
                : () async {
                    _stats.recordWhatsAppTap(doctor.id);
                    await WhatsAppNamePrompt.maybeAsk(
                      context,
                      profileService: _profileService,
                    );
                    final message = await WhatsAppMessageSettingsService()
                        .buildPrefill(
                          providerTitle: doctor.name,
                          profileService: _profileService,
                          section: WhatsAppSection.doctors,
                        );
                    await launchClinicWhatsApp(
                      doctor.whatsapp,
                      message: message,
                    );
                  },
          ),
        ),
      );
    }
    if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
    actions.add(
      Semantics(
        button: true,
        label: 'البطاقة الرقمية QR',
        excludeSemantics: true,
        child: Material(
          color: GhadeerTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
            side: const BorderSide(color: GhadeerTokens.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
            onTap: _showDigitalCard,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.qr_code_2_rounded, color: GhadeerTokens.ink),
            ),
          ),
        ),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: GhadeerTokens.surface,
        border: Border(top: BorderSide(color: GhadeerTokens.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: actions),
        ),
      ),
    );
  }
}

/// عرض اسم الطبيب في الـ Hero.
/// إن احتوى الاسم على «استشاري» يُعرض كما هو من الإدارة؛ وإلا يُختصر إلى «د.».
String _doctorProfileDisplayName(String raw) {
  var body = raw.trim();
  if (body.isEmpty) return 'طبيب';

  // مثال: «الدكتور الاستشاري علي فليح جودة» — يبقى كاملًا.
  if (body.contains('استشاري') || body.contains('استشارية')) {
    return body;
  }

  body = body
      .replaceFirst(
        RegExp(
          r'^(?:ال)?د(?:\.|كتور|كتورة)?\s+|^د\.\s*|'
          r'^(?:الدكتور|الدكتورة|دكتور|دكتورة)\s+',
        ),
        '',
      )
      .trim();

  if (body.isEmpty) return 'طبيب';
  if (RegExp(r'^د\.\s*').hasMatch(body)) return body;
  return 'د. $body';
}

/// الاسم + الاختصاص في الهوية (يسار، تحت شعار الغدير).
class _HeroDoctorNameSpecialty extends StatelessWidget {
  const _HeroDoctorNameSpecialty({
    super.key,
    required this.name,
    required this.specialty,
    required this.supportLine,
  });

  final String name;
  final String specialty;
  final String supportLine;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final compact = w < 168;
        final nameSize = compact ? 17.5 : 20.0;
        final specialtySize = compact ? 13.0 : 14.0;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: w.isFinite ? w : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.trim().isEmpty ? 'طبيب' : name.trim(),
                  maxLines: 3,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: nameSize,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: GhadeerTokens.ink,
                  ),
                ),
                if (specialty.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    specialty.trim(),
                    maxLines: 3,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: specialtySize,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: GhadeerTokens.tealDeep,
                    ),
                  ),
                ],
                if (supportLine.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    supportLine.trim(),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: compact ? 11.0 : 12.0,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: GhadeerTokens.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// الدوام بشكل مختصر: «يومياً مساءً» + ملاحظات (عطلة / فترة مختلفة)،
/// وجدول الأيام كامل مخفي يفتح بزر «كل الأيام».
class _HeroPresencePanel extends StatefulWidget {
  const _HeroPresencePanel({
    required this.leaveMessage,
    required this.weekDays,
    required this.today,
  });

  final String leaveMessage;
  final List<DoctorWeekDayEntry> weekDays;
  final String today;

  @override
  State<_HeroPresencePanel> createState() => _HeroPresencePanelState();
}

class _HeroPresencePanelState extends State<_HeroPresencePanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final leave = widget.leaveMessage.trim();
    if (leave.isNotEmpty) {
      return _box(
        color: GhadeerTokens.warnWash,
        border: const Color(0xFFEBD3AE),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.event_busy_rounded,
              size: 20,
              color: GhadeerTokens.warn,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                leave,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: GhadeerTokens.warn,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final summary = summarizeDoctorWeek(widget.weekDays);
    DoctorWeekDayEntry? todayEntry;
    for (final e in widget.weekDays) {
      if (e.day == widget.today) todayEntry = e;
    }
    final todayText = todayEntry == null
        ? null
        : (todayEntry.isOff ? 'اليوم عطلة' : 'اليوم ${todayEntry.status}');

    return _box(
      color: Colors.white.withValues(alpha: 0.92),
      border: GhadeerTokens.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: GhadeerTokens.tealWash,
                  borderRadius: BorderRadius.circular(GhadeerTokens.radiusSm),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: GhadeerTokens.tealDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الدوام', style: GhadeerTokens.caption),
                    Text(
                      summary.headline,
                      key: const Key('doctor_schedule_headline'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: GhadeerTokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (todayText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: todayEntry!.isOff
                        ? GhadeerTokens.warnWash
                        : GhadeerTokens.tealWash,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    todayText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: todayEntry.isOff
                          ? GhadeerTokens.warn
                          : GhadeerTokens.tealDeep,
                    ),
                  ),
                ),
            ],
          ),
          if (summary.notes.isNotEmpty || summary.offDays.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final note in summary.notes)
                  _noteChip(
                    note,
                    GhadeerTokens.tealDeep,
                    GhadeerTokens.tealWash,
                  ),
                if (summary.offDays.isNotEmpty)
                  _noteChip(
                    'عطلة: ${summary.offDays.join('، ')}',
                    GhadeerTokens.warn,
                    GhadeerTokens.warnWash,
                  ),
              ],
            ),
          ],
          if (widget.weekDays.length > 1) ...[
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                key: const Key('doctor_schedule_toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(_expanded ? 'إخفاء الأيام' : 'كل الأيام'),
                style: TextButton.styleFrom(
                  foregroundColor: GhadeerTokens.tealDeep,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _HeroWeekSchedule(
                        entries: widget.weekDays,
                        today: widget.today,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }

  Widget _box({
    required Color color,
    required Color border,
    required Widget child,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }

  Widget _noteChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// جدول أيام التواجد: صفوف متقابلة (سبت↔ثلاثاء …) ثم الجمعة في المنتصف.
class _HeroWeekSchedule extends StatelessWidget {
  const _HeroWeekSchedule({required this.entries, required this.today});

  final List<DoctorWeekDayEntry> entries;
  final String today;

  static const _pairs = <(String, String)>[
    ('السبت', 'الثلاثاء'),
    ('الأحد', 'الأربعاء'),
    ('الاثنين', 'الخميس'),
  ];

  DoctorWeekDayEntry? _byDay(String day) {
    for (final e in entries) {
      if (e.day == day) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final friday = _byDay('الجمعة');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _pairs.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            _pairedRow(_byDay(_pairs[i].$1), _byDay(_pairs[i].$2)),
          ],
          if (friday != null) ...[
            const SizedBox(height: 3),
            Align(
              alignment: Alignment.center,
              child: _dayChip(friday, shrinkWrap: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pairedRow(DoctorWeekDayEntry? sideA, DoctorWeekDayEntry? sideB) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: sideA == null ? const SizedBox.shrink() : _dayChip(sideA),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: sideB == null ? const SizedBox.shrink() : _dayChip(sideB),
        ),
      ],
    );
  }

  Widget _dayChip(DoctorWeekDayEntry entry, {bool shrinkWrap = false}) {
    final isToday = entry.day == today;
    final statusColor = entry.isOff
        ? GhadeerTokens.warn
        : GhadeerTokens.tealDeep;
    final status = Text(
      entry.status,
      maxLines: 1,
      overflow: shrinkWrap ? TextOverflow.ellipsis : TextOverflow.visible,
      style: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: statusColor,
      ),
    );
    final row = Row(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: shrinkWrap
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Text(
          entry.day,
          style: TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w800,
            color: GhadeerTokens.ink,
          ),
        ),
        const SizedBox(width: 5),
        if (shrinkWrap)
          status
        else
          // تصغير بدل القص: «السبت م…» كانت تخفي الدوام على 375px.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: status,
            ),
          ),
      ],
    );
    // اليوم الحالي بخلفية فيروزية خفيفة.
    return Semantics(
      label: isToday ? 'اليوم' : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: isToday
            ? BoxDecoration(
                color: GhadeerTokens.tealWash,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: GhadeerTokens.teal.withValues(alpha: 0.45),
                ),
              )
            : null,
        child: row,
      ),
    );
  }
}

class _GhadeerVerifiedPill extends StatelessWidget {
  const _GhadeerVerifiedPill();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 186),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        decoration: BoxDecoration(
          color: GhadeerTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GhadeerTokens.line),
        ),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 15, color: GhadeerTokens.teal),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'طبيب موثّق',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: GhadeerTokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حالة الطبيب اليوم — حبّة بيضاء صغيرة أسفل الصورة.
class _HeroStatusChip extends StatelessWidget {
  const _HeroStatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// لون الماي الفاتح لخلفية الهوية.
const _heroBase = Color(0xFFEFF7F6);

/// صورة الطبيب داخل إطارها — ظل خفيف تحت حتى تبين حبّة الحالة.
class _HeroDoctorImage extends StatelessWidget {
  const _HeroDoctorImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final photo = imageUrl.trim().isNotEmpty
        ? GhadeerResolvedImage(
            imageUrl,
            fit: BoxFit.cover,
            // تركيز أعلى قليلاً لإظهار الوجه بوضوح دون قصّ مفرط.
            alignment: const Alignment(0, -0.35),
            cacheWidth: 800,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const _PortraitFallback(),
          )
        : const _PortraitFallback();

    return Stack(
      fit: StackFit.expand,
      children: [
        photo,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0x330D3B42), Color(0x000D3B42)],
              stops: [0.0, 0.35],
            ),
          ),
        ),
      ],
    );
  }
}

/// زر بالشريط السفلي (اتصال / واتساب) — InkWell واحد فقط.
class _BarAction extends StatelessWidget {
  const _BarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = enabled ? color : GhadeerTokens.line;
    final fg = enabled ? Colors.white : GhadeerTokens.inkFaint;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fg,
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
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _heroBase,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 72,
        color: Color(0xFF8DBDB8),
      ),
    );
  }
}

class _CompactRatingAction extends StatelessWidget {
  const _CompactRatingAction({
    required this.average,
    required this.count,
    required this.myRating,
    required this.busy,
    required this.onRate,
  });

  final double average;
  final int count;
  final int? myRating;
  final bool busy;
  final Future<void> Function(int value) onRate;

  @override
  Widget build(BuildContext context) {
    final label = count > 0 ? average.toStringAsFixed(1) : '—';

    return Material(
      color: GhadeerTokens.surface,
      borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GhadeerTokens.radiusMd),
          border: Border.all(color: GhadeerTokens.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: GhadeerTokens.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final selected = (myRating ?? 0) >= star;
                return InkWell(
                  onTap: busy ? null : () => onRate(star),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 14,
                      color: const Color(0xFFE89B28),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 2),
            const Text(
              'تقييم',
              maxLines: 1,
              style: TextStyle(
                color: Color(0xFF5B6C70),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
