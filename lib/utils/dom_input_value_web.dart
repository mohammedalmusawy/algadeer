import 'dart:html' as html;

/// على Flutter Web: يقرأ قيمة input من DOM عندما لا يصل النص
/// إلى TextEditingController (مشكلة شائعة مع الأتمتة/اللصق).
String? readFirstDomInputValue() {
  for (final el in html.document.querySelectorAll('input')) {
    if (el is html.InputElement) {
      final value = el.value?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}
