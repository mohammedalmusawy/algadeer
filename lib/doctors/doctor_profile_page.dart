import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../branding/ghadeer_brand_mark.dart';
import '../labs/lab_card_links.dart';
import '../models/doctor_item.dart';
import '../services/app_stats_service.dart';
import '../companion/personal_companion_profile_service.dart';
import '../settings/whatsapp_message_settings.dart';
import '../utils/contact_launch.dart';
import '../voice/voice_response_controller.dart';
import 'doctor_availability_service.dart';
import 'doctor_card_links.dart';
import 'doctor_engagement_service.dart';
import 'doctor_gender.dart';

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
  DoctorRatingSummary _rating = const DoctorRatingSummary();
  int? _myRating;
  bool _ratingBusy = false;
  bool _bioSpeechBusy = false;

  // هوية الغدير الطبية — Accent وليس إغراقًا.
  static const _navy = Color(0xFF123B42);
  static const _actionBlue = Color(0xFF1197A8);
  static const _muted = Color(0xFF5B6C70);
  static const _pageBg = Color(0xFFF7FBFC);

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

  DoctorItem get doctor => widget.doctor;

  /// مصدر صورة الـ Hero الحالي.
  /// حالياً: image_url فقط (غالباً بوستر ترويجي في البيانات الحالية).
  /// عند إضافة portrait نظيف لاحقاً: غيّر هذا الـ getter فقط دون إعادة تصميم الـ Hero.
  String get _heroPortraitUrl => doctor.imageUrl;

  DoctorLeaveDisplay get _leave => DoctorLeaveDisplay.fromDoctor(doctor);

  bool get _onLeave => _leave.isOnLeave;

  bool get _actionsEnabled {
    if (_onLeave) return false;
    final status = doctor.bookingStatus.trim().toLowerCase();
    if (status == 'full') return true;
    if (status == 'walk_in_only' || status == 'unavailable') return false;
    return doctor.available;
  }

  bool get _canContact => !_onLeave && _actionsEnabled;

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
    if (short.isNotEmpty) return short;
    final quote = doctor.profileQuote.trim();
    if (quote.isNotEmpty) return quote;
    return '';
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
                        SliverToBoxAdapter(child: _buildActions()),
                        SliverToBoxAdapter(child: _buildBioAndClinicAddress()),
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

  Widget _circleIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    bool mirrorIconLtr = false,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8EEF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: iconColor ?? _navy,
            textDirection: mirrorIconLtr ? TextDirection.ltr : null,
          ),
        ),
      ),
    );
  }

  /// Hero مطابق للمرجع: صورة مهيمنة يمينًا + هوية يسارًا + أزرار علوية.
  Widget _buildHero() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardW = constraints.maxWidth;
            final narrow = cardW < 400;
            // ارتفاع يكفي للاسم + الاختصاص + جدول الأيام العمودي.
            final heroH = (cardW * (narrow ? 1.02 : 0.90)).clamp(390.0, 520.0);
            // صورة أوضح على الموبايل مع الإبقاء على نسبة العرض دون تمديد.
            final imageW = cardW * (narrow ? 0.66 : 0.60);
            final showBadge = doctor.ghadeerBadge;
            // عمود اليسار الموحّد (رجوع → هوية → اسم → تواجد).
            final leftColW =
                (cardW * (narrow ? 0.52 : 0.48)).clamp(168.0, 220.0);
            final weekDays = parseDoctorWeekSchedule(
              workingDays: doctor.workingDays,
              workingHours: doctor.workingHours,
            );
            final leaveMessage = _leaveMessage;
            final showPresencePanel =
                leaveMessage.isNotEmpty || weekDays.isNotEmpty;

            return SizedBox(
              width: cardW,
              height: heroH,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.hardEdge,
                    children: [
                      const _HeroDepthBackground(),
                      Positioned(
                        top: 0,
                        bottom: -12,
                        right: -6,
                        width: imageW,
                        child: _HeroDoctorImage(imageUrl: _heroPortraitUrl),
                      ),
                      // عمود اليسار: مسافات متساوية بين الصفوف لملء ارتفاع الصورة يمينًا.
                      Positioned(
                        top: 10,
                        left: 12,
                        bottom: 12,
                        width: leftColW,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _circleIconBtn(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () => unawaited(_stopSpeechAndPop()),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (showBadge) ...[
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: _GhadeerVerifiedPill(),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: GhadeerBrandHeaderRow(),
                                  ),
                                ],
                              ),
                              const Text(
                                'التشخيص قبل كل شئ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.left,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A4F58),
                                ),
                              ),
                              _HeroDoctorNameSpecialty(
                                key: const Key(
                                  'hero_doctor_name_specialty',
                                ),
                                name: _doctorProfileDisplayName(
                                  doctor.name,
                                ),
                                specialty: doctor.specialty,
                                supportLine: _heroSupportLine,
                              ),
                              if (showPresencePanel)
                                _HeroPresencePanel(
                                  leaveMessage: leaveMessage,
                                  weekDays: weekDays,
                                ),
                            ],
                          ),
                        ),
                      ),
                      // يمين الهيدر: مشاركة بمحاذاة زر الرجوع، والتفضيل أسفلها مباشرة.
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _circleIconBtn(
                          icon: Icons.ios_share_rounded,
                          onTap: _share,
                        ),
                      ),
                      Positioned(
                        top: 10 + 38 + 8,
                        right: 10,
                        child: _circleIconBtn(
                          icon: _favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: _favorite
                              ? const Color(0xFFE25555)
                              : _navy,
                          onTap: () {
                            setState(() => _favorite = !_favorite);
                            widget.onToggleFavorite();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBioAndClinicAddress() {
    final bio = doctor.bio.trim();
    final location = doctor.location.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _voice,
            builder: (context, _) {
              final speaking = _voice.isSpeaking;
              final canSpeak = _bioSpeechText.isNotEmpty;
              return Row(
                children: [
                  const Expanded(
                    child: Text(
                      'نبذة عن الطبيب',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: speaking
                        ? const Color(0xFFE6F8F6)
                        : Colors.white,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: canSpeak ? () => unawaited(_toggleBioSpeech()) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: ShapeDecoration(
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: canSpeak
                                  ? _actionBlue.withValues(alpha: 0.35)
                                  : const Color(0xFFE8EEF2),
                            ),
                          ),
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: canSpeak ? _navy : _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            bio.isNotEmpty
                ? bio
                : 'لم تتم إضافة نبذة عن الطبيب حتى الآن.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.85,
              fontWeight: FontWeight.w500,
              color: bio.isNotEmpty
                  ? const Color(0xFF33454F)
                  : _muted,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'عنوان العيادة',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _navy,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => LabCardLinks.openMapUrl(location),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: _actionBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.55,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF33454F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    // تحت الهيرو مباشرة: اتصال | واتساب | تقييم — صغيرة وموحّدة اللون.
    const unified = Color(0xFF1197A8);
    final children = <Widget>[];

    if (doctor.showCallButton) {
      children.add(
        Expanded(
          child: _CompactContactAction(
            icon: Icons.phone_in_talk_rounded,
            title: 'اتصال',
            subtitle: 'مباشر',
            color: unified,
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

    if (doctor.showWhatsAppButton) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 8));
      children.add(
        Expanded(
          child: _CompactContactAction(
            icon: Icons.chat_rounded,
            title: 'واتساب',
            subtitle: 'مباشر',
            color: unified,
            onTap: (!_canContact || doctor.whatsapp.trim().isEmpty)
                ? null
                : () async {
                    _stats.recordWhatsAppTap(doctor.id);
                    final message =
                        await WhatsAppMessageSettingsService().buildPrefill(
                      providerTitle: doctor.name,
                      profileService: _profileService,
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

    if (children.isNotEmpty) children.add(const SizedBox(width: 8));
    children.add(
      Expanded(
        child: _CompactRatingAction(
          average: _rating.average,
          count: _rating.count,
          myRating: _myRating,
          busy: _ratingBusy,
          onRate: _submitRating,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
          if (doctor.showBookingButton) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _onBookingPressed,
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: const Text('حجز موعد'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: unified,
                  side: BorderSide(color: unified.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E8F9A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _showDigitalCard,
                icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                label: const Text(
                  'عرض QR الخاص بالطبيب',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            Container(width: 1, height: 28, color: Colors.white24),
            Expanded(
              child: TextButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                label: const Text(
                  'مشاركة البطاقة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ترتيب أيام الأسبوع للعرض والحفظ.
const doctorWeekDayOrder = <String>[
  'السبت',
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
];

/// يوم واحد في جدول التواجد: الاسم + الحالة (مساءً / عطلة / …).
typedef DoctorWeekDayEntry = ({String day, String status, bool isOff});

String? _periodLabelFromChunk(String chunk) {
  final n = chunk
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا');
  if (n.contains('عطل') || n.contains('اجاز') || n.contains('إجاز')) {
    return 'عطلة';
  }
  final hasMorning = n.contains('صباح');
  final hasEvening = n.contains('مساء');
  if (hasMorning && hasEvening) return 'صباحًا ومساءً';
  if (hasMorning) return 'صباحًا';
  if (hasEvening) return 'مساءً';
  return null;
}

/// يقرأ جدول الأسبوع من حقول الإدارة (متوافق مع الصيغ القديمة).
List<DoctorWeekDayEntry> parseDoctorWeekSchedule({
  required String workingDays,
  required String workingHours,
}) {
  final hours = workingHours.trim();
  final daysRaw = workingDays.trim();
  final parsed = <String, String>{};

  if (hours.isNotEmpty) {
    for (final day in doctorWeekDayOrder) {
      final match = RegExp(
        '$day\\s*:?\\s*([^،|]+)',
        unicode: true,
      ).firstMatch(hours);
      if (match == null) continue;
      final period = _periodLabelFromChunk(match.group(1) ?? '');
      if (period == null) continue;
      parsed[day] = period;
    }
  }

  if (parsed.isEmpty && daysRaw.isNotEmpty) {
    final allWeek = daysRaw.contains('كل أيام الأسبوع');
    for (final day in doctorWeekDayOrder) {
      if (allWeek || daysRaw.contains(day)) {
        parsed[day] = 'مساءً';
      }
    }
  }

  if (parsed.isEmpty) return const [];

  return [
    for (final day in doctorWeekDayOrder)
      if (parsed.containsKey(day))
        (
          day: day,
          status: parsed[day]!,
          isOff: parsed[day] == 'عطلة',
        ),
  ];
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

/// الاسم + نص الاختصاص في الـ Hero.
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
        final nameSize = compact ? 17.0 : 19.5;
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
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F2A3D),
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
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: const Color(0xFF0D8F9E),
                    ),
                  ),
                ],
                if (supportLine.trim().isNotEmpty) ...[
                  const SizedBox(height: 7),
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
                      color: const Color(0xFF5B6C70),
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

/// مستطيل أيام التواجد / رسالة الإجازة — بمحاذاة يسار هوية الغدير.
class _HeroPresencePanel extends StatelessWidget {
  const _HeroPresencePanel({
    required this.leaveMessage,
    required this.weekDays,
  });

  final String leaveMessage;
  final List<DoctorWeekDayEntry> weekDays;

  @override
  Widget build(BuildContext context) {
    final onLeave = leaveMessage.trim().isNotEmpty;
    final bg = onLeave ? const Color(0xFFFFF7EE) : const Color(0xFFF2F9FA);
    final border = onLeave ? const Color(0xFFE8D2B8) : const Color(0xFFD5E8EC);
    final accent = onLeave ? const Color(0xFFC47A2C) : const Color(0xFF1A4F58);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          onLeave ? 'حالة التواجد' : 'أيام تواجد الطبيب',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A4F58),
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: onLeave
                ? Text(
                    leaveMessage.trim(),
                    maxLines: 4,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  )
                : _HeroWeekSchedule(entries: weekDays),
          ),
        ),
      ],
    );
  }
}

/// جدول أيام التواجد: صفوف متقابلة (سبت↔ثلاثاء …) ثم الجمعة في المنتصف.
class _HeroWeekSchedule extends StatelessWidget {
  const _HeroWeekSchedule({required this.entries});

  final List<DoctorWeekDayEntry> entries;

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
            if (i > 0) const SizedBox(height: 4),
            _pairedRow(_byDay(_pairs[i].$1), _byDay(_pairs[i].$2)),
          ],
          if (friday != null) ...[
            const SizedBox(height: 6),
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
          child: sideA == null
              ? const SizedBox.shrink()
              : _dayChip(sideA),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: sideB == null
              ? const SizedBox.shrink()
              : _dayChip(sideB),
        ),
      ],
    );
  }

  Widget _dayChip(DoctorWeekDayEntry entry, {bool shrinkWrap = false}) {
    final statusColor = entry.isOff
        ? const Color(0xFFC47A2C)
        : const Color(0xFF2A6B75);
    final status = Text(
      entry.status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14.5,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: statusColor,
      ),
    );
    return Row(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: shrinkWrap
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Text(
          entry.day,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A4F58),
          ),
        ),
        const SizedBox(width: 6),
        if (shrinkWrap) status else Flexible(child: status),
      ],
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
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD7E6EE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // LTR صريح: الأيقونة الزرقاء تبقى على يسار الشارة حتى في صفحة RTL.
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 15, color: Color(0xFF1A73E8)),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'طبيب في منصة الغدير',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Color(0xFF123B42),
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

class _HeroDepthBackground extends StatelessWidget {
  const _HeroDepthBackground();

  // Soft Medical Blue / Ice Blue
  static const _ice = Color(0xFFEAF4F6);
  static const _iceSoft = Color(0xFFE5F1F4);
  static const _iceMist = Color(0xFFF5FBFC);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // قاعدة: أبيض → سماوي طبي فاتح جدًا مائل للرمادي
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                _ice,
                _iceSoft,
                _iceMist,
              ],
              stops: [0.0, 0.32, 0.68, 1.0],
            ),
          ),
        ),
        // بقع ضوء سماوية ناعمة قبل الـ Blur
        Positioned(
          right: -48,
          top: -10,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFD5EBEF).withValues(alpha: 0.85),
                  _ice.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: -70,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFCFE6EB).withValues(alpha: 0.55),
                  _iceSoft.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: -30,
          top: 70,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  _ice.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Blur طبي فخم يدمج التدرج والبقع
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: const ColoredBox(color: Color(0x33FFFFFF)),
          ),
        ),
      ],
    );
  }
}

/// صورة الطبيب داخل Hero — مدمجة مع الخلفية وليست داخل بطاقة صغيرة.
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
            alignment: const Alignment(0.15, -0.35),
            cacheWidth: 1200,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const _PortraitFallback(),
          )
        : const _PortraitFallback();

    return Stack(
      fit: StackFit.expand,
      children: [
        photo,
        // دمج ناعم مع Soft Medical Blue خلف الصورة الشفافة.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xEAEAF4F6),
                Color(0x66EAF4F6),
                Color(0x22FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.12, 0.34, 0.58],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xCCE5F1F4),
                Color(0x44EAF4F6),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.14, 0.40],
            ),
          ),
        ),
      ],
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 72,
        color: Color(0xFF9BB8B6),
      ),
    );
  }
}

class _CompactContactAction extends StatelessWidget {
  const _CompactContactAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4EEF0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFF123B42),
                fontWeight: FontWeight.w900,
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
                      selected
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
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

