import 'dart:convert';
import 'dart:io';

import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';

/// M6 — تمثيل حالة corpus (اختبارات فقط، ليست منطق تشغيل).
class M6CorpusCase {
  const M6CorpusCase({
    required this.id,
    required this.source,
    required this.category,
    required this.input,
    this.expectedIntent,
    this.expectedIntentAnyOf = const [],
    this.expectedIntentNot,
    this.expectRefuse = false,
    this.expectNotRefuse = false,
    this.expectNoEntityHallucination = false,
    this.expectedNotPlatformForce = false,
    this.expectedActionKind,
    this.expectedEntityType,
    this.expectedCanonicalId,
    this.expectedClarification,
    this.expectedConfidence,
    this.notes,
  });

  final String id;
  final String source; // golden | generated
  final String category;
  final String input;

  final String? expectedIntent;
  final List<String> expectedIntentAnyOf;
  final String? expectedIntentNot;
  final bool expectRefuse;
  final bool expectNotRefuse;
  final bool expectNoEntityHallucination;
  final bool expectedNotPlatformForce;
  final String? expectedActionKind;
  final String? expectedEntityType;
  final String? expectedCanonicalId;
  final bool? expectedClarification;
  final String? expectedConfidence;
  final String? notes;

  factory M6CorpusCase.fromJson(Map<String, dynamic> j) {
    final any = j['expectedIntentAnyOf'];
    return M6CorpusCase(
      id: j['id'] as String,
      source: (j['source'] as String?) ?? 'golden',
      category: j['category'] as String,
      input: j['input'] as String? ?? j['query'] as String? ?? '',
      expectedIntent: j['expectedIntent'] as String?,
      expectedIntentAnyOf: any is List
          ? any.map((e) => e.toString()).toList()
          : const [],
      expectedIntentNot: j['expectedIntentNot'] as String?,
      expectRefuse: j['expectRefuse'] == true,
      expectNotRefuse: j['expectNotRefuse'] == true,
      expectNoEntityHallucination: j['expectNoEntityHallucination'] == true,
      expectedNotPlatformForce: j['expectedNotPlatformForce'] == true,
      expectedActionKind: j['expectedActionKind'] as String?,
      expectedEntityType: j['expectedEntityType'] as String?,
      expectedCanonicalId: j['expectedCanonicalId'] as String?,
      expectedClarification: j['expectedClarification'] as bool?,
      expectedConfidence: j['expectedConfidence'] as String?,
      notes: j['notes'] as String?,
    );
  }

  bool matchesIntent(AssistantIntent intent) {
    final name = intent.name;
    if (expectedIntentNot != null && name == expectedIntentNot) {
      return false;
    }
    if (expectedIntent != null) return name == expectedIntent;
    if (expectedIntentAnyOf.isNotEmpty) {
      return expectedIntentAnyOf.contains(name);
    }
    return true;
  }
}

List<M6CorpusCase> loadM6GoldenCorpus() {
  final file = File('test/fixtures/m6_iraqi_corpus_golden.json');
  final decoded = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return [
    for (final row in decoded)
      M6CorpusCase.fromJson(Map<String, dynamic>.from(row as Map)),
  ];
}

