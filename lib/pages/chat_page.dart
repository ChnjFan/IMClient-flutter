import 'dart:async';
import 'package:flutter/material.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';
import 'package:im_client/session/user_session.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _msgHandler = TcpMessageHandler();
  bool _isVoiceMode = false;
  int _msgIdCounter = 0;
  final Set<int> _pendingMsgIds = {};
  final Map<int, Timer> _timers = {};

  List<Map<String, dynamic>> get _messages =>
      widget.conversation['messages'] as List<Map<String, dynamic>>;

  @override
  void initState() {
    super.initState();
    _setupMessageHandlers();
    UserSession().tcpClient?.onMessage(_onTcpMessage);
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    UserSession().tcpClient?.removeMessageHandler(_onTcpMessage);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessageHandlers() {
    _msgHandler.on(TcpMsgId.notifyChatMsgRsp, (msgId, data) {
      if (!mounted) return;
      final error = data['error'] as int? ?? -1;
      final localId = data['msg_id'] as int?;
      if (localId != null) {
        _pendingMsgIds.remove(localId);
        _timers.remove(localId)?.cancel();
        for (final m in _messages) {
          if (m['localId'] == localId) {
            setState(() => m['status'] = error == 0 ? 'sent' : 'failed');
            break;
          }
        }
      }
    });
  }

  void _onTcpMessage(int msgId, Map<String, dynamic> data) {
    _msgHandler.handle(msgId, data);
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;

    final localId = ++_msgIdCounter;
    final toUid = widget.conversation['uid'] as int? ?? 0;

    _textController.clear();
    _pendingMsgIds.add(localId);
    setState(() {
      _messages.add({
        'text': text,
        'time': DateTime.now().toString(),
        'isMe': true,
        'localId': localId,
        'status': 'sending',
      });
    });
    _startTimeout(localId);
    _scrollToBottom();

    tcpClient.sendMessage(TcpMsgId.notifyChatMsgReq.value, {
      'from_uid': UserSession().uid,
      'to_uid': toUid,
      'msg_type': 1,
      'content': text,
      'msg_id': localId,
    });
  }

  void _retrySend(int index) {
    final msg = _messages[index];
    final text = msg['text']?.toString() ?? '';
    final localId = msg['localId'] as int? ?? 0;
    final toUid = widget.conversation['uid'] as int? ?? 0;

    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;

    _pendingMsgIds.add(localId);
    setState(() => _messages[index]['status'] = 'sending');
    _startTimeout(localId);

    tcpClient.sendMessage(TcpMsgId.notifyChatMsgReq.value, {
      'from_uid': UserSession().uid,
      'to_uid': toUid,
      'msg_type': 0,
      'content': text,
      'msg_id': localId,
    });
  }

  void _startTimeout(int localId) {
    _timers[localId]?.cancel();
    _timers[localId] = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      if (_pendingMsgIds.remove(localId)) {
        _timers.remove(localId);
        for (final m in _messages) {
          if (m['localId'] == localId) {
            setState(() => m['status'] = 'failed');
            break;
          }
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.conversation['name']?.toString() ?? '';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final myName = UserSession().nickname;
    final peerName = widget.conversation['name']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(name.isNotEmpty ? name : '聊天')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'] == true;
                final status = msg['status']?.toString() ?? 'sent';

                final avatarLetter =
                    (isMe
                            ? (myName.isNotEmpty ? myName[0] : '我')
                            : (peerName.isNotEmpty ? peerName[0] : '?'))
                        .toUpperCase();

                final avatar = CircleAvatar(
                  radius: 18,
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(fontSize: 14),
                  ),
                );

                Widget statusWidget = const SizedBox.shrink();
                if (isMe && status == 'sending') {
                  statusWidget = const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                } else if (isMe && status == 'failed') {
                  statusWidget = GestureDetector(
                    onTap: () => _retrySend(index),
                    child: const Icon(Icons.error, size: 18, color: Colors.red),
                  );
                }

                final bubble = Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                      ),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF95EC69) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(msg['text']?.toString() ?? ''),
                    ),
                  ],
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        isMe
                            ? [
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: statusWidget,
                              ),
                              const SizedBox(width: 4),
                              Flexible(child: bubble),
                              const SizedBox(width: 8),
                              avatar,
                            ]
                            : [
                              avatar,
                              const SizedBox(width: 8),
                              Flexible(child: bubble),
                            ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 50 + bottomInset),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isVoiceMode ? Icons.keyboard_outlined : Icons.mic_none,
                  ),
                  iconSize: 30,
                  onPressed: () => setState(() => _isVoiceMode = !_isVoiceMode),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                Expanded(
                  child:
                      _isVoiceMode
                          ? Container(
                            height: 40,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Center(
                              child: Text(
                                '按住说话',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                          : TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: '输入消息',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  iconSize: 30,
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 30,
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
