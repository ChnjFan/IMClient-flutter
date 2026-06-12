import 'package:flutter/foundation.dart';

class AppConfig {
  static const String host =
      kReleaseMode ? 'https://8.155.163.55:443' : 'http://127.0.0.1:8080';

  static const int httpConnectTimeout = 10;
  static const int httpReceiveTimeout = 10;
  static const int httpSendTimeout = 10;

  static const int tcpReconnectDelay = 10;
}
