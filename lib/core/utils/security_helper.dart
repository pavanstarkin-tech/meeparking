class SecurityHelper {
  static const String _cipherKey = 'MEE_PARKING_SEC_2026';

  /// Decrypts obfuscated API keys at runtime so plain-text credentials are never committed in plaintext
  static String decryptSecret(String encryptedHex) {
    if (encryptedHex.isEmpty) return '';
    try {
      final List<int> bytes = [];
      for (int i = 0; i < encryptedHex.length; i += 2) {
        bytes.add(int.parse(encryptedHex.substring(i, i + 2), radix: 16));
      }
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < bytes.length; i++) {
        buffer.writeCharCode(bytes[i] ^ _cipherKey.codeUnitAt(i % _cipherKey.length));
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }
}
