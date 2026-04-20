import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vibration/vibration.dart';

class SOSService {
  static final SOSService _instance = SOSService._internal();
  factory SOSService() => _instance;
  SOSService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isAlarming = false;

  bool get isAlarming => _isAlarming;

  Future<void> triggerSOS() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Update Firestore to notify others
    await _firestore.collection('users').doc(user.uid).update({
      'isSOS': true,
      'sosTimestamp': FieldValue.serverTimestamp(),
    });

    // Add to a global SOS collection or group-specific SOS
    // For simplicity, we'll use the user's document flag
  }

  Future<void> stopSOS() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isSOS': false,
    });

    await stopLocalAlarm();
  }

  Future<void> startLocalAlarm() async {
    if (_isAlarming) return;
    _isAlarming = true;

    // Set volume to max for the alarm
    // Note: To truly bypass silent mode, specific native code or plugins like 'volume_control' might be needed
    // but we'll try to play it on the alarm stream if possible.

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // 'alarm.mp3' should be in assets
      await _audioPlayer.play(AssetSource('alarm.mp3'), volume: 1.0);

      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
      print("Error playing alarm: $e");
    }
  }

  Future<void> stopLocalAlarm() async {
    _isAlarming = false;
    await _audioPlayer.stop();
    await Vibration.cancel();
  }
}
