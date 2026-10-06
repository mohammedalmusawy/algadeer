import 'pharmacy_catalog_bundles.dart';
import 'pharmacy_models.dart';

/// إصدار كتالوج اقتراحات باقات المكملات (للمزامنة والاختبارات).
const pharmacyPackageSuggestionCatalogVersion = 2;

const _reviewedOn = '2026-10-02';

const _catalogOrganizationalNoteAr =
    'تصنيف تنظيمي داخل التطبيق وليس تشخيصاً أو وصفاً علاجياً؛ راجع مختصاً قبل أي مكمل.';

enum PharmacyIngredientKind { vitamin, mineral, multivitamin, other }

class PharmacySuggestionCategory {
  const PharmacySuggestionCategory({
    required this.id,
    required this.titleAr,
    required this.descriptionAr,
    required this.evidenceNoteAr,
  });

  final String id;
  final String titleAr;
  final String descriptionAr;
  final String evidenceNoteAr;
}

class PharmacyPackageTemplate {
  const PharmacyPackageTemplate({
    required this.id,
    required this.categoryId,
    required this.titleAr,
    required this.summaryAr,
    required this.supportedUsesAr,
    required this.limitedEvidenceAr,
    required this.cautionAr,
    this.suggestedIngredientIds = const [],
    this.sourceUrls = const [],
    required this.reviewedOn,
  });

  final String id;
  final String categoryId;
  final String titleAr;
  final String summaryAr;
  final String supportedUsesAr;
  final String limitedEvidenceAr;
  final String cautionAr;
  final List<String> suggestedIngredientIds;
  final List<String> sourceUrls;
  final String reviewedOn;
}

class PharmacyIngredientSuggestion {
  const PharmacyIngredientSuggestion({
    required this.id,
    required this.nameAr,
    required this.kind,
    this.nameEn = '',
    this.aliases = const [],
    this.noteAr = '',
  });

  final String id;
  final String nameAr;
  /// اسم علمي/إنجليزي ثانوي للبحث والعرض الاختياري.
  final String nameEn;
  final PharmacyIngredientKind kind;
  final List<String> aliases;
  final String noteAr;
}

const categories = <PharmacySuggestionCategory>[
  PharmacySuggestionCategory(
    id: 'general_nutrition',
    titleAr: 'تغذية عامة',
    descriptionAr:
        'اقتراحات لتغطية احتياجات يومية شائعة عند تنوع محدود في النظام الغذائي.',
    evidenceNoteAr: _catalogOrganizationalNoteAr,
  ),
  PharmacySuggestionCategory(
    id: 'nutrient_deficiencies',
    titleAr: 'نقص عناصر غذائية',
    descriptionAr:
        'قوالب تنظيمية عند اشتباه نقص (تحليل أو تقييم مختص) — لا تغني عن التشخيص.',
    evidenceNoteAr: _catalogOrganizationalNoteAr,
  ),
  PharmacySuggestionCategory(
    id: 'bone_health',
    titleAr: 'صحة العظام',
    descriptionAr:
        'تركيز على معادن وفيتامينات مرتبطة ببنية العظام ضمن إرشادات عامة.',
    evidenceNoteAr: _catalogOrganizationalNoteAr,
  ),
  PharmacySuggestionCategory(
    id: 'pregnancy_preconception',
    titleAr: 'حمل وتخطيط حمل',
    descriptionAr:
        'عناصر شائعة في إرشادات ما قبل الحمل والحمل؛ يحدد الجرعة والنوع الطبيب.',
    evidenceNoteAr: _catalogOrganizationalNoteAr,
  ),
  PharmacySuggestionCategory(
    id: 'older_adults',
    titleAr: 'كبار السن',
    descriptionAr:
        'احتياجات شائعة مع التقدم بالعمر (امتصاص، عظام) — تنظيم فقط.',
    evidenceNoteAr: _catalogOrganizationalNoteAr,
  ),
  PharmacySuggestionCategory(
    id: 'sports_nutrition',
    titleAr: 'تغذية رياضية',
    descriptionAr:
        'دعم عام للنشاط البدني دون ادعاءات أداء أو موافقة تجارية على منتج.',
    evidenceNoteAr: _catalogOrganizationalNoteAr,
  ),
];

