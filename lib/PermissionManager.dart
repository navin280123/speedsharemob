import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();
  
  bool _isRequestingPermissions = false;
  Completer<bool>? _permissionCompleter;
  
  Future<bool> requestAppPermissions() async {
    // If already requesting permissions, return the same future
    if (_isRequestingPermissions) {
      return _permissionCompleter?.future ?? Future.value(false);
    }
    
    _isRequestingPermissions = true;
    _permissionCompleter = Completer<bool>();
    
    try {
      // Request all needed permissions at once
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.location,
        Permission.manageExternalStorage, // For Android 11+
        Permission.nearbyWifiDevices,     // For Android 12+
        Permission.mediaLibrary,          // For iOS
        Permission.photos,                // For iOS
      ].request();
      
      // Log all permissions for debugging
      debugPrint('Permission statuses: $statuses');
      
      // Check if all critical permissions are granted
      bool allGranted = statuses.values.every((status) => 
          status.isGranted || status.isLimited || status.isDenied == false);
      
      _permissionCompleter?.complete(allGranted);
      return allGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _permissionCompleter?.complete(false);
      return false;
    } finally {
      _isRequestingPermissions = false;
    }
  }
}