import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speedsharemob/PermissionManager.dart';

class SyncScreen extends StatefulWidget {
  @override
  _SyncScreenState createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> with TickerProviderStateMixin {
  // Storage Server
  HttpServer? _storageServer;
  RawDatagramSocket? _syncDiscoverySocket;
  String? _accessCode;
  bool _isStorageSharing = false;
  List<String> _sharedPaths = [];
  
  // Storage Browser
  List<SyncDevice> _availableDevices = [];
  bool _isDiscovering = false;
  Timer? _discoveryTimer;
  
  // UI State
  SyncDevice? _selectedDevice;
  List<RemoteFileInfo> _remoteFiles = [];
  bool _isBrowsingFiles = false;
  String _currentRemotePath = '/';
  List<DownloadTask> _downloadQueue = [];
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSync();
    _loadSettings();
    _startDiscovery();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeSync() async {
    try {
      // Request permissions first
      bool hasPermissions = await PermissionManager().requestAppPermissions();
      if (!hasPermissions) {
        _showErrorSnackBar('Storage permissions required for sync feature');
        return;
      }

      // Initialize sync discovery socket
      _syncDiscoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8083,
        reuseAddress: true,
      );
      _syncDiscoverySocket!.broadcastEnabled = true;
      
      _syncDiscoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _syncDiscoverySocket!.receive();
          if (datagram != null) {
            _handleSyncDiscovery(datagram);
          }
        }
      });
    } catch (e) {
      print('Error initializing sync: $e');
    }
  }

  void _handleSyncDiscovery(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final data = json.decode(message) as Map<String, dynamic>;
      
      if (data['type'] == 'SPEEDSHARE_SYNC_ANNOUNCE') {
        final device = SyncDevice(
          name: data['deviceName'],
          ip: datagram.address.address,
          port: data['storagePort'],
          accessCode: data['accessCode'],
          capabilities: List<String>.from(data['capabilities']),
          lastSeen: DateTime.now(),
        );
        
        setState(() {
          _availableDevices.removeWhere((d) => d.ip == device.ip);
          _availableDevices.add(device);
        });
      }
    } catch (e) {
      print('Error handling sync discovery: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPaths = prefs.getStringList('sync_shared_paths') ?? [];
      
      // For mobile, add default shared directories
      if (savedPaths.isEmpty) {
        final List<String> defaultPaths = [];
        
        try {
          // Add platform-appropriate default directories
          if (Platform.isAndroid) {
            defaultPaths.add('/storage/emulated/0/Download');
            defaultPaths.add('/storage/emulated/0/DCIM/Camera');
            defaultPaths.add('/storage/emulated/0/Pictures');
          } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
            // Use system Downloads directory for desktop
            final downloadsDir = await getDownloadsDirectory();
            if (downloadsDir != null) {
              defaultPaths.add(downloadsDir.path);
            } else {
              final documentsDir = await getApplicationDocumentsDirectory();
              defaultPaths.add(documentsDir.path);
            }
          } else {
            // iOS — app documents directory (sandboxed)
            final documentsDir = await getApplicationDocumentsDirectory();
            defaultPaths.add(documentsDir.path);
          }
        } catch (e) {
          print('Error getting default directories: $e');
        }
        
        setState(() {
          _sharedPaths = defaultPaths;
        });
      } else {
        setState(() {
          _sharedPaths = savedPaths;
        });
      }
    } catch (e) {
      print('Error loading sync settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sync_shared_paths', _sharedPaths);
    } catch (e) {
      print('Error saving sync settings: $e');
    }
  }

  void _startDiscovery() {
    _discoveryTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _sendSyncAnnouncement();
      _cleanupStaleDevices();
    });
    _sendSyncAnnouncement();
  }

  void _sendSyncAnnouncement() {
    if (_syncDiscoverySocket == null || !_isStorageSharing) return;
    
    try {
      final announcement = json.encode({
        'type': 'SPEEDSHARE_SYNC_ANNOUNCE',
        'deviceName': Platform.localHostname,
        'storagePort': 8082,
        'accessCode': _accessCode,
        'capabilities': ['storage_share', 'storage_browse'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      final data = utf8.encode(announcement);
      _syncDiscoverySocket!.send(data, InternetAddress('255.255.255.255'), 8083);
    } catch (e) {
      print('Error sending sync announcement: $e');
    }
  }

  void _cleanupStaleDevices() {
    final now = DateTime.now();
    setState(() {
      _availableDevices.removeWhere((device) =>
          now.difference(device.lastSeen).inMinutes > 5);
    });
  }

  Future<void> _startStorageSharing() async {
    // Check permissions first
    bool hasPermissions = await _checkStoragePermissions();
    if (!hasPermissions) {
      _showErrorSnackBar('Storage permissions required to share files');
      return;
    }

    if (_sharedPaths.isEmpty) {
      _showErrorSnackBar('Please select at least one directory to share');
      return;
    }

    try {
      _accessCode = _generateAccessCode();
      
      _storageServer = await HttpServer.bind(InternetAddress.anyIPv4, 8082);
      _storageServer!.listen(_handleStorageRequest);
      
      setState(() {
        _isStorageSharing = true;
      });
      
      _pulseController.repeat(reverse: true);
      _sendSyncAnnouncement();
      
      _showSuccessSnackBar('Storage sharing started with code: $_accessCode');
    } catch (e) {
      _showErrorSnackBar('Failed to start storage sharing: $e');
    }
  }

  Future<bool> _checkStoragePermissions() async {
    // Desktop platforms (Windows, macOS, Linux) do not need runtime storage permissions
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isAndroid) {
      final permissions = [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ];

      // Request Android 11+ permissions if available
      if (await Permission.manageExternalStorage.status == PermissionStatus.denied) {
        permissions.add(Permission.manageExternalStorage);
      }

      final results = await permissions.request();
      return results.values.any((status) => status == PermissionStatus.granted);
    } else if (Platform.isIOS) {
      final results = await [
        Permission.photos,
        Permission.mediaLibrary,
      ].request();
      return results.values.any((status) => status == PermissionStatus.granted);
    }

    return true;
  }

  Future<void> _stopStorageSharing() async {
    try {
      await _storageServer?.close();
      _storageServer = null;
      _accessCode = null;
      
      setState(() {
        _isStorageSharing = false;
      });
      
      _pulseController.stop();
      _showSuccessSnackBar('Storage sharing stopped');
    } catch (e) {
      _showErrorSnackBar('Failed to stop storage sharing: $e');
    }
  }

  void _handleStorageRequest(HttpRequest request) async {
    try {
      final uri = request.uri;
      final accessCode = uri.queryParameters['code'];
      
      if (accessCode != _accessCode) {
        request.response.statusCode = 403;
        request.response.write('Invalid access code');
        await request.response.close();
        return;
      }

      if (uri.path.startsWith('/api/files')) {
        await _handleFileListRequest(request);
      } else if (uri.path.startsWith('/api/download')) {
        await _handleFileDownloadRequest(request);
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      print('Error handling storage request: $e');
      request.response.statusCode = 500;
      await request.response.close();
    }
  }

  Future<void> _handleFileListRequest(HttpRequest request) async {
    final _ = request.uri.queryParameters['path'] ?? '/'; // reserved for sub-directory browsing
    final files = <Map<String, dynamic>>[];
    
    try {
      for (final sharedPath in _sharedPaths) {
        final directory = Directory(sharedPath);
        
        if (await directory.exists()) {
          await for (final entity in directory.list()) {
            try {
              final stat = await entity.stat();
              files.add({
                'name': p.basename(entity.path),
                'path': entity.path,
                'isDirectory': entity is Directory,
                'size': entity is File ? stat.size : 0,
                'modified': stat.modified.toIso8601String(),
                'type': entity is File ? lookupMimeType(entity.path) ?? 'application/octet-stream' : 'directory',
              });
            } catch (e) {
              // Skip files that can't be accessed
              continue;
            }
          }
        }
      }
      
      request.response.headers.contentType = ContentType.json;
      request.response.write(json.encode(files));
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Error listing files: $e');
    }
    
    await request.response.close();
  }

  Future<void> _handleFileDownloadRequest(HttpRequest request) async {
    final filePath = request.uri.queryParameters['file'];
    
    if (filePath == null || !_isPathAllowed(filePath)) {
      request.response.statusCode = 403;
      request.response.write('Access denied');
      await request.response.close();
      return;
    }
    
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileSize = await file.length();
        request.response.headers.contentType = ContentType.binary;
        request.response.headers.add('Content-Length', fileSize.toString());
        request.response.headers.add('Content-Disposition', 'attachment; filename="${p.basename(filePath)}"');
        
        await file.openRead().pipe(request.response);
      } else {
        request.response.statusCode = 404;
        request.response.write('File not found');
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Error downloading file: $e');
      await request.response.close();
    }
  }

  bool _isPathAllowed(String filePath) {
    return _sharedPaths.any((sharedPath) => filePath.startsWith(sharedPath));
  }

  String _generateAccessCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(6, (index) => chars[(random + index) % chars.length]).join();
  }

  Future<void> _browseDevice(SyncDevice device) async {
    setState(() {
      _selectedDevice = device;
      _isBrowsingFiles = true;
      _currentRemotePath = '/';
    });
    
    await _loadRemoteFiles('/');
  }

  Future<void> _loadRemoteFiles(String path) async {
    if (_selectedDevice == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('http://${_selectedDevice!.ip}:${_selectedDevice!.port}/api/files?path=$path&code=${_selectedDevice!.accessCode}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _remoteFiles = data.map((item) => RemoteFileInfo.fromJson(item)).toList();
          _currentRemotePath = path;
        });
      } else {
        _showErrorSnackBar('Failed to load files: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error loading files: $e');
    }
  }

  Future<void> _downloadFile(RemoteFileInfo file) async {
    if (_selectedDevice == null) return;
    
    try {
      // Get Downloads directory for the active platform
      Directory downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download/speedshare');
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final downloadsDir = await getDownloadsDirectory();
        final base = downloadsDir ?? await getApplicationDocumentsDirectory();
        downloadDir = Directory('${base.path}/speedshare');
      } else {
        // iOS
        final appDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${appDir.path}/speedshare');
      }
      
      // Create directory if it doesn't exist
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      
      final savePath = p.join(downloadDir.path, file.name);
      
      final downloadTask = DownloadTask(
        file: file,
        savePath: savePath,
        progress: 0.0,
        status: 'Starting',
      );
      
      setState(() {
        _downloadQueue.add(downloadTask);
      });
      
      final response = await http.get(
        Uri.parse('http://${_selectedDevice!.ip}:${_selectedDevice!.port}/api/download?file=${file.path}&code=${_selectedDevice!.accessCode}'),
      );
      
      if (response.statusCode == 200) {
        await File(savePath).writeAsBytes(response.bodyBytes);
        
        setState(() {
          downloadTask.progress = 1.0;
          downloadTask.status = 'Completed';
        });
        
        _showSuccessSnackBar('Downloaded: ${file.name}');
      } else {
        setState(() {
          downloadTask.status = 'Failed';
        });
        _showErrorSnackBar('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error downloading file: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Color(0xFF2AB673),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _discoveryTimer?.cancel();
    _storageServer?.close();
    _syncDiscoverySocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBrowsingFiles && _selectedDevice != null) {
      return _buildFileBrowser();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Share Storage Card
              _buildShareStorageCard(),
              
              const SizedBox(height: 16),
              
              // Access Storage Card
              Expanded(child: _buildAccessStorageCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareStorageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ScaleTransition(
                  scale: _isStorageSharing ? _pulseAnimation : 
                         AlwaysStoppedAnimation(1.0),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isStorageSharing 
                          ? const Color(0xFF2AB673).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.smartphone_rounded,
                      color: _isStorageSharing 
                          ? const Color(0xFF2AB673)
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share This Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isStorageSharing 
                            ? 'Others can access your files'
                            : 'Allow others to browse your files',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isStorageSharing 
                        ? const Color(0xFF2AB673)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isStorageSharing ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            if (_isStorageSharing) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E6AF3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security,
                      color: Color(0xFF4E6AF3),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Access Code: ',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      _accessCode ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E6AF3),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _accessCode ?? ''));
                        _showSuccessSnackBar('Access code copied');
                      },
                      child: const Icon(
                        Icons.copy,
                        color: Color(0xFF4E6AF3),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isStorageSharing ? _stopStorageSharing : _startStorageSharing,
                    icon: Icon(_isStorageSharing ? Icons.stop : Icons.play_arrow),
                    label: Text(_isStorageSharing ? 'Stop Sharing' : 'Start Sharing'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _isStorageSharing 
                          ? Colors.red 
                          : const Color(0xFF2AB673),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (!_isStorageSharing) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showSharedPathsDialog(),
                    icon: const Icon(Icons.settings),
                    tooltip: 'Configure shared folders',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
    Widget _buildAccessStorageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E6AF3).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.devices_rounded,
                    color: Color(0xFF4E6AF3),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Browse Other Devices',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Access files from other devices',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isDiscovering)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Device list
            Expanded(
              child: _availableDevices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/searchss.json',
                            height: 100,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.search_off,
                                size: 60,
                                color: Colors.grey[300],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No devices found',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Make sure other devices are sharing storage',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isDiscovering = true;
                              });
                              _sendSyncAnnouncement();
                              Timer(Duration(seconds: 3), () {
                                if (mounted) {
                                  setState(() {
                                    _isDiscovering = false;
                                  });
                                }
                              });
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Scan Again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4E6AF3),
                              side: const BorderSide(color: Color(0xFF4E6AF3)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = _availableDevices[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2AB673).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                device.name.toLowerCase().contains('mobile') || 
                                device.name.toLowerCase().contains('phone')
                                    ? Icons.phone_android
                                    : Icons.computer,
                                color: const Color(0xFF2AB673),
                                size: 24,
                              ),
                            ),
                            title: Text(
                              device.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'IP: ${device.ip}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  'Last seen: ${_getTimeAgo(device.lastSeen)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => _browseDevice(device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4E6AF3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Browse',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Download queue
            if (_downloadQueue.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Downloads',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: _downloadQueue.length,
                  itemBuilder: (context, index) {
                    final task = _downloadQueue[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getFileIcon(task.file.type),
                        color: _getFileIconColor(task.file.type),
                        size: 20,
                      ),
                      title: Text(
                        task.file.name,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.status,
                            style: const TextStyle(fontSize: 10),
                          ),
                          if (task.progress > 0 && task.progress < 1)
                            LinearProgressIndicator(
                              value: task.progress,
                              minHeight: 2,
                            ),
                        ],
                      ),
                      trailing: task.status == 'Completed'
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2AB673),
                              size: 16,
                            )
                          : task.status == 'Failed'
                              ? const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 16,
                                )
                              : const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileBrowser() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedDevice?.name ?? 'Device'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isBrowsingFiles = false;
              _selectedDevice = null;
              _remoteFiles.clear();
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadRemoteFiles(_currentRemotePath),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Path indicator
            if (_currentRemotePath != '/')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]
                    : Colors.grey[100],
                child: Text(
                  _currentRemotePath,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            
            // File list
            Expanded(
              child: _remoteFiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No files found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _remoteFiles.length,
                      itemBuilder: (context, index) {
                        final file = _remoteFiles[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: file.isDirectory
                                    ? const Color(0xFF4E6AF3).withOpacity(0.1)
                                    : _getFileIconColor(file.type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                file.isDirectory 
                                    ? Icons.folder 
                                    : _getFileIcon(file.type),
                                color: file.isDirectory 
                                    ? const Color(0xFF4E6AF3) 
                                    : _getFileIconColor(file.type),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              file.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: file.isDirectory
                                ? const Text(
                                    'Folder',
                                    style: TextStyle(fontSize: 12),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatFileSize(file.size),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        _formatDate(file.modified),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                            trailing: file.isDirectory
                                ? const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF4E6AF3),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.download,
                                      color: Color(0xFF2AB673),
                                    ),
                                    onPressed: () => _downloadFile(file),
                                  ),
                            onTap: file.isDirectory
                                ? () => _loadRemoteFiles(file.path)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSharedPathsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shared Folders'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              const Text(
                'Select folders to share with other devices:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _sharedPaths.length,
                  itemBuilder: (context, index) {
                    final path = _sharedPaths[index];
                    return ListTile(
                      leading: const Icon(Icons.folder, size: 20),
                      title: Text(
                        p.basename(path),
                        style: const TextStyle(fontSize: 12),
                      ),
                      subtitle: Text(
                        path,
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, size: 18),
                        onPressed: () {
                          setState(() {
                            _sharedPaths.removeAt(index);
                          });
                          Navigator.of(context).pop();
                          _showSharedPathsDialog();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result = await FilePicker.platform.getDirectoryPath();
              if (result != null && !_sharedPaths.contains(result)) {
                setState(() {
                  _sharedPaths.add(result);
                });
                await _saveSettings();
              }
            },
            child: const Text('Add Folder'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    if (type.startsWith('image/')) return Icons.image;
    if (type.startsWith('video/')) return Icons.video_file;
    if (type.startsWith('audio/')) return Icons.audio_file;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('document') || type.contains('word')) return Icons.description;
    if (type.contains('spreadsheet') || type.contains('excel')) return Icons.table_chart;
    if (type.contains('presentation')) return Icons.slideshow;
    if (type.contains('zip') || type.contains('compressed')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String type) {
    if (type.startsWith('image/')) return Colors.blue;
    if (type.startsWith('video/')) return Colors.red;
    if (type.startsWith('audio/')) return Colors.purple;
    if (type.contains('pdf')) return Colors.red;
    if (type.contains('document') || type.contains('word')) return Colors.blue;
    if (type.contains('spreadsheet') || type.contains('excel')) return const Color(0xFF2AB673);
    if (type.contains('presentation')) return Colors.orange;
    if (type.contains('zip') || type.contains('compressed')) return Colors.amber;
    return Colors.grey;
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

// Data models for mobile sync
class SyncDevice {
  final String name;
  final String ip;
  final int port;
  final String accessCode;
  final List<String> capabilities;
  final DateTime lastSeen;

  SyncDevice({
    required this.name,
    required this.ip,
    required this.port,
    required this.accessCode,
    required this.capabilities,
    required this.lastSeen,
  });
}

class RemoteFileInfo {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final String type;

  RemoteFileInfo({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.type,
  });

  factory RemoteFileInfo.fromJson(Map<String, dynamic> json) {
    return RemoteFileInfo(
      name: json['name'],
      path: json['path'],
      isDirectory: json['isDirectory'],
      size: json['size'],
      modified: DateTime.parse(json['modified']),
      type: json['type'],
    );
  }
}

class DownloadTask {
  final RemoteFileInfo file;
  final String savePath;
  double progress;
  String status;

  DownloadTask({
    required this.file,
    required this.savePath,
    required this.progress,
    required this.status,
  });
}
  