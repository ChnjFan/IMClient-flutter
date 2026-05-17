import 'package:flutter/material.dart';
import 'package:im_client/network/http_client.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _keywordController = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _keywordController.addListener(() {
      final hasInput = _keywordController.text.trim().isNotEmpty;
      if (hasInput != _hasInput) {
        setState(() => _hasInput = hasInput);
      }
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool get _isEmail => _keywordController.text.trim().contains('@');

  Future<void> _search() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      final response = await HttpClient().post(
        '/user_search',
        data: {_isEmail ? 'email' : 'user': keyword},
      );

      if (!mounted) return;

      final error = response.data['error'] as int? ?? -1;
      if (error == 0) {
        final users = response.data['data'] as List<dynamic>? ?? [];
        setState(() {
          _results = users.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() {
          _results = [];
          _loading = false;
        });
        _showError('搜索失败');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _loading = false;
      });
      _showError('搜索失败: $e');
    }
  }

  Future<void> _addFriend(Map<String, dynamic> user) async {
    try {
      final response = await HttpClient().post(
        '/friend_add',
        data: {'uid': user['uid']},
      );

      if (!mounted) return;

      final error = response.data['error'] as int? ?? -1;
      if (error == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('好友请求已发送')));
      } else {
        _showError('添加失败');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('添加失败: $e');
    }
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
                        final nickname = user['nickname']?.toString() ?? '';
                        final email = user['email']?.toString() ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              nickname.isNotEmpty ? nickname[0] : '?',
                            ),
                          ),
                          title: Text(nickname.isNotEmpty ? nickname : '未知用户'),
                          subtitle: Text(email),
                          trailing: FilledButton.tonal(
                            onPressed: () => _addFriend(user),
                            child: const Text('添加'),
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
