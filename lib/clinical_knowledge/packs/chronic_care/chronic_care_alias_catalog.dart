/// مرادفات عربية/عراقية لرعاية السكري والضغط.
class ChronicCareAliasCatalog {
  const ChronicCareAliasCatalog();

  bool looksLikeDiabetes(String n) => RegExp(
        r'(?:سكري|سكر\b|التراكمي|hb\s*a1c|hba1c|انسولين|إنسولين)',
      ).hasMatch(n);

  bool looksLikeHypertension(String n) => RegExp(
        r'(?:ضغط|الضغط|ارتفاع\s*ضغط|hypertension)',
      ).hasMatch(n);

  bool looksLikeChronicClinical(String n) =>
      looksLikeDiabetes(n) ||
      looksLikeHypertension(n) ||
      RegExp(
        r'(?:فحوص\s*دوريه|فحص\s*(?:العين|الكلى|القدم)|وظائف\s*الكلى|'
        r'UACR|eGFR|قائمة\s*متابعه|شنو\s*باقي)',
      ).hasMatch(n);
}
