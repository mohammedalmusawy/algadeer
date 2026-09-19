import 'dart:async';

import 'package:flutter/material.dart';

import '../models/lab_models.dart';
import '../services/app_stats_service.dart';
import '../voice/lab_packages_speech.dart';
import '../voice/voice_response_controller.dart';
import 'labs_service.dart';
import 'widgets/package_hero_image.dart';
import '../widgets/clinic_app_bar.dart';

class LabPackageDetailPage extends StatefulWidget {
  const LabPackageDetailPage({
    super.key,
    required this.packageId,
    this.labName = '',
  });

  final String packageId;
  final String labName;

  @override
  State<LabPackageDetailPage> createState() => _LabPackageDetailPageState();
}

class _LabPackageDetailPageState extends State<LabPackageDetailPage> {
  final _service = LabsService();
  final _stats = AppStatsService();
  final _voice = VoiceResponseController();
  LabPackageItem? _package;
  bool _loading = true;
  String? _error;
  bool _speechBusy = false;
  bool _viewRecorded = false;

  static const _navy = Color(0xFF123B42);
  static const _actionBlue = Color(0xFF1197A8);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _recordViewOnce(String packageId) async {
    if (_viewRecorded || packageId.isEmpty) return;
    _viewRecorded = true;
    await _stats.recordPackageProfileView(packageId);
  }

  @override
  void dispose() {
    unawaited(_voice.stop());
    _voice.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final package = await _service.fetchPackageDetails(widget.packageId);
      if (!mounted) return;
      setState(() {
        _package = package;
        _loading = false;
      });
      if (package.id.isNotEmpty) {
        unawaited(_recordViewOnce(package.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل تفاصيل الباقة';
      });
    }
  }

  Future<void> _stopSpeechAndPop() async {
    await _voice.stop();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _togglePackageSpeech() async {
    if (_voice.isSpeaking || _speechBusy) {
      await _voice.stop();
      _speechBusy = false;
      return;
    }
    final package = _package;
    if (package == null) return;

    final text = LabPackagesSpeech.buildOne(
      package,
      labName: widget.labName,
    );
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد تفاصيل صوتية لهذه الباقة حالياً.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _speechBusy = true;
    try {
      await _voice.speak(text);
    } finally {
      _speechBusy = false;
    }
  }

  Widget _speakButton() {
    return AnimatedBuilder(
      animation: _voice,
      builder: (context, _) {
        final speaking = _voice.isSpeaking;
        return Material(
          color: speaking ? const Color(0xFFE6F8F6) : Colors.white,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => unawaited(_togglePackageSpeech()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: BorderSide(
                    color: _actionBlue.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                    size: 18,
                    color: _actionBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    speaking ? 'إيقاف' : 'اسمع الباقة',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final package = _package;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_stopSpeechAndPop());
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: ClinicAppBar(
            title: Text(package?.name ?? 'تفاصيل الباقة'),
            backgroundColor: const Color(0xFF0FAFA3),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => unawaited(_stopSpeechAndPop()),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : package == null
              ? const Center(child: Text('الباقة غير موجودة'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: PackageHeroImage(
                          packageName: package.name,
                          imageUrl: package.imageUrl,
                          isFeatured: package.isFeatured,
                          width: double.infinity,
                          height: 180,
                          borderRadius: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE4EEEE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: widget.labName.isNotEmpty
                                    ? Text(
                                        widget.labName,
                                        style: const TextStyle(
                                          color: Color(0xFF0FAFA3),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              _speakButton(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            package.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF123B42),
                            ),
                          ),
                          if (package.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              package.description,
                              style: const TextStyle(
                                height: 1.55,
                                color: Color(0xFF53636D),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          PackagePriceBlock(package: package),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'التحاليل المشمولة في الباقة',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123B42),
                      ),
                    ),
                    if (package.analyses.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${package.analyses.length} تحليل',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF708084),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (package.analyses.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4EEEE)),
                        ),
                        child: const Text(
                          'لم تُضف تحاليل لهذه الباقة بعد',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF708084)),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE4EEEE)),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < package.analyses.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF0F4F4),
                                ),
                              _UserAnalysisRow(analysis: package.analyses[i]),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _UserAnalysisRow extends StatelessWidget {
  const _UserAnalysisRow({required this.analysis});

  final AnalysisItem analysis;

  @override
  Widget build(BuildContext context) {
    final arabic = analysis.arabicDisplayName;
    final english = analysis.englishDisplayName;
    final showEnglish =
        english.isNotEmpty && english.toLowerCase() != arabic.toLowerCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.science_outlined,
              size: 20,
              color: Color(0xFF0FAFA3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              arabic,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF123B42),
                height: 1.3,
              ),
            ),
          ),
          if (showEnglish) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                english,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5B6C70),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
