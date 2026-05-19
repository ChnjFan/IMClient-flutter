import 'package:im_client/network/tcp_client.dart';

class UserSession {
  static final UserSession _instance = UserSession._();
  factory UserSession() => _instance;
  UserSession._();

  int uid = 0;
  String token = '';
  String tcpHost = '';
  int tcpPort = 0;
  String nickname = '';
  String email = '';

  TcpClient? tcpClient;

  bool get isLogin => uid != 0 && token.isNotEmpty;

  void saveLoginResponse(Map<String, dynamic> data) {
    uid = data['uid'] as int? ?? 0;
    token = data['token']?.toString() ?? '';
    tcpHost = data['host']?.toString() ?? '';
    tcpPort = int.tryParse(data['port']?.toString() ?? '') ?? 0;
    nickname = data['user']?.toString() ?? '';
    email = data['email']?.toString() ?? '';
  }

  void clear() {
    tcpClient?.disconnect();
    tcpClient = null;
    uid = 0;
    token = '';
    tcpHost = '';
    tcpPort = 0;
    nickname = '';
    email = '';
  }
}
