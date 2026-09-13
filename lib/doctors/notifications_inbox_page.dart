import 'package:flutter/material.dart';

import 'doctor_engagement_service.dart';
import '../widgets/clinic_app_bar.dart';

class NotificationsInboxPage extends StatefulWidget {
  const NotificationsInboxPage({super.key});

  @override
  State<NotificationsInboxPage> createState() => _NotificationsInboxPageState();
}

class _NotificationsInboxPageState extends State<NotificationsInboxPage> {
  final _service = NotificationsService();
  List<AppNotificationItem> _items = [];
  Set<String> _read = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _service.fetchActive();
    final read = await _service.readIds();
    if (!mounted) return;
    setState(() {
      _items = items;
      _read = read;
      _loading = false;
    });
  }

  Future<void> _open(AppNotificationItem item) async {
    await _service.markRead(item.id);
    setState(() => _read.add(item.id));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(item.title),
          content: Text(item.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: ClinicAppBar(
          title: const Text('الإشعارات'),
          backgroundColor: const Color(0xFF0FAFA3),
          foregroundColor: Colors.white,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
            ? const Center(child: Text('لا توجد إشعارات حالياً'))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final unread = !_read.contains(item.id);
                    return Card(
                      color: unread ? const Color(0xFFEAF7F8) : Colors.white,
                      child: ListTile(
                        leading: Icon(
                          item.type == 'doctor_leave'
                              ? Icons.beach_access_rounded
                              : item.type == 'lab_package'
                              ? Icons.science_outlined
                              : Icons.notifications_rounded,
                          color: const Color(0xFF0FAFA3),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: unread
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _open(item),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
