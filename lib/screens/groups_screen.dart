import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _selectedIndex = 1;
  String? _userId;
  String _userName = "User";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('user_id');
      _userName = prefs.getString('user_name') ?? "User";
    });
  }

  String _generateGroupCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  void _showCreateGroupDialog() {
    if (_userId == null) return;
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Group Name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final groupCode = _generateGroupCode();
                await _firestore.collection('groups').add({
                  'name': nameController.text,
                  'description': descController.text,
                  'code': groupCode,
                  'members': [_userId], // Store ID instead of name
                  'ownerId': _userId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                _showSnackBar('Group Created! Code: $groupCode', Colors.green);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    if (_userId == null) return;
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Group Code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              final query = await _firestore.collection('groups').where('code', isEqualTo: code).get();

              if (query.docs.isNotEmpty) {
                final docId = query.docs.first.id;
                await _firestore.collection('groups').doc(docId).update({
                  'members': FieldValue.arrayUnion([_userId]) // Add ID
                });
                Navigator.pop(context);
                _showSnackBar('Joined Successfully!', Colors.green);
              } else {
                _showSnackBar('Invalid Code', Colors.red);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(icon: const Icon(Icons.group_add), onPressed: _showJoinGroupDialog),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Show groups where my userId is in the members list
        stream: _firestore.collection('groups').where('members', arrayContains: _userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading groups'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) return const Center(child: Text('No groups yet.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index].data() as Map<String, dynamic>;
              final docId = groups[index].id;
              final members = group['members'] as List;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.people)),
                  title: Text(group['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${members.length} members • Code: ${group['code']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onLongPress: () async {
                    await _firestore.collection('groups').doc(docId).update({
                      'members': FieldValue.arrayRemove([_userId])
                    });
                    _showSnackBar('You left the group.', Colors.orange);
                  },
                  onTap: () => context.go('/group-details/$docId'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Group'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) context.go('/home');
          if (index == 2) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
