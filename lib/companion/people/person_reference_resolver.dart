import '../../health/subject/health_subject_models.dart';
import '../../search/arabic_text_utils.dart';
import 'family_person_profile.dart';

enum PersonResolutionStatus {
  none,
  resolved,
  ambiguous,
  notFound,
}

class PersonReferenceResolution {
  const PersonReferenceResolution({
    this.status = PersonResolutionStatus.none,
    this.profile,
    this.candidates = const [],
    this.message = '',
  });

  final PersonResolutionStatus status;
  final FamilyPersonProfile? profile;
  final List<FamilyPersonProfile> candidates;
  final String message;

  bool get isResolved => status == PersonResolutionStatus.resolved;
  bool get isAmbiguous => status == PersonResolutionStatus.ambiguous;

  Map<String, Object?> debugMap() => {
        'resolutionStatus': status.name,
        'personProfileCount': candidates.length,
        'operationType': 'resolve',
      };
}

/// يحلّ مراجع الأشخاص — بلا اختيار عشوائي.
class PersonReferenceResolver {
  const PersonReferenceResolver();

  PersonReferenceResolution resolve({
    required String query,
    required List<FamilyPersonProfile> profiles,
    PersonRelationship? relationshipHint,
    String? nameHint,
    bool includeDisabled = false,
  }) {
    final pool = includeDisabled
        ? profiles
        : profiles.where((p) => p.profileEnabled).toList();

    if (pool.isEmpty) {
      return const PersonReferenceResolution(
        status: PersonResolutionStatus.notFound,
        message: 'ما عندي أشخاص محفوظين بالعائلة حالياً.',
      );
    }

    final n = ArabicTextUtils.normalize(query);
    final rel = relationshipHint ?? _detectRelationship(n);
    final name = (nameHint ?? _extractName(n, rel)).trim();

    var candidates = pool;
    if (rel != null) {
      candidates = candidates
          .where((p) => _relationshipMatches(p.relationship, rel))
          .toList();
    }
    if (name.isNotEmpty) {
      final byName = candidates
          .where((p) => _nameMatches(p.effectiveName, name))
          .toList();
      if (byName.isNotEmpty) candidates = byName;
    }

    if (candidates.isEmpty) {
      return PersonReferenceResolution(
        status: PersonResolutionStatus.notFound,
        message: 'ما لقيت شخصاً مطابقاً بالملف المحفوظ.',
      );
    }

    if (candidates.length == 1) {
      return PersonReferenceResolution(
        status: PersonResolutionStatus.resolved,
        profile: candidates.first,
        candidates: candidates,
      );
    }

    // علاقة فقط بلا اسم — أكثر من طفل
    if (name.isEmpty && rel != null) {
      return PersonReferenceResolution(
        status: PersonResolutionStatus.ambiguous,
        candidates: candidates,
        message:
            'عندي أكثر من ${_relationshipLabel(rel)}. أي واحد تقصد؟ ${_nameList(candidates)}',
      );
    }

    // نفس الاسم أكثر من مرة
    return PersonReferenceResolution(
      status: PersonResolutionStatus.ambiguous,
      candidates: candidates,
      message:
          'اسم "$name" موجود أكثر من مرة. حدّد العلاقة أو الاسم الكامل: ${_nameList(candidates)}',
    );
  }

  PersonRelationship? _detectRelationship(String n) {
    if (RegExp(r'(?:ابني|ولدي|بنيه|بني)').hasMatch(n)) {
      return PersonRelationship.son;
    }
    if (RegExp(r'(?:بنتي|بنيتي)').hasMatch(n)) {
      return PersonRelationship.daughter;
    }
    if (RegExp(r'(?:ابني|ابنتي|طفلي|طفلتي|ولدي)').hasMatch(n)) {
      return PersonRelationship.child;
    }
    if (RegExp(r'(?:امي|أمي|والدتي)').hasMatch(n)) {
      return PersonRelationship.mother;
    }
    if (RegExp(r'(?:ابوي|أبوي|والدي|ابي|أبي)').hasMatch(n)) {
      return PersonRelationship.father;
    }
    if (RegExp(r'(?:زوجتي|مراتي|زوج)').hasMatch(n)) {
      return PersonRelationship.wife;
    }
    if (RegExp(r'(?:زوجي)').hasMatch(n)) {
      return PersonRelationship.husband;
    }
    if (RegExp(r'(?:زوج|زوجه|زوجة)').hasMatch(n)) {
      return PersonRelationship.spouse;
    }
    return null;
  }

