import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
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
                  'members': [_userId],
                  'ownerId': _userId,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
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
                  'members': FieldValue.arrayUnion([_userId])
                });
                if (mounted) Navigator.pop(context);
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
        stream: _firestore.collection('groups').where('members', arrayContains: _userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading groups'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final groups = snapshot.data?.docs ?? [];

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No groups yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Create or join a group to start tracking!', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: _showJoinGroupDialog, child: const Text('Join a Group')),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final groupDoc = groups[index];
              final group = groupDoc.data() as Map<String, dynamic>;
              final docId = groupDoc.id;
              final members = group['members'] as List? ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.people, color: Colors.blue),
                  ),
                  title: Text(group['name'] ?? 'Unnamed Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${members.length} member${members.length > 1 ? 's' : ''} • Code: ${group['code']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Leave Group?'),
                        content: Text('Are you sure you want to leave "${group['name']}"?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () async {
                              await _firestore.collection('groups').doc(docId).update({
                                'members': FieldValue.arrayRemove([_userId])
                              });
                              if (mounted) Navigator.pop(context);
                              _showSnackBar('You left the group.', Colors.orange);
                            },
                            child: const Text('Leave', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
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
        currentIndex: 1,
        onTap: (index) {
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
