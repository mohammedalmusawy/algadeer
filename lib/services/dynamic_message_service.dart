import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai/ai_service.dart';

/// أماكن ظهور العبارة داخل التطبيق.
class DynamicMessagePlacement {
  static const home = 'home';
  static const labs = 'labs';
  static const doctors = 'doctors';

  static const all = [home, labs, doctors];

  static String labelAr(String placement) {
    switch (placement) {
      case labs:
        return 'المختبرات';
      case doctors:
        return 'الأطباء';
      case home:
      default:
        return 'الصفحة الرئيسية';
    }
  }
}

/// شارات جاهزة لهوية الغدير (إعلان مصغّر).
class DynamicMessageBadges {
  static const suggestions = <String>[
    'عيادة الغدير',
    'أشعة الغدير',
    'تطبيق الغدير',
    'مختبرات الغدير',
    'معاً لصحة أفضل',
  ];
}

/// وجهة اختيارية بعد فتح تفاصيل البطاقة.
class DynamicMessageDestination {
  static const none = 'none';
  static const doctor = 'doctor';
  static const lab = 'lab';
  static const radiology = 'radiology';
  static const url = 'url';

  static const all = [none, doctor, lab, radiology, url];

  static String labelAr(String kind) {
    switch (kind) {
      case doctor:
        return 'طبيب';
      case lab:
        return 'مختبر';
      case radiology:
        return 'أشعة';
      case url:
        return 'رابط خارجي';
      case none:
      default:
        return 'تفاصيل فقط';
    }
  }

  static String ctaLabelAr(String kind) {
    switch (kind) {
      case doctor:
        return 'عرض الطبيب';
      case lab:
        return 'عرض المختبر';
      case radiology:
        return 'عرض مركز الأشعة';
      case url:
        return 'فتح الرابط';
      default:
        return '';
    }
  }
}

/// رسالة ديناميكية من Supabase (أو Fallback طارئ عند انقطاع الاتصال).
class DynamicMessage {
  final String id;
  final String title;
  final String body;
  final String placement;
  final int priority;
  final bool isActive;
  final String contextHint;
  final String imageUrl;
  final String badge;
  final String linkUrl;
  final String destinationKind;
  final String destinationId;
  final String address;
  final String mapUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String source; // supabase | fallback | ai

  const DynamicMessage({
    required this.id,
    required this.title,
    required this.body,
    this.placement = DynamicMessagePlacement.home,
    this.priority = 0,
    this.isActive = true,
    this.contextHint = '',
    this.imageUrl = '',
    this.badge = '',
    this.linkUrl = '',
    this.destinationKind = DynamicMessageDestination.none,
    this.destinationId = '',
    this.address = '',
    this.mapUrl = '',
    this.createdAt,
    this.updatedAt,
    this.source = 'supabase',
  });

  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasContent =>
      title.trim().isNotEmpty || body.trim().isNotEmpty || hasImage;

  bool get hasLocation =>
      address.trim().isNotEmpty || mapUrl.trim().isNotEmpty;

  /// رابط الخرائط إن وُجد، وإلا النص المكتوب (للبحث في الخرائط).
  String get mapLaunchTarget {
    final map = mapUrl.trim();
    if (map.isNotEmpty) return map;
    return address.trim();
  }

