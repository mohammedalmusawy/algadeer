import 'package:flutter/material.dart';

import '../models/lab_models.dart';
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
  LabPackageItem? _package;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل تفاصيل الباقة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = _package;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(package?.name ?? 'تفاصيل الباقة'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
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
                        if (widget.labName.isNotEmpty)
                          Text(
                            widget.labName,
                            style: const TextStyle(
                              color: Color(0xFF0FAFA3),
                              fontWeight: FontWeight.w700,
                            ),
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
