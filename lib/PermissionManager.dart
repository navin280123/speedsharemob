import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();
  
  bool _isRequestingPermissions = false;
  Completer<bool>? _permissionCompleter;
  
  // Simplified version focusing on permissions that exist in manifest
  Future<bool> requestAppPermissions() async {
    // If already requesting permissions, return the same future
    if (_isRequestingPermissions) {
      return _permissionCompleter?.future ?? Future.value(false);
    }
    
    _isRequestingPermissions = true;
    _permissionCompleter = Completer<bool>();
    
    try {
      List<Permission> permissions = [];
      
      // Core permissions for file sharing app
      if (Platform.isAndroid) {
        // Location permissions needed for Wi-Fi Direct
        permissions.add(Permission.locationWhenInUse);
        
        // Storage permissions - use the correct ones based on Android version
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
      } else if (Platform.isIOS) {
        permissions.addAll([
          Permission.photos,
          Permission.locationWhenInUse,
        ]);
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
  
  // Helper to check Android version
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;
    
    // This is a very simplified check - in a real app you should use
    // a proper method to detect Android version
    try {
      // Check if we have the Android 13 specific permissions
      return await Permission.photos.status != PermissionStatus.permanentlyDenied &&
             await Permission.videos.status != PermissionStatus.permanentlyDenied &&
             await Permission.audio.status != PermissionStatus.permanentlyDenied;
    } catch (e) {
      return false;
    }
  }
  
  // Check if we have the minimum required permissions
  bool _checkMinimumPermissions(Map<Permission, PermissionStatus> statuses) {
    // For a file sharing app, we need at minimum location and some file access
    bool hasLocationPermission = statuses[Permission.locationWhenInUse] == PermissionStatus.granted;
    
    bool hasFileAccess = false;
    if (Platform.isAndroid) {
      // Check for either storage or media permissions
      hasFileAccess = statuses[Permission.storage] == PermissionStatus.granted ||
                     statuses[Permission.photos] == PermissionStatus.granted ||
                     statuses[Permission.videos] == PermissionStatus.granted ||
                     statuses[Permission.audio] == PermissionStatus.granted;
    } else if (Platform.isIOS) {
      hasFileAccess = statuses[Permission.photos] == PermissionStatus.granted;
    }
    
    return hasLocationPermission && hasFileAccess;
  }
}