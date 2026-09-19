import 'symptom_catalog_source.dart';
import 'symptom_models.dart';

/// كتالوج محلي أولي — قابل للاستبدال بـ Supabase لاحقاً.
class LocalSymptomCatalog extends SyncSymptomCatalogSource {
  const LocalSymptomCatalog();

  @override
  List<SymptomConcept> enabledSymptomsSync() => _concepts
      .where((c) => c.enabled)
      .toList(growable: false);

  @override
  List<SymptomAliasEntry> enabledAliasesSync() {
    final out = <SymptomAliasEntry>[];
    for (final c in _concepts) {
      if (!c.enabled) continue;
      out.add(SymptomAliasEntry(
        symptomId: c.id,
        alias: c.canonicalArabicName,
      ));
      for (final a in c.aliases) {
        out.add(SymptomAliasEntry(symptomId: c.id, alias: a));
      }
    }
    return List.unmodifiable(out);
  }

  @override
  List<BodyRegionConcept> enabledBodyRegionsSync() =>
      List.unmodifiable(_regions);

  static const _concepts = <SymptomConcept>[
    SymptomConcept(
      id: 'headache',
      canonicalArabicName: 'صداع',
      bodyRegions: [BodyRegionId.head],
      aliases: [
        'راسي يوجعني',
        'راسي يعورني',
        'وجع راس',
        'وجع الراس',
        'الم براسي',
        'ألم براسي',
        'الم بالراس',
        'ألم بالرأس',
        'الم بالرأس',
        'راسي يؤلمني',
      ],
    ),
    SymptomConcept(
      id: 'dizziness',
      canonicalArabicName: 'دوخة',
      bodyRegions: [BodyRegionId.head],
      aliases: [
        'دايخ',
        'دايخة',
        'دايخه',
        'احس بدوخة',
        'أحس بدوخة',
        'احس بدوخه',
        'عندي دوخة',
      ],
    ),
    SymptomConcept(
      id: 'vertigo',
      canonicalArabicName: 'دوار',
      bodyRegions: [BodyRegionId.head],
      aliases: [
        'الدنيا تدور',
        'المكان يدور',
        'كلشي يدور بي',
        'احس الغرفة تدور',
        'أحس الغرفة تدور',
        'الغرفة تدور',
        'المكان يدور بي',
      ],
    ),
    SymptomConcept(
      id: 'nausea',
      canonicalArabicName: 'غثيان',
      aliases: [
        'لوعه',
        'لوعة',
        'نفسي تتلوع',
        'احس بلوعه',
        'أحس بلوعة',
        'احس بلوعة',
        'عندي غثيان',
      ],
    ),
    SymptomConcept(
      id: 'vomiting',
      canonicalArabicName: 'استفراغ',
      aliases: [
        'استفرغ',
        'اتقيأ',
        'تقيؤ',
        'ترجيع',
        'اقياء',
        'إقياء',
      ],
    ),
    SymptomConcept(
      id: 'fever',
      canonicalArabicName: 'حرارة',
      aliases: [
        'حمى',
        'جسمي حار',
        'عندي حرارة',
        'حرارتي مرتفعة',
        'سخونة',
      ],
    ),
    SymptomConcept(
      id: 'cough',
      canonicalArabicName: 'سعال',
      aliases: [
        'كحة',
        'اكح',
        'كحتي',
        'عندي سعال',
        'عندي كحة',
      ],
    ),
    SymptomConcept(
      id: 'shortness_of_breath',
      canonicalArabicName: 'ضيق نفس',
      bodyRegions: [BodyRegionId.chest],
      aliases: [
        'ضيق النفس',
        'نفسي ضايج',
        'ما اكدر اتنفس زين',
        'ما أقدر أتنفس زين',
        'تنفسي صعب',
        'احس نفسي قصير',
        'أحس نفسي قصير',
        'ضيق بالتنفس',
      ],
    ),
    SymptomConcept(
      id: 'chest_pain',
      canonicalArabicName: 'ألم بالصدر',
      bodyRegions: [BodyRegionId.chest],
      aliases: [
        'الم بالصدر',
        'صدري يوجعني',
        'وجع بالصدر',
        'وجع الصدر',
        'صدري يؤلمني',
      ],
    ),
    SymptomConcept(
      id: 'loss_of_consciousness',
      canonicalArabicName: 'فقدان الوعي',
      aliases: [
        'فقدت الوعي',
        'فقدان الوعي',
        'اغمى علي',
        'أغمي علي',
        'غمضت',
        'انغميت',
        'اغماء',
        'إغماء',
      ],
    ),
    SymptomConcept(
      id: 'seizure',
      canonicalArabicName: 'نوبة تشنج',
      aliases: [
        'تشنج',
        'تشنجات',
        'نوبة صرع',
        'صار عندي تشنج',
        'نوبة تشنج',
      ],
    ),
    SymptomConcept(
      id: 'active_bleeding',
      canonicalArabicName: 'نزيف نشط',
      aliases: [
        'ينزف',
        'نزيف',
        'نزيف قوي',
        'ينزف كلش',
        'ما يوقف النزيف',
        'نزيف نشط',
      ],
    ),
    SymptomConcept(
      id: 'chest_tightness',
      canonicalArabicName: 'كتمة بالصدر',
      bodyRegions: [BodyRegionId.chest],
      aliases: [
        'صدري مكتوم',
        'احس بكتمة',
        'أحس بكتمة',
        'كتمة',
        'كتمه بالصدر',
      ],
    ),
    SymptomConcept(
      id: 'abdominal_pain',
      canonicalArabicName: 'ألم بالبطن',
      bodyRegions: [BodyRegionId.abdomen],
      aliases: [
        'بطني يوجعني',
        'الم بالبطن',
        'وجع بطن',
        'وجع البطن',
        'مغص',
        'بطني يؤلمني',
      ],
    ),
    SymptomConcept(
      id: 'back_pain',
      canonicalArabicName: 'ألم بالظهر',
      bodyRegions: [BodyRegionId.back],
      aliases: [
        'ظهري يوجعني',
        'الم بالظهر',
        'وجع ظهر',
        'وجع الظهر',
        'ظهري يؤلمني',
      ],
    ),
    SymptomConcept(
      id: 'neck_pain',
      canonicalArabicName: 'ألم بالرقبة',
      bodyRegions: [BodyRegionId.neck],
      aliases: [
        'رقبتي توجعني',
        'الم بالرقبة',
        'وجع رقبة',
      ],
    ),
    SymptomConcept(
      id: 'joint_pain',
      canonicalArabicName: 'ألم بالمفاصل',
      aliases: [
        'الم بالمفاصل',
        'مفاصلي توجعني',
        'وجع مفاصل',
      ],
    ),
    SymptomConcept(
      id: 'knee_pain',
      canonicalArabicName: 'ألم بالركبة',
      bodyRegions: [BodyRegionId.knee],
      aliases: [
        'ركبتي توجعني',
        'رگبتي توجعني',
        'الم بالركبة',
        'ألم بالركبة',
        'وجع ركبة',
        'وجع بالركبة',
      ],
    ),
    SymptomConcept(
      id: 'weakness',
      canonicalArabicName: 'ضعف',
      aliases: [
        'احس رجلي ضعيفة',
        'أحس رجلي ضعيفة',
        'ما بيه حيل',
        'ما بيا حيل',
        'ضعف باليد',
        'ضعف عام',
      ],
    ),
    SymptomConcept(
      id: 'numbness',
      canonicalArabicName: 'خدر',
      aliases: [
        'خدران',
        'تنميل',
        'رجلي تخدر',
        'ايدي تخدر',
        'إيدي تخدر',
        'تخدر',
      ],
    ),
    SymptomConcept(
      id: 'tingling',
      canonicalArabicName: 'وخز',
      aliases: [
        'تنميل ووخز',
        'احس بوخز',
        'نخز',
      ],
    ),
    SymptomConcept(
      id: 'tremor',
      canonicalArabicName: 'رعشة',
      aliases: [
        'رعش',
        'ايدي ترتعش',
        'رجفة',
      ],
    ),
    SymptomConcept(
      id: 'palpitations',
      canonicalArabicName: 'خفقان',
      bodyRegions: [BodyRegionId.chest],
      aliases: [
        'قلبي يدق بسرعة',
        'خفقان القلب',
        'نبض سريع',
      ],
    ),
    SymptomConcept(
      id: 'sore_throat',
      canonicalArabicName: 'ألم بالحلق',
      bodyRegions: [BodyRegionId.throat],
      aliases: [
        'حلقي يوجعني',
        'حلگي يوجعني',
        'الم بالحلق',
        'وجع حلق',
      ],
    ),
    SymptomConcept(
      id: 'ear_pain',
      canonicalArabicName: 'ألم بالأذن',
      bodyRegions: [BodyRegionId.ear],
      aliases: [
        'اذني توجعني',
        'أذني توجعني',
        'وجع اذن',
        'وجع أذن',
        'الم بالاذن',
        'ألم بالأذن',
      ],
    ),
    SymptomConcept(
      id: 'hearing_loss',
      canonicalArabicName: 'ضعف سمع',
      bodyRegions: [BodyRegionId.ear],
      aliases: [
        'سمعي ضعيف',
        'ما اسمع زين',
        'ما أسمع زين',
        'ضعف بالسمع',
      ],
    ),
    SymptomConcept(
      id: 'tinnitus',
      canonicalArabicName: 'طنين',
      bodyRegions: [BodyRegionId.ear],
      aliases: [
        'صفير بالاذن',
        'صفير بالأذن',
        'صفير باذني',
        'صوت باذني',
        'طنين بالأذن',
      ],
    ),
    SymptomConcept(
      id: 'nasal_congestion',
      canonicalArabicName: 'انسداد الأنف',
      bodyRegions: [BodyRegionId.nose],
      aliases: [
        'خشمي مسدود',
        'انسداد الانف',
        'ما اكدر اتنفس من خشمي',
        'ما أقدر أتنفس من خشمي',
        'انفي مسدود',
      ],
    ),
    SymptomConcept(
      id: 'diarrhea',
      canonicalArabicName: 'إسهال',
      bodyRegions: [BodyRegionId.abdomen],
      aliases: [
        'اسهال',
        'بطن لين',
        'اسهال متكرر',
      ],
    ),
    SymptomConcept(
      id: 'constipation',
      canonicalArabicName: 'إمساك',
      bodyRegions: [BodyRegionId.abdomen],
      aliases: [
        'امساك',
        'ما اقدر اتبرز',
      ],
    ),
    SymptomConcept(
      id: 'poor_appetite',
      canonicalArabicName: 'فقدان شهية',
      aliases: [
        'ما اشتهي اكل',
        'ما عندي شهية',
        'فقدان الشهية',
      ],
    ),
    SymptomConcept(
      id: 'difficulty_swallowing',
      canonicalArabicName: 'صعوبة بلع',
      bodyRegions: [BodyRegionId.throat],
      aliases: [
        'ما اكدر ابلع',
        'صعوبة بالبلع',
      ],
    ),
    SymptomConcept(
      id: 'hoarseness',
      canonicalArabicName: 'بحة صوت',
      bodyRegions: [BodyRegionId.throat],
      aliases: [
        'صوتي مبحوح',
        'بحة',
      ],
    ),
    SymptomConcept(
      id: 'balance_problem',
      canonicalArabicName: 'مشكلة توازن',
      aliases: [
        'ما اتوازن',
        'فقدت توازني',
        'اختلال توازن',
      ],
    ),
    SymptomConcept(
      id: 'fatigue',
      canonicalArabicName: 'تعب',
      aliases: [
        'تعبان',
        'تعبانه',
        'تعبانة',
        'ارهاق',
        'إرهاق',
        'مرهق',
      ],
      metadata: {'broad': true},
    ),
  ];

