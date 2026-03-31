import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapController _mapController = MapController();
  final Battery _battery = Battery();

  String? _userId;
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
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name') ?? "User_${Random().nextInt(999)}";

    if (_userId == null) {
      _userId = const Uuid().v4();
      await prefs.setString('user_id', _userId!);
      await prefs.setString('user_name', _userName);
    }

    await _syncUserToFirestore();
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
    _battery.batteryLevel.then((level) => setState(() => _batteryLevel = level));
    _batteryStream = _battery.onBatteryStateChanged.listen((_) async {
      final level = await _battery.batteryLevel;
      setState(() => _batteryLevel = level);
      _syncUserToFirestore();
    });
  }

  Future<void> _initLocation() async {
    final prefs = await SharedPreferences.getInstance();
    int freq = prefs.getInt('update_freq') ?? 10;
    bool isBatterySaver = prefs.getBool('battery_saver') ?? false;
    int distFilter = isBatterySaver ? 30 : 10;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    await _positionStream?.cancel();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: isBatterySaver ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: distFilter,
        timeLimit: Duration(seconds: freq * 2),
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
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              final users = snapshot.data?.docs ?? [];

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _currentPosition, initialZoom: 15.0),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // Idagdag ito para hindi na ma-block ng OpenStreetMap
                    userAgentPackageName: 'com.example.kita_kita',
                  ),
                  MarkerLayer(
                    markers: users.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final isMe = data['id'] == _userId;
                      final pos = LatLng(data['lat'] ?? 0, data['lng'] ?? 0);

                      return Marker(
                        point: pos,
                        width: 80, height: 80,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isMe ? Colors.blue : Colors.red, width: 1),
                              ),
                              child: Text("${data['name']} (${data['battery']}%)", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            Icon(Icons.location_on, color: isMe ? Colors.blue : Colors.red, size: 35),
                          ],
                        ),
                      );
                    }).toList(),
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
