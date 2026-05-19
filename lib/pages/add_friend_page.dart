import 'package:flutter/material.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';
import 'package:im_client/session/user_session.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _keywordController = TextEditingController();
  final _msgHandler = TcpMessageHandler();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;
  bool _hasInput = false;
  final Set<int> _appliedUids = {};
  int? _requestingUid;

  @override
  void initState() {
    super.initState();
    _keywordController.addListener(() {
      final hasInput = _keywordController.text.trim().isNotEmpty;
      if (hasInput != _hasInput) {
        setState(() => _hasInput = hasInput);
      }
    });
    _setupMessageHandlers();
    UserSession().tcpClient?.onMessage(_onTcpMessage);
  }

  @override
  void dispose() {
    UserSession().tcpClient?.removeMessageHandler(_onTcpMessage);
    _keywordController.dispose();
    super.dispose();
  }

  void _setupMessageHandlers() {
    _msgHandler.on(TcpMsgId.userSearchRsp, (msgId, data) {
      if (!mounted) return;
      final error = data['error'] as int? ?? -1;
      if (error == 0) {
        final results = <Map<String, dynamic>>[];
        final inner = data['data'];
        if (inner is List) {
          results.addAll(inner.cast<Map<String, dynamic>>());
        } else if (inner is Map<String, dynamic> && inner['uid'] != null) {
          results.add(inner);
        }
        setState(() {
          _results = results;
          _loading = false;
        });
      } else {
        setState(() {
          _results = [];
          _loading = false;
        });
        _showError('搜索失败');
      }
    });

    _msgHandler.on(TcpMsgId.friendAddRsp, (msgId, data) {
      if (!mounted) return;
      final error = data['error'] as int? ?? -1;
      if (error == 0) {
        if (_requestingUid != null) {
          _appliedUids.add(_requestingUid!);
        }
        setState(() => _requestingUid = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('好友请求已发送')));
      } else {
        setState(() => _requestingUid = null);
        _showError('添加失败');
      }
    });
  }

  void _onTcpMessage(int msgId, Map<String, dynamic> data) {
    _msgHandler.handle(msgId, data);
  }

  bool get _isEmail => _keywordController.text.trim().contains('@');

  void _search() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) {
      _showError('未连接到服务器');
      return;
    }

    setState(() {
      _loading = true;
      _searched = true;
    });

    tcpClient.sendMessage(TcpMsgId.userSearchReq.value, {
      _isEmail ? 'email' : 'name': keyword,
    });
  }

  void _addFriend(Map<String, dynamic> user) {
    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) {
      _showError('未连接到服务器');
      return;
    }

    final toUid = user['uid'] as int? ?? -1;
    if (toUid == UserSession().uid) {
      _showError('无法添加自己为好友');
      return;
    }
    setState(() => _requestingUid = toUid);

    tcpClient.sendMessage(TcpMsgId.friendAddReq.value, {
      'fromUid': UserSession().uid,
      'toUid': toUid,
      'applyName': user['name'] as String? ?? '',
      'applyEmail': user['email'] as String? ?? '',
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加好友')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                hintText: '输入邮箱或用户名搜索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _hasInput
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _keywordController.clear();
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_hasInput)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton(
                  onPressed: _loading ? null : _search,
                  child:
                      _loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('搜索'),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child:
                !_searched
                    ? const Center(
                      child: Text(
                        '输入邮箱或用户名搜索好友',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : _results.isEmpty
                    ? const Center(
                      child: Text(
                        '未找到用户',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder:
                          (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        final uid = user['uid'] as int? ?? -1;
                        final nickname = user['name']?.toString() ?? '';
                        final email = user['email']?.toString() ?? '';
                        final applied = _appliedUids.contains(uid);
                        final requesting = _requestingUid == uid;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              nickname.isNotEmpty ? nickname[0] : '?',
                            ),
                          ),
                          title: Text(nickname.isNotEmpty ? nickname : '未知用户'),
                          subtitle: Text(email),
                          trailing: FilledButton.tonal(
                            onPressed:
                                (applied || requesting)
                                    ? null
                                    : () => _addFriend(user),
                            child:
                                applied
                                    ? const Text('已申请')
                                    : requesting
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text('添加'),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
