import 'package:flutter/material.dart';
import 'package:im_client/session/user_session.dart';
import 'chat_page.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserProfilePage({super.key, required this.user});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic> get user => widget.user;

  bool get _isStarred => user['isStarred'] == true;
  bool get _isBlocked => user['isBlocked'] == true;

  void _toggleStar() {
    setState(() => user['isStarred'] = !_isStarred);
  }

  void _toggleBlock() {
    setState(() => user['isBlocked'] = !_isBlocked);
  }

  void _deleteFriend() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: const Text('确定要删除该好友吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              UserSession().friends.removeWhere(
                (f) => f['uid'] == user['uid'],
              );
              Navigator.of(context).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('详细资料'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'star':
                  _toggleStar();
                  break;
                case 'block':
                  _toggleBlock();
                  break;
                case 'delete':
                  _deleteFriend();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'star',
                child: Text(_isStarred ? '取消星标好友' : '设为星标好友'),
              ),
              PopupMenuItem(
                value: 'block',
                child: Text(_isBlocked ? '移除黑名单' : '加入黑名单'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('删除好友', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name.isNotEmpty ? name : '未知用户',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              if (_isStarred)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.star, size: 20, color: Colors.amber),
                ),
            ],
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
