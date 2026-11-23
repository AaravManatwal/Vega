/// Tiny English / Hindi switch used by the screens (the web design offers both).
class VegaStrings {
  const VegaStrings(this.hi);
  final bool hi;

  /// `s.t('Send', 'भेजें')` returns the Hindi text when Hindi is selected.
  String t(String en, String hindi) => hi ? hindi : en;
}
