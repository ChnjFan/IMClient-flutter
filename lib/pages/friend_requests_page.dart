import 'package:flutter/material.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';
import 'package:im_client/session/user_session.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  final _msgHandler = TcpMessageHandler();
  final Set<int> _acceptedFromUids = {};
  int? _acceptingFromUid;

  List<Map<String, dynamic>> get _requests => UserSession().friendRequests;

  @override
  void initState() {
    super.initState();
    _setupMessageHandlers();
    UserSession().tcpClient?.onMessage(_onTcpMessage);
  }

  @override
  void dispose() {
    UserSession().tcpClient?.removeMessageHandler(_onTcpMessage);
    super.dispose();
  }

  void _setupMessageHandlers() {
    _msgHandler.on(TcpMsgId.notifyFriendReq, (msgId, data) {
      if (!mounted) return;
      setState(() {});
    });

    _msgHandler.on(TcpMsgId.friendAuthRsp, (msgId, data) {
      if (!mounted) return;
      final error = data['error'] as int? ?? -1;
      if (error == 0 && _acceptingFromUid != null) {
        _acceptedFromUids.add(_acceptingFromUid!);
        for (final req in UserSession().friendRequests) {
          final uid = req['fromUid'] as int?;
          if (uid == _acceptingFromUid) {
            req['status'] = 1;
            break;
          }
        }
      }
      setState(() => _acceptingFromUid = null);
    });
  }

  void _acceptFriend(Map<String, dynamic> req) {
    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;

    final fromUid = req['fromUid'] as int? ?? -1;
    setState(() => _acceptingFromUid = fromUid);

    tcpClient.sendMessage(TcpMsgId.friendAuthReq.value, {
      'auth_uid': UserSession().uid,
      'apply_uid': fromUid,
    });
  }

  void _onTcpMessage(int msgId, Map<String, dynamic> data) {
    _msgHandler.handle(msgId, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新的朋友')),
      body:
          _requests.isEmpty
              ? const Center(
                child: Text('暂无好友申请', style: TextStyle(color: Colors.grey)),
              )
              : ListView.separated(
                itemCount: _requests.length,
                separatorBuilder:
                    (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  final applyName = req['applyName']?.toString() ?? '';
                  final applyEmail = req['applyEmail']?.toString() ?? '';
                  final fromUid = req['fromUid'] as int? ?? -1;
                  final status = req['status'] as int? ?? 0;
                  final accepted = _acceptedFromUids.contains(fromUid);
                  final accepting = _acceptingFromUid == fromUid;

                  String statusText(int s) {
                    switch (s) {
                      case 1:
                        return '已同意';
                      case 2:
                        return '已拒绝';
                      case 3:
                        return '已过期';
                      default:
                        return '';
                    }
                  }

                  final showButton = status == 0 && !accepted;
                  final statusLabel = accepted ? '已添加' : statusText(status);

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(applyName.isNotEmpty ? applyName[0] : '?'),
                    ),
                    title: Text(applyName.isNotEmpty ? applyName : '未知用户'),
                    subtitle: Text(applyEmail),
                    trailing:
                        showButton
                            ? FilledButton.tonal(
                              onPressed:
                                  accepting ? null : () => _acceptFriend(req),
                              child:
                                  accepting
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('添加'),
                            )
                            : statusLabel.isNotEmpty
                            ? Text(
                              statusLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            )
                            : null,
                  );
                },
              ),
    );
  }
}
