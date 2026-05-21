import 'package:flutter/material.dart';
import 'package:im_client/session/user_session.dart';
import 'chat_page.dart';

class UserProfilePage extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('详细资料')),
      body: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 40,
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name.isNotEmpty ? name : '未知用户',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '邮箱: $email',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('发消息'),
            onTap: () {
              final conv = UserSession().addOrGetConversation(user);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChatPage(conversation: conv)),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('音视频通话'),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('音视频通话功能开发中')));
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
