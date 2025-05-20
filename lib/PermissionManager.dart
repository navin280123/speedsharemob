import 'dart:async';
import 'dart:io';
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
      List<Permission> permissions = [];
      
      // Android-specific permissions
      if (Platform.isAndroid) {
        // For Android 10 and below, use storage permission
        permissions.add(Permission.storage);
        
        // Common Android permissions
        permissions.addAll([
          Permission.location,
        ]);
        
        // Add MANAGE_EXTERNAL_STORAGE for Android 11+
        if (await Permission.manageExternalStorage.status != PermissionStatus.granted) {
          permissions.add(Permission.manageExternalStorage);
        }
        
        // For Android 12+, add NEARBY_WIFI_DEVICES
        if (await Permission.nearbyWifiDevices.status != PermissionStatus.permanentlyDenied) {
          permissions.add(Permission.nearbyWifiDevices);
        }
      }
      
      // iOS-specific permissions
      if (Platform.isIOS) {
        permissions.addAll([
          Permission.photos,
          Permission.mediaLibrary,
        ]);
      }
      
      // Request all permissions at once
      Map<Permission, PermissionStatus> statuses = await permissions.request();
      debugPrint('Permission statuses: $statuses');
      
      // For Android 11+, we need to check MANAGE_EXTERNAL_STORAGE separately
      if (Platform.isAndroid && 
          await Permission.manageExternalStorage.status != PermissionStatus.granted) {
        // On Android 11+, MANAGE_EXTERNAL_STORAGE requires app settings
        if (statuses[Permission.storage] == PermissionStatus.granted) {
          // Regular storage is enough for basic functionality
          _permissionCompleter?.complete(true);
          return true;
        } else {
          // Try to get full access
          await openAppSettings();
        }
      }
      
      // Check for critical permissions
      bool hasStorageAccess = Platform.isAndroid 
          ? statuses[Permission.storage] == PermissionStatus.granted
          : true; // iOS doesn't need explicit storage permission
      
      _permissionCompleter?.complete(hasStorageAccess);
      return hasStorageAccess;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _permissionCompleter?.complete(false);
      return false;
    } finally {
      _isRequestingPermissions = false;
    }
  }
}