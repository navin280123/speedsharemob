import 'dart:io';
import 'package:flutter/foundation.dart';

class SocketHelper {
  static Future<RawDatagramSocket?> createDiscoverySocket(int port) async {
    try {
      // For Android 10+, we need to request permissions before using sockets
      if (Platform.isAndroid) {
        return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, 
            reusePort: true, reuseAddress: true);
      } else {
        return await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      }
    } catch (e) {
      debugPrint('Error creating UDP socket: $e');
      return null;
    }
  }
  
  static Future<ServerSocket?> createServerSocket(int port) async {
    try {
      return await ServerSocket.bind(InternetAddress.anyIPv4, port, 
          shared: true);
    } catch (e) {
      debugPrint('Error creating server socket: $e');
      return null;
    }
  }
}