import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  String _name = "User";
  String _userId = "";
  int _batteryLevel = 0;
  int _groupCount = 0;
  String _avatarColor = "0xFF0066CC"; // Default color hex string

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? "";
    final name = prefs.getString('user_name') ?? "User";
    final level = await _battery.batteryLevel;
    
    // Get group count from Firestore
    final groupQuery = await _firestore.collection('groups').where('members', arrayContains: userId).get();

    setState(() {
      _userId = userId;
      _name = name;
      _batteryLevel = level;
      _groupCount = groupQuery.docs.length;
      _avatarColor = prefs.getString('avatar_color') ?? "0xFF0066CC";
    });
  }

  Future<void> _updateName() async {
    final controller = TextEditingController(text: _name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_name', controller.text);

                // Update Firestore
                await _firestore.collection('users').doc(_userId).update({
                  'name': controller.text,
                });

                setState(() => _name = controller.text);
                Navigator.pop(context);
                _showSnackBar('Name updated!', Colors.green);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changeAvatarColor() {
    final colors = [
      {'name': 'Blue', 'hex': '0xFF0066CC'},
      {'name': 'Purple', 'hex': '0xFF8B5CF6'},
      {'name': 'Red', 'hex': '0xFFEF4444'},
      {'name': 'Green', 'hex': '0xFF22C55E'},
      {'name': 'Orange', 'hex': '0xFFF59E0B'},
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Avatar Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: colors.map((c) => GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('avatar_color', c['hex']!);
                  setState(() => _avatarColor = c['hex']!);
                  Navigator.pop(context);
                },
                child: CircleAvatar(
                  backgroundColor: Color(int.parse(c['hex']!)),
                  radius: 25,
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/settings')),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar with Color Picker
            GestureDetector(
              onTap: _changeAvatarColor,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(int.parse(_avatarColor)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Center(
                      child: Text(_name[0].toUpperCase(), style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: Icon(Icons.colorize, size: 18, color: Color(int.parse(_avatarColor))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _changeAvatarColor, child: const Text('Change Avatar Color')),

            const SizedBox(height: 30),
            // Name Section
            ListTile(
              title: const Text('Display Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF))),
              trailing: const Icon(Icons.edit),
              onTap: _updateName,
            ),
            const Divider(),

            // Stats Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildStatCard('Battery', '$_batteryLevel%', Colors.green, Icons.battery_full),
                  const SizedBox(width: 16),
                  _buildStatCard('Groups', '$_groupCount', Colors.blue, Icons.group),
                ],
              ),
            ),

            const SizedBox(height: 40),
            Text('User ID: $_userId', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 20),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/login'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/groups');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
