import 'internet_probe_stub.dart'
    if (dart.library.io) 'internet_probe_io.dart' as impl;

/// هل أكو إنترنت فعلاً؟ (مو بس واي فاي مشبوك.) على الويب يرجع true دائماً.
Future<bool> hasInternet() => impl.hasInternet();
