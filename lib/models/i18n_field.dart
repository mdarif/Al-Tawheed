// Shared helpers for multilingual JSON fields ({en, ur, roman, ...}).

/// Converts a JSON value that may be a plain String (legacy) or an i18n Map
/// into a normalised `Map<String, dynamic>`.
Map<String, dynamic> toI18nMap(dynamic value) {
  if (value is String) return {'en': value};
  if (value is Map) return Map<String, dynamic>.from(value);
  return {'en': ''};
}

/// Merges [overlay] keys into [field] when present (client-side CDN fallback).
Map<String, dynamic> mergeI18nOverlay(
  Map<String, dynamic> field,
  Map<String, String>? overlay,
) {
  if (overlay == null || overlay.isEmpty) return field;
  return {...field, ...overlay};
}

/// Convenience extension so widgets can write field.en instead of field['en'].
extension I18nField on Map<String, dynamic> {
  String get en => (this['en'] as String?) ?? '';
  String get ur => (this['ur'] as String?) ?? en;
  String get ar => (this['ar'] as String?) ?? en;
  String get roman => (this['roman'] as String?) ?? en;

  /// Returns the value for [languageCode] if present, falling back to [en].
  String forLanguage(String languageCode) =>
      (this[languageCode] as String?)?.isNotEmpty == true
          ? this[languageCode] as String
          : en;
}
