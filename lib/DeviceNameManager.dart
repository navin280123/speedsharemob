import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceNameManager {
  static const List<String> _adjectives = [
    'Swift', 'Speedy', 'Cosmic', 'Nova', 'Thunder',
    'Cyber', 'Turbo', 'Neon', 'Quantum', 'Hyper',
    'Solar', 'Apex', 'Starlight', 'Vanguard', 'Phantom',
    'Aero', 'Zenith', 'Pulse', 'Orbit', 'Glider',
    'Titan', 'Sonic', 'Flash', 'Vortex', 'Blaze'
  ];

  static const List<String> _nouns = [
    'Phoenix', 'Falcon', 'Panther', 'Hawk', 'Lynx',
    'Viper', 'Eagle', 'Cheetah', 'Raptor', 'Jaguar',
    'Tiger', 'Voyager', 'Comet', 'Spark', 'Jet',
    'Storm', 'Beacon', 'Nexus', 'Courier', 'Rider',
    'Drifter', 'Ranger', 'Striker', 'Shadow', 'Pioneer'
  ];

  /// Generates a random friendly device name like "Swift Falcon 42"
  static String generateRandomName() {
    final random = Random();
    final adj = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final num = random.nextInt(90) + 10; // 10..99
    return '$adj $noun $num';
  }

  /// Returns true if the given name is generic or invalid ("local", "localhost", "android", etc.)
  static bool isGenericName(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final lower = name.trim().toLowerCase();
    return lower == 'local' ||
        lower == 'localhost' ||
        lower == 'android' ||
        lower == 'localhost.localdomain' ||
        lower == 'unknown device' ||
        lower == 'unknown' ||
        lower == 'null';
  }

  /// Gets the stored device name or generates and persists a new random name
  static Future<String> getDeviceName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? saved = prefs.getString('deviceName');
      
      if (saved == null || isGenericName(saved)) {
        // Try getting system localHostname first if non-generic
        try {
          final hostname = Platform.localHostname;
          if (!isGenericName(hostname)) {
            saved = hostname;
          }
        } catch (_) {}
      }

      // If still generic or null, generate random name
      if (saved == null || isGenericName(saved)) {
        saved = generateRandomName();
      }

      await prefs.setString('deviceName', saved);
      return saved;
    } catch (e) {
      debugPrint('Error getting device name: $e');
      return generateRandomName();
    }
  }

  /// Saves a custom device name
  static Future<void> setDeviceName(String newName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('deviceName', newName.trim());
    } catch (e) {
      debugPrint('Error saving device name: $e');
    }
  }
}
