import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _backgroundTracking = false;
  bool _batterySaverMode = false;
  bool _notifications = true;
  int _updateFrequency = 10; // in seconds

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundTracking = prefs.getBool('bg_tracking') ?? false;
      _batterySaverMode = prefs.getBool('battery_saver') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
      _updateFrequency = prefs.getInt('update_freq') ?? 10;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }

    // Special logic for Background Tracking
    if (key == 'bg_tracking') {
      if (value == true) {
        Workmanager().registerPeriodicTask(
          "1",
          "com.example.kita_kita.fetchBackgroundLocation",
          frequency: const Duration(minutes: 15),
        );
      } else {
        Workmanager().cancelByUniqueName("1");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Binago mula sa context.go('/home') papuntang Navigator.pop
            // para gumana ang auto-refresh sa HomeScreen
            Navigator.of(context).pop();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Location Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Update Frequency
          Card(
            child: ListTile(
              title: const Text('Update Frequency'),
              subtitle: Text('Current: $_updateFrequency seconds'),
              trailing: DropdownButton<int>(
                value: _updateFrequency,
                items: [5, 10, 30, 60].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value < 60 ? '$value sec' : '1 min'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _updateFrequency = val);
                    _saveSetting('update_freq', val);
                  }
                },
              ),
            ),
          ),

          // Background Tracking Switch
          Card(
            child: SwitchListTile(
              title: const Text('Background Tracking'),
              subtitle: const Text('Track location even when app is closed'),
              value: _backgroundTracking,
              onChanged: (val) {
                setState(() => _backgroundTracking = val);
                _saveSetting('bg_tracking', val);
              },
            ),
          ),

          const SizedBox(height: 20),
          const Text('System Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Battery Saver Switch
          Card(
            child: SwitchListTile(
              title: const Text('Battery Saver Mode'),
              subtitle: const Text('Reduce update frequency to save power'),
              value: _batterySaverMode,
              onChanged: (val) {
                setState(() => _batterySaverMode = val);
                _saveSetting('battery_saver', val);
              },
            ),
          ),

          // Notifications Switch
          Card(
            child: SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Get alerts for group activity'),
              value: _notifications,
              onChanged: (val) {
                setState(() => _notifications = val);
                _saveSetting('notifications', val);
              },
            ),
          ),

          const SizedBox(height: 40),
          const Center(
            child: Text('App Version 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
