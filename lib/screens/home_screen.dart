import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart'; // Import ito para sa Navigator

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MapController _mapController = MapController();
  final Battery _battery = Battery();

  String? _userId;
  String? _selectedGroupId;
  String _userName = "User";
  LatLng _currentPosition = const LatLng(14.5995, 120.9842);
  int _batteryLevel = 100;
  bool _isLoading = true;

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<BatteryState>? _batteryStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupUserAndData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initLocation();
    }
  }

  Future<void> _setupUserAndData() async {
    await _initUser();
    await _initLocation();
    _initBattery();
  }

  Future<void> _initUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      _userName = user.displayName ?? user.email?.split('@')[0] ?? "User";
      await _syncUserToFirestore();
    } else {
      if (mounted) context.go('/login');
    }
  }

  Future<void> _syncUserToFirestore() async {
    if (_userId == null) return;
    await _firestore.collection('users').doc(_userId).set({
      'id': _userId,
      'name': _userName,
      'lat': _currentPosition.latitude,
      'lng': _currentPosition.longitude,
      'battery': _batteryLevel,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _initBattery() {
    _battery.batteryLevel.then((level) {
      if (mounted) setState(() => _batteryLevel = level);
    });
    _batteryStream = _battery.onBatteryStateChanged.listen((_) async {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() => _batteryLevel = level);
        _syncUserToFirestore();
      }
    });
  }

  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();

    // Kunin ang settings mula sa SharedPreferences
    bool isBatterySaver = prefs.getBool('battery_saver') ?? false;
    int updateFreq = prefs.getInt('update_freq') ?? 10;

    // Mas malaking distance filter kung naka Battery Saver (30 meters vs 10 meters)
    int distFilter = isBatterySaver ? 30 : 10;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return;

    await _positionStream?.cancel();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: isBatterySaver ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: distFilter,
        timeLimit: Duration(seconds: updateFreq * 2),
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _isLoading = false;
      });
      _syncUserToFirestore();
      _mapController.move(_currentPosition, 15);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _batteryStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kita Kita Live'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
              if (mounted) context.go('/login');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // INALIS ANG CONST DITO
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _initLocation();
            },
          ),
        ],
      ),
      body: _isLoading || _userId == null
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('groups').where('members', arrayContains: _userId).snapshots(),
            builder: (context, groupsSnapshot) {
              if (groupsSnapshot.hasError) return Center(child: Text('Error: ${groupsSnapshot.error}'));

              final groups = groupsSnapshot.data?.docs ?? [];
              Set<String> visibleMemberIds = {_userId!};

              if (_selectedGroupId == null) {
                if (groupsSnapshot.hasData) {
                  for (var doc in groups) {
                    final data = doc.data() as Map<String, dynamic>;
                    final members = List<String>.from(data['members'] ?? []);
                    visibleMemberIds.addAll(members);
                  }
                }
              } else {
                try {
                  final selectedDoc = groups.firstWhere((doc) => doc.id == _selectedGroupId);
                  final data = selectedDoc.data() as Map<String, dynamic>;
                  final members = List<String>.from(data['members'] ?? []);
                  visibleMemberIds.addAll(members);
                } catch (e) {}
              }

              return Column(
                children: [
                  if (groups.isNotEmpty)
                    Container(
                      height: 50,
                      width: double.infinity,
                      color: Colors.white,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        children: [
                          ChoiceChip(
                            label: const Text("All Groups"),
                            selected: _selectedGroupId == null,
                            onSelected: (selected) {
                              setState(() => _selectedGroupId = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ...groups.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(data['name'] ?? 'Group'),
                                selected: _selectedGroupId == doc.id,
                                onSelected: (selected) {
                                  setState(() => _selectedGroupId = selected ? doc.id : null);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('users').snapshots(),
                      builder: (context, usersSnapshot) {
                        if (usersSnapshot.hasError) return Center(child: Text('Error: ${usersSnapshot.error}'));

                        final allUsers = usersSnapshot.data?.docs ?? [];
                        final visibleUsers = allUsers.where((doc) => visibleMemberIds.contains(doc.id)).toList();

                        return FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentPosition,
                            initialZoom: 15.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.kita_kita',
                            ),
                            MarkerLayer(
                              markers: visibleUsers.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final id = data['id'] as String?;
                                if (id == null) return const Marker(point: LatLng(0,0), child: SizedBox());

                                final isMe = id == _userId;
                                final pos = LatLng(data['lat'] ?? 0, data['lng'] ?? 0);
                                final String? photoBase64 = data['photoBase64'];
                                final name = data['name'] ?? 'User';

                                return Marker(
                                  point: pos,
                                  width: 80,
                                  height: 80,
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: isMe ? Colors.blue : Colors.red, width: 1),
                                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                        ),
                                        child: Text(
                                          "$name (${data['battery'] ?? '?' }%)",
                                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(Icons.location_on, color: isMe ? Colors.blue : Colors.red, size: 50),
                                          Positioned(
                                            top: 5,
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                                image: photoBase64 != null
                                                  ? DecorationImage(
                                                      image: MemoryImage(base64Decode(photoBase64)),
                                                      fit: BoxFit.cover
                                                    )
                                                  : null,
                                                color: Colors.blue.shade100,
                                              ),
                                              child: photoBase64 == null
                                                ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?",
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))
                                                : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) context.go('/groups');
          if (i == 2) context.go('/profile');
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
