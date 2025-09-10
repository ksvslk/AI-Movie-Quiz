/// Extension methods for converting ISO 8601 subscription period strings to English
extension SubscriptionPeriod on String? {
  /// Converts an ISO 8601 subscription period string to a human-readable English string.
  ///
  /// Examples:
  /// - "P1W".toEnglish() -> "1 week"
  /// - "P1M".toEnglish() -> "1 month"
  /// - "P3M".toEnglish() -> "3 months"
  /// - "P6M".toEnglish() -> "6 months"
  /// - "P1Y".toEnglish() -> "1 year"
  /// - "P2Y".toEnglish() -> "2 years"
  ///
  /// Returns null if the input is null or invalid format.
  String? toEnglish() {
    if (this == null || this!.isEmpty) {
      return null;
    }

    // Remove 'P' prefix if present
    String cleanPeriod = this!.startsWith('P') ? this!.substring(1) : this!;

    if (cleanPeriod.isEmpty) {
      return null;
    }

    // Extract number and unit
    final RegExp regex = RegExp(r'^(\d+)([DWMY])$');
    final match = regex.firstMatch(cleanPeriod);

    if (match == null) {
      return null;
    }

    final int number = int.parse(match.group(1)!);
    final String unit = match.group(2)!;

    String unitName;
    switch (unit) {
      case 'D':
        unitName = number == 1 ? 'day' : 'days';
        break;
      case 'W':
        unitName = number == 1 ? 'week' : 'weeks';
        break;
      case 'M':
        unitName = number == 1 ? 'month' : 'months';
        break;
      case 'Y':
        unitName = number == 1 ? 'year' : 'years';
        break;
      default:
        return null;
    }

    return '$number $unitName';
  }

  /// Converts subscription period to more user-friendly English with common subscription terms.
  ///
  /// Examples:
  /// - "P1W".toFriendlyEnglish() -> "Weekly"
  /// - "P1M".toFriendlyEnglish() -> "Monthly"
  /// - "P3M".toFriendlyEnglish() -> "Quarterly"
  /// - "P6M".toFriendlyEnglish() -> "Semi-annually"
  /// - "P1Y".toFriendlyEnglish() -> "Yearly"
  /// - "P5M".toFriendlyEnglish() -> "5 months"
  ///
  /// Returns null if the input is null or invalid format.
  String? toFriendlyEnglish() {
    final basic = toEnglish();
    if (basic == null) return null;

    // Handle common subscription periods with more friendly names
    switch (this) {
      case 'P1W':
        return 'week';
      case 'P1M':
        return 'month';
      case 'P3M':
        return 'quarter';
      case 'P6M':
        return 'semi-annual';
      case 'P1Y':
        return 'year';
      case 'P2Y':
        return 'bi-annual';
      default:
        // Capitalize first letter for other periods
        return basic[0].toUpperCase() + basic.substring(1);
    }
  }
}