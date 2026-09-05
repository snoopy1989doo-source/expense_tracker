class NameHelper {
  /// Resolves display name according to user requirement:
  /// 1. Set nickname (ชื่อเล่นที่ตั้ง)
  /// 2. Gmail / Email prefix (ชื่อ Gmail ที่ล็อกอิน ก่อนเครื่องหมาย @)
  /// 3. Default fallback (เช่น 'แฟน' หรือ 'ฉัน')
  static String resolveDisplayName({
    String? nickname,
    String? email,
    String defaultFallback = 'แฟน',
  }) {
    final cleanNickname = nickname?.trim() ?? '';
    if (cleanNickname.isNotEmpty) {
      return cleanNickname;
    }

    final cleanEmail = email?.trim() ?? '';
    if (cleanEmail.isNotEmpty) {
      if (cleanEmail.contains('@')) {
        final prefix = cleanEmail.split('@').first.trim();
        if (prefix.isNotEmpty) {
          return prefix;
        }
      }
      return cleanEmail;
    }

    return defaultFallback;
  }
}
