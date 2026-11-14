/// Pure-Dart phone normalization helpers for formatting local and E.164 numbers.
class PhoneUtils {
  PhoneUtils._();

  /// Normalize user-entered phone text together with a selected dial code into E.164 format.
  static String buildInternationalPhone(String countryCode, String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.startsWith('+')) {
      return formatInternationalPhone(trimmed);
    }
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    final codeDigits = countryCode.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    } else if (codeDigits.isNotEmpty &&
        digits.length == codeDigits.length + 10 &&
        digits.startsWith(codeDigits)) {
      digits = digits.substring(codeDigits.length);
    }
    return '+$codeDigits$digits';
  }

  /// Format mobile number in E.164 international format (+91 default for 10-digit numbers).
  static String formatInternationalPhone(String phoneNumber) {
    final trimmed = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '').trim();
    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }
    var clean = trimmed.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('0') && clean.length == 11) {
      clean = clean.substring(1);
    }
    if (clean.length == 10) {
      return '+91$clean';
    }
    return '+$clean';
  }
}