const _ods = 'https://ods.od.nih.gov/factsheets';

const _allIngredients = <PharmacyIngredientSuggestion>[
  PharmacyIngredientSuggestion(
    id: 'vitamin_a',
    nameAr: 'فيتامين أ',
    nameEn: 'Vitamin A (Retinol)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['vitamin a', 'الريتينول'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_c',
    nameAr: 'فيتامين ج',
    nameEn: 'Vitamin C (Ascorbic acid)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['vitamin c'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_d',
    nameAr: 'فيتامين د',
    nameEn: 'Vitamin D',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['vitamin d', 'd3'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_e',
    nameAr: 'فيتامين هـ',
    nameEn: 'Vitamin E',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['vitamin e'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_k',
    nameAr: 'فيتامين ك',
    nameEn: 'Vitamin K',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['vitamin k'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b1',
    nameAr: 'فيتامين ب1 (الثيامين)',
    nameEn: 'Thiamin (B1)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['thiamin', 'b1'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b2',
    nameAr: 'فيتامين ب2 (ريبوفلافين)',
    nameEn: 'Riboflavin (B2)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['riboflavin', 'b2'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b3',
    nameAr: 'فيتامين ب3 (نياسين)',
    nameEn: 'Niacin (B3)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['niacin', 'b3'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b5',
    nameAr: 'فيتامين ب5',
    nameEn: 'Pantothenic acid (B5)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['pantothenic', 'b5'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b6',
    nameAr: 'فيتامين ب6',
    nameEn: 'Vitamin B6',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['b6'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b7',
    nameAr: 'فيتامين ب7 (بيوتين)',
    nameEn: 'Biotin (B7)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['biotin', 'b7'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b9',
    nameAr: 'فيتامين ب9 (فولات)',
    nameEn: 'Folate (B9)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['فولات', 'folic', 'b9'],
  ),
  PharmacyIngredientSuggestion(
    id: 'vitamin_b12',
    nameAr: 'فيتامين ب12',
    nameEn: 'Vitamin B12 (Cobalamin)',
    kind: PharmacyIngredientKind.vitamin,
    aliases: ['b12', 'cobalamin'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_calcium',
    nameAr: 'الكالسيوم',
    nameEn: 'Calcium',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['calcium', 'ca'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_magnesium',
    nameAr: 'المغنسيوم',
    nameEn: 'Magnesium',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['magnesium', 'mg'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_iron',
    nameAr: 'الحديد',
    nameEn: 'Iron',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['iron', 'fe'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_zinc',
    nameAr: 'الزنك',
    nameEn: 'Zinc',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['zinc', 'zn'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_selenium',
    nameAr: 'السيلينيوم',
    nameEn: 'Selenium',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['selenium', 'se'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_iodine',
    nameAr: 'اليود',
    nameEn: 'Iodine',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['iodine'],
  ),
  PharmacyIngredientSuggestion(
    id: 'mineral_potassium',
    nameAr: 'البوتاسيوم',
    nameEn: 'Potassium',
    kind: PharmacyIngredientKind.mineral,
    aliases: ['potassium'],
  ),
  PharmacyIngredientSuggestion(
    id: 'multivitamin',
    nameAr: 'فيتامينات متعددة',
    nameEn: 'Multivitamin / Multimineral',
    kind: PharmacyIngredientKind.multivitamin,
    aliases: ['multivitamin'],
  ),
  PharmacyIngredientSuggestion(
    id: 'omega_3',
    nameAr: 'أوميغا-3',
    nameEn: 'Omega-3 (EPA/DHA)',
    kind: PharmacyIngredientKind.other,
    aliases: ['omega-3', 'epa', 'dha'],
  ),
  PharmacyIngredientSuggestion(
    id: 'probiotic',
    nameAr: 'بروبيوتيك',
    nameEn: 'Probiotics',
    kind: PharmacyIngredientKind.other,
    aliases: ['probiotic', 'probiotics'],
  ),
];

final Map<String, PharmacyIngredientSuggestion> ingredientsById = {
  for (final i in _allIngredients) i.id: i,
};

const packageTemplates = <PharmacyPackageTemplate>[
  PharmacyPackageTemplate(
    id: 'gen_daily_multi',
    categoryId: 'general_nutrition',
    titleAr: 'تغطية يومية متوازنة',
    summaryAr: 'فيتامينات متعددة مع فيتامين د اختياري عند قلة التعرض للشمس.',
    supportedUsesAr:
        'دعم تغطية فيتامينات ومعادن عند نظام غذائي غير متنوع (مراجع NIH ODS).',
    limitedEvidenceAr:
        'لا يثبت أن الفيتامينات المتعددة تمنع أمراض مزمنة لدى الأصحاء؛ الفائدة أكبر عند نقص موثّق.',
    cautionAr: 'لا يُستبدل وجبات متنوعة؛ انتبه للتداخلات مع الأدوية.',
    suggestedIngredientIds: ['multivitamin', 'vitamin_d'],
    sourceUrls: [
      '$_ods/MultivitaminMineralSupplements-Consumer/',
      '$_ods/VitaminD-Consumer/',
    ],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'gen_antioxidant_mild',
    categoryId: 'general_nutrition',
    titleAr: 'دعم مضادات أكسدة خفيف',
    summaryAr: 'فيتامين ج مع هـ عند نقص واضح في مصادرهما الغذائية.',
    supportedUsesAr:
        'فيتامين ج يشار إلى دور في الكولاجين والمناعة؛ هـ مضاد أكسدة.',
    limitedEvidenceAr:
        'مكملات مضادات الأكسدة لم تثبت منع أمراض قلبية بشكل عام في دراسات كبيرة.',
    cautionAr: 'جرعات عالية من هـ قد تتداخل مع بعض العلاجات.',
    suggestedIngredientIds: ['vitamin_c', 'vitamin_e'],
    sourceUrls: ['$_ods/VitaminC-Consumer/', '$_ods/VitaminE-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'def_iron_focus',
    categoryId: 'nutrient_deficiencies',
    titleAr: 'تركيز حديد (بعد تقييم)',
    summaryAr: 'حديد مع فيتامين ج لتحسين الامتصاص عند نقص مؤكد.',
    supportedUsesAr: 'علاج نقص حديد موثّق يُحدده الطبيب؛ ج يساعد الامتصاص.',
    limitedEvidenceAr: 'مكمل عشوائي دون تحليل قد يسبب زيادة حديد ضارة.',
    cautionAr: 'لا يُستخدم عند فرط تخزين الحديد؛ اضطراب معدي شائع.',
    suggestedIngredientIds: ['mineral_iron', 'vitamin_c'],
    sourceUrls: ['$_ods/Iron-Consumer/', '$_ods/VitaminC-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'def_vitd_mg',
    categoryId: 'nutrient_deficiencies',
    titleAr: 'فيتامين د والمغنسيوم',
    summaryAr: 'دعم مستويات د الشائعة مع مغنسيوم مرتبط أيضاً بالعضلات.',
    supportedUsesAr: 'د للعظام والامتصاص؛ المغنسيوم في تفاعلات إنزيمية كثيرة.',
    limitedEvidenceAr: 'المغنسيوم كبديل لعلاج نقص د غير مثبت.',
    cautionAr: 'جرعات د العالية تحتاج متابعة؛ المغنسيوم يسبب إسهالاً بجرعات عالية.',
    suggestedIngredientIds: ['vitamin_d', 'mineral_magnesium'],
    sourceUrls: ['$_ods/VitaminD-Consumer/', '$_ods/Magnesium-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'bone_ca_d_k',
    categoryId: 'bone_health',
    titleAr: 'عظام: كالسيوم + د + ك',
    summaryAr: 'ثلاثية شائعة لدعم تعزيز العظام مع نشاط ووجبات غنية.',
    supportedUsesAr: 'الكالسيوم ود أساسيان للعظام؛ ك مرتبط ببروينات العظمية.',
    limitedEvidenceAr: 'مكملات ك2: بيانات متباينة عن الكسور خارج النقص.',
    cautionAr: 'الكالسيوم مع أدوية قلب/كلى يحتاج إشرافاً؛ ك مع مميعات.',
    suggestedIngredientIds: ['mineral_calcium', 'vitamin_d', 'vitamin_k'],
    sourceUrls: [
      '$_ods/Calcium-Consumer/',
      '$_ods/VitaminD-Consumer/',
      '$_ods/VitaminK-Consumer/',
    ],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'bone_maint_senior',
    categoryId: 'bone_health',
    titleAr: 'صيانة عظام مع ب12',
    summaryAr: 'كالسيوم ود مع ب12 عند قلة مصادر حيوانية.',
    supportedUsesAr: 'ب12 للدم والأعصاب عند النقص؛ كالسيوم/د للهيكل.',
    limitedEvidenceAr: 'ب12 ل هشاشة العظام غير مثبت كعلاج منفرد.',
    cautionAr: 'نوع ب12 (فموي/حقن) حسب سبب النقص.',
    suggestedIngredientIds: ['mineral_calcium', 'vitamin_d', 'vitamin_b12'],
    sourceUrls: [
      '$_ods/Calcium-Consumer/',
      '$_ods/VitaminB12-Consumer/',
    ],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'preg_folate_core',
    categoryId: 'pregnancy_preconception',
    titleAr: 'قبل الحمل: حمض فولات',
    summaryAr: 'فيتامين ب9 مع يود و حديد حسب توصية الطبيب.',
    supportedUsesAr: 'فولات يقلل خطر عيوب أنبوب عصبي قبل/بداية الحمل (ODS).',
    limitedEvidenceAr: 'مكملات إضافية فوق ما قبل الحمل قياسي غير موحدة.',
    cautionAr: 'حديد فقط عند نقص أو توصية؛ نوع فولات حسب الطبيب.',
    suggestedIngredientIds: ['vitamin_b9', 'mineral_iodine', 'mineral_iron'],
    sourceUrls: ['$_ods/Folate-Consumer/', '$_ods/Iodine-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'preg_preconception_style',
    categoryId: 'pregnancy_preconception',
    titleAr: 'حزمة ما قبل/أثناء الحمل',
    summaryAr: 'فيتامين ما قبل الحمل + د + أوميغا-3 اختياري.',
    supportedUsesAr: 'فيتامينات ما قبل الحمل يغطي غالباً فولات/حديد/يود؛ DHA للنمو.',
    limitedEvidenceAr: 'أوميغا-3 لولادة مبكرة: أدلة mixed.',
    cautionAr: 'تجنب فيتامين أ الريتينول بجرعات عالية في الحمل.',
    suggestedIngredientIds: ['multivitamin', 'vitamin_d', 'omega_3'],
    sourceUrls: ['$_ods/Folate-Consumer/', '$_ods/VitaminD-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'older_b12_d',
    categoryId: 'older_adults',
    titleAr: 'ب12 + فيتامين د',
    summaryAr: 'شائع عند ضعف امتصاص ب12 وقلة التعرض للشمس.',
    supportedUsesAr: 'ب12 عند نقصه؛ د للعظام.',
    limitedEvidenceAr: 'ب12 للإدراك عند غير الناقص: أدلة محدودة.',
    cautionAr: 'فحص ب12 قبل جرعات عالية طويلة.',
    suggestedIngredientIds: ['vitamin_b12', 'vitamin_d'],
    sourceUrls: ['$_ods/VitaminB12-Consumer/', '$_ods/VitaminD-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'older_multi_senior',
    categoryId: 'older_adults',
    titleAr: 'فيتامينات متعددة 50+',
    summaryAr: 'فيتامينات متعددة مع كالسيوم/المغنسيوم حسب الحاجة الغذائية.',
    supportedUsesAr: 'صيغ 50+ تعدّل غالباً ب12/د.',
    limitedEvidenceAr: 'لا يثبت إطالة العمر في تجارب عامة.',
    cautionAr: 'تجنب تكرار كالسيوم من فيتامين متعددة + منفصل دون حساب.',
    suggestedIngredientIds: ['multivitamin', 'mineral_calcium', 'mineral_magnesium'],
    sourceUrls: ['$_ods/MultivitaminMineralSupplements-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'sport_electrolytes',
    categoryId: 'sports_nutrition',
    titleAr: 'معادن نشاط (مغنسيوم/بوتاسيوم/زنك)',
    summaryAr: 'دعم فقد عرق/حمية قليلة التنوع — ليس بديل مشروبات الأملاح المعدنية.',
    supportedUsesAr: 'المغنسيوم/البوتاسيوم في انقباض/سوائل؛ الزنك في أيض أساسي.',
    limitedEvidenceAr: 'الزنك لأداء رياضي عند غير الناقص: ضعيف.',
    cautionAr: 'مكملات البوتاسيوم خطرة مع بعض أدوية القلب/الكلى.',
    suggestedIngredientIds: ['mineral_magnesium', 'mineral_potassium', 'mineral_zinc'],
    sourceUrls: [
      '$_ods/Magnesium-Consumer/',
      '$_ods/Potassium-Consumer/',
      '$_ods/Zinc-Consumer/',
    ],
    reviewedOn: _reviewedOn,
  ),
  PharmacyPackageTemplate(
    id: 'sport_recovery_omega',
    categoryId: 'sports_nutrition',
    titleAr: 'استشفاء: أوميغا + ج',
    summaryAr: 'أوميغا-3 مع فيتامين ج ضمن نظام غذائي عام بعد مجهود.',
    supportedUsesAr: 'EPA/DHA للقلب والالتهاب أساسيات؛ ج لل الكولاجين.',
    limitedEvidenceAr: 'أوميغا-3 لتقليل ألم العضلات بعد الجهد: غير ثابت.',
    cautionAr: 'أوميغا-3 يزيد خطر نزيف مع مميعات.',
    suggestedIngredientIds: ['omega_3', 'vitamin_c', 'mineral_magnesium'],
    sourceUrls: ['$_ods/VitaminC-Consumer/', '$_ods/Magnesium-Consumer/'],
    reviewedOn: _reviewedOn,
  ),
];

/// مسودة عناصر من قالب واحد: الاسم فقط.
/// لا تُنسخ الجرعة ولا نصوص الفائدة أو التحذير، ولا يتغير القالب نفسه.
List<PharmacyPackageProduct> draftProductsFromTemplate(
  PharmacyPackageTemplate template,
) {
  final products = <PharmacyPackageProduct>[];
  for (final id in template.suggestedIngredientIds) {
    final ingredient = ingredientsById[id];
    if (ingredient == null) continue;
    products.add(
      PharmacyPackageProduct(
        id: 'sug_${template.id}_$id',
        name: ingredient.nameAr,
        ingredient: ingredient.nameAr,
      ),
    );
  }
  return products;
}

List<PharmacyPackageTemplate> templatesForCategory(String categoryId) {
  return packageTemplates
      .where((t) => t.categoryId == categoryId)
      .toList(growable: false);
}

List<PharmacyIngredientSuggestion> searchIngredients(String query) {
  final q = query.trim();
  if (q.isEmpty) {
    return ingredientsById.values.toList(growable: false);
  }
  final qLower = q.toLowerCase();
  return ingredientsById.values
      .where((i) => _ingredientMatches(i, q, qLower))
      .toList(growable: false);
}

bool _ingredientMatches(
  PharmacyIngredientSuggestion i,
  String q,
  String qLower,
) {
  if (i.nameAr.contains(q)) return true;
  if (i.nameEn.toLowerCase().contains(qLower)) return true;
  if (i.id.contains(qLower)) return true;
  for (final a in i.aliases) {
    if (a.toLowerCase().contains(qLower) || a.contains(q)) return true;
  }
  return false;
}

List<PharmacyPackageTemplate> searchAllTemplates(String query) {
  return searchTemplates('', query);
}

String categoryTitleAr(String categoryId) {
  for (final c in categories) {
    if (c.id == categoryId) return c.titleAr;
  }
  return categoryId;
}

List<PharmacyPackageTemplate> searchTemplates(String categoryId, String query) {
  final base = categoryId.isEmpty
      ? packageTemplates
      : templatesForCategory(categoryId);
  final q = query.trim();
  if (q.isEmpty) return List<PharmacyPackageTemplate>.of(base);
  return base
      .where(
        (t) =>
            t.titleAr.contains(q) ||
            t.summaryAr.contains(q) ||
            t.supportedUsesAr.contains(q),
      )
      .toList(growable: false);
}

/// عناوين الباقات الـ35 في الكتالوج الحالي (لعدم فقدان الأسماء عند الدمج).
List<String> existingCatalogPackageTitles() {
  return PharmacyCatalogBundles.all
      .map((b) => b.title)
      .toList(growable: false);
}
