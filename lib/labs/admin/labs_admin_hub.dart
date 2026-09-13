import 'package:flutter/material.dart';

import 'analyses_admin_page.dart';
import 'labs_admin_page.dart';
import 'packages_admin_page.dart';
import '../../widgets/clinic_app_bar.dart';

class LabsAdminHubPage extends StatelessWidget {
  const LabsAdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F8),
        appBar: ClinicAppBar(
          title: const Text('إدارة المختبرات'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _tile(
                context,
                icon: Icons.biotech_rounded,
                title: 'المختبرات',
                subtitle: 'إضافة وتعديل المختبرات والشعارات',
                page: const LabsAdminPage(),
              ),
              _tile(
                context,
                icon: Icons.science_rounded,
                title: 'الباقات',
                subtitle: 'باقات التحاليل والأسعار والخصومات',
                page: const PackagesAdminPage(),
              ),
              _tile(
                context,
                icon: Icons.bloodtype_outlined,
                title: 'قاموس التحاليل',
                subtitle: 'إضافة وتحرير التحاليل لإعادة استخدامها',
                page: const AnalysesAdminPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE4EEEE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F8F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: const Color(0xFF0FAFA3), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Color(0xFF123B42),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF5B6C70),
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF9AA6A8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
