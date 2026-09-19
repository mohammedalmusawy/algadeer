import 'wellness_models.dart';

/// بناء ردود عافية — نص عملي بلا وصف طبي وبلا ضغط.
class WellnessResponseBuilder {
  const WellnessResponseBuilder();

  String startingActivity({required bool overwhelmed}) {
    if (overwhelmed) {
      return 'تمام. خطوة واحدة تكفي للبداية: مشي خفيف 5–10 دقائق اليوم، '
          'وإذا حسّيت بأي أعراض مقلقة (صدر، ضيق شديد، إغماء) وقف وراجع مختص.';
    }
    return 'بداية ممتازة. الأفضل تكون تدريجية ومستدامة:\n'
        '• اختر حركة تناسبك (مشي غالباً الأسهل)\n'
        '• ابدأ بوقت يمكن الالتزام فيه\n'
        '• زِد تدريجياً مع الوقت\n'
        '• خلِّ للاستراحة مكان\n'
        '• إذا ظهرت أعراض مقلقة، وقف وناقشها مع مختص\n'
        'هذا إطار عام، مو برنامج تأهيل طبي.';
  }

  String walkingGuidance({String? preventiveSnippet}) {
    final buf = StringBuffer(
      'المشي خيار عملي جيد لكثير من الناس — مو لازم رقم خطوات واحد يناسب الجميع.\n'
      'ركّز على انتظام يناسب يومك أكثر من مطاردة «10,000 خطوة» كقاعدة مطلقة.',
    );
    if (preventiveSnippet != null && preventiveSnippet.trim().isNotEmpty) {
      buf.writeln();
      buf.writeln(preventiveSnippet.trim());
    }
    return buf.toString();
  }

  String activityReportAck(WellnessUserReport report) {
    if (report.completed == false) {
      return 'تمام، سجّلت للفترة الحالية إن اليوم ما صار مشي. '
          'ما عندي سجل أيام سابقة تلقائي — أعتمد على اللي تخبرني به.';
    }
    final parts = <String>['شكراً، فهمت تقرير اليوم.'];
    if (report.durationMinutes != null) {
      parts.add('المدة اللي ذكرتها محفوظة بهذه المحادثة فقط.');
    }
    parts.add('ما أسوي دفتر تمارين دائم تلقائي بهالمرحلة.');
    return parts.join(' ');
  }

  String progressHonest({
    required bool hasSessionReports,
    required bool hasGoal,
  }) {
    if (!hasSessionReports && !hasGoal) {
      return 'ما عندي سجل خطوات أو تاريخ مشي تلقائي. '
          'أكدر أساعدك بهدف محفوظ أو بما تذكره بهالمحادثة فقط — بدون اختلاق تقدّم.';
    }
    if (hasGoal && !hasSessionReports) {
      return 'عندك هدف مشي محفوظ، بس ما عندي سجل أيام سابق تلقائي. '
          'خبرني شنو سويت اليوم/هالأسبوع حتى أجاوب بصدق.';
    }
    return 'من اللي ذكرته بهالمحادثة أقدر أعلّق على هالجلسة فقط — '
        'بدون اتجاهات تاريخية مخترعة.';
  }

  String barrierClarification(String question) {
    return 'ما أشخّص السبب. $question '
        'إذا الألم شديد أو يزداد، الأفضل تناقشه مع مختص — مو برنامج تأهيل مني.';
  }

  String routineFramework({required bool overwhelmed}) {
    if (overwhelmed) {
      return 'إطار بسيط جداً: مشي خفيف معظم الأيام بوقت قصير يناسبك، '
          'ويوم راحة حسب الحاجة. مو تأهيل سريري ولا برنامج بطولات.';
    }
    return 'إطار حركة محافظ (عام، مو وصفة طبية):\n'
        '• معظم الأيام: مشي أو حركة خفيفة بوقت يناسبك\n'
        '• يوم أو يومين: نفس الفكرة أو راحة نشطة\n'
        '• راحة عند الإرهاق أو الألم غير المعتاد\n'
        'عدّل حسب يومك — مو برنامج إعادة تأهيل.';
  }

  String lowMotivation() {
    return 'عادي تحس بهالشي. ما في ضغط ولا «سلسلة» تتكسر. '
        'تقدر تختار راحة، أو خطوة أصغر اختيارية (مثل مشي دقيقتين قرب البيت) — أنت تقرّر.';
  }

  String restRecovery() {
    return 'الراحة جزء من الحركة الصحية. إذا تمرّنت، خلِّ للجسم مجال يتعافى. '
        'الإفراط مو هدف. إذا التعب شديد أو غريب، ناقشه مع مختص.';
  }

  String sleepWellness() {
    return 'روتين نوم منتظم يساعد العافية عموماً. '
        'ما أشخّص اضطرابات نوم — إذا في شخير شديد أو توقف تنفس أو نعاس خطير، راجع مختص.';
  }

  String sedentary() {
    return 'الجلوس الطويل يستاهل كسرات حركة قصيرة بين فترة وفترة. '
        'وقفات بسيطة أفضل من محاولة تعويض كل شيء بجلسة قاسية مرة واحدة.';
  }

  String familyGeneralOnly() {
    return 'أكدر أعطي معلومات عامة عن الحركة بأمان، '
        'بس ما أستخدم عمرك أو صحتك أو أهدافك لتخصيص روتين لشخص ثاني بهالمرحلة.';
  }

  String goalSaved(String label) {
    return 'تم. حفظت «$label» كهدف شخصي عبر ذاكرة الأهداف — مو دفتر تمارين يومي.';
  }

  String clinicianDiscussion() {
    return 'بما إن في سياق صحي مذكور، الأفضل تناقش شلون تبدأ النشاط مع مختصك. '
        'أكدر أعطيك إطاراً عاماً حذراً، مو خطة تمرين مرضية.';
  }

  String declineAck() {
    return 'تمام، ما أضيف نصائح رياضة هسه.';
  }

  String focusWalkingAck() {
    return 'زين، نركّز على المشي.';
  }

  bool containsForbiddenLanguage(String message) {
    return RegExp(
      r'(?:لازم\s*تنحف|جسمك\s*سيئ|وزنك\s*كارثه|وزنك\s*كارثة|'
      r'لا\s*تخيب\s*ظني|لا\s*تكسر\s*السلسله|لا\s*تكسر\s*السلسلة|'
      r'streak|نقاط|شاره|شارة|كرياتين|فات\s*بيرنر|'
      r'علاج\s*للاكتئاب|يشفي\s*الاكتئاب|'
      r'عرفت\s*انك\s*مشيت|شفت\s*خطواتك|5000\s*خطوه)',
    ).hasMatch(message);
  }
}
