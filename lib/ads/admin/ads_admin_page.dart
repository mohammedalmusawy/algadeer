import 'package:flutter/material.dart';

import '../../widgets/clinic_app_bar.dart';
import '../ad_campaign.dart';
import '../ads_notify.dart';
import '../ads_service.dart';
import 'ad_campaign_form_page.dart';

class AdsAdminPage extends StatefulWidget {
  const AdsAdminPage({super.key});

  @override
  State<AdsAdminPage> createState() => _AdsAdminPageState();
}

class _AdsAdminPageState extends State<AdsAdminPage> {
  final _service = AdsService();
  List<AdCampaign> _items = [];
  bool _loading = true;
  String? _error;
  bool _tableMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _tableMissing = false;
    });
    try {
      final has = await _service.hasTable();
      if (!has) {
        if (!mounted) return;
        setState(() {
          _tableMissing = true;
          _items = [];
          _loading = false;
        });
        return;
      }
      final items = await _service.fetchAllForAdmin();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _openForm([AdCampaign? campaign]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdCampaignFormPage(campaign: campaign),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _toggle(AdCampaign c, bool value) async {
    try {
      await _service.setActive(c.id, value);
      if (value && !c.isActive) {
        await AdsNotify.notifyCampaignActivated(c.copyWith(isActive: true));
      }
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحديث: $e')),
      );
    }
  }

  Future<void> _delete(AdCampaign c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحملة؟'),
        content: Text(c.title.trim().isEmpty ? 'حملة بدون عنوان' : c.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.delete(c.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF0FAFA3);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('إدارة الإعلانات'),
          backgroundColor: teal,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: _tableMissing
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _openForm(),
                backgroundColor: teal,
                icon: const Icon(Icons.add),
                label: const Text('حملة جديدة'),
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tableMissing
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'نفّذ ملف supabase/ads_campaigns_schema.sql في SQL Editor أولًا.\nالتطبيق يعمل طبيعيًا بدون إعلانات حتى ذلك الحين.',
                    textAlign: TextAlign.center,
                    style: TextStyle(height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            : _error != null
            ? Center(child: Text(_error!))
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'لا توجد حملات بعد.\nأضف حملة متى احتجت — ولن يظهر شيء للمستخدم قبل التفعيل.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final c = _items[index];
                          return Card(
                            child: ListTile(
                              onTap: () => _openForm(c),
                              title: Text(
                                c.title.trim().isEmpty ? 'بدون عنوان' : c.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                'موضع: ${c.placement} · ظهور: ${c.impressionCount} · ضغط: ${c.clickCount}\n'
                                'حد مستخدم: ${c.maxPerUser} · يومي: ${c.maxPerUserPerDay}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Switch(
                                    value: c.isActive,
                                    onChanged: (v) => _toggle(c, v),
                                  ),
                                  IconButton(
                                    onPressed: () => _delete(c),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFC94A4A),
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
}