  /// عبارات مهمة مختصرة للعمود الإعلاني جنب الصورة.
  List<String> get highlightPhrases {
    final raw = body.trim();
    if (raw.isEmpty) return const [];
    final parts = raw
        .split(RegExp(r'[\n.!؟?]+'))
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.length >= 4)
        .toList();
    final selected = (parts.isEmpty ? <String>[raw] : parts).take(3).toList();
    return selected
        .map((p) => p.length > 72 ? '${p.substring(0, 72)}…' : p)
        .toList();
  }

  bool get hasActionableDestination {
    final kind = destinationKind.trim();
    if (kind.isEmpty || kind == DynamicMessageDestination.none) return false;
    if (kind == DynamicMessageDestination.url) {
      return linkUrl.trim().isNotEmpty;
    }
    return destinationId.trim().isNotEmpty;
  }

  factory DynamicMessage.fromMap(Map<String, dynamic> data) {
    final link = data['link_url']?.toString().trim() ?? '';
    var kind = data['destination_kind']?.toString().trim() ?? '';
    if (kind.isEmpty) {
      kind = link.isNotEmpty
          ? DynamicMessageDestination.url
          : DynamicMessageDestination.none;
    }
    return DynamicMessage(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString().trim().isNotEmpty == true
          ? data['title'].toString().trim()
          : 'رسالة اليوم',
      body: data['body']?.toString().trim() ?? '',
      placement: data['placement']?.toString().trim().isNotEmpty == true
          ? data['placement'].toString().trim()
          : DynamicMessagePlacement.home,
      priority: int.tryParse('${data['priority'] ?? 0}') ?? 0,
      isActive: data['is_active'] != false,
      contextHint: data['context_hint']?.toString() ?? '',
      imageUrl: data['image_url']?.toString() ?? '',
      badge: data['badge']?.toString() ?? '',
      linkUrl: link,
      destinationKind: kind,
      destinationId: data['destination_id']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      mapUrl: data['map_url']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      source: 'supabase',
    );
  }

  Map<String, dynamic> toMap({bool includeId = false}) {
    final kind = destinationKind.trim().isEmpty
        ? DynamicMessageDestination.none
        : destinationKind.trim();
    final map = <String, dynamic>{
      'placement': placement.trim().isEmpty
          ? DynamicMessagePlacement.home
          : placement.trim(),
      'title': title.trim().isEmpty ? 'رسالة اليوم' : title.trim(),
      'body': body.trim(),
      'priority': priority,
      'is_active': isActive,
      'context_hint': contextHint.trim(),
      'image_url': imageUrl.trim(),
      'badge': badge.trim(),
      'link_url': kind == DynamicMessageDestination.url ? linkUrl.trim() : '',
      'destination_kind': kind,
      'destination_id': kind == DynamicMessageDestination.url ||
              kind == DynamicMessageDestination.none
          ? ''
          : destinationId.trim(),
      'address': address.trim(),
      'map_url': mapUrl.trim(),
    };
    if (includeId && id.trim().isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  DynamicMessage copyWith({
    String? id,
    String? title,
    String? body,
    String? placement,
    int? priority,
    bool? isActive,
    String? contextHint,
    String? imageUrl,
    String? badge,
    String? linkUrl,
    String? destinationKind,
    String? destinationId,
    String? address,
    String? mapUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
  }) {
    return DynamicMessage(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      placement: placement ?? this.placement,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      contextHint: contextHint ?? this.contextHint,
      imageUrl: imageUrl ?? this.imageUrl,
      badge: badge ?? this.badge,
      linkUrl: linkUrl ?? this.linkUrl,
      destinationKind: destinationKind ?? this.destinationKind,
      destinationId: destinationId ?? this.destinationId,
      address: address ?? this.address,
      mapUrl: mapUrl ?? this.mapUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}

/// خدمة العبارة الديناميكية — المصدر الأساسي Supabase.
class DynamicMessageService {
  DynamicMessageService({SupabaseClient? client, AiService? aiService})
    : _clientOverride = client,
      _ai = aiService ?? EdgeFunctionAiService.fromConfig();

  final SupabaseClient? _clientOverride;
  final AiService _ai;
  static const mediaBucket = 'clinic-media';

  /// Fallback طارئ فقط عند فشل الشبكة/غياب الجدول — ليس مصدر المحتوى الأساسي.
  static const emergencyFallback = DynamicMessage(
    id: 'fallback',
    title: 'رسالة اليوم',
    body: 'عيادة الغدير تهتم بصحتك — راجع طبيبك عند الحاجة.',
    badge: 'عيادة الغدير',
    source: 'fallback',
  );

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => _client?.auth.currentUser != null;

  /// للمستخدم: أعلى أولوية مفعّلة للمكان المحدد.
  Future<DynamicMessage?> fetchActiveMessage({
    String placement = DynamicMessagePlacement.home,
  }) async {
    final client = _client;
    if (client == null) return null;
    try {
      final row = await client
          .from('dynamic_messages')
          .select()
          .eq('placement', placement)
          .eq('is_active', true)
          .order('priority', ascending: false)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final message = DynamicMessage.fromMap(Map<String, dynamic>.from(row));
      if (!message.hasContent) return null;
      return message;
    } catch (_) {
      return null;
    }
  }

  /// الرئيسية: من Supabase؛ عند الفشل فقط emergency fallback.
  Future<DynamicMessage?> fetchHomeMessage({
    AiRequestContext context = const AiRequestContext(screen: 'home'),
    bool useEmergencyFallback = false,
  }) async {
    final fromDb = await fetchActiveMessage(
      placement: DynamicMessagePlacement.home,
    );
    if (fromDb != null) return fromDb;

    try {
      final aiText = await _ai.generateDynamicMessage(
        purpose: 'home_tip',
        context: context,
      );
      if (aiText != null && aiText.trim().isNotEmpty) {
        return DynamicMessage(
          id: 'ai_home',
          title: 'رسالة اليوم',
          body: aiText.trim(),
          badge: 'عيادة الغدير',
          source: 'ai',
        );
      }
    } catch (_) {}

    if (useEmergencyFallback) return emergencyFallback;
    return null;
  }

  Future<List<DynamicMessage>> fetchAllForAdmin() async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase غير جاهز');
    }
    if (!isAuthenticated) {
      throw StateError('يجب تسجيل دخول الإدارة');
    }

    final data = await client
        .from('dynamic_messages')
        .select()
        .order('priority', ascending: false)
        .order('updated_at', ascending: false);

    return (data as List)
        .map((e) => DynamicMessage.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> uploadHighlightImage({
    required Uint8List bytes,
    required String originalName,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) throw StateError('يجب تسجيل دخول الإدارة');

    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension =
        ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(extension)
        ? extension
        : 'jpg';
    final fileName =
        'dynamic/${DateTime.now().millisecondsSinceEpoch}.$safeExtension';

    await client.storage.from(mediaBucket).uploadBinary(
          fileName,
          bytes,
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

    return client.storage.from(mediaBucket).getPublicUrl(fileName);
  }

  /// خيارات الوجهة للإدارة: [{id, name, subtitle?}].
  Future<List<Map<String, String>>> fetchDestinationOptions(String kind) async {
    final client = _client;
    if (client == null) return [];
    try {
      switch (kind) {
        case DynamicMessageDestination.doctor:
          final data = await client
              .from('doctors')
              .select('id, doctor_name, specialty')
              .order('display_order', ascending: true);
          return (data as List).map((row) {
            final m = Map<String, dynamic>.from(row as Map);
            final name =
                (m['doctor_name'] ?? '').toString().trim().isEmpty
                ? 'طبيب'
                : m['doctor_name'].toString().trim();
            final specialty = (m['specialty'] ?? '').toString().trim();
            return {
              'id': m['id']?.toString() ?? '',
              'name': name,
              if (specialty.isNotEmpty) 'subtitle': specialty,
            };
          }).where((e) => e['id']!.isNotEmpty).toList();
        case DynamicMessageDestination.lab:
          final data = await client
              .from('labs')
              .select()
              .order('display_order', ascending: true);
          return (data as List).map((row) {
            final m = Map<String, dynamic>.from(row as Map);
            final name = (m['lab_name'] ?? m['name'] ?? '')
                    .toString()
                    .trim()
                    .isEmpty
                ? 'مختبر'
                : (m['lab_name'] ?? m['name']).toString().trim();
            return {
              'id': m['id']?.toString() ?? '',
              'name': name,
            };
          }).where((e) => e['id']!.isNotEmpty).toList();
        case DynamicMessageDestination.radiology:
          List<dynamic> data;
          try {
            data = await client
                .from('radiology_centers')
                .select('id, name, center_name')
                .order('display_order', ascending: true);
          } catch (_) {
            data = await client.from('radiology_centers').select();
          }
          return (data).map((row) {
            final m = Map<String, dynamic>.from(row as Map);
            final name = (m['name'] ?? m['center_name'] ?? '')
                    .toString()
                    .trim()
                    .isEmpty
                ? 'مركز أشعة'
                : (m['name'] ?? m['center_name']).toString().trim();
            return {
              'id': m['id']?.toString() ?? '',
              'name': name,
            };
          }).where((e) => e['id']!.isNotEmpty).toList();
        default:
          return [];
      }
    } catch (_) {
      return [];
    }
  }

  Future<DynamicMessage> upsertMessage(
    DynamicMessage message, {
    String? existingId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) {
      throw StateError('يجب تسجيل دخول الإدارة قبل الحفظ');
    }
    if (!message.hasContent) {
      throw ArgumentError('أدخل عنوانًا أو نصًا أو صورة');
    }

    final payload = message.toMap();
    final id = existingId ?? message.id;

    Future<Map<String, dynamic>> persist(Map<String, dynamic> data) async {
      var working = Map<String, dynamic>.from(data);
      for (var i = 0; i < 8; i++) {
        try {
          if (id.trim().isEmpty) {
            final row = await client
                .from('dynamic_messages')
                .insert(working)
                .select()
                .single();
            return Map<String, dynamic>.from(row);
          }
          final row = await client
              .from('dynamic_messages')
              .update(working)
              .eq('id', id)
              .select()
              .single();
          return Map<String, dynamic>.from(row);
        } on PostgrestException catch (e) {
          if (e.code != 'PGRST204') rethrow;
          final missing = RegExp(
            r"Could not find the '([^']+)' column",
            caseSensitive: false,
          ).firstMatch(e.message)?.group(1);
          if (missing == null || !working.containsKey(missing)) rethrow;
          working.remove(missing);
        }
      }
      throw Exception('تعذر حفظ العبارة');
    }

    final row = await persist(payload);
    final saved = DynamicMessage.fromMap(row);
    // إن رُفعت صورة لكن العمود غير موجود في Supabase تُحذف بهدوء — نبّه المدير.
    if (message.imageUrl.trim().isNotEmpty && saved.imageUrl.trim().isEmpty) {
      throw StateError(
        'الصورة لم تُحفظ: نفّذ ملف supabase/dynamic_messages_highlight_schema.sql '
        'في SQL Editor ثم أعد الحفظ.',
      );
    }
    if (message.destinationKind != DynamicMessageDestination.none &&
        message.destinationKind.trim().isNotEmpty &&
        saved.destinationKind == DynamicMessageDestination.none &&
        !saved.hasActionableDestination) {
      throw StateError(
        'الوجهة لم تُحفظ: أعد تشغيل dynamic_messages_highlight_schema.sql '
        'ثم احفظ البطاقة مرة أخرى.',
      );
    }
    if ((message.address.trim().isNotEmpty || message.mapUrl.trim().isNotEmpty) &&
        !saved.hasLocation) {
      throw StateError(
        'العنوان/رابط الخرائط لم يُحفظ: نفّذ dynamic_messages_highlight_schema.sql '
        'في SQL Editor ثم أعد الحفظ.',
      );
    }
    return saved;
  }

  Future<void> setActive({required String id, required bool isActive}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) throw StateError('يجب تسجيل دخول الإدارة');
    await client
        .from('dynamic_messages')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> deleteMessage(String id) async {
    final client = _client;
    if (client == null) throw StateError('Supabase غير جاهز');
    if (!isAuthenticated) throw StateError('يجب تسجيل دخول الإدارة');
    if (id.trim().isEmpty) return;
    await client.from('dynamic_messages').delete().eq('id', id);
  }

  Future<bool> hasTable() async {
    final client = _client;
    if (client == null) return false;
    try {
      await client.from('dynamic_messages').select('id').limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
