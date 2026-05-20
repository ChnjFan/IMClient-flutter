import 'package:im_client/network/tcp_client.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';

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

  final List<Map<String, dynamic>> friendRequests = [];
  int viewedFriendRequestCount = 0;
  final _globalMsgHandler = TcpMessageHandler();
  bool _globalHandlerRegistered = false;

  int get unviewedFriendRequestCount =>
      friendRequests.length - viewedFriendRequestCount;

  bool get isLogin => uid != 0 && token.isNotEmpty;

  void saveLoginResponse(Map<String, dynamic> data) {
    uid = data['uid'] as int? ?? 0;
    token = data['token']?.toString() ?? '';
    tcpHost = data['host']?.toString() ?? '';
    tcpPort = int.tryParse(data['port']?.toString() ?? '') ?? 0;
    nickname = data['user']?.toString() ?? '';
    email = data['email']?.toString() ?? '';
  }

  void setupGlobalHandlers() {
    if (_globalHandlerRegistered) return;
    _globalHandlerRegistered = true;

    tcpClient?.onMessage(_onGlobalTcpMessage);

    _globalMsgHandler.on(TcpMsgId.notifyFriendReq, (msgId, data) {
      friendRequests.add(data);
    });
  }

  void _onGlobalTcpMessage(int msgId, Map<String, dynamic> data) {
    _globalMsgHandler.handle(msgId, data);
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
    friendRequests.clear();
    viewedFriendRequestCount = 0;
    _globalHandlerRegistered = false;
  }
}