  static const _regions = <BodyRegionConcept>[
    BodyRegionConcept(
      id: BodyRegionId.head,
      canonicalArabicName: 'رأس',
      aliases: ['راسي', 'الراس', 'الرأس', 'براسي'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.face,
      canonicalArabicName: 'وجه',
      aliases: ['وجهي', 'الوجه'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.eye,
      canonicalArabicName: 'عين',
      aliases: ['عيني', 'عيوني', 'العين'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.ear,
      canonicalArabicName: 'أذن',
      aliases: ['اذني', 'أذني', 'الاذن', 'الأذن', 'باذني'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.nose,
      canonicalArabicName: 'أنف',
      aliases: ['خشمي', 'انفي', 'الانف', 'الأنف'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.throat,
      canonicalArabicName: 'حلق',
      aliases: ['حلقي', 'حلگي', 'الحلق'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.neck,
      canonicalArabicName: 'رقبة',
      aliases: ['رقبتي', 'الرقبة'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.chest,
      canonicalArabicName: 'صدر',
      aliases: ['صدري', 'الصدر'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.abdomen,
      canonicalArabicName: 'بطن',
      aliases: ['بطني', 'البطن', 'بطن'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.back,
      canonicalArabicName: 'ظهر',
      aliases: ['ظهري', 'الظهر'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.lowerBack,
      canonicalArabicName: 'خصر',
      aliases: ['خصري', 'اسفل الظهر', 'أسفل الظهر'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.shoulder,
      canonicalArabicName: 'كتف',
      aliases: ['كتفي', 'الكتف'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.arm,
      canonicalArabicName: 'ذراع',
      aliases: ['ذراعي', 'ايدي', 'إيدي'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.hand,
      canonicalArabicName: 'يد',
      aliases: ['كفي', 'اليد'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.hip,
      canonicalArabicName: 'ورك',
      aliases: ['وركي', 'الورك'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.leg,
      canonicalArabicName: 'رجل',
      aliases: ['رجلي', 'ساقي', 'الرجل'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.knee,
      canonicalArabicName: 'ركبة',
      aliases: ['ركبتي', 'رگبتي', 'الركبة'],
    ),
    BodyRegionConcept(
      id: BodyRegionId.foot,
      canonicalArabicName: 'قدم',
      aliases: ['قدمي', 'رجلي من تحت', 'القدم'],
    ),
  ];
}
