import 'dart:convert';

import '../branding/ghadeer_brand_mark.dart';

bool labBoolFlag(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value == true || value == 1 || value == 'true') return true;
  if (value == false || value == 0 || value == 'false') return false;
  return fallback;
}

/// يحول قيمة سعر/عدد صحيح إلى [int] لأعمدة PostgreSQL integer.
/// يقبل: 50000, "50000", "50000.0", "50,000"
/// يرفض الكسور الحقيقية مثل 50000.5 (يرجع null بدون قص صامت).
int? labParseWholeNumber(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) {
    final d = value.toDouble();
    if (d.isNaN || d.isInfinite) return null;
    if (d != d.roundToDouble()) return null;
    return d.toInt();
  }

  var text = value
      .toString()
      .trim()
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .replaceAll('\u00A0', '');
  if (text.isEmpty) return null;

  final asInt = int.tryParse(text);
  if (asInt != null) return asInt;

  final asDouble = double.tryParse(text);
  if (asDouble == null || asDouble.isNaN || asDouble.isInfinite) return null;
  if (asDouble != asDouble.roundToDouble()) return null;
  return asDouble.toInt();
}

/// أسعار الباقات في lab_packages من نوع integer.
int? labParsePrice(dynamic value) => labParseWholeNumber(value);

int labParseDisplayOrder(dynamic value, {int fallback = 0}) {
  return labParseWholeNumber(value) ?? fallback;
}

/// نص حقل السعر في النماذج: بدون ".0"
String labPriceFieldText(int? value) {
  if (value == null) return '';
  return value.toString();
}

