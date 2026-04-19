import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  bool _isRequestingPermissions = false;
  Completer<bool>? _permissionCompleter;

  /// Requests necessary app permissions.
  /// On desktop (Windows/macOS/Linux), permissions are not required
  /// and this returns true immediately.
  Future<bool> requestAppPermissions() async {
    // Desktop platforms don't need runtime permissions
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    // If already requesting permissions, return the same future
    if (_isRequestingPermissions) {
      return _permissionCompleter?.future ?? Future.value(false);
    }

    _isRequestingPermissions = true;
    _permissionCompleter = Completer<bool>();

    try {
      List<Permission> permissions = [];

      if (Platform.isAndroid) {
        // Location permissions needed for Wi-Fi Direct / network discovery
        permissions.add(Permission.locationWhenInUse);

        // Storage permissions - use correct ones based on Android version
        if (await _isAndroid13OrHigher()) {
          // On Android 13+, use granular media permissions
          permissions.addAll([
            Permission.photos,
            Permission.videos,
            Permission.audio,
          ]);
        } else {
          // For older Android versions, use storage permission
          permissions.add(Permission.storage);
        }

        // Android 12+ nearby Wi-Fi devices
        if (await _isAndroid12OrHigher()) {
          permissions.add(Permission.nearbyWifiDevices);
        }
      } else if (Platform.isIOS) {
        permissions.addAll([
          Permission.photos,
          Permission.locationWhenInUse,
        ]);
      }

      if (permissions.isEmpty) {
        _permissionCompleter?.complete(true);
        return true;
      }

      // Request permissions
      debugPrint('Requesting permissions: $permissions');
      Map<Permission, PermissionStatus> statuses = await permissions.request();

      // Log the results
      statuses.forEach((permission, status) {
        debugPrint('Permission $permission status: $status');
      });

      // Check if we have the basic needed permissions
      bool hasRequiredPermissions = _checkMinimumPermissions(statuses);

      _permissionCompleter?.complete(hasRequiredPermissions);
      return hasRequiredPermissions;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _permissionCompleter?.complete(false);
      return false;
    } finally {
      _isRequestingPermissions = false;
    }
  }

  /// Detects if the device is running Android 13 (API 33) or higher.
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 33;
    } catch (e) {
      return false;
    }
  }

  /// Detects if the device is running Android 12 (API 31) or higher.
  Future<bool> _isAndroid12OrHigher() async {
    if (!Platform.isAndroid) return false;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 31;
    } catch (e) {
      return false;
    }
  }

  /// Check if we have the minimum required permissions.
  bool _checkMinimumPermissions(Map<Permission, PermissionStatus> statuses) {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    // For a file sharing app, we need at minimum location and some file access
    bool hasLocationPermission =
        statuses[Permission.locationWhenInUse] == PermissionStatus.granted;

    bool hasFileAccess = false;
    if (Platform.isAndroid) {
      // Check for either storage or media permissions
      hasFileAccess = statuses[Permission.storage] == PermissionStatus.granted ||
          statuses[Permission.photos] == PermissionStatus.granted ||
          statuses[Permission.videos] == PermissionStatus.granted ||
          statuses[Permission.audio] == PermissionStatus.granted;
    } else if (Platform.isIOS) {
      // Photos access is optional on iOS; the app can still function
      hasFileAccess = true;
    }

    return hasLocationPermission && hasFileAccess;
  }
}