/// توليد حتمي لتركيبات لغة عراقية × نوع كيان (بلا عشوائية).
List<M6CorpusCase> generateM6CorpusCases() {
  const prefixes = <String>[
    'أريد',
    'اريد',
    'طلعلي',
    'دورلي',
    'شوفلي',
    'وين',
    'وين اكو',
    'اكو',
    'عدكم',
    'عندكم',
  ];

  const entities = <({String phrase, String intent, String category})>[
    (phrase: 'صيدلية', intent: 'findPharmacy', category: 'gen_pharmacy'),
    (phrase: 'صيدليه', intent: 'findPharmacy', category: 'gen_pharmacy'),
    (phrase: 'صيدليات', intent: 'findPharmacy', category: 'gen_pharmacy'),
    (phrase: 'مختبر', intent: 'findLab', category: 'gen_lab'),
    (phrase: 'مختبرات', intent: 'findLab', category: 'gen_lab'),
    (phrase: 'علاج طبيعي', intent: 'findPhysio', category: 'gen_physio'),
    (phrase: 'فيزيو', intent: 'findPhysio', category: 'gen_physio'),
    (phrase: 'تأهيل', intent: 'findPhysio', category: 'gen_physio'),
    (phrase: 'مستلزمات طبية', intent: 'findSupply', category: 'gen_supply'),
    (phrase: 'تجهيزات طبية', intent: 'findSupply', category: 'gen_supply'),
    (phrase: 'اشعة', intent: 'findRadiology', category: 'gen_radiology'),
    (phrase: 'أشعة', intent: 'findRadiology', category: 'gen_radiology'),
    (phrase: 'باقات', intent: 'findPackage', category: 'gen_package'),
    (phrase: 'عروض', intent: 'findOffer', category: 'gen_offer'),
  ];

  final out = <M6CorpusCase>[];
  var n = 0;
  for (final p in prefixes) {
    for (final e in entities) {
      n++;
      // عروض: اقبل findOffer أو findPackage
      final anyOf = e.intent == 'findOffer'
          ? const ['findOffer', 'findPackage']
          : <String>[e.intent];
      out.add(
        M6CorpusCase(
          id: 'gen_pref_ent_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: e.category,
          input: '$p ${e.phrase}',
          expectedIntent: anyOf.length == 1 ? e.intent : null,
          expectedIntentAnyOf: anyOf.length > 1 ? anyOf : const [],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // بادئات طلب إضافية × صيدلية/فيزيو/مستلزمات فقط (تقليل الضوضاء).
  const extraPrefixes = ['أريدلي', 'اريدلي', 'دلني على', 'أبي', 'ابي'];
  const coreEntities = <({String phrase, String intent, String cat})>[
    (phrase: 'صيدلية', intent: 'findPharmacy', cat: 'gen_extra_pharm'),
    (phrase: 'علاج طبيعي', intent: 'findPhysio', cat: 'gen_extra_physio'),
    (phrase: 'مستلزمات', intent: 'findSupply', cat: 'gen_extra_supply'),
    (phrase: 'مختبر', intent: 'findLab', cat: 'gen_extra_lab'),
  ];
  for (final p in extraPrefixes) {
    for (final e in coreEntities) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_extra_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: e.cat,
          input: '$p ${e.phrase}',
          expectedIntentAnyOf: [e.intent, 'generalSearch', 'doctorSearch'],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // تنويعات أطفال حتمية.
  const pedVariants = [
    'طبيب أطفال',
    'دكتور اطفال',
    'طبيب جهال',
    'دكتور اطفل',
    'طبيب للجهال',
    'اطباء اطفال',
  ];
  for (final ped in pedVariants) {
    for (final p in ['أريد', 'اريد', 'طلعلي', 'دورلي']) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_ped_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: 'gen_pediatrics',
          input: '$p $ped',
          expectedIntentAnyOf: const [
            'specialtySearch',
            'doctorSearch',
            'generalSearch',
          ],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // تنويعات واتساب إملائية (نية رسالة أو منصة).
  const waForms = [
    'واتساب',
    'واتس',
    'واتس اب',
    'وتساب',
    'وات ساب',
  ];
  for (final w in waForms) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_wa_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'gen_whatsapp_form',
        input: 'دزله $w',
        expectedIntentAnyOf: const [
          'messageDoctor',
          'messagePharmacy',
          'messagePhysio',
          'unknown',
          'generalSearch',
        ],
      ),
    );
  }

  // خارج النطاق مولَّد بحذر (قائمة ثابتة).
  const oos = [
    'منو فاز بالمباراة',
    'سعر النفط اليوم',
    'شغل لي فيسبوك',
    'ترجم كلمة school',
    'وصفة طبخ دولمة',
    'منو الممثل الافضل',
  ];
  for (final q in oos) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_oos_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'gen_out_of_scope',
        input: q,
        expectRefuse: true,
      ),
    );
  }

  out.addAll(_generateM6V2ExtraCases(startIndex: n));
  return List.unmodifiable(out);
}

