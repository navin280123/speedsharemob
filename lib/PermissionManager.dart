import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

      // Check current status of each permission to avoid re-requesting permanently denied or granted permissions
      List<Permission> permissionsToRequest = [];
      Map<Permission, PermissionStatus> currentStatuses = {};

      for (var permission in permissions) {
        var status = await permission.status;
        currentStatuses[permission] = status;
        if (!status.isGranted && !status.isLimited && !status.isPermanentlyDenied) {
          permissionsToRequest.add(permission);
        }
      }

      // Request only pending permissions
      if (permissionsToRequest.isNotEmpty) {
        debugPrint('Requesting permissions: $permissionsToRequest');
        Map<Permission, PermissionStatus> requestedStatuses =
            await permissionsToRequest.request();
        currentStatuses.addAll(requestedStatuses);
      }

      // Log current statuses
      currentStatuses.forEach((permission, status) {
        debugPrint('Permission $permission status: $status');
      });

      // Check if we have the minimum required permissions
      bool hasRequiredPermissions = _checkMinimumPermissions(currentStatuses);

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

    if (Platform.isIOS) {
      // On iOS, local network sharing works via Sockets and NSLocalNetworkUsageDescription in Info.plist.
      // Photos picker uses native system picker sheets which do not block core socket file transfers.
      return true;
    }

    if (Platform.isAndroid) {
      bool hasLocationOrNearby =
          statuses[Permission.locationWhenInUse]?.isGranted == true ||
          statuses[Permission.nearbyWifiDevices]?.isGranted == true;

      bool hasFileAccess =
          statuses[Permission.storage]?.isGranted == true ||
          statuses[Permission.photos]?.isGranted == true ||
          statuses[Permission.videos]?.isGranted == true ||
          statuses[Permission.audio]?.isGranted == true;

      return hasLocationOrNearby || hasFileAccess;
    }

    return true;
  }
}