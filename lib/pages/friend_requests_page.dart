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
  final List<Map<String, dynamic>> _requests = [];

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
    _msgHandler.on(TcpMsgId.notifyFriendAddReq, (msgId, data) {
      if (!mounted) return;
      setState(() => _requests.add(data));
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
                child: Text(
                  '暂无好友申请',
                  style: TextStyle(color: Colors.grey),
                ),
              )
              : ListView.separated(
                itemCount: _requests.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final req = _requests[index];
                  final name = req['name']?.toString() ?? '';
                  final email = req['email']?.toString() ?? '';
                  final reason = req['reason']?.toString() ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(name.isNotEmpty ? name[0] : '?'),
                    ),
                    title: Text(name.isNotEmpty ? name : '未知用户'),
                    subtitle: Text(reason.isNotEmpty ? reason : email),
                  );
                },
              ),
    );
  }
}
