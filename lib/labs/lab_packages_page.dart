import 'package:flutter/material.dart';

import '../models/lab_models.dart';
import '../utils/contact_launch.dart';
import 'lab_package_detail_page.dart';
import 'labs_service.dart';
import 'widgets/lab_package_card.dart';
import '../widgets/clinic_app_bar.dart';

class LabPackagesPage extends StatefulWidget {
  const LabPackagesPage({super.key, required this.lab});

  final LabItem lab;

  @override
  State<LabPackagesPage> createState() => _LabPackagesPageState();
}

class _LabPackagesPageState extends State<LabPackagesPage> {
  final _service = LabsService();
  List<LabPackageItem> _packages = [];
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
      final packages = await _service.fetchPublicPackages(widget.lab.id);
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الباقات';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lab = widget.lab;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: Text(lab.name),
          backgroundColor: const Color(0xFF123B42),
          foregroundColor: Colors.white,
          actions: [
            if (lab.phone.trim().isNotEmpty)
              IconButton(
                tooltip: 'اتصال',
                onPressed: () => launchClinicCall(lab.phone),
                icon: const Icon(Icons.phone_outlined),
              ),
            if (lab.whatsapp.trim().isNotEmpty)
              IconButton(
                tooltip: 'واتساب',
                onPressed: () => launchClinicWhatsApp(lab.whatsapp),
                icon: const Icon(Icons.chat_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 200,
                        height: 48,
                        child: FilledButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      if (lab.description.trim().isNotEmpty ||
                          lab.address.trim().isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3FAF9),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (lab.description.trim().isNotEmpty)
                                Text(
                                  lab.description,
                                  style: const TextStyle(
                                    height: 1.5,
                                    color: Color(0xFF42555A),
                                  ),
                                ),
                              if (lab.address.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 18,
                                      color: Color(0xFF0FAFA3),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(lab.address)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      const Text(
                        'الباقات المتوفرة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF123B42),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_packages.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              'لا توجد باقات مفعّلة لهذا المختبر حالياً',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._packages.map(
                          (pkg) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LabPackageCard(
                              package: pkg,
                              onOpen: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LabPackageDetailPage(
                                      packageId: pkg.id,
                                      labName: lab.name,
                                    ),
                                  ),
                                );
                              },
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
