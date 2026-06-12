import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SslConfig {
  static String? _pinnedFingerprint;

  /// 在 main() 中调用，从 assets 加载证书并提取 SHA-256 指纹。
  static Future<void> init() async {
    if (!kReleaseMode) return;

    final certBytes = await rootBundle.load('assets/certs/server.crt');
    final pemStr = utf8.decode(certBytes.buffer.asUint8List());
    _pinnedFingerprint = _pemToSha256(pemStr);
  }

  static String _certSha256(X509Certificate cert) {
    return sha256.convert(cert.der as Uint8List).toString();
  }

  /// 验证服务端证书 SHA-256 指纹是否与 assets 中加载的证书一致。
  static bool verifyCertificate(X509Certificate cert) {
    if (_pinnedFingerprint == null) return false;
    return _certSha256(cert) == _pinnedFingerprint;
  }

  static String _pemToSha256(String pem) {
    final lines = const LineSplitter()
        .convert(pem)
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    final derBytes = base64Decode(lines);
    return sha256.convert(derBytes).toString();
  }
}
