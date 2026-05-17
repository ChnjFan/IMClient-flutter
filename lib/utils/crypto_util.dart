import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class CryptoUtil {
  static String sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  static String sha256WithSalt(String input, String salt) {
    final salted = '$input$salt';
    final bytes = utf8.encode(salted);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  static String md5(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.md5.convert(bytes);
    return digest.toString();
  }
}
