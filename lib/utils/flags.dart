bool readBoolFlag(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value == true || value == 1 || value == 'true') return true;
  if (value == false || value == 0 || value == 'false') return false;
  return fallback;
}
