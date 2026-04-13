import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Battery _battery = Battery();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  String _name = "User";
  String _userId = "";
  String? _photoBase64;
  int _batteryLevel = 0;
  int _groupCount = 0;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final level = await _battery.batteryLevel;
    
    final userDoc = await _firestore.collection('users').doc(userId).get();
    String currentName = user.displayName ?? user.email?.split('@')[0] ?? "User";
    String? currentPhotoBase64;

    if (userDoc.exists) {
      final data = userDoc.data()!;
      currentName = data['name'] ?? currentName;
      currentPhotoBase64 = data['photoBase64'];
    }

    final groupQuery = await _firestore.collection('groups').where('members', arrayContains: userId).get();

    if (mounted) {
      setState(() {
        _userId = userId;
        _name = currentName;
        _batteryLevel = level;
        _groupCount = groupQuery.docs.length;
        _photoBase64 = currentPhotoBase64;
      });
    }
  }

  Future<void> _pickAndSaveImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
      maxWidth: 200,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final File file = File(image.path);
      final List<int> bytes = await file.readAsBytes();
      final String base64String = base64Encode(bytes);

      await _firestore.collection('users').doc(_userId).set({
        'photoBase64': base64String,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _photoBase64 = base64String;
          _isUploading = false;
        });
        _showSnackBar('Profile picture updated!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showSnackBar('Failed to save image: $e', Colors.red);
      }
    }
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
                await _auth.currentUser?.updateDisplayName(controller.text);
                await _firestore.collection('users').doc(_userId).set({
                  'name': controller.text,
                }, SetOptions(merge: true));

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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _isUploading ? null : _pickAndSaveImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: _photoBase64 != null
                        ? MemoryImage(base64Decode(_photoBase64!))
                        : null,
                    child: _photoBase64 == null && !_isUploading
                        ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : "U",
                            style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.blue))
                        : null,
                  ),
                  if (_isUploading)
                    const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 18,
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _pickAndSaveImage, child: const Text('Change Profile Picture')),
            const SizedBox(height: 30),
            ListTile(
              title: const Text('Display Name', style: TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.edit),
              onTap: _updateName,
            ),
            const Divider(),
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
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () async {
                    await _auth.signOut();
                    if (mounted) context.go('/login');
                  },
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
