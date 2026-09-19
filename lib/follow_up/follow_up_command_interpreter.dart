import '../search/arabic_text_utils.dart';
import 'follow_up_command_models.dart';
import 'follow_up_models.dart';

/// مفسّر أوامر المتابعة الموحّدة — حتمي.
class FollowUpCommandInterpreter {
  const FollowUpCommandInterpreter();

  FollowUpCommandInterpretation interpret({
    required String raw,
    required FollowUpPendingOp pending,
  }) {
    final original = raw.trim();
    final n = ArabicTextUtils.normalize(original);
    if (n.isEmpty) return FollowUpCommandInterpretation.none;

    if (pending.kind == FollowUpPendingKind.createConsent) {
      if (_isYes(n)) {
        return FollowUpCommandInterpretation(
          kind: FollowUpCommandKind.consentYes,
          domain: pending.domain,
          topicKey: pending.topicKey,
          displayTopic: pending.displayTopic,
          timingIntent: pending.timingIntent,
        );
      }
      if (_isLater(n)) {
        return const FollowUpCommandInterpretation(
          kind: FollowUpCommandKind.consentLater,
        );
      }
      if (_isNo(n)) {
        return const FollowUpCommandInterpretation(
          kind: FollowUpCommandKind.consentNo,
        );
      }
      final correction = _parseCorrection(n);
      if (correction != null) {
        return correction;
      }
    }

    if (_looksLikeUrgent(n)) {
      return const FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.deferToUrgentSafety,
      );
    }
    if (_looksLikeMental(n)) {
      return const FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.deferToMentalSafety,
      );
    }
    if (_looksLikeEntityEscape(n)) {
      return const FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.deferToEntityIntent,
      );
    }

    if (_looksLikeList(n)) {
      return const FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.listCommitments,
      );
    }

    if (_looksLikeStopAsking(n)) {
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.stopAsking,
        topicKey: _topicKeyFromText(n),
        domain: _domainFromText(n),
        displayTopic: _displayFromText(n),
      );
    }

    if (_looksLikePause(n)) {
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.pauseCommitment,
        topicKey: _topicKeyFromText(n),
        domain: _domainFromText(n),
        displayTopic: _displayFromText(n),
      );
    }

    if (_looksLikeResume(n)) {
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.resumeCommitment,
        topicKey: _topicKeyFromText(n),
        domain: _domainFromText(n),
        displayTopic: _displayFromText(n),
      );
    }

    if (_looksLikeComplete(n)) {
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.completeCommitment,
        topicKey: _topicKeyFromText(n),
        domain: _domainFromText(n),
        displayTopic: _displayFromText(n),
      );
    }

    if (_looksLikeDelete(n)) {
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.deleteCommitment,
        topicKey: _topicKeyFromText(n),
        domain: _domainFromText(n),
        displayTopic: _displayFromText(n),
      );
    }

    if (_looksLikeCancel(n)) {
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.cancelCommitment,
        topicKey: _topicKeyFromText(n),
        domain: _domainFromText(n),
        displayTopic: _displayFromText(n),
      );
    }

    if (_looksLikeCreate(n)) {
      final timing = _timingFromText(n);
      final domain = _domainFromText(n) ?? FollowUpDomain.generalCommitment;
      final topic = _topicKeyFromText(n) ?? domain.name;
      return FollowUpCommandInterpretation(
        kind: FollowUpCommandKind.createCommitment,
        domain: domain,
        topicKey: topic,
        displayTopic: _displayFromText(n),
        timingIntent: timing,
      );
    }

    return FollowUpCommandInterpretation.none;
  }

  bool looksLikeFollowUpCommand(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    return _looksLikeList(n) ||
        _looksLikeCreate(n) ||
        _looksLikePause(n) ||
        _looksLikeResume(n) ||
        _looksLikeComplete(n) ||
        _looksLikeDelete(n) ||
        _looksLikeCancel(n) ||
        _looksLikeStopAsking(n);
  }

  bool _looksLikeList(String n) => RegExp(
        r'(?:شنو|ماذا)\s*(?:الاشياء|الأشياء)?\s*(?:اللي\s*)?(?:تتابعها|متابعها)\s*وياي|'
        r'(?:شنو|ماذا)\s*(?:متذكر\s*)?(?:لازم\s*)?نرجعله|'
        r'(?:قائمه\s*المتابعات|المتابعات\s*النشطه)',
      ).hasMatch(n);

  bool _looksLikeCreate(String n) => RegExp(
        r'(?:تابع\s*وياي)|'
        r'(?:ذكرني)|'
        r'(?:اسألني\s*بعدين)|'
        r'(?:من\s*(?:تطلع|تظهر)\s*نتيجه)|'
        r'(?:من\s*أراجع\s*الطبيب)|'
        r'(?:أريد\s*ألتزم)|'
        r'(?:نرجع\s*نحچي)|'
        r'(?:نرجع\s*(?:ل|الى|إلي)?\s*(?:هذا\s*)?الموضوع)',
      ).hasMatch(n);

  bool _looksLikeStopAsking(String n) => RegExp(
        r'(?:لا\s*تسألني\s*بعد)|'
        r'(?:لا\s*تسالني\s*بعد)|'
        r'(?:توقف\s*عن\s*السؤال)|'
        r'(?:لا\s*تعيد\s*السؤال)',
      ).hasMatch(n);

  bool _looksLikePause(String n) => RegExp(
        r'(?:وقف\s*متابعه)|'
        r'(?:اوقف\s*متابعه)|'
        r'(?:علق\s*متابعه)',
      ).hasMatch(n);

  bool _looksLikeResume(String n) => RegExp(
        r'(?:رجع\s*تابع\s*وياي)|'
        r'(?:أعد\s*المتابعه)|'
        r'(?:فعل\s*المتابعه\s*من\s*جديد)|'
        r'(?:ارجع\s*تابع\s*وياي)|'
        r'(?:رجع\s*تابع\s*وياي)',
      ).hasMatch(n);

  bool _looksLikeComplete(String n) => RegExp(
        r'(?:خلص\s*(?:هذا\s*)?الموضوع)|'
        r'(?:اعتبره\s*مكتمل)|'
        r'(?:أنهِ\s*المتابعه)',
      ).hasMatch(n);

  bool _looksLikeDelete(String n) => RegExp(
        r'(?:امسح\s*(?:هذه\s*)?المتابعه)|'
        r'(?:احذف\s*(?:هذه\s*)?المتابعه)',
      ).hasMatch(n);

  bool _looksLikeCancel(String n) => RegExp(
        r'(?:الغي\s*المتابعه)|'
        r'(?:إلغاء\s*المتابعه)',
      ).hasMatch(n);

  bool _looksLikeEntityEscape(String n) => RegExp(
        r'(?:أريد|اريد|ابي|دور)\s*(?:رقم\s*)?(?:طبيب|دكتور|مختبر)|'
        r'(?:رقم\s*مختبر|رقم\s*الطبيب)',
      ).hasMatch(n);

  bool _looksLikeUrgent(String n) => RegExp(
        r'(?:ضيق\s*نفس|اختناق|فاقد\s*وعي|نزيف|الم\s*صدر|ألم\s*صدر)',
      ).hasMatch(n);

  bool _looksLikeMental(String n) => RegExp(
        r'(?:انتحار|اذي\s*نفسي|أذي\s*نفسي|اقتل\s*نفسي)',
      ).hasMatch(n);

  FollowUpDomain? _domainFromText(String n) {
    if (RegExp(r'(?:سكر|السكري|diabetes)').hasMatch(n)) {
      return FollowUpDomain.chronicHealth;
    }
    if (RegExp(r'(?:ضغط)').hasMatch(n)) {
      return FollowUpDomain.chronicHealth;
    }
    if (RegExp(r'(?:ربو)').hasMatch(n)) {
      return FollowUpDomain.chronicHealth;
    }
    if (RegExp(r'(?:نتيجه\s*(?:التحليل|الفحص)|التحليل)').hasMatch(n)) {
      return FollowUpDomain.labResult;
    }
    if (RegExp(r'(?:مختبر|فحص\s*مختبر)').hasMatch(n)) {
      return FollowUpDomain.labTest;
    }
    if (RegExp(r'(?:طبيب|دكتور|مراجعة)').hasMatch(n)) {
      return FollowUpDomain.doctorVisit;
    }
    if (RegExp(
      r'(?:مشي|نوم|ألتزم|التزم|ادرس|أدرس|هدف|هدفي|flutter|تعلم)',
    ).hasMatch(n)) {
      return FollowUpDomain.personalGoal;
    }
    if (RegExp(r'(?:وقائي|تحصين|فحص\s*دوري)').hasMatch(n)) {
      return FollowUpDomain.preventive;
    }
    return null;
  }

  String? _topicKeyFromText(String n) {
    if (RegExp(r'(?:سكر|السكري)').hasMatch(n)) return 'diabetes';
    if (RegExp(r'ضغط').hasMatch(n)) return 'hypertension';
    if (RegExp(r'ربو').hasMatch(n)) return 'asthma';
    if (RegExp(r'(?:نتيجه|تحليل)').hasMatch(n)) return 'lab_result';
    if (RegExp(r'(?:طبيب|مراجعة)').hasMatch(n)) return 'doctor_visit';
    if (RegExp(r'مشي').hasMatch(n)) return 'walking';
    if (RegExp(r'نوم').hasMatch(n)) return 'sleep';
    if (RegExp(r'(?:ادرس|أدرس)').hasMatch(n)) return 'study';
    if (RegExp(r'(?:هذا\s*الموضوع|هالموضوع)').hasMatch(n)) {
      return 'current_topic';
    }
    return null;
  }

  String _displayFromText(String n) {
    if (RegExp(r'(?:سكر|السكري)').hasMatch(n)) return 'متابعه السكر';
    if (RegExp(r'ضغط').hasMatch(n)) return 'متابعه الضغط';
    if (RegExp(r'ربو').hasMatch(n)) return 'متابعه الربو';
    if (RegExp(r'(?:نتيجه|تحليل)').hasMatch(n)) return 'نتيجه التحليل';
    if (RegExp(r'(?:طبيب|مراجعة)').hasMatch(n)) return 'مراجعة الطبيب';
    if (RegExp(r'مشي').hasMatch(n)) return 'المشي';
    if (RegExp(r'نوم').hasMatch(n)) return 'النوم';
    return 'هذا الموضوع';
  }

  FollowUpTimingIntent _timingFromText(String n) {
    if (RegExp(r'(?:باچر|بكره|غدا|غداً)').hasMatch(n)) {
      return FollowUpTimingIntent.tomorrow;
    }
    if (RegExp(r'(?:بعد\s*اسبوع|بعد\s*أسبوع)').hasMatch(n)) {
      return FollowUpTimingIntent.afterAWeek;
    }
    if (RegExp(r'(?:نتيجه|تطلع|تظهر)').hasMatch(n) &&
        RegExp(r'(?:تحليل|فحص|نتيجه)').hasMatch(n)) {
      return FollowUpTimingIntent.whenResultAvailable;
    }
    if (RegExp(r'(?:من\s*أراجع|المراجعة\s*القادمه)').hasMatch(n)) {
      return FollowUpTimingIntent.nextVisit;
    }
    if (RegExp(r'(?:بعدين|لاحقا)').hasMatch(n) &&
        !RegExp(r'(?:نتيجه|تحليل)').hasMatch(n)) {
      return FollowUpTimingIntent.later;
    }
    if (RegExp(r'(?:من\s*ترجع|نرجع)').hasMatch(n)) {
      return FollowUpTimingIntent.whenUserReturns;
    }
    return FollowUpTimingIntent.whenUserReturns;
  }

  FollowUpCommandInterpretation? _parseCorrection(String n) {
    final m = RegExp(
      r'(?:لا\s*مو\s*(?:ال)?(?:سكر|ضغط|ربو)).{0,20}(?:أقصد|اقصد)\s*(?:ال)?(سكر|ضغط|ربو)',
    ).firstMatch(n);
    if (m == null) return null;
    final t = m.group(1)!;
    final key = t.contains('سكر')
        ? 'diabetes'
        : (t.contains('ضغط') ? 'hypertension' : 'asthma');
    final display = key == 'diabetes'
        ? 'متابعه السكر'
        : (key == 'hypertension' ? 'متابعه الضغط' : 'متابعه الربو');
    return FollowUpCommandInterpretation(
      kind: FollowUpCommandKind.correctPendingTopic,
      domain: FollowUpDomain.chronicHealth,
      topicKey: key,
      displayTopic: display,
      correctedTopicKey: key,
    );
  }

  bool _isYes(String n) =>
      RegExp(r'^(?:نعم|اي|أي|موافق|اوك|ok|yes)$').hasMatch(n);
  bool _isNo(String n) => RegExp(r'^(?:لا|كلا|مو)$').hasMatch(n);
  bool _isLater(String n) =>
      RegExp(r'(?:بعدين|لاحقا|مو\s*هسه)').hasMatch(n);
}
