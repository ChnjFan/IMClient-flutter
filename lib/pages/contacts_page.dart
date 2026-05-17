import 'package:flutter/material.dart';
import 'add_friend_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _searchController = TextEditingController();
  String _keyword = '';

  final _allContacts = const ['张三', '李四', '王五', '赵六', '小明', '小红'];

  List<String> get _filteredContacts {
    if (_keyword.isEmpty) return _allContacts;
    return _allContacts.where((name) => name.contains(_keyword)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _filteredContacts;

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
            child:
                contacts.isEmpty
                    ? const Center(
                      child: Text(
                        '未找到联系人',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder:
                          (_, __) => const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        final name = contacts[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(name[0])),
                          title: Text(name),
                          onTap: () {},
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
