import 'dart:io' show pid;

/// معرف العملية الحالي (للتشخيص فقط).
String get appPidLabel => '$pid';

int get appPid => pid;
