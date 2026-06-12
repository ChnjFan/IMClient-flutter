import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _convReqSuccess = false;
  Timer? _convReqTimer;

  List<Map<String, dynamic>> get _messages =>
      widget.conversation['messages'] as List<Map<String, dynamic>>;

  @override
  void initState() {
    super.initState();
    _setupMessageHandlers();
    UserSession().tcpClient?.onMessage(_onTcpMessage);
    _sendConversationReqIfNeeded();
  }

  void _sendConversationReqIfNeeded() {
    if (widget.conversation['needsConvReq'] == true) {
      widget.conversation['needsConvReq'] = false;
      _sendConversationReq();
    } else {
      _convReqSuccess = true;
    }
  }

  void _sendConversationReq() {
    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;
    tcpClient.sendMessage(TcpMsgId.conversationReq.value, {
      'uid': UserSession().uid,
      'conv_id': widget.conversation['convId']?.toString() ?? '',
      'conv_type': 1,
      'to_uid': widget.conversation['uid'] as int? ?? 0,
    });
    _convReqTimer?.cancel();
    _convReqTimer = Timer(const Duration(seconds: 5), () {
      _convReqSuccess = false;
    });
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _convReqTimer?.cancel();
    UserSession().tcpClient?.removeMessageHandler(_onTcpMessage);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessageHandlers() {
    _msgHandler.on(TcpMsgId.chatMsgRsp, (msgId, data) {
      if (!mounted) return;
      final error = data['error'] as int? ?? -1;
      final localId = data['msg_id'] as int?;
      if (localId != null) {
        _pendingMsgIds.remove(localId);
        _timers.remove(localId)?.cancel();
        for (final m in _messages) {
          if (m['localId'] == localId) {
            if (m['type'] == 'file' && error == 0) {
              setState(() => m['status'] = 'uploading');
              _startFileUpload(m, localId);
            } else {
              setState(() => m['status'] = error == 0 ? 'sent' : 'failed');
            }
            break;
          }
        }
      }
    });

    _msgHandler.on(TcpMsgId.conversationRsp, (msgId, data) {
      if (!mounted) return;
      _convReqTimer?.cancel();
      final error = data['error'] as int? ?? -1;
      _convReqSuccess = error == 0;
    });

    _msgHandler.on(TcpMsgId.notifyChatMsg, (msgId, data) {
      if (!mounted) return;
      final fromUid = data['from_uid'] as int? ?? 0;
      final convUid = widget.conversation['uid'] as int? ?? 0;
      if (fromUid == convUid) {
        setState(() {});
        _scrollToBottom();
      }
    });
  }

  void _onTcpMessage(int msgId, Map<String, dynamic> data) {
    _msgHandler.handle(msgId, data);
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || text.length > 1024) return;

    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;

    if (!_convReqSuccess) {
      _sendConversationReq();
      return;
    }

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

    tcpClient.sendMessage(TcpMsgId.chatMsgReq.value, {
      'from_uid': UserSession().uid,
      'to_uid': toUid,
      'conv_id': widget.conversation['convId']?.toString() ?? '',
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

    tcpClient.sendMessage(TcpMsgId.chatMsgReq.value, {
      'from_uid': UserSession().uid,
      'to_uid': toUid,
      'conv_id': widget.conversation['convId']?.toString() ?? '',
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

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: const Text('文件'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSendFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final filePath = file.path;
    if (filePath == null) return;

    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;

    if (!_convReqSuccess) {
      _sendConversationReq();
      return;
    }

    final localId = ++_msgIdCounter;
    final toUid = widget.conversation['uid'] as int? ?? 0;

    setState(() {
      _messages.add({
        'type': 'file',
        'fileName': file.name,
        'filePath': filePath,
        'fileSize': file.size,
        'time': DateTime.now().toString(),
        'isMe': true,
        'localId': localId,
        'status': 'sending',
        'uploadSeq': 0,
      });
    });
    _startTimeout(localId);
    _scrollToBottom();

    final content = jsonEncode({'filename': file.name, 'size': file.size});
    tcpClient.sendMessage(TcpMsgId.chatMsgReq.value, {
      'from_uid': UserSession().uid,
      'to_uid': toUid,
      'conv_id': widget.conversation['convId']?.toString() ?? '',
      'msg_type': 2,
      'content': content,
      'msg_id': localId,
    });
  }

  static const int _chunkSize = 1024;

  Future<void> _startFileUpload(Map<String, dynamic> msg, int localId) async {
    final filePath = msg['filePath']?.toString();
    if (filePath == null) return;

    final tcpClient = UserSession().tcpClient;
    if (tcpClient == null || !tcpClient.isConnected) return;

    final fileBytes = await File(filePath).readAsBytes();
    final md5Hash = md5.convert(fileBytes).toString();
    final totalSize = fileBytes.length;
    final convId = widget.conversation['convId']?.toString() ?? '';
    final storePath = convId;
    final fileName = msg['fileName']?.toString() ?? '';

    int seq = 0;
    int offset = 0;
    while (offset < totalSize) {
      seq++;
      final end =
          (offset + _chunkSize > totalSize) ? totalSize : offset + _chunkSize;
      final chunk = Uint8List.sublistView(fileBytes, offset, end);
      final last = end >= totalSize ? 1 : 0;

      tcpClient.sendMessage(TcpMsgId.fileUploadReq.value, {
        'conv_id': storePath,
        'name': fileName,
        'md5': md5Hash,
        'seq': seq,
        'trans_size': chunk.length,
        'total_size': totalSize,
        'data': base64Encode(chunk),
        'last': last,
        'msg_id': localId,
      });

      setState(() => msg['uploadSeq'] = seq);

      if (last == 1) {
        if (mounted) setState(() => msg['status'] = 'sent');
        break;
      }

      final completer = Completer<void>();
      void handler(TcpMsgId rspMsgId, Map<String, dynamic> rspData) {
        final rspSeq = rspData['seq'] as int?;
        if (rspSeq == seq + 1) {
          _msgHandler.remove(TcpMsgId.fileUploadRsp, handler);
          completer.complete();
        }
      }

      _msgHandler.on(TcpMsgId.fileUploadRsp, handler);

      try {
        await completer.future.timeout(const Duration(seconds: 30));
        offset = end;
      } catch (_) {
        _msgHandler.remove(TcpMsgId.fileUploadRsp, handler);
        if (mounted) {
          setState(() => msg['status'] = 'failed');
        }
        return;
      }
    }
  }

  Widget _buildBubbleContent(Map<String, dynamic> msg) {
    if (msg['type'] == 'file') {
      final fileName = msg['fileName']?.toString() ?? '未知文件';
      final fileSize = msg['fileSize'] as int?;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                ),
                if (fileSize != null)
                  Text(
                    _formatFileSize(fileSize),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Text(msg['text']?.toString() ?? '');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
    final myName = UserSession().nickname;
    final peerName = widget.conversation['name']?.toString() ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                if (isMe && (status == 'sending' || status == 'uploading')) {
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
                      child: _buildBubbleContent(msg),
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
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
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
                  onPressed: _showAttachmentSheet,
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
