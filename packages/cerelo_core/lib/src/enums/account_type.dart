/// Customer account classification.
enum AccountType {
  /// Individual personal account.
  individual,

  /// Business/merchant account (e.g., Kwari Market trader).
  business;

  static AccountType fromString(String value) {
    final cleaned = value.replaceAll('_', '').toLowerCase();
    return AccountType.values.firstWhere(
      (e) => e.name.toLowerCase() == cleaned,
      orElse: () => AccountType.individual,
    );
  }
}