String formatLabPrice(int? value) {
  if (value == null) return '';
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

/// يدعم: List / JSON-like string / نص مفصول بفواصل أو أسطر.
List<String> parseLabTests(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  final text = value.toString().trim();
  if (text.isEmpty) return const [];
  if (text.startsWith('[')) {
    try {
      final inner = text.substring(1, text.length - 1);
      return inner
          .split(',')
          .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {}
  }
  return text
      .split(RegExp(r'[\n,،|•]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class LabItem {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String address;
  final String phone;
  final String whatsapp;
  final bool isActive;
  final bool isFeatured;
  final int displayOrder;
  final String mapUrl;
  final String workingHours;
  final String slogan;
  final DateTime? createdAt;

  const LabItem({
    required this.id,
    required this.name,
    this.description = '',
    this.imageUrl = '',
    this.address = '',
    this.phone = '',
    this.whatsapp = '',
    this.isActive = true,
    this.isFeatured = false,
    this.displayOrder = 0,
    this.mapUrl = '',
    this.workingHours = '',
    this.slogan = '',
    this.createdAt,
  });

  factory LabItem.fromMap(Map<String, dynamic> data) {
    return LabItem(
      id: data['id']?.toString() ?? '',
      name: (data['lab_name'] ?? data['name'])?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: GhadeerBranding.normalizeEntityImageUrl(
        data['image_url']?.toString() ?? '',
      ),
      address: data['address']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      whatsapp: data['whatsapp']?.toString() ?? '',
      isActive: labBoolFlag(data['is_active'], fallback: true),
      isFeatured: labBoolFlag(data['is_featured']),
      displayOrder: int.tryParse('${data['display_order'] ?? 0}') ?? 0,
      mapUrl: data['map_url']?.toString() ?? '',
      workingHours: data['working_hours']?.toString() ?? '',
      slogan: data['slogan']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lab_name': name,
      'description': description,
      'image_url': imageUrl.isEmpty ? null : imageUrl,
      'address': address,
      'phone': phone,
      'whatsapp': whatsapp,
      'is_active': isActive,
      'is_featured': isFeatured,
      'display_order': displayOrder,
      'map_url': mapUrl.trim(),
      'working_hours': workingHours.trim(),
      'slogan': slogan.trim(),
    };
  }
}

class AnalysisItem {
  final String id;
  final String name;
  final String shortName;
  final String nameAr;
  final String descriptionAr;
  final String category;
  final String description;
  final List<String> aliases;
  final String searchText;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;

  const AnalysisItem({
    required this.id,
    required this.name,
    this.shortName = '',
    this.nameAr = '',
    this.descriptionAr = '',
    this.category = '',
    this.description = '',
    this.aliases = const [],
    this.searchText = '',
    this.isActive = true,
    this.displayOrder = 9999,
    this.createdAt,
  });

  factory AnalysisItem.fromMap(Map<String, dynamic> data) {
    final aliasesRaw = data['aliases'];
    final aliases = <String>[];
    if (aliasesRaw is List) {
      for (final item in aliasesRaw) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) aliases.add(text);
      }
    }

    return AnalysisItem(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      shortName: data['short_name']?.toString() ?? '',
      nameAr: data['name_ar']?.toString() ?? '',
      descriptionAr: data['description_ar']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      aliases: aliases,
      searchText: data['search_text']?.toString() ?? '',
      isActive: labBoolFlag(data['is_active'], fallback: true),
      displayOrder: int.tryParse('${data['display_order'] ?? 9999}') ?? 9999,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  factory AnalysisItem.fromName(String name) {
    final n = name.trim();
    return AnalysisItem(id: n, name: n);
  }

  AnalysisItem copyWith({
    String? id,
    String? name,
    String? shortName,
    String? nameAr,
    String? descriptionAr,
    String? category,
    String? description,
    List<String>? aliases,
    String? searchText,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
  }) {
    return AnalysisItem(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      nameAr: nameAr ?? this.nameAr,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      category: category ?? this.category,
      description: description ?? this.description,
      aliases: aliases ?? this.aliases,
      searchText: searchText ?? this.searchText,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get displayLabel {
    if (shortName.trim().isEmpty) return name;
    return '$name ($shortName)';
  }

  /// الاسم العربي للعرض للمستخدم (من نفس سجل التحليل في Supabase).
  String get arabicDisplayName {
    if (nameAr.trim().isNotEmpty) return nameAr.trim();
    if (descriptionAr.trim().isNotEmpty) return descriptionAr.trim();
    return name.trim();
  }

  /// الاسم/الاختصار الإنكليزي (نفس حقل name الظاهر في شاشة الإدارة).
  String get englishDisplayName {
    if (name.trim().isNotEmpty) return name.trim();
    return shortName.trim();
  }

  /// وصف عربي للعرض: description_ar ثم name_ar
  String get arabicDescriptionDisplay {
    if (descriptionAr.trim().isNotEmpty) return descriptionAr.trim();
    return nameAr.trim();
  }

  List<String> get searchableTerms {
    return [
      name,
      shortName,
      nameAr,
      descriptionAr,
      description,
      ...aliases,
      if (searchText.isNotEmpty) searchText,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'short_name': shortName.trim().isEmpty ? null : shortName.trim(),
      'name_ar': nameAr.trim().isEmpty ? null : nameAr.trim(),
      'description_ar': descriptionAr.trim(),
      'category': category.trim().isEmpty ? null : category.trim(),
      'description': description,
      'aliases': aliases,
      'is_active': isActive,
    };
  }
}

class PackageTemplateItem {
  final String id;
  final String name;
  final String description;
  final int displayOrder;
  final bool isActive;
  final List<AnalysisItem> analyses;

  const PackageTemplateItem({
    required this.id,
    required this.name,
    this.description = '',
    this.displayOrder = 0,
    this.isActive = true,
    this.analyses = const [],
  });

  List<String> get suggestedAnalysisNames =>
      analyses.map((a) => a.name).toList(growable: false);

  factory PackageTemplateItem.fromMap(Map<String, dynamic> data) {
    final analyses = <AnalysisItem>[];
    final links = data['package_template_analyses'];
    if (links is List) {
      final rows = [...links];
      rows.sort((a, b) {
        final ao = (a is Map) ? (a['display_order'] as num? ?? 0) : 0;
        final bo = (b is Map) ? (b['display_order'] as num? ?? 0) : 0;
        return ao.compareTo(bo);
      });
      for (final row in rows) {
        if (row is! Map) continue;
        final analysis = row['analyses'];
        if (analysis is Map) {
          analyses.add(
            AnalysisItem.fromMap(Map<String, dynamic>.from(analysis)),
          );
        }
      }
    }

    return PackageTemplateItem(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      displayOrder: int.tryParse('${data['display_order'] ?? 0}') ?? 0,
      isActive: labBoolFlag(data['is_active'], fallback: true),
      analyses: analyses,
    );
  }
}

/// ترتيب نتائج البحث: exact → prefix → short → alias → contains
List<AnalysisItem> rankAnalysisMatches(
  List<AnalysisItem> catalog,
  String query, {
  int limit = 20,
  Set<String> excludeIds = const {},
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final exact = <AnalysisItem>[];
  final prefix = <AnalysisItem>[];
  final shortExact = <AnalysisItem>[];
  final aliasHits = <AnalysisItem>[];
  final contains = <AnalysisItem>[];

  for (final item in catalog) {
    if (!item.isActive) continue;
    if (excludeIds.contains(item.id)) continue;

    final name = item.name.toLowerCase();
    final short = item.shortName.toLowerCase();
    final ar = item.nameAr.toLowerCase();
    final aliasList = item.aliases.map((e) => e.toLowerCase()).toList();

    if (name == q || short == q || ar == q || aliasList.contains(q)) {
      exact.add(item);
      continue;
    }
    if (short == q || short.startsWith(q)) {
      shortExact.add(item);
      continue;
    }
    if (name.startsWith(q) || ar.startsWith(q)) {
      prefix.add(item);
      continue;
    }
    if (aliasList.any((a) => a.startsWith(q) || a == q)) {
      aliasHits.add(item);
      continue;
    }
    final blob = [
      name,
      short,
      ar,
      item.description.toLowerCase(),
      ...aliasList,
      item.searchText.toLowerCase(),
    ].join(' ');
    if (blob.contains(q)) {
      contains.add(item);
    }
  }

  return [
    ...exact,
    ...shortExact,
    ...prefix,
    ...aliasHits,
    ...contains,
  ].take(limit).toList();
}

List<PackageTemplateItem> rankPackageTemplates(
  List<PackageTemplateItem> templates,
  String query, {
  int limit = 12,
}) {
  final q = query.trim().toLowerCase();
  final source = q.isEmpty ? templates : templates;
  if (q.isEmpty) {
    return source.take(limit).toList();
  }

  final exact = <PackageTemplateItem>[];
  final prefix = <PackageTemplateItem>[];
  final contains = <PackageTemplateItem>[];
  for (final t in source) {
    final name = t.name.toLowerCase();
    final desc = t.description.toLowerCase();
    if (name == q) {
      exact.add(t);
    } else if (name.startsWith(q)) {
      prefix.add(t);
    } else if (name.contains(q) || desc.contains(q)) {
      contains.add(t);
    }
  }
  return [...exact, ...prefix, ...contains].take(limit).toList();
}

class LabPackageItem {
  final String id;
  final String labId;
  final String name;
  final String description;
  final int? oldPrice;
  final int? newPrice;
  final String imageUrl;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final int analysesCount;
  final List<AnalysisItem> analyses;
  final bool isFeatured;
  final bool showOnHome;
  final List<String> testNames;

  const LabPackageItem({
    required this.id,
    required this.labId,
    required this.name,
    this.description = '',
    this.oldPrice,
    this.newPrice,
    this.imageUrl = '',
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.analysesCount = 0,
    this.analyses = const [],
    this.isFeatured = false,
    this.showOnHome = false,
    this.testNames = const [],
  });

  bool get hasOldPrice =>
      oldPrice != null &&
      oldPrice! > 0 &&
      (newPrice == null || oldPrice != newPrice);

  /// نسبة الخصم للعرض فقط (null إن لا يوجد خصم صالح).
  int? get discountPercent {
    if (oldPrice == null || newPrice == null) return null;
    if (oldPrice! <= 0 || newPrice! >= oldPrice!) return null;
    return (((oldPrice! - newPrice!) / oldPrice!) * 100).round();
  }

  factory LabPackageItem.fromMap(Map<String, dynamic> data) {
    final linkRows = data['lab_package_analyses'];
    var count = 0;
    final analyses = <AnalysisItem>[];

    if (linkRows is List) {
      count = linkRows.length;
      for (final row in linkRows) {
        if (row is Map) {
          final mapRow = Map<String, dynamic>.from(row);
          if (mapRow.containsKey('count') && mapRow['count'] is num) {
            count = (mapRow['count'] as num).toInt();
            continue;
          }
          final analysis = mapRow['analyses'];
          if (analysis is Map) {
            analyses.add(
              AnalysisItem.fromMap(Map<String, dynamic>.from(analysis)),
            );
          }
        }
      }
      if (analyses.isNotEmpty) {
        count = analyses.length;
      }
    }

    final tests = parseLabTests(data['tests']);
    if (analyses.isEmpty && tests.isNotEmpty) {
      analyses.addAll(tests.map(AnalysisItem.fromName));
    }

    final contentCount = analyses.isNotEmpty ? analyses.length : tests.length;
    if (contentCount > 0) {
      count = contentCount;
    } else if (data['analyses_count'] != null) {
      count = int.tryParse('${data['analyses_count']}') ?? count;
    }

    return LabPackageItem(
      id: data['id']?.toString() ?? '',
      labId: data['lab_id']?.toString() ?? '',
      name: (data['package_name'] ?? data['name'])?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      oldPrice: labParsePrice(data['old_price']),
      newPrice: labParsePrice(data['price'] ?? data['new_price']),
      imageUrl: GhadeerBranding.normalizeEntityImageUrl(
        data['image_url']?.toString() ?? '',
      ),
      isActive: labBoolFlag(data['is_active'], fallback: true),
      displayOrder: labParseDisplayOrder(data['display_order']),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      analysesCount: count,
      analyses: analyses,
      isFeatured: labBoolFlag(data['is_featured']),
      showOnHome: labBoolFlag(data['show_on_home']),
      testNames: tests.isNotEmpty
          ? tests
          : analyses.map((a) => a.name).toList(),
    );
  }

  Map<String, dynamic> toMap({List<String>? testsOverride}) {
    final tests =
        testsOverride ??
        (testNames.isNotEmpty
            ? testNames
            : analyses
                  .map((a) => a.name)
                  .where((n) => n.trim().isNotEmpty)
                  .toList());
    // عمود tests في Supabase من نوع text وليس jsonb/array.
    final testsText = tests.isEmpty ? null : jsonEncode(tests);
    // أنواع صريحة لأعمدة integer/boolean في lab_packages
    return {
      'lab_id': labId,
      'package_name': name.trim(),
      'description': description,
      'old_price': oldPrice, // int?
      'price': newPrice, // int?  (عمود price وليس new_price)
      'image_url': imageUrl.trim(),
      'is_active': isActive,
      'display_order': displayOrder, // int
      'is_featured': isFeatured,
      'show_on_home': showOnHome,
      'tests': testsText,
    };
  }
}
