import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;

  const GroupDetailsScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _userId;
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _loadMyInfo();
  }

  Future<void> _loadMyInfo() async {
    setState(() {
      _userId = _auth.currentUser?.uid;
    });

    try {
      Position pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _myLat = pos.latitude;
          _myLng = pos.longitude;
        });
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  Color _getBatteryColor(int battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }

  String _calculateDistance(double? lat, double? lng) {
    if (_myLat == null || _myLng == null || lat == null || lng == null) return "Unknown";
    double distance = Geolocator.distanceBetween(_myLat!, _myLng!, lat, lng);
    return distance < 1000 ? "${distance.toStringAsFixed(0)}m" : "${(distance / 1000).toStringAsFixed(1)}km";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Members'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/groups'),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.hasError) return const Center(child: Text('Error loading group info'));
          if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
          final List memberIds = groupData['members'] ?? [];

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.blue.withOpacity(0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(groupData['name'] ?? 'Group', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Code: ${groupData['code']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: groupData['code'] ?? ''));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('users').where('id', whereIn: memberIds.isEmpty ? [''] : memberIds).snapshots(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.hasError) return const Center(child: Text('Error loading members'));
                    if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final users = userSnapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final userData = users[index].data() as Map<String, dynamic>;
                        final int battery = userData['battery'] ?? 0;
                        final bool isMe = userData['id'] == _userId;

                        // SAFE NAME HANDLING
                        final String name = userData['name'] ?? "User";
                        final String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isMe ? Colors.blue : Colors.grey[200],
                              child: Text(initial, style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                            ),
                            title: Text("$name ${isMe ? '(You)' : ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${_calculateDistance(userData['lat'], userData['lng'])} away"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.battery_full, color: _getBatteryColor(battery), size: 20),
                                Text("$battery%", style: TextStyle(fontSize: 10, color: _getBatteryColor(battery), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      if (_userId == null) return;
                      await _firestore.collection('groups').doc(widget.groupId).update({
                        'members': FieldValue.arrayRemove([_userId])
                      });
                      if (context.mounted) context.go('/groups');
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    child: const Text('Leave Group'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