  String _extractName(String n, PersonRelationship? rel) {
    final patterns = <RegExp>[
      RegExp(r'(?:تذكر|احفظ|اسم)\s*(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي)?\s*([^\s،,]+)'),
      RegExp(r'([^\s،,]+)\s*(?:ابني|ابنتي)'),
      RegExp(r'(?:عن)\s*([^\s،,]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(n);
      final g = m?.group(1)?.trim() ?? '';
      if (g.isNotEmpty && !_isRelationshipWord(g) && g.length > 1) {
        return g;
      }
    }
    return '';
  }

  bool _isRelationshipWord(String w) {
    return RegExp(
      r'^(?:ابني|ابنتي|امي|ابوي|زوجتي|زوجي|طفلي|ولدي|بنتي|الولد)$',
    ).hasMatch(w);
  }

  bool _isChildRelationship(PersonRelationship r) =>
      r == PersonRelationship.son ||
      r == PersonRelationship.daughter ||
      r == PersonRelationship.child;

  bool _relationshipMatches(PersonRelationship a, PersonRelationship b) {
    if (a == b) return true;
    if (b == PersonRelationship.child && _isChildRelationship(a)) return true;
    if (b == PersonRelationship.son &&
        (a == PersonRelationship.son || a == PersonRelationship.child)) {
      return true;
    }
    if (b == PersonRelationship.daughter &&
        (a == PersonRelationship.daughter || a == PersonRelationship.child)) {
      return true;
    }
    if (b == PersonRelationship.spouse &&
        (a == PersonRelationship.wife ||
            a == PersonRelationship.husband ||
            a == PersonRelationship.spouse)) {
      return true;
    }
    return false;
  }

  bool _nameMatches(String? stored, String queryName) {
    if (stored == null) return false;
    final a = ArabicTextUtils.normalize(stored);
    final b = ArabicTextUtils.normalize(queryName);
    return a == b || a.contains(b) || b.contains(a);
  }

  String _relationshipLabel(PersonRelationship r) {
    switch (r) {
      case PersonRelationship.son:
        return 'ابن';
      case PersonRelationship.daughter:
        return 'بنت';
      case PersonRelationship.child:
        return 'طفل';
      case PersonRelationship.mother:
        return 'أم';
      case PersonRelationship.father:
        return 'أب';
      case PersonRelationship.wife:
        return 'زوجة';
      case PersonRelationship.husband:
        return 'زوج';
      case PersonRelationship.spouse:
        return 'زوج/ة';
      default:
        return 'شخص';
    }
  }

  String _nameList(List<FamilyPersonProfile> list) {
    return list
        .map((p) => p.effectiveName ?? _relationshipLabel(p.relationship))
        .join('، ');
  }

  HealthSubjectType toHealthSubjectType(PersonRelationship rel) {
    switch (rel) {
      case PersonRelationship.son:
      case PersonRelationship.daughter:
      case PersonRelationship.child:
        return HealthSubjectType.child;
      case PersonRelationship.mother:
        return HealthSubjectType.mother;
      case PersonRelationship.father:
        return HealthSubjectType.father;
      case PersonRelationship.wife:
      case PersonRelationship.husband:
      case PersonRelationship.spouse:
        return HealthSubjectType.spouse;
      case PersonRelationship.brother:
      case PersonRelationship.sister:
      case PersonRelationship.familyMember:
        return HealthSubjectType.familyMember;
      case PersonRelationship.otherPerson:
        return HealthSubjectType.otherPerson;
    }
  }
}
