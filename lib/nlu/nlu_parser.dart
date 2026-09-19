import '../clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'nlu_models.dart';

/// مدقّق عقد NLU — يرفض أي حقل طبي غير مدعوم أو JSON فاسد.
class NluParser {
  const NluParser();

  static const _allowedTop = {
    'schema_version',
    'intent',
    'continuation',
    'subject',
    'population',
    'age_years',
    'duration',
    'slots',
    'requested_action',
    'confidence',
    'explicit_entities',
  };

  static const _allowedSlots = {
    'cough',
    'fever',
    'breathlessness',
    'sputum',
    'hemoptysis',
  };

  static const _allowedDuration = {'bucket', 'raw'};

  static const _allowedConfidence = {'overall', 'slots'};

  static const _allowedEntities = {
    'doctor_name',
    'specialty',
    'lab_name',
    'package_or_offer',
  };

  static const _forbidden = {
    'diagnosis',
    'diagnoses',
    'disease',
    'medication',
    'prescription',
    'drug',
    'destination',
    'destinationType',
    'destination_type',
    'clinicalCareDestination',
    'doctor',
    'doctors',
    'doctor_id',
    'lab',
    'labs',
    'package',
    'packages',
    'test',
    'tests',
    'imaging',
    'guidance',
    'answer',
    'message',
    'reply',
    'treatment',
    'specialty_to_book',
  };

  NluParseResult parse(Object? raw) {
    if (raw is! Map) {
      return const NluParseResult.rejected(NluSkipReason.invalidJson);
    }
    final map = _stringKeyed(raw);
    if (map == null) {
      return const NluParseResult.rejected(NluSkipReason.invalidJson);
    }

    for (final key in map.keys) {
      if (_forbidden.contains(key)) {
        return const NluParseResult.rejected(NluSkipReason.unsupportedFields);
      }
      if (!_allowedTop.contains(key)) {
        return const NluParseResult.rejected(NluSkipReason.unsupportedFields);
      }
    }

    final version = map['schema_version'];
    if (version is! num || version.toInt() != kNluSchemaVersion) {
      return const NluParseResult.rejected(NluSkipReason.schemaRejected);
    }

    final slotsRaw = map['slots'];
    if (slotsRaw != null) {
      if (slotsRaw is! Map) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      final slots = _stringKeyed(slotsRaw);
      if (slots == null) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      for (final key in slots.keys) {
        if (!_allowedSlots.contains(key)) {
          return const NluParseResult.rejected(NluSkipReason.unsupportedFields);
        }
      }
    }

    final durationRaw = map['duration'];
    if (durationRaw != null) {
      if (durationRaw is! Map) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      final duration = _stringKeyed(durationRaw);
      if (duration == null) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      for (final key in duration.keys) {
        if (!_allowedDuration.contains(key)) {
          return const NluParseResult.rejected(NluSkipReason.unsupportedFields);
        }
      }
    }

    final confRaw = map['confidence'];
    if (confRaw is! Map) {
      return const NluParseResult.rejected(NluSkipReason.schemaRejected);
    }
    final conf = _stringKeyed(confRaw);
    if (conf == null) {
      return const NluParseResult.rejected(NluSkipReason.schemaRejected);
    }
    for (final key in conf.keys) {
      if (!_allowedConfidence.contains(key)) {
        return const NluParseResult.rejected(NluSkipReason.unsupportedFields);
      }
    }
    final overall = conf['overall'];
    if (overall is! num) {
      return const NluParseResult.rejected(NluSkipReason.schemaRejected);
    }
    final overallValue = overall.toDouble();
    if (overallValue < 0 || overallValue > 1) {
      return const NluParseResult.rejected(NluSkipReason.schemaRejected);
    }

    final slotConf = <String, double>{};
    final slotConfRaw = conf['slots'];
    if (slotConfRaw != null) {
      if (slotConfRaw is! Map) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      final sc = _stringKeyed(slotConfRaw);
      if (sc == null) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      for (final entry in sc.entries) {
        if (!_allowedSlots.contains(entry.key) || entry.value is! num) {
          return const NluParseResult.rejected(NluSkipReason.schemaRejected);
        }
        slotConf[entry.key] = (entry.value as num).toDouble();
      }
    }

    if (map['explicit_entities'] != null) {
      if (map['explicit_entities'] is! Map) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      final ent = _stringKeyed(map['explicit_entities'] as Map);
      if (ent == null) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      for (final key in ent.keys) {
        if (!_allowedEntities.contains(key) || _forbidden.contains(key)) {
          return const NluParseResult.rejected(NluSkipReason.unsupportedFields);
        }
      }
    }

    final age = map['age_years'];
    int? ageYears;
    if (age != null) {
      if (age is! num || age != age.roundToDouble() || age < 0 || age > 120) {
        return const NluParseResult.rejected(NluSkipReason.schemaRejected);
      }
      ageYears = age.toInt();
    }

    final slots = map['slots'] is Map
        ? _stringKeyed(map['slots'] as Map) ?? const <String, Object?>{}
        : const <String, Object?>{};
    final duration = map['duration'] is Map
        ? _stringKeyed(map['duration'] as Map)
        : null;

    final parse = NluParse(
      schemaVersion: kNluSchemaVersion,
      intent: _intent(map['intent']),
      continuation: map['continuation'] == true,
      subject: _subject(map['subject']),
      population: _population(map['population']),
      ageYears: ageYears,
      durationBucket: _duration(duration?['bucket']),
      cough: _tri(slots['cough']),
      fever: _tri(slots['fever']),
      breathlessness: _tri(slots['breathlessness']),
      sputum: _tri(slots['sputum']),
      hemoptysis: _tri(slots['hemoptysis']),
      requestedAction: _action(map['requested_action']),
      overallConfidence: overallValue,
      slotConfidence: slotConf,
    );
    return NluParseResult.ok(parse);
  }

