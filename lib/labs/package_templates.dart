import '../models/lab_models.dart';

/// احتياطي محلي فقط إذا لم تُنفَّذ جداول القوالب في Supabase بعد.
/// المصدر الأساسي بعد تنفيذ SQL: package_templates + package_template_analyses.
List<PackageTemplateItem> localFallbackPackageTemplates() {
  const raw = <(String, String, List<String>)>[
    (
      'باقة تساقط الشعر',
      'فحوصات مرتبطة بتساقط الشعر',
      [
        'CBC',
        'Ferritin',
        'Serum Iron',
        'Vitamin D',
        'Vitamin B12',
        'TSH',
        'Free T4',
        'Zinc',
        'Magnesium',
      ],
    ),
    (
      'باقة السكري',
      'تشخيص ومتابعة السكري',
      [
        'FBS',
        'PPBS',
        'HbA1c',
        'Creatinine',
        'eGFR',
        'Total Cholesterol',
        'Triglycerides',
        'HDL',
        'LDL',
      ],
    ),
    (
      'باقة الغدة الدرقية',
      'تقييم الغدة الدرقية',
      ['TSH', 'Free T4', 'Free T3', 'Anti-TPO', 'Anti-Thyroglobulin'],
    ),
    (
      'باقة فقر الدم',
      'تقييم فقر الدم',
      ['CBC', 'Ferritin', 'Serum Iron', 'TIBC', 'Vitamin B12', 'Folate'],
    ),
    (
      'باقة التعب والإرهاق',
      'أسباب شائعة للتعب',
      ['CBC', 'Ferritin', 'Vitamin D', 'Vitamin B12', 'FBS', 'TSH', 'Free T4'],
    ),
  ];

  return [
    for (var i = 0; i < raw.length; i++)
      PackageTemplateItem(
        id: 'local-$i',
        name: raw[i].$1,
        description: raw[i].$2,
        displayOrder: i + 1,
        analyses: raw[i].$3.map(AnalysisItem.fromName).toList(),
      ),
  ];
}
