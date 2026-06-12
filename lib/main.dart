import 'package:flutter/material.dart';
import 'app.dart';
import 'network/ssl_config.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await SslConfig.init();
  runApp(const IMClientApp());
}
