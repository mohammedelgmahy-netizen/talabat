/// دوال مساعدة لقراءة JSON القادم من PostgREST (الأرقام قد تصل int أو double أو String)
double toDouble(Object? v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

double? toDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int toInt(Object? v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

DateTime? toDate(Object? v) => v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
