import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  bool _isRequestingPermissions = false;
  Completer<bool>? _permissionCompleter;

  /// Shows Google Play compliant prominent rationale dialog before requesting permissions
  Future<bool> showPermissionRationaleDialog(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    // Check if rationale is needed
    bool hasPermissions = await checkPermissionsGranted();
    if (hasPermissions) return true;

    if (!context.mounted) return false;

    bool? granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF4E6AF3)),
              SizedBox(width: 10),
              Text('Permissions Needed'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To share files over local Wi-Fi and save incoming downloads, SpeedShare requires the following permissions:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildRationaleTile(
                  icon: Icons.wifi_find_rounded,
                  title: 'Nearby Devices & Location',
                  description:
                      'Used exclusively to discover and connect with nearby devices on your local Wi-Fi network.',
                ),
                const SizedBox(height: 12),
                _buildRationaleTile(
                  icon: Icons.folder_open_rounded,
                  title: 'Storage & Media Access',
                  description:
                      'Used to select files to send and save received files directly to your Downloads folder.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E6AF3).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '🔒 Privacy First: Your location and files remain 100% private and are never uploaded to any cloud server.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF4E6AF3)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6AF3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (granted == true) {
      return await requestAppPermissions();
    }
    return false;
  }

  static Widget _buildRationaleTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4E6AF3).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF4E6AF3), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Checks whether minimum permissions are already granted
  Future<bool> checkPermissionsGranted() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    if (Platform.isIOS) return true;

    try {
      if (Platform.isAndroid) {
        var locationStatus = await Permission.locationWhenInUse.status;
        var nearbyStatus = await Permission.nearbyWifiDevices.status;
        var storageStatus = await Permission.storage.status;
        var photosStatus = await Permission.photos.status;

        bool hasLocation = locationStatus.isGranted || nearbyStatus.isGranted;
        bool hasStorage = storageStatus.isGranted || photosStatus.isGranted;
        return hasLocation && hasStorage;
      }
    } catch (_) {}
    return false;
  }

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