import 'package:flutter/material.dart';
import 'package:im_client/session/user_session.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    final dt = DateTime.tryParse(timeStr);
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (msgDay == today.subtract(const Duration(days: 1))) {
      return '昨天';
    }
    if (dt.year == now.year) {
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final conversations = UserSession().conversations;

    return Scaffold(
      appBar: AppBar(title: const Text('消息')),
      body:
          conversations.isEmpty
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '暂无会话',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
              : ListView.separated(
                itemCount: conversations.length,
                separatorBuilder:
                    (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  final name = conv['name']?.toString() ?? '';
                  final messages =
                      conv['messages'] as List<Map<String, dynamic>>;
                  final lastMsg =
                      messages.isNotEmpty
                          ? (messages.last['text']?.toString() ?? '')
                          : '';
                  final unreadCount = conv['unreadCount'] as int? ?? 0;
                  final isTop = conv['isTop'] == true;
                  final isMute = conv['isMute'] == true;
                  final lastTimeStr = conv['lastTime']?.toString() ??
                      (messages.isNotEmpty
                          ? messages.last['time']?.toString()
                          : '') ??
                      '';

                  return Container(
                    color: isTop ? const Color(0xFFF0F0F0) : null,
                    child: ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            child: Text(name.isNotEmpty ? name[0] : '?'),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.isNotEmpty ? name : '未知用户',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(lastTimeStr),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          if (isMute)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.volume_off,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              lastMsg.isNotEmpty ? lastMsg : '暂无消息',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          if (isTop)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.push_pin,
                                size: 14,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => ChatPage(conversation: conv),
                              ),
                            )
                            .then((_) => setState(() {}));
                      },
                    ),
                  );
                },
              ),
    );
  }
}