/// M6 V2 — توليد إضافي حتمي (STT / بادئات / أفعال / تصحيح).
List<M6CorpusCase> _generateM6V2ExtraCases({required int startIndex}) {
  final out = <M6CorpusCase>[];
  var n = startIndex;

  // بادئات أوسع × كيانات أساسية.
  const v2Prefixes = [
    'أريدلي',
    'اريدلي',
    'دلني على',
    'ابي',
    'أبي',
    'وريني',
    'جيبلي',
    'طلعلي',
    'شوفلي',
    'اكو يمكم',
  ];
  const v2Entities = <({String phrase, List<String> intents, String cat})>[
    (phrase: 'صيدلية', intents: ['findPharmacy'], cat: 'v2_gen_pharm'),
    (phrase: 'صيدليه', intents: ['findPharmacy'], cat: 'v2_gen_pharm'),
    (phrase: 'مختبر', intents: ['findLab'], cat: 'v2_gen_lab'),
    (phrase: 'علاج طبيعي', intents: ['findPhysio'], cat: 'v2_gen_physio'),
    (phrase: 'فيزيو', intents: ['findPhysio'], cat: 'v2_gen_physio'),
    (phrase: 'مستلزمات', intents: ['findSupply'], cat: 'v2_gen_supply'),
    (phrase: 'تجهيزات طبية', intents: ['findSupply'], cat: 'v2_gen_supply'),
    (phrase: 'اشعة', intents: ['findRadiology'], cat: 'v2_gen_rad'),
    (phrase: 'أشعة', intents: ['findRadiology'], cat: 'v2_gen_rad'),
    (phrase: 'باقات', intents: ['findPackage'], cat: 'v2_gen_pkg'),
    (phrase: 'عروض', intents: ['findOffer', 'findPackage'], cat: 'v2_gen_offer'),
    (phrase: 'خصومات', intents: ['findOffer', 'findPackage'], cat: 'v2_gen_offer'),
  ];
  for (final p in v2Prefixes) {
    for (final e in v2Entities) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_v2_pref_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: e.cat,
          input: '$p ${e.phrase}',
          expectedIntent: e.intents.length == 1 ? e.intents.first : null,
          expectedIntentAnyOf: e.intents.length > 1
              ? e.intents
              : const [],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // STT-like typos × prefixes (محدود الجودة).
  const sttPairs = <({String phrase, List<String> intents})>[
    (phrase: 'صيدلييه', intents: ['findPharmacy', 'generalSearch', 'doctorSearch']),
    (phrase: 'علاج طبييعي', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'مستلزمات طبيه', intents: ['findSupply', 'generalSearch']),
    (phrase: 'مختبرات', intents: ['findLab']),
    (phrase: 'اشعع', intents: ['findRadiology', 'generalSearch', 'doctorSearch', 'specialtySearch']),
    (phrase: 'فيزيو ثيرابي', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'باااقات', intents: ['findPackage', 'generalSearch', 'doctorSearch']),
    (phrase: 'خصمووات', intents: ['findOffer', 'findPackage', 'generalSearch', 'doctorSearch']),
  ];
  for (final p in ['أريد', 'اريد', 'طلعلي', 'وين اكو']) {
    for (final s in sttPairs) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_v2_stt_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: 'v2_gen_stt',
          input: '$p ${s.phrase}',
          expectedIntentAnyOf: s.intents,
          expectNotRefuse: true,
        ),
      );
    }
  }

  // أفعال اتصال/واتساب/موقع سياقية (نية فقط).
  const actionForms = [
    (q: 'اتصل بيه', any: ['callDoctor', 'unknown', 'generalSearch']),
    (q: 'دزله واتساب', any: ['messageDoctor', 'unknown', 'generalSearch']),
    (q: 'دزلها واتس', any: ['messageDoctor', 'unknown', 'generalSearch']),
    (q: 'راسله', any: ['messageDoctor', 'unknown', 'generalSearch', 'doctorSearch']),
    (q: 'وينه', any: ['showLocation', 'unknown', 'generalSearch', 'selectResult']),
    (q: 'وينها', any: ['showLocation', 'unknown', 'generalSearch', 'selectResult']),
    (q: 'افتحه', any: ['showProfile', 'selectResult', 'unknown', 'generalSearch']),
    (q: 'وريني', any: ['showProfile', 'unknown', 'generalSearch', 'doctorSearch']),
    (q: 'دكله', any: ['callDoctor']),
    (q: 'دكلهم', any: ['callDoctor']),
    (q: 'دلني عليه', any: ['showLocation']),
    (q: 'دلني عليها', any: ['showLocation']),
  ];
  for (final a in actionForms) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2_act_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2_gen_action',
        input: a.q,
        expectedIntentAnyOf: a.any,
      ),
    );
  }

  // تصحيح نوع الخدمة.
  const corrections = <({String q, List<String> intents})>[
    (q: 'لا قصدي صيدلية', intents: ['findPharmacy']),
    (q: 'قصدي مختبر', intents: ['findLab']),
    (q: 'أقصد علاج طبيعي', intents: ['findPhysio']),
    (q: 'قصدي مستلزمات', intents: ['findSupply']),
    (q: 'أقصد اشعة', intents: ['findRadiology']),
    (q: 'قصدي باقات', intents: ['findPackage']),
    (q: 'أقصد عروض', intents: ['findOffer', 'findPackage']),
    (q: 'لا قصدي صيدليه', intents: ['findPharmacy']),
  ];
  for (final c in corrections) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2_corr_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2_gen_correction',
        input: c.q,
        expectedIntent: c.intents.length == 1 ? c.intents.first : null,
        expectedIntentAnyOf: c.intents.length > 1 ? c.intents : const [],
        expectNotRefuse: true,
      ),
    );
  }

  // رفض اقتراح.
  for (final q in ['مو هذا', 'مو هو', 'غيره', 'مو هاي', 'لا مو هذا']) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2_rej_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2_gen_reject',
        input: q,
        expectNoEntityHallucination: true,
      ),
    );
  }

  // أطفال STT إضافي.
  for (final ped in ['طبيب اطفاال', 'دكتور جهاال', 'اطباء اطفالل', 'طبيب للجهال']) {
    for (final p in ['أريد', 'طلعلي', 'دورلي']) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_v2_ped_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: 'v2_gen_pediatrics',
          input: '$p $ped',
          expectedIntentAnyOf: const [
            'specialtySearch',
            'doctorSearch',
            'generalSearch',
          ],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // OOS إضافي.
  const oos2 = [
    'منو رئيس الوزراء',
    'شغل اغنية عراقية',
    'احسبلي 20*5',
    'هل عندي سكري',
    'افتح تيك توك',
    'شنو عاصمة فرنسا',
    'سعر الاسهم اليوم',
    'ترجم كلمة book',
  ];
  for (final q in oos2) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2_oos_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2_gen_oos',
        input: q,
        expectRefuse: true,
      ),
    );
  }

  // ترتيب إضافي.
  for (final q in [
    'الأول',
    'الاول',
    'الثاني',
    'الثالث',
    'الرابع',
    'الأخير',
    'الاخير',
    'اول واحد',
    'ثاني واحد',
  ]) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2_ord_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2_gen_ordinal',
        input: q,
        expectedIntent: 'selectResult',
      ),
    );
  }

  out.addAll(_generateM6V2Batch2(startIndex: n));
  return out;
}

