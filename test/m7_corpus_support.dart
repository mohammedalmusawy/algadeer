import 'dart:convert';
import 'dart:io';

import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';

import 'm6_iraqi_corpus_support.dart';

/// عائلات عدّ M7 بدون ازدواج مضلّل (كل حالة عائلة واحدة أساسية).
abstract final class M7Family {
  static const golden = 'GOLDEN';
  static const generated = 'GENERATED';
  static const adversarial = 'ADVERSARIAL';
  static const stt = 'STT';
  static const typo = 'TYPO';
  static const oos = 'OOS';
  static const falsePositive = 'FALSE_POSITIVE';
  static const dynamicData = 'DYNAMIC_DATA';
  static const multiTurn = 'MULTI_TURN';
  static const longConversation = 'LONG_CONVERSATION';
}

/// حالة M7 = M6 + عائلة عدّ.
class M7CorpusCase {
  const M7CorpusCase({
    required this.base,
    required this.family,
  });

  final M6CorpusCase base;
  final String family;

  String get id => base.id;
  String get source => base.source;
  String get category => base.category;
  String get input => base.input;
  bool matchesIntent(AssistantIntent intent) => base.matchesIntent(intent);
}

M6CorpusCase _m7({
  required String id,
  required String family,
  required String category,
  required String input,
  String source = 'generated',
  String? expectedIntent,
  List<String> expectedIntentAnyOf = const [],
  String? expectedIntentNot,
  bool expectRefuse = false,
  bool expectNotRefuse = false,
  bool expectNoEntityHallucination = false,
  String? notes,
}) {
  return M6CorpusCase(
    id: id,
    source: source,
    category: '${family.toLowerCase()}|$category',
    input: input,
    expectedIntent: expectedIntent,
    expectedIntentAnyOf: expectedIntentAnyOf,
    expectedIntentNot: expectedIntentNot,
    expectRefuse: expectRefuse,
    expectNotRefuse: expectNotRefuse,
    expectNoEntityHallucination: expectNoEntityHallucination,
    notes: notes,
  );
}

String m7FamilyOf(M6CorpusCase c) {
  final cat = c.category;
  if (cat.startsWith('adversarial|') || cat.contains('|adv_')) {
    return M7Family.adversarial;
  }
  if (cat.startsWith('stt|') || cat.contains('|stt_')) return M7Family.stt;
  if (cat.startsWith('typo|') || cat.contains('|typo_')) return M7Family.typo;
  if (cat.startsWith('oos|') ||
      cat.contains('out_of_scope') ||
      cat.contains('|oos_')) {
    return M7Family.oos;
  }
  if (cat.startsWith('false_positive|') || cat.contains('|fp_')) {
    return M7Family.falsePositive;
  }
  if (c.source == 'golden') return M7Family.golden;
  return M7Family.generated;
}