  Map<String, Object?>? _stringKeyed(Map raw) {
    final out = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) return null;
      out[key] = entry.value;
    }
    return out;
  }

  NluIntent _intent(Object? v) {
    switch (v) {
      case 'clinical_continuation':
        return NluIntent.clinicalContinuation;
      case 'clinical_complaint':
        return NluIntent.clinicalComplaint;
      case 'care_direction':
        return NluIntent.careDirection;
      case 'doctor_search':
        return NluIntent.doctorSearch;
      case 'lab_search':
        return NluIntent.labSearch;
      case 'offer_search':
        return NluIntent.offerSearch;
      case 'app_action':
        return NluIntent.appAction;
      default:
        return NluIntent.unknown;
    }
  }

  NluSubject _subject(Object? v) {
    switch (v) {
      case 'self':
        return NluSubject.self;
      case 'child':
        return NluSubject.child;
      case 'other':
        return NluSubject.other;
      case 'inherit':
        return NluSubject.inherit;
      default:
        return NluSubject.unknown;
    }
  }

  RespiratoryPopulation _population(Object? v) {
    switch (v) {
      case 'child':
        return RespiratoryPopulation.child;
      case 'adult':
        return RespiratoryPopulation.adult;
      default:
        return RespiratoryPopulation.unknown;
    }
  }

  RespiratoryDurationBucket _duration(Object? v) {
    switch (v) {
      case 'hours':
        return RespiratoryDurationBucket.hours;
      case 'days':
        return RespiratoryDurationBucket.days;
      case 'weeks':
        return RespiratoryDurationBucket.weeks;
      case 'months':
        return RespiratoryDurationBucket.months;
      default:
        return RespiratoryDurationBucket.unknown;
    }
  }

  RespiratoryTriState _tri(Object? v) {
    switch (v) {
      case 'present':
        return RespiratoryTriState.present;
      case 'absent':
        return RespiratoryTriState.absent;
      default:
        return RespiratoryTriState.unknown;
    }
  }

  NluRequestedAction _action(Object? v) {
    switch (v) {
      case 'none':
        return NluRequestedAction.none;
      case 'care_direction':
        return NluRequestedAction.careDirection;
      case 'call':
        return NluRequestedAction.call;
      case 'whatsapp':
        return NluRequestedAction.whatsapp;
      case 'show_profile':
        return NluRequestedAction.showProfile;
      default:
        return NluRequestedAction.unknown;
    }
  }
}

class NluParseResult {
  const NluParseResult.ok(this.parse)
      : rejected = false,
        reason = null;

  const NluParseResult.rejected(this.reason)
      : parse = null,
        rejected = true;

  final NluParse? parse;
  final bool rejected;
  final NluSkipReason? reason;
}