/// دفعة ثانية لبلوغ ~1000 حالة meaningful (بادئات × كيانات × STT × تخصصات).
List<M6CorpusCase> _generateM6V2Batch2({required int startIndex}) {
  final out = <M6CorpusCase>[];
  var n = startIndex;

  const prefixes = [
    'أريد',
    'اريد',
    'أريدلي',
    'اريدلي',
    'طلعلي',
    'دورلي',
    'شوفلي',
    'وريني',
    'جيبلي',
    'دلني على',
    'وين',
    'وين اكو',
    'اكو',
    'عدكم',
    'عندكم',
    'اكو يمكم',
    'ابي',
    'أبي',
  ];
  const entities = <({String phrase, List<String> intents, String cat})>[
    (phrase: 'صيدلية', intents: ['findPharmacy'], cat: 'v2b_pharm'),
    (phrase: 'صيدليه قريبة', intents: ['findPharmacy'], cat: 'v2b_pharm'),
    (phrase: 'مختبر', intents: ['findLab'], cat: 'v2b_lab'),
    (phrase: 'مختبر تحاليل', intents: ['findLab'], cat: 'v2b_lab'),
    (phrase: 'علاج طبيعي', intents: ['findPhysio'], cat: 'v2b_physio'),
    (phrase: 'مركز تأهيل', intents: ['findPhysio', 'generalSearch'], cat: 'v2b_physio'),
    (phrase: 'فيزيو', intents: ['findPhysio'], cat: 'v2b_physio'),
    (phrase: 'مستلزمات طبية', intents: ['findSupply'], cat: 'v2b_supply'),
    (phrase: 'تجهيزات', intents: ['findSupply', 'generalSearch'], cat: 'v2b_supply'),
    (phrase: 'اشعة', intents: ['findRadiology'], cat: 'v2b_rad'),
    (phrase: 'أشعة مقطعية', intents: ['findRadiology', 'specialtySearch', 'generalSearch'], cat: 'v2b_rad'),
    (phrase: 'باقات', intents: ['findPackage'], cat: 'v2b_pkg'),
    (phrase: 'باقة دم', intents: ['findPackage', 'generalSearch'], cat: 'v2b_pkg'),
    (phrase: 'عروض', intents: ['findOffer', 'findPackage'], cat: 'v2b_offer'),
    (phrase: 'خصم', intents: ['findOffer', 'findPackage'], cat: 'v2b_offer'),
  ];
  for (final p in prefixes) {
    for (final e in entities) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_v2b_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: e.cat,
          input: '$p ${e.phrase}',
          expectedIntent: e.intents.length == 1 ? e.intents.first : null,
          expectedIntentAnyOf: e.intents.length > 1 ? e.intents : const [],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // تخصصات شائعة × بادئات.
  const specs = [
    'أطفال',
    'اطفال',
    'جهال',
    'باطنية',
    'قلبية',
    'نسائية',
    'جلدية',
    'عظام',
    'أعصاب',
    'اعصاب',
    'أنف وأذن',
    'انف واذن',
    'عيون',
    'أسنان',
    'اسنان',
  ];
  for (final p in ['أريد', 'اريد', 'طلعلي', 'دورلي', 'وين اكو', 'عدكم']) {
    for (final s in specs) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_v2b_spec_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: 'v2b_specialty',
          input: '$p طبيب $s',
          expectedIntentAnyOf: const [
            'specialtySearch',
            'doctorSearch',
            'generalSearch',
          ],
          expectNotRefuse: true,
        ),
      );
    }
  }

  // STT إضافي أوسع.
  const sttMore = <({String phrase, List<String> intents})>[
    (phrase: 'صيدل يه', intents: ['findPharmacy', 'generalSearch', 'doctorSearch']),
    (phrase: 'مختب ر', intents: ['findLab', 'generalSearch', 'doctorSearch']),
    (phrase: 'علااج طبيعي', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'مستلزممات', intents: ['findSupply', 'generalSearch']),
    (phrase: 'اشعه', intents: ['findRadiology']),
    (phrase: 'باقاتت', intents: ['findPackage', 'generalSearch']),
    (phrase: 'عرووض', intents: ['findOffer', 'findPackage', 'generalSearch']),
    (phrase: 'فيزيييو', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'تاهيل', intents: ['findPhysio', 'generalSearch']),
    (phrase: 'تجهيزاات طبية', intents: ['findSupply', 'generalSearch']),
  ];
  for (final p in ['أريد', 'أريدلي', 'طلعلي', 'وريني', 'جيبلي']) {
    for (final s in sttMore) {
      n++;
      out.add(
        M6CorpusCase(
          id: 'gen_v2b_stt_${n.toString().padLeft(3, '0')}',
          source: 'generated',
          category: 'v2b_stt',
          input: '$p ${s.phrase}',
          expectedIntentAnyOf: s.intents,
          expectNotRefuse: true,
        ),
      );
    }
  }

  // اتصال/واتساب مع نوع كيان صريح.
  const typedActs = <({String q, List<String> intents})>[
    (q: 'اتصل بالصيدلية', intents: ['callPharmacy', 'findPharmacy', 'generalSearch']),
    (q: 'دزله واتساب للمختبر', intents: ['messageLab', 'findLab', 'messageDoctor', 'generalSearch']),
    (q: 'اتصل بمختبر', intents: ['callLab', 'findLab', 'generalSearch']),
    (q: 'راسل الصيدلية واتساب', intents: ['messagePharmacy', 'findPharmacy', 'generalSearch']),
    (q: 'وين الصيدلية', intents: ['showLocation', 'findPharmacy']),
    (q: 'وين المختبر', intents: ['showLocation', 'findLab']),
    (q: 'افتح بروفايل الصيدلية', intents: ['showProfile', 'findPharmacy', 'generalSearch']),
    (q: 'دكله على العلاج الطبيعي', intents: ['callPhysio', 'findPhysio', 'callDoctor', 'generalSearch']),
    (q: 'دزله واتس للمستلزمات', intents: ['messageSupply', 'findSupply', 'messageDoctor', 'generalSearch']),
    (q: 'وين الاشعة', intents: ['showLocation', 'findRadiology']),
  ];
  for (final a in typedActs) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2b_act_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2b_typed_action',
        input: a.q,
        expectedIntentAnyOf: a.intents,
        expectNotRefuse: true,
      ),
    );
  }

  // تصحيحات إضافية.
  for (final q in [
    'مو صيدلية قصدي مختبر',
    'لا قصدي فيزيو',
    'أقصد مستلزمات طبية',
    'قصدي أشعة',
    'لا مو مختبر قصدي صيدلية',
    'قصدي باقة',
    'أقصد عروض وخصومات',
    'مو هذا قصدي علاج طبيعي',
  ]) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2b_corr_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2b_correction',
        input: q,
        expectedIntentAnyOf: const [
          'findPharmacy',
          'findLab',
          'findPhysio',
          'findSupply',
          'findRadiology',
          'findPackage',
          'findOffer',
          'generalSearch',
          'doctorSearch',
          'unknown',
        ],
        expectNotRefuse: true,
      ),
    );
  }

  // OOS دفعة ثانية.
  const oos3 = [
    'منو رئيس الجمهوريه',
    'شغل اغنيه',
    'احسب لي الجمع',
    'هل عندي ضغط',
    'افتح يوتيوب',
    'شنو عاصمه العراق',
    'سعر الدولار اليوم',
    'ترجم جمله',
    'من فاز بكاس العالم',
    'وش الطقس باجر',
    'وصفه طبخ مقلوبه',
    'منو المغني الافضل',
  ];
  for (final q in oos3) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2b_oos_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2b_oos',
        input: q,
        expectRefuse: true,
      ),
    );
  }

  // فلاتر جنس/قريب.
  for (final q in [
    'طبيبة',
    'دكتورة',
    'طبيب رجال',
    'دكتور رجال',
    'قريب علي',
    'اليمني',
    'بالشطره',
    'بالكرادة',
  ]) {
    n++;
    out.add(
      M6CorpusCase(
        id: 'gen_v2b_filt_${n.toString().padLeft(3, '0')}',
        source: 'generated',
        category: 'v2b_filter',
        input: q,
        expectedIntentAnyOf: const [
          'doctorSearch',
          'specialtySearch',
          'generalSearch',
          'unknown',
          'selectResult',
        ],
      ),
    );
  }

  return out;
}
