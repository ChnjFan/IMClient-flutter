import 'package:flutter/material.dart';
import 'package:im_client/session/user_session.dart';
import 'chat_page.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
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
                          ? messages.last['text']?.toString()
                          : '';

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(name.isNotEmpty ? name[0] : '?'),
                    ),
                    title: Text(name.isNotEmpty ? name : '未知用户'),
                    subtitle: Text(
                      lastMsg != null ? lastMsg : '暂无消息',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
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
                  );
                },
              ),
    );
  }
}
