import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize local notification settings for Android, iOS, macOS, Windows, and Linux
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android setup
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS & macOS setup
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Linux setup
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open SpeedShare',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Create Android channel
      if (!kIsWeb && Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          'speedshare_transfers',
          'File Transfers',
          description: 'Notifications for completed file transfers and sync operations',
          importance: Importance.high,
        );

        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(androidChannel);
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  /// Request notification permissions (Android 13+, iOS, macOS)
  Future<bool> requestPermissions() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidImplementation = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await androidImplementation?.requestNotificationsPermission() ??
            false;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final darwinImplementation = _notifications
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        return await darwinImplementation?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Display a completed file transfer notification
  Future<void> showTransferCompletedNotification({
    required String fileName,
    required bool isReceived,
    String? peerName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool showNotifications = prefs.getBool('showNotifications') ?? true;
      if (!showNotifications) return;

      if (!_isInitialized) {
        await initialize();
      }

      final title = isReceived ? 'File Received' : 'File Sent';
      final peer = peerName != null && peerName.isNotEmpty ? peerName : 'device';
      final body = isReceived
          ? '"$fileName" received from $peer'
          : '"$fileName" sent to $peer';

      const androidDetails = AndroidNotificationDetails(
        'speedshare_transfers',
        'File Transfers',
        channelDescription: 'Notifications for completed file transfers',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const linuxDetails = LinuxNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
        linux: linuxDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _notifications.show(id, title, body, details);
    } catch (e) {
      debugPrint('Error showing transfer notification: $e');
    }
  }

  /// Display storage sync download completion notification
  Future<void> showSyncCompletedNotification({
    required String fileName,
    required String sourceDevice,
  }) async {
    await showTransferCompletedNotification(
      fileName: fileName,
      isReceived: true,
      peerName: sourceDevice,
    );
  }
}
