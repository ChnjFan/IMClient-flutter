import 'package:im_client/network/tcp_client.dart';

class UserSession {
  static final UserSession _instance = UserSession._();
  factory UserSession() => _instance;
  UserSession._();

  String uid = '';
  String token = '';
  String tcpHost = '';
  int tcpPort = 0;
  String nickname = '';
  String email = '';

  TcpClient? tcpClient;

  bool get isLogin => uid.isNotEmpty && token.isNotEmpty;

  void saveLoginResponse(Map<String, dynamic> data) {
    uid = data['uid']?.toString() ?? '';
    token = data['token']?.toString() ?? '';
    tcpHost = data['host']?.toString() ?? '';
    tcpPort = int.tryParse(data['port']?.toString() ?? '') ?? 0;
    nickname = data['user']?.toString() ?? '';
    email = data['email']?.toString() ?? '';
  }

  void clear() {
    tcpClient?.disconnect();
    tcpClient = null;
    uid = '';
    token = '';
    tcpHost = '';
    tcpPort = 0;
    nickname = '';
    email = '';
  }
}
