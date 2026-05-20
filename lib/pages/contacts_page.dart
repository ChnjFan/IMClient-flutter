import 'package:flutter/material.dart';
import 'package:im_client/network/tcp_message_handler.dart';
import 'package:im_client/network/tcp_msg_id.dart';
import 'package:im_client/session/user_session.dart';
import 'add_friend_page.dart';
import 'friend_requests_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchController = TextEditingController();
  final _msgHandler = TcpMessageHandler();
  String _keyword = '';

  final _allContacts = const ['张三', '李四', '王五', '赵六', '小明', '小红'];

  List<String> get _filteredContacts {
    if (_keyword.isEmpty) return _allContacts;
    return _allContacts.where((name) => name.contains(_keyword)).toList();
  }

  @override
  void initState() {
    super.initState();
    _setupMessageHandlers();
    UserSession().tcpClient?.onMessage(_onTcpMessage);
  }

  @override
  void dispose() {
    UserSession().tcpClient?.removeMessageHandler(_onTcpMessage);
    _searchController.dispose();
    super.dispose();
  }

  void _setupMessageHandlers() {
    _msgHandler.on(TcpMsgId.notifyFriendReq, (msgId, data) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _onTcpMessage(int msgId, Map<String, dynamic> data) {
    _msgHandler.handle(msgId, data);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;
    final unviewedCount = UserSession().unviewedFriendRequestCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddFriendPage()));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索好友',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _keyword.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _keyword = '');
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() => _keyword = value.trim());
              },
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.person_add, color: Colors.orange.shade700),
                  ),
                  title: const Text('新的朋友'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unviewedCount > 0)
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Text(
                            '$unviewedCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const FriendRequestsPage(),
                          ),
                        )
                        .then((_) => setState(() {}));
                  },
                ),
                const Divider(height: 1, indent: 72),
                if (contacts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text(
                        '未找到联系人',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < contacts.length; i++) ...[
                    ListTile(
                      leading: CircleAvatar(child: Text(contacts[i][0])),
                      title: Text(contacts[i]),
                      onTap: () {},
                    ),
                    if (i < contacts.length - 1)
                      const Divider(height: 1, indent: 72),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