List<M6CorpusCase> loadM7GoldenCorpus() {
  final file = File('test/fixtures/m7_iraqi_corpus_golden.json');
  if (!file.existsSync()) return const [];
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return [
    for (final row in decoded)
      M6CorpusCase.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
}

/// كل حالات corpus ذات الدور الواحد لـ M7 (M6 + M7 golden + M7 generated).
List<M6CorpusCase> loadAllM7SingleTurnCases() {
  final m6Golden = loadM6GoldenCorpus();
  final m6Gen = generateM6CorpusCases();
  final m7Golden = loadM7GoldenCorpus();
  final m7Gen = generateM7CorpusCases();
  return List.unmodifiable([...m6Golden, ...m6Gen, ...m7Golden, ...m7Gen]);
}

Map<String, int> countM7Families(List<M6CorpusCase> cases) {
  final counts = <String, int>{
    M7Family.golden: 0,
    M7Family.generated: 0,
    M7Family.adversarial: 0,
    M7Family.stt: 0,
    M7Family.typo: 0,
    M7Family.oos: 0,
    M7Family.falsePositive: 0,
  };
  for (final c in cases) {
    final f = m7FamilyOf(c);
    counts[f] = (counts[f] ?? 0) + 1;
  }
  return counts;
}

/// توليد حتمي M7 — تركيبات ذات معنى عبر أبعاد الفهم (بلا عشوائية).
List<M6CorpusCase> generateM7CorpusCases() {
  final out = <M6CorpusCase>[];
  var n = 0;

  String nextId(String prefix) {
    n++;
    return '${prefix}_${n.toString().padLeft(4, '0')}';
  }

  // —— 1) بادئات طلب عراقية × أنواع كيان مدعومة ——
  const iraqiPrefixes = <String>[
    'اريد',
    'أريد',
    'اريدلي',
    'أريدلي',
    'اريد لي',
    'أريد لي',
    'طلعلي',
    'طلع لي',
    'دورلي',
    'دور لي',
    'شوفلي',
    'شوف لي',
    'دلني',
    'دلني على',
    'جيبلي',
    'جيب لي',
    'وين',
    'وين اكو',
    'اكو يمكم',
    'عدكم',
    'عندكم',
  ];

  const entityExact = <({String phrase, String intent, String cat})>[
    (phrase: 'صيدلية', intent: 'findPharmacy', cat: 'ent_pharm'),
    (phrase: 'صيدليه', intent: 'findPharmacy', cat: 'ent_pharm'),
    (phrase: 'صيدليات', intent: 'findPharmacy', cat: 'ent_pharm'),
    (phrase: 'مختبر', intent: 'findLab', cat: 'ent_lab'),
    (phrase: 'مختبرات', intent: 'findLab', cat: 'ent_lab'),
    (phrase: 'مختبر تحليل', intent: 'findLab', cat: 'ent_lab'),
    (phrase: 'اشعة', intent: 'findRadiology', cat: 'ent_rad'),
    (phrase: 'أشعة', intent: 'findRadiology', cat: 'ent_rad'),
    (phrase: 'اشعه', intent: 'findRadiology', cat: 'ent_rad'),
    (phrase: 'تصوير شعاعي', intent: 'findRadiology', cat: 'ent_rad'),
    (phrase: 'صورة شعاعية', intent: 'findRadiology', cat: 'ent_rad'),
    (phrase: 'أشعة سينية', intent: 'findRadiology', cat: 'ent_rad'),
    (phrase: 'علاج طبيعي', intent: 'findPhysio', cat: 'ent_physio'),
    (phrase: 'فيزيو', intent: 'findPhysio', cat: 'ent_physio'),
    (phrase: 'مستلزمات طبية', intent: 'findSupply', cat: 'ent_supply'),
    (phrase: 'تجهيزات طبية', intent: 'findSupply', cat: 'ent_supply'),
    (phrase: 'باقات', intent: 'findPackage', cat: 'ent_pkg'),
    (phrase: 'باقة', intent: 'findPackage', cat: 'ent_pkg'),
    (phrase: 'عروض', intent: 'findOffer', cat: 'ent_offer'),
    (phrase: 'عرض', intent: 'findOffer', cat: 'ent_offer'),
    (phrase: 'تحليل الدم', intent: 'findAnalysis', cat: 'ent_analysis'),
  ];

  for (final p in iraqiPrefixes) {
    for (final e in entityExact) {
      final anyOf = e.intent == 'findOffer'
          ? const ['findOffer', 'findPackage']
          : <String>[e.intent];
      out.add(
        _m7(
          id: nextId('m7_pref'),
          family: M7Family.generated,
          category: e.cat,
          input: '$p ${e.phrase}',
          expectedIntent: anyOf.length == 1 ? e.intent : null,
          expectedIntentAnyOf: anyOf.length > 1 ? anyOf : const [],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // —— 2) تخصصات × بادئات × أشكال ——
  const specPrefixes = <String>[
    'اريد',
    'أريد',
    'اريدلي',
    'طلعلي',
    'دورلي',
    'شوفلي',
    'جيبلي',
    'دلني على',
    'وين اكو',
    'عدكم',
    'عندكم',
    'اكو يمكم',
  ];
  const specialties = <String>[
    'اطفال',
    'أطفال',
    'نسائية',
    'باطنية',
    'قلبية',
    'جلدية',
    'عظام',
    'اسنان',
    'أسنان',
    'عيون',
    'انف واذن',
    'نفسية',
    'جراحة',
    'مسالك',
    'اعصاب',
    'صدرية',
    'غدد',
    'تغذية',
    'تخدير',
    'اورام',
  ];
  final specForms = <String Function(String)>[
    (s) => 'طبيب $s',
    (s) => 'دكتور $s',
    (s) => s,
  ];
  const specAny = [
    'specialtySearch',
    'doctorSearch',
    'generalSearch',
    'findDoctor',
  ];
  for (final p in specPrefixes) {
    for (final s in specialties) {
      for (final form in specForms) {
        out.add(
          _m7(
            id: nextId('m7_spec'),
            family: M7Family.generated,
            category: 'spec_$s',
            input: '$p ${form(s)}',
            expectedIntentAnyOf: specAny,
            expectNotRefuse: true,
          ),
        );
      }
    }
  }

  // —— 3) مصفوفة أفعال typed (PHONE ≠ WHATSAPP) ——
  const actionRows = <({String input, List<String> intents, String cat})>[
    (
      input: 'اتصل ب صيدلية الصفا',
      intents: ['callPharmacy'],
      cat: 'act_call_pharm',
    ),
    (
      input: 'اتصل ب صيدلية النور',
      intents: ['callPharmacy'],
      cat: 'act_call_pharm',
    ),
    (
      input: 'اتصل ب صيدلية الامل',
      intents: ['callPharmacy'],
      cat: 'act_call_pharm',
    ),
    (
      input: 'اتصل ب مختبر النور',
      intents: ['callLab'],
      cat: 'act_call_lab',
    ),
    (
      input: 'اتصل ب مختبر الشفاء',
      intents: ['callLab'],
      cat: 'act_call_lab',
    ),
    (
      input: 'اتصل ب مركز علاج طبيعي الامل',
      intents: ['callPhysio', 'findPhysio'],
      cat: 'act_call_physio',
    ),
    (
      input: 'اتصل ب مستلزمات الرافدين',
      intents: ['callSupply', 'findSupply'],
      cat: 'act_call_supply',
    ),
    (
      input: 'دز واتساب ل صيدلية الصفا',
      intents: ['messagePharmacy', 'messageDoctor'],
      cat: 'act_wa_pharm',
    ),
    (
      input: 'دزله واتساب صيدلية النور',
      intents: ['messagePharmacy', 'messageDoctor'],
      cat: 'act_wa_pharm',
    ),
    (
      input: 'دز واتساب ل مختبر النور',
      intents: ['messageLab', 'messageDoctor'],
      cat: 'act_wa_lab',
    ),
    (
      input: 'دز واتساب ل مركز علاج طبيعي الامل',
      intents: ['messagePhysio', 'messageDoctor'],
      cat: 'act_wa_physio',
    ),
    (
      input: 'وين صيدلية الصفا',
      intents: ['findPharmacy', 'showLocation', 'generalSearch'],
      cat: 'act_loc_pharm',
    ),
    (
      input: 'وين مختبر النور',
      intents: ['findLab', 'showLocation', 'generalSearch'],
      cat: 'act_loc_lab',
    ),
    (
      input: 'افتح صيدلية الصفا',
      intents: ['findPharmacy', 'openPharmacy', 'generalSearch', 'doctorSearch'],
      cat: 'act_open_pharm',
    ),
    (
      input: 'افتح مختبر النور',
      intents: ['findLab', 'openLab', 'generalSearch', 'doctorSearch'],
      cat: 'act_open_lab',
    ),
  ];
  const actionPrefixes = [
    '',
    'اريد ',
    'أريد ',
    'طلعلي ',
    'شوفلي ',
    'دورلي ',
  ];
  for (final row in actionRows) {
    for (final ap in actionPrefixes) {
      final intents = row.input.contains('افتح مختبر')
          ? <String>[
              ...row.intents,
              'showProfile',
            ]
          : row.intents;
      out.add(
        _m7(
          id: nextId('m7_act'),
          family: M7Family.generated,
          category: row.cat,
          input: '${ap}${row.input}'.trim(),
          expectedIntent: intents.length == 1 ? intents.first : null,
          expectedIntentAnyOf: intents.length > 1 ? intents : const [],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // —— 4) STT-like ——
  const sttPairs = <({String phrase, List<String> intents})>[
    (
      phrase: 'صيدلييه',
      intents: ['findPharmacy', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'علاج طبييعي',
      intents: ['findPhysio', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'مركز علاج طبييعي',
      intents: ['findPhysio', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'مستلزمات طبيه',
      intents: ['findSupply', 'generalSearch'],
    ),
    (
      phrase: 'مختبرات',
      intents: ['findLab'],
    ),
    (
      phrase: 'اشعع',
      intents: [
        'findRadiology',
        'generalSearch',
        'doctorSearch',
        'specialtySearch',
      ],
    ),
    (
      phrase: 'تصوير شعاعيي',
      intents: ['findRadiology', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'فيزيو ثيرابي',
      intents: ['findPhysio', 'generalSearch'],
    ),
    (
      phrase: 'باااقات',
      intents: ['findPackage', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'خصمووات',
      intents: ['findOffer', 'findPackage', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'اريد اريد طبيب اطفال',
      intents: ['specialtySearch', 'doctorSearch', 'generalSearch'],
    ),
    (
      phrase: 'دزله وات ساب',
      intents: [
        'messageDoctor',
        'messagePharmacy',
        'messagePhysio',
        'unknown',
        'generalSearch',
      ],
    ),
    (
      phrase: 'دزله واتساب',
      intents: [
        'messageDoctor',
        'messagePharmacy',
        'messagePhysio',
        'unknown',
        'generalSearch',
      ],
    ),
    (
      phrase: 'صيدليه الصفا',
      intents: ['findPharmacy', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'مختبرالنور',
      intents: ['findLab', 'generalSearch', 'doctorSearch'],
    ),
  ];
  const sttPrefixes = [
    'أريد',
    'اريد',
    'طلعلي',
    'دورلي',
    'شوفلي',
    'وين اكو',
    'جيبلي',
    'عدكم',
    'عندكم',
    'اكو يمكم',
    'دلني على',
    'اريدلي',
  ];
  for (final p in sttPrefixes) {
    for (final s in sttPairs) {
      // عبارات تبدأ بطلب كامل لا تُسبق ببادئة
      final input = s.phrase.startsWith('اريد') || s.phrase.startsWith('دزله')
          ? s.phrase
          : '$p ${s.phrase}';
      out.add(
        _m7(
          id: nextId('m7_stt'),
          family: M7Family.stt,
          category: 'stt_var',
          input: input,
          expectedIntentAnyOf: s.intents,
        ),
      );
    }
  }

  // —— 5) عائلات أخطاء إملائية مسيطر عليها ——
  String delChar(String s) =>
      s.length < 3 ? s : '${s.substring(0, 2)}${s.substring(3)}';
  String dupChar(String s) =>
      s.length < 2 ? s : '${s.substring(0, 2)}${s[1]}${s.substring(2)}';
  String swapAdj(String s) {
    if (s.length < 3) return s;
    final chars = s.split('');
    final t = chars[1];
    chars[1] = chars[2];
    chars[2] = t;
    return chars.join();
  }

  String spaceInsert(String s) {
    if (s.length < 4) return s;
    return '${s.substring(0, 2)} ${s.substring(2)}';
  }

  String spaceRemove(String s) => s.replaceAll(' ', '');

  const typoBases = <({String phrase, List<String> intents})>[
    (phrase: 'صيدلية', intents: ['findPharmacy', 'generalSearch']),
    (phrase: 'مختبر', intents: ['findLab', 'generalSearch']),
    (phrase: 'اشعة', intents: ['findRadiology', 'generalSearch', 'specialtySearch']),
    (phrase: 'علاج طبيعي', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'مستلزمات طبية', intents: ['findSupply', 'generalSearch']),
    (phrase: 'باقات', intents: ['findPackage', 'generalSearch']),
    (phrase: 'عروض', intents: ['findOffer', 'findPackage', 'generalSearch']),
    (phrase: 'تصوير شعاعي', intents: ['findRadiology', 'generalSearch']),
    (phrase: 'صيدليات', intents: ['findPharmacy']),
    (phrase: 'مختبرات', intents: ['findLab']),
  ];
  final typoOps = <String Function(String)>[
    delChar,
    dupChar,
    swapAdj,
    spaceInsert,
    spaceRemove,
    (String s) => s.replaceAll('ة', 'ه'),
    (String s) =>
        s.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا'),
    (String s) => s.replaceAll('ى', 'ي'),
  ];
  const typoPrefixes = [
    'أريد',
    'اريد',
    'طلعلي',
    'دورلي',
    'شوفلي',
    'وين',
    'جيبلي',
    'عدكم',
  ];
  for (final p in typoPrefixes) {
    for (final base in typoBases) {
      for (final op in typoOps) {
        final mutated = op(base.phrase);
        if (mutated.trim().isEmpty || mutated == base.phrase) continue;
        out.add(
          _m7(
            id: nextId('m7_typo'),
            family: M7Family.typo,
            category: 'typo_var',
            input: '$p $mutated',
            expectedIntentAnyOf: [
              ...base.intents,
              'doctorSearch',
              'specialtySearch',
              'unknown',
            ],
          ),
        );
      }
    }
  }

  // —— 6) عدائي / إيجابي زائف ——
  const adversarial = <({String input, String? not, bool refuse, List<String> any})>[
    (input: 'سن', not: 'specialtySearch', refuse: false, any: []),
    (input: 'سنوات', not: 'findDoctor', refuse: false, any: []),
    (input: 'علاج', not: null, refuse: false, any: ['findPhysio', 'generalSearch', 'doctorSearch', 'specialtySearch', 'unknown']),
    (input: 'تحليل', not: 'doctorSearch', refuse: false, any: ['findAnalysis', 'findLab', 'generalSearch', 'unknown']),
    (input: 'مختبر', not: null, refuse: false, any: ['findLab']),
    (input: 'أشعة', not: 'specialtySearch', refuse: false, any: ['findRadiology']),
    (input: 'اشعة', not: 'specialtySearch', refuse: false, any: ['findRadiology']),
    (input: 'الثاني', not: null, refuse: false, any: ['selectOrdinal', 'selectResult', 'unknown', 'generalSearch']),
    (input: 'نعم', not: null, refuse: false, any: ['unknown', 'confirm', 'generalSearch']),
    (input: 'على', not: 'doctorSearch', refuse: false, any: ['unknown', 'generalSearch']),
    (input: 'دلني على', not: 'doctorSearch', refuse: false, any: ['unknown', 'generalSearch', 'clarify']),
    (input: 'هو', not: null, refuse: false, any: ['unknown', 'generalSearch', 'pronounResolve', 'doctorSearch']),
    (input: 'هي', not: null, refuse: false, any: ['unknown', 'generalSearch', 'pronounResolve', 'doctorSearch']),
    (input: 'وينه', not: null, refuse: false, any: ['showLocation', 'unknown', 'generalSearch']),
    (input: 'اتصل بيه', not: null, refuse: false, any: ['callDoctor', 'unknown', 'generalSearch']),
    (input: 'دزله', not: null, refuse: false, any: ['messageDoctor', 'unknown', 'generalSearch']),
    (input: 'مختبر تحاليل', not: 'findAnalysis', refuse: false, any: ['findLab']),
    (input: 'تحليل الدم', not: 'doctorSearch', refuse: false, any: ['findAnalysis']),
    (input: 'CBC', not: 'doctorSearch', refuse: false, any: ['findAnalysis', 'generalSearch', 'unknown']),
    (input: 'أريد علاج طبيعي', not: 'doctorSearch', refuse: false, any: ['findPhysio']),
    (input: 'أريد علاج', not: null, refuse: false, any: ['findPhysio', 'generalSearch', 'doctorSearch', 'specialtySearch']),
  ];
  for (final a in adversarial) {
    out.add(
      _m7(
        id: nextId('m7_adv'),
        family: M7Family.adversarial,
        category: 'adv_boundary',
        input: a.input,
        expectedIntentNot: a.not,
        expectedIntentAnyOf: a.any,
        expectRefuse: a.refuse,
      ),
    );
  }

  // توسيع حدود إيجابية زائفة عبر بادئات
  const fpPhrases = <({String phrase, String? not, List<String> any})>[
    (phrase: 'سن', not: 'specialtySearch', any: ['unknown', 'generalSearch', 'doctorSearch']),
    (phrase: 'سنوات الخبرة', not: null, any: ['unknown', 'generalSearch', 'doctorSearch']),
    (phrase: 'تحليل', not: 'doctorSearch', any: ['findAnalysis', 'findLab', 'generalSearch', 'unknown']),
    (phrase: 'على الدكتور', not: null, any: ['doctorSearch', 'generalSearch', 'unknown', 'findDoctor']),
    (phrase: 'اشعة مقطعية', not: 'specialtySearch', any: ['findRadiology', 'generalSearch']),
    (phrase: 'صورة شعاعية', not: 'specialtySearch', any: ['findRadiology']),
  ];
  for (final p in ['أريد', 'اريد', 'طلعلي', 'شوفلي', 'دورلي', 'وين']) {
    for (final fp in fpPhrases) {
      out.add(
        _m7(
          id: nextId('m7_fp'),
          family: M7Family.falsePositive,
          category: 'fp_boundary',
          input: '$p ${fp.phrase}',
          expectedIntentNot: fp.not,
          expectedIntentAnyOf: fp.any,
        ),
      );
    }
  }

  // —— 7) خارج النطاق ——
  const oos = [
    'منو فاز بالمباراة',
    'سعر النفط اليوم',
    'شغل لي فيسبوك',
    'ترجم كلمة school',
    'وصفة طبخ دولمة',
    'منو الممثل الافضل',
    'كم درجة الحرارة',
    'حالة الطقس بغداد',
    'اخبار السياسة اليوم',
    'حل معادلة 2x+5',
    'شغل اغنية',
    'منو فاز بكاس العالم',
    'سعر الدولار',
    'افتح يوتيوب',
    'احسب لي 15*12',
    'ما هي عاصمة فرنسا',
    'من اخترع الهاتف',
    'نكتة جديدة',
    'سافر لي تذكرة طيران',
    'اطلب بيتزا',
    'شراء ملابس اونلاين',
    'نتائج الدوري',
    'توقعات الابراج',
    'قصيدة غزل',
    'برمجة بايثون',
    'سعر الذهب',
    'بث مباشر مباراة',
    'كلمات اغنية',
    'من فاز بالانتخابات',
    'تحضير كيكة',
  ];
  for (final q in oos) {
    for (final wrap in ['', 'لو سمحت ', 'ممكن ']) {
      out.add(
        _m7(
          id: nextId('m7_oos'),
          family: M7Family.oos,
          category: 'oos_general',
          input: '$wrap$q'.trim(),
          expectRefuse: true,
        ),
      );
    }
  }

  // —— 8) تصحيح / ضمائر / ترتيبات (دور واحد — توقعات نية فقط) ——
  const correctionForms = [
    'لا الأول',
    'لا الثاني',
    'لا قصدي نسائية',
    'لا قصدي صيدلية',
    'لا مختبر',
    'لا لا قصدي صيدلية',
    'لا اتصل بيه',
    'لا دزله واتساب',
    'غيره',
    'مو هذا',
  ];
  for (final c in correctionForms) {
    out.add(
      _m7(
        id: nextId('m7_corr'),
        family: M7Family.generated,
        category: 'corr_form',
        input: c,
        expectedIntentAnyOf: const [
          'unknown',
          'generalSearch',
          'rejectSuggestion',
          'correctSelection',
          'selectOrdinal',
          'selectResult',
          'callDoctor',
          'messageDoctor',
          'specialtySearch',
          'findPharmacy',
          'findLab',
          'doctorSearch',
        ],
      ),
    );
  }

  const pronouns = [
    'هو',
    'هي',
    'هذا',
    'هاي',
    'بيه',
    'بيها',
    'وياه',
    'وياها',
    'ماله',
    'مالتها',
    'نفسه',
    'نفسها',
    'وينه',
    'وينها',
  ];
  for (final pr in pronouns) {
    out.add(
      _m7(
        id: nextId('m7_prn'),
        family: M7Family.generated,
        category: 'pronoun_bare',
        input: pr,
        expectedIntentAnyOf: const [
          'unknown',
          'generalSearch',
          'showLocation',
          'callDoctor',
          'messageDoctor',
          'pronounResolve',
          'doctorSearch',
        ],
      ),
    );
  }

  const ordinals = [
    'الأول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الأخير',
    'اللي قبله',
    'اللي بعده',
    'رجع للأول',
  ];
  for (final o in ordinals) {
    out.add(
      _m7(
        id: nextId('m7_ord'),
        family: M7Family.generated,
        category: 'ordinal_bare',
        input: o,
        expectedIntentAnyOf: const [
          'selectOrdinal',
          'selectResult',
          'unknown',
          'generalSearch',
          'correctSelection',
          'doctorSearch',
        ],
      ),
    );
  }

  // —— 9) مركّبات طلب (بحث + فلتر لغوي) ——
  const compounds = <({String input, List<String> intents})>[
    (
      input: 'أريد طبيب أطفال قريب',
      intents: ['specialtySearch', 'doctorSearch', 'generalSearch'],
    ),
    (
      input: 'طلعلي صيدلية فيها واتساب',
      intents: ['findPharmacy', 'messagePharmacy', 'generalSearch'],
    ),
    (
      input: 'دورلي مختبر فتح اليوم',
      intents: ['findLab', 'generalSearch'],
    ),
    (
      input: 'أريد علاج طبيعي للنساء',
      intents: ['findPhysio', 'generalSearch'],
    ),
    (
      input: 'شوفلي أشعة مقطعية',
      intents: ['findRadiology', 'generalSearch'],
    ),
    (
      input: 'اريد باقات مخفضة',
      intents: ['findPackage', 'findOffer', 'generalSearch'],
    ),
    (
      input: 'جيبلي عروض الصيدليات',
      intents: ['findOffer', 'findPackage', 'findPharmacy', 'generalSearch'],
    ),
    (
      input: 'أريد مستلزمات طبية رخيصة',
      intents: ['findSupply', 'generalSearch'],
    ),
    (
      input: 'اتصل ب صيدلية الصفا واتساب',
      intents: ['callPharmacy', 'messagePharmacy', 'findPharmacy'],
    ),
    (
      input: 'دز واتساب واتصل ب صيدلية النور',
      intents: ['messagePharmacy', 'callPharmacy', 'findPharmacy', 'generalSearch'],
    ),
  ];
  for (final c in compounds) {
    for (final p in ['', 'لو سمحت ', 'يمكم ']) {
      out.add(
        _m7(
          id: nextId('m7_cmp'),
          family: M7Family.generated,
          category: 'compound',
          input: '$p${c.input}'.trim(),
          expectedIntentAnyOf: c.intents,
          expectNotRefuse: true,
        ),
      );
    }
  }

  // —— 10) أسماء وهمية — لا هلوسة كيان (نية بحث/رفض فقط) ——
  const fakeNames = [
    'دكتور زرزور الفوسفوري',
    'صيدلية الكويكب البعيد',
    'مختبر المريخ الشمالي',
    'مركز فيزيو القطب الجنوبي',
    'مستلزمات نبتون الطبية',
    'أشعة مجرة أندروميدا',
  ];
  for (final name in fakeNames) {
    for (final p in ['أريد', 'طلعلي', 'دورلي', 'وين']) {
      out.add(
        _m7(
          id: nextId('m7_hallu'),
          family: M7Family.adversarial,
          category: 'no_hallucination',
          input: '$p $name',
          expectNoEntityHallucination: true,
          expectedIntentAnyOf: const [
            'doctorSearch',
            'specialtySearch',
            'findPharmacy',
            'findLab',
            'findPhysio',
            'findSupply',
            'findRadiology',
            'generalSearch',
            'unknown',
          ],
        ),
      );
    }
  }

  // —— 11) حدود تحليل / مختبر إضافية ——
  const analysisBoundary = [
    ('تحليل', ['findAnalysis', 'findLab', 'generalSearch', 'unknown']),
    ('أريد تحليل', ['findAnalysis', 'findLab', 'generalSearch']),
    ('مختبر تحاليل', ['findLab']),
    ('أريد مختبر تحاليل', ['findLab']),
    ('تحليل الدم', ['findAnalysis']),
    ('أريد تحليل الدم', ['findAnalysis']),
    ('CBC', ['findAnalysis', 'generalSearch', 'unknown']),
    ('أريد CBC', ['findAnalysis', 'generalSearch', 'unknown']),
  ];
  for (final a in analysisBoundary) {
    for (final p in ['', 'شوفلي ', 'دورلي ', 'طلعلي ']) {
      final input = '${p}${a.$1}'.trim();
      out.add(
        _m7(
          id: nextId('m7_anal'),
          family: M7Family.adversarial,
          category: 'analysis_boundary',
          input: input,
          expectedIntentAnyOf: a.$2,
          expectedIntentNot: a.$1.contains('مختبر') ? 'findAnalysis' : null,
        ),
      );
    }
  }

  // —— 12) أشعة أشكال إضافية × بادئات ——
  const radForms = [
    'اشعة',
    'أشعة',
    'اشعه',
    'تصوير شعاعي',
    'صورة شعاعية',
    'أشعة سينية',
    'اشعة مقطعية',
    'رنين مغناطيسي',
  ];
  for (final r in radForms) {
    for (final p in iraqiPrefixes) {
      out.add(
        _m7(
          id: nextId('m7_rad'),
          family: M7Family.generated,
          category: 'radiology_form',
          input: '$p $r',
          expectedIntentAnyOf: (r.contains('رنين') || r.contains('مقطعية'))
              ? const [
                  'findRadiology',
                  'generalSearch',
                  'specialtySearch',
                  'doctorSearch',
                ]
              : const [
                  'findRadiology',
                  'generalSearch',
                  'doctorSearch',
                ],
          expectedIntentNot: (r.contains('رنين') || r.contains('مقطعية'))
              ? null
              : 'specialtySearch',
          expectNotRefuse: true,
        ),
      );
    }
  }

  // —— 13) دفعة توسعة حتمية للوصول ≥5000 مع أبعاد فهم إضافية ——
  out.addAll(_generateM7Batch2(startIndex: n));
  return List.unmodifiable(out);
}

List<M6CorpusCase> _generateM7Batch2({required int startIndex}) {
  final out = <M6CorpusCase>[];
  var n = startIndex;

  String nextId(String prefix) {
    n++;
    return '${prefix}_${n.toString().padLeft(4, '0')}';
  }

  // تخصصات إضافية × صيغ جمع/اختصاص
  const moreSpecs = [
    'اطفال',
    'نسائية',
    'باطنية',
    'قلبية',
    'جلدية',
    'عظام',
    'اسنان',
    'عيون',
    'نفسية',
    'جراحة عامة',
    'مسالك بولية',
    'اذن وانف',
    'تغذية',
    'غدد صماء',
    'صدرية',
  ];
  const moreForms = [
    'اطباء',
    'دكاترة',
    'اختصاص',
    'طبيب',
    'دكتور',
  ];
  const morePrefixes = [
    'اريد',
    'أريد',
    'طلعلي',
    'دورلي',
    'شوفلي',
    'جيبلي',
    'عدكم',
    'عندكم',
    'وين اكو',
    'اكو يمكم',
    'اريدلي',
    'دلني على',
  ];
  const specAny = [
    'specialtySearch',
    'doctorSearch',
    'generalSearch',
    'findDoctor',
  ];
  for (final p in morePrefixes) {
    for (final s in moreSpecs) {
      for (final f in moreForms) {
        out.add(
          _m7(
            id: nextId('m7b_spec'),
            family: M7Family.generated,
            category: 'spec_ext',
            input: '$p $f $s',
            expectedIntentAnyOf: specAny,
            expectNotRefuse: true,
          ),
        );
      }
    }
  }

  // فلاتر لغوية × أنواع
  const filters = ['قرب', 'قريب', 'اليمنا', 'فتح', 'اليوم', 'للنساء', 'رجال'];
  const filterEntities = <({String phrase, List<String> intents})>[
    (phrase: 'صيدلية', intents: ['findPharmacy', 'generalSearch']),
    (phrase: 'مختبر', intents: ['findLab', 'generalSearch']),
    (phrase: 'علاج طبيعي', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'اشعة', intents: ['findRadiology', 'generalSearch']),
    (phrase: 'مستلزمات طبية', intents: ['findSupply', 'generalSearch']),
    (phrase: 'طبيب اطفال', intents: ['specialtySearch', 'doctorSearch', 'generalSearch']),
  ];
  for (final p in ['أريد', 'طلعلي', 'دورلي', 'شوفلي', 'جيبلي']) {
    for (final e in filterEntities) {
      for (final f in filters) {
        out.add(
          _m7(
            id: nextId('m7b_filt'),
            family: M7Family.generated,
            category: 'filter_combo',
            input: '$p ${e.phrase} $f',
            expectedIntentAnyOf: e.intents,
            expectNotRefuse: true,
          ),
        );
      }
    }
  }

  // أسماء مركّبة typed × أفعال
  const names = ['الصفا', 'النور', 'الامل', 'الشفاء', 'الرافدين', 'الغدير'];
  const typedActions = <({String tmpl, List<String> intents, String cat})>[
    (
      tmpl: 'اتصل ب صيدلية {n}',
      intents: ['callPharmacy'],
      cat: 'act_call_pharm',
    ),
    (
      tmpl: 'دز واتساب ل صيدلية {n}',
      intents: ['messagePharmacy', 'messageDoctor'],
      cat: 'act_wa_pharm',
    ),
    (
      tmpl: 'وين صيدلية {n}',
      intents: ['findPharmacy', 'showLocation', 'generalSearch'],
      cat: 'act_loc_pharm',
    ),
    (
      tmpl: 'افتح صيدلية {n}',
      intents: ['findPharmacy', 'openPharmacy', 'generalSearch', 'doctorSearch'],
      cat: 'act_open_pharm',
    ),
    (
      tmpl: 'اتصل ب مختبر {n}',
      intents: ['callLab'],
      cat: 'act_call_lab',
    ),
    (
      tmpl: 'دز واتساب ل مختبر {n}',
      intents: ['messageLab', 'messageDoctor'],
      cat: 'act_wa_lab',
    ),
    (
      tmpl: 'وين مختبر {n}',
      intents: ['findLab', 'showLocation', 'generalSearch'],
      cat: 'act_loc_lab',
    ),
    (
      tmpl: 'اتصل ب مركز علاج طبيعي {n}',
      intents: ['callPhysio', 'findPhysio'],
      cat: 'act_call_physio',
    ),
    (
      tmpl: 'دز واتساب ل مركز علاج طبيعي {n}',
      intents: ['messagePhysio', 'messageDoctor'],
      cat: 'act_wa_physio',
    ),
    (
      tmpl: 'وين مركز علاج طبيعي {n}',
      intents: ['findPhysio', 'showLocation', 'generalSearch'],
      cat: 'act_loc_physio',
    ),
  ];
  for (final name in names) {
    for (final a in typedActions) {
      out.add(
        _m7(
          id: nextId('m7b_act'),
          family: M7Family.generated,
          category: a.cat,
          input: a.tmpl.replaceAll('{n}', name),
          expectedIntent: a.intents.length == 1 ? a.intents.first : null,
          expectedIntentAnyOf:
              a.intents.length > 1 ? a.intents : const [],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // STT إضافي: تكرار / مسافات / تقطيع
  const sttExtra = <({String phrase, List<String> intents})>[
    (
      phrase: 'اريد اريد صيدلية',
      intents: ['findPharmacy', 'generalSearch'],
    ),
    (
      phrase: 'أريد  مختبر',
      intents: ['findLab'],
    ),
    (
      phrase: 'طلعليطلعلي علاج طبيعي',
      intents: ['findPhysio', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'دزله  واتساب',
      intents: [
        'messageDoctor',
        'messagePharmacy',
        'messagePhysio',
        'unknown',
        'generalSearch',
      ],
    ),
    (
      phrase: 'دزله واتس اب',
      intents: [
        'messageDoctor',
        'messagePharmacy',
        'messagePhysio',
        'unknown',
        'generalSearch',
      ],
    ),
    (
      phrase: 'اشعةاشعة',
      intents: ['findRadiology', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'مستلزمات  طبية',
      intents: ['findSupply'],
    ),
    (
      phrase: 'باقاتباقات',
      intents: ['findPackage', 'generalSearch', 'doctorSearch'],
    ),
    (
      phrase: 'صيد لية',
      intents: ['findPharmacy', 'generalSearch', 'doctorSearch', 'unknown'],
    ),
    (
      phrase: 'مخت بر',
      intents: ['findLab', 'generalSearch', 'doctorSearch', 'unknown'],
    ),
    (
      phrase: 'علاج  طبيعي',
      intents: ['findPhysio'],
    ),
    (
      phrase: 'تصويرشعاعي',
      intents: ['findRadiology', 'generalSearch', 'doctorSearch'],
    ),
  ];
  for (final s in sttExtra) {
    for (final p in ['', 'أريد ', 'طلعلي ', 'دورلي ', 'شوفلي ', 'وين ']) {
      final input = s.phrase.startsWith('اريد') ||
              s.phrase.startsWith('أريد') ||
              s.phrase.startsWith('طلعلي') ||
              s.phrase.startsWith('دزله')
          ? s.phrase
          : '${p}${s.phrase}'.trim();
      out.add(
        _m7(
          id: nextId('m7b_stt'),
          family: M7Family.stt,
          category: 'stt_extra',
          input: input,
          expectedIntentAnyOf: s.intents,
        ),
      );
    }
  }

  // إيجابي زائف موسّع
  const fpExtra = [
    ('سنتين', 'specialtySearch'),
    ('ثلاث سنوات', 'specialtySearch'),
    ('على الطريق', null),
    ('مختبر المدرسة', null),
    ('أشعة الشمس', null),
    ('علاج بالاعشاب', null),
    ('تحليل سياسي', null),
  ];
  for (final fp in fpExtra) {
    for (final p in ['', 'أريد ', 'شوفلي ', 'دورلي ']) {
      out.add(
        _m7(
          id: nextId('m7b_fp'),
          family: M7Family.falsePositive,
          category: 'fp_extra',
          input: '${p}${fp.$1}'.trim(),
          expectedIntentNot: fp.$2,
          expectedIntentAnyOf: const [
            'unknown',
            'generalSearch',
            'doctorSearch',
            'findLab',
            'findRadiology',
            'findPhysio',
            'findAnalysis',
            'specialtySearch',
          ],
        ),
      );
    }
  }

  // OOS إضافي
  const oosExtra = [
    'منو احسن لاعب',
    'سعر البيتكوين',
    'وصفة كبة',
    'اخبار هوليود',
    'حل سودوكو',
    'ترجم للانجليزي',
    'افتح انستغرام',
    'احجز فندق',
    'شراء سيارة',
    'نتيجة اليانصيب',
  ];
  for (final q in oosExtra) {
    for (final wrap in ['', 'ممكن ', 'لو سمحت ', 'يا غدير ']) {
      out.add(
        _m7(
          id: nextId('m7b_oos'),
          family: M7Family.oos,
          category: 'oos_extra',
          input: '$wrap$q'.trim(),
          expectRefuse: true,
        ),
      );
    }
  }

  // ضمائر + أفعال سياقية (بدون سياق — لا تنفيذ)
  const pronounActions = [
    'اتصل بيه',
    'اتصل بيها',
    'دزله واتساب',
    'دزلها واتساب',
    'وينه',
    'وينها',
    'افتحه',
    'افتحها',
  ];
  for (final pa in pronounActions) {
    out.add(
      _m7(
        id: nextId('m7b_prn'),
        family: M7Family.generated,
        category: 'pronoun_action_bare',
        input: pa,
        expectedIntentAnyOf: const [
          'callDoctor',
          'messageDoctor',
          'showLocation',
          'showProfile',
          'unknown',
          'generalSearch',
          'openDoctor',
          'pronounResolve',
          'doctorSearch',
        ],
      ),
    );
  }

  // حزم/عروض علاقات
  const pkgOffer = [
    ('باقة مختبر', ['findPackage', 'findLab', 'generalSearch']),
    ('عروض صيدلية', ['findOffer', 'findPackage', 'findPharmacy', 'generalSearch']),
    ('باقات اشعة', ['findPackage', 'findRadiology', 'generalSearch']),
    ('خصم صيدلية', ['findOffer', 'findPackage', 'findPharmacy', 'generalSearch']),
    ('عرض باقة', ['findOffer', 'findPackage', 'generalSearch']),
  ];
  for (final po in pkgOffer) {
    for (final p in iraqiBatch2Prefixes) {
      out.add(
        _m7(
          id: nextId('m7b_pkg'),
          family: M7Family.generated,
          category: 'pkg_offer',
          input: '$p ${po.$1}',
          expectedIntentAnyOf: po.$2,
          expectNotRefuse: true,
        ),
      );
    }
  }

  return out;
}

const iraqiBatch2Prefixes = [
  'اريد',
  'أريد',
  'طلعلي',
  'دورلي',
  'شوفلي',
  'جيبلي',
  'عدكم',
  'عندكم',
  'وين اكو',
  'اكو يمكم',
  'اريدلي',
  'دلني على',
];
