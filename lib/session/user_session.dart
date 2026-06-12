import 'package:im_client/network/tcp_client.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';
import 'package:im_client/services/notification_service.dart';

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
  final List<Map<String, dynamic>> friends = [];
  final List<Map<String, dynamic>> conversations = [];
  TcpMessageHandler _globalMsgHandler = TcpMessageHandler();
  bool _globalHandlerRegistered = false;

  void Function()? onForceLogout;

  void _addOrUpdateFriendRequest(Map<String, dynamic> item) {
    final fromUid = item['fromUid'] as int? ?? 0;
    friendRequests.removeWhere((r) => r['fromUid'] == fromUid);
    friendRequests.add(item);
  }

  void addFriend(Map<String, dynamic> friend) {
    final fUid = friend['uid'] as int? ?? 0;
    friends.removeWhere((f) => f['uid'] == fUid);
    friends.add(friend);
  }

  void processAuthApplyList(dynamic applyList) {
    if (applyList is! List) return;
    var pendingCount = 0;
    for (final item in applyList) {
      if (item is Map<String, dynamic>) {
        final status = item['status'] as int? ?? 0;
        _addOrUpdateFriendRequest({
          'applyName': item['name']?.toString() ?? '',
          'applyEmail': item['email']?.toString() ?? '',
          'fromUid': item['uid'] as int? ?? 0,
          'status': status,
        });
        if (status == 0) pendingCount++;
      }
    }
    if (pendingCount > 0) {
      NotificationService().show(title: '好友申请', body: '您有新的好友申请');
    }
  }

  Map<String, dynamic> addOrGetConversation(Map<String, dynamic> user) {
    final fUid = user['uid'] as int? ?? 0;
    for (final c in conversations) {
      if (c['uid'] == fUid) return c;
    }
    final minUid = uid < fUid ? uid : fUid;
    final maxUid = uid > fUid ? uid : fUid;
    final conv = <String, dynamic>{
      'uid': fUid,
      'name': user['name']?.toString() ?? '',
      'email': user['email']?.toString() ?? '',
      'messages': <Map<String, dynamic>>[],
      'convId': 'c2c_${minUid}_$maxUid',
      'convType': 1,
      'unreadCount': 0,
      'lastMsgId': 0,
      'lastTime': '',
      'isTop': false,
      'isMute': false,
      'needsConvReq': true,
    };
    conversations.insert(0, conv);
    return conv;
  }

  void processAuthFriendList(dynamic friendList) {
    if (friendList is! List) return;
    for (final item in friendList) {
      if (item is Map<String, dynamic>) {
        addFriend(item);
      }
    }
  }

  void processAuthConversationList(dynamic convList) {
    if (convList is! List) return;
    for (final item in convList) {
      if (item is! Map<String, dynamic>) continue;
      final convId = item['conv_id']?.toString() ?? '';
      if (convId.isEmpty) continue;
      if (conversations.any((c) => c['convId'] == convId)) continue;

      // conv_id format: c2c_<uid1>_<uid2>, parse out peer uid
      final parts = convId.split('_');
      final parsedPeerUid = parts.length == 3
          ? (int.tryParse(parts[1]) == uid ? int.tryParse(parts[2]) : int.tryParse(parts[1]))
          : null;
      final toUid = parsedPeerUid ?? item['to_uid'] as int? ?? 0;

      Map<String, dynamic> friend = {};
      for (final f in friends) {
        if (f['uid'] == toUid) {
          friend = f;
          break;
        }
      }

      final lastMsg = item['last_msg']?.toString() ?? '';
      final messages = <Map<String, dynamic>>[];
      if (lastMsg.isNotEmpty) {
        messages.add({
          'text': lastMsg,
          'time': item['last_time']?.toString() ?? '',
          'isMe': false,
          'status': 'sent',
        });
      }

      conversations.add({
        'uid': toUid,
        'convId': convId,
        'convType': item['conv_type'] as int? ?? 0,
        'name': friend['name']?.toString() ?? '',
        'email': friend['email']?.toString() ?? '',
        'messages': messages,
        'unreadCount': item['unread_count'] as int? ?? 0,
        'lastMsgId': item['last_msg_id'] as int? ?? 0,
        'lastTime': item['last_time']?.toString() ?? '',
        'isTop': (item['is_top'] as int? ?? 0) == 1,
        'isMute': (item['is_mute'] as int? ?? 0) == 1,
        'needsConvReq': true,
      });
    }
    conversations.sort((a, b) {
      final aTop = (a['isTop'] == true) ? 1 : 0;
      final bTop = (b['isTop'] == true) ? 1 : 0;
      if (aTop != bTop) return bTop - aTop;
      final aTime = a['lastTime']?.toString() ?? '';
      final bTime = b['lastTime']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });
  }

  int get unviewedFriendRequestCount =>
      friendRequests.where((r) => r['status'] == 0).length;

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

    _globalMsgHandler.on(TcpMsgId.authRsp, (msgId, data) {
      final error = data['error'] as int? ?? -1;
      if (error != 0) return;
      processAuthApplyList(data['apply_list']);
      processAuthFriendList(data['friend_list']);
      processAuthConversationList(data['conv_list']);
    });

    _globalMsgHandler.on(TcpMsgId.notifyFriendReq, (msgId, data) {
      _addOrUpdateFriendRequest(data);
      NotificationService().show(title: '好友申请', body: '您有新的好友申请');
    });

    _globalMsgHandler.on(TcpMsgId.notifyFriendAuth, (msgId, data) {
      final error = data['error'] as int? ?? -1;
      if (error != 0) return;
      final friend = data['friend'];
      if (friend is Map<String, dynamic>) {
        addFriend(friend);
      }
    });

    _globalMsgHandler.on(TcpMsgId.notifyOffline, (msgId, data) {
      clear();
      onForceLogout?.call();
    });

    _globalMsgHandler.on(TcpMsgId.notifyChatMsg, (msgId, data) {
      final fromUid = data['from_uid'] as int? ?? 0;
      final content = data['content']?.toString() ?? '';
      if (fromUid == 0 || content.isEmpty) return;

      Map<String, dynamic> sender = {'uid': fromUid};
      for (final f in friends) {
        if (f['uid'] == fromUid) {
          sender = f;
          break;
        }
      }

      final conv = addOrGetConversation(sender);
      final messages = conv['messages'] as List<Map<String, dynamic>>;
      final now = DateTime.now().toString();
      messages.add({
        'text': content,
        'time': now,
        'isMe': false,
        'status': 'sent',
      });
      conv['lastTime'] = now;
      conv['unreadCount'] = (conv['unreadCount'] as int? ?? 0) + 1;
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
    friends.clear();
    conversations.clear();
    _globalMsgHandler = TcpMessageHandler();
    _globalHandlerRegistered = false;
  }
}
