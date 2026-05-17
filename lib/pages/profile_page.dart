import 'package:flutter/material.dart';
import 'package:im_client/session/user_session.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = UserSession();
    final nickname = session.nickname;
    final email = session.email;
    final avatarChar = nickname.isNotEmpty ? nickname[0] : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Column(
        children: [
          const SizedBox(height: 32),
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              avatarChar,
              style: const TextStyle(fontSize: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            nickname.isNotEmpty ? nickname : '未设置昵称',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : '未知邮箱',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('退出登录', style: TextStyle(color: Colors.red)),
            onTap: () {
              session.clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
