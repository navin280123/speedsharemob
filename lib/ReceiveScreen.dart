import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speedsharemob/PermissionManager.dart';

class ReceiveScreen extends StatefulWidget {
  @override
  _ReceiveScreenState createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with SingleTickerProviderStateMixin {
  ServerSocket? serverSocket;
  RawDatagramSocket? _discoverySocket;
  String receivedFileName = '';
  double progress = 0.0;
  String ipAddress = '';
  String computerName = '';
  int fileSize = 0;
  int bytesReceived = 0;
  File? receivedFile;
  bool isReceiving = false;
  List<Map<String, dynamic>> receivedFiles = [];
  String downloadDirectoryPath = '';
  bool isLoadingIp = true;
  bool isReceivingAnimation = false;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Fixed date/time and user login
  final String currentDateTime = "2025-05-20 17:13:21";
  final String userLogin = "navin280123";

  @override
  void initState() {
    super.initState();
    _getIpAddress();
    _getComputerName();
    _getDownloadsDirectory();
    _checkPermissionsAndStart();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);
  }
  Future<void> _checkPermissionsAndStart() async {
  bool hasPermissions = await PermissionManager().requestAppPermissions();
  
  if (hasPermissions) {
    // In FileSenderScreen
    // startScanning();
    
    // OR in ReceiveScreen
    startReceiving();
  } else {
    // Show a message that permissions are required
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Required permissions not granted. Some features may not work.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
  void _getDownloadsDirectory() async {
    try {
      Directory? downloadsDirectory = await getDownloadsDirectory();
      String speedsharePath = '${downloadsDirectory!.path}/speedshare';
      Directory speedshareDirectory = Directory(speedsharePath);
      if (!await speedshareDirectory.exists()) {
        await speedshareDirectory.create(recursive: true);
      }
      setState(() {
        downloadDirectoryPath = speedsharePath;
      });
      _loadReceivedFiles(speedshareDirectory);
    } catch (e) {
      print('Error getting downloads directory: $e');
    }
  }

  void _loadReceivedFiles(Directory directory) async {
    try {
      List<FileSystemEntity> files = await directory.list().toList();
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      List<Map<String, dynamic>> filesList = [];
      for (var file in files) {
        if (file is File) {
          filesList.add({
            'name': p.basename(file.path),
            'path': file.path,
            'size': file.lengthSync(),
            'date': file.statSync().modified.toString(),
          });
        }
      }
      setState(() {
        receivedFiles = filesList;
      });
    } catch (e) {
      print('Error loading received files: $e');
    }
  }

  void _getIpAddress() async {
    setState(() {
      isLoadingIp = true;
    });
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.') &&
              !addr.address.startsWith('0.')) {
            setState(() {
              ipAddress = addr.address;
              isLoadingIp = false;
            });
            return;
          }
        }
      }
    } catch (e) {
      print('Error getting IP address: $e');
    }
    setState(() {
      ipAddress = 'Not available';
      isLoadingIp = false;
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final permissions = <Permission>[
        Permission.storage,
        Permission.location,
        // Add Permission.nearbyWifiDevices if available in your permission_handler version
        if (Permission.values.contains(Permission.nearbyWifiDevices))
          Permission.nearbyWifiDevices,
      ];
      await permissions.request();
    } else if (Platform.isIOS) {
      await [Permission.photos, Permission.mediaLibrary].request();
    }
  }

  void _getComputerName() async {
    try {
      final hostname = Platform.localHostname;
      setState(() {
        computerName = hostname;
      });
    } catch (e) {
      setState(() {
        computerName = 'Unknown Device';
      });
    }
  }

  void startReceiving() async {
    try {
      serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);

      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        8081,
      );
      _discoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            if (message == 'SPEEDSHARE_DISCOVERY') {
              final responseMessage = utf8.encode(
                'SPEEDSHARE_RESPONSE:$computerName:READY',
              );
              _discoverySocket!.send(
                responseMessage,
                datagram.address,
                datagram.port,
              );
            }
          }
        }
      });

      setState(() {
        isReceiving = true;
        isReceivingAnimation = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Ready to receive files'),
            ],
          ),
          backgroundColor: Color(0xFF2AB673),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
        ),
      );

      serverSocket!.listen((client) {
        // Protocol state variables
        bool receivingMetadata = true;
        bool receivingHeaderSize = true;
        int metadataSize = 0;
        List<int> headerBuffer = [];
        int expectedFileSize = 0;
        String expectedFileName = '';
        File? fileForWrite;
        int writtenFileBytes = 0;

        client.listen((data) async {
          if (receivingMetadata) {
            if (receivingHeaderSize) {
              // First 4 bytes indicate metadata size
              if (data.length >= 4) {
                ByteData byteData = ByteData.sublistView(
                  Uint8List.fromList(data.sublist(0, 4)),
                );
                metadataSize = byteData.getInt32(0);
                if (data.length > 4) {
                  headerBuffer.addAll(data.sublist(4));
                }
                receivingHeaderSize = false;
                if (headerBuffer.length >= metadataSize) {
                  final metadataJson = utf8.decode(
                    headerBuffer.sublist(0, metadataSize),
                  );
                  final metadata =
                      json.decode(metadataJson) as Map<String, dynamic>;
                  expectedFileName = sanitizeFileName(
                    p.basename(metadata['fileName']),
                  );
                  expectedFileSize = metadata['fileSize'];
                  writtenFileBytes = 0;
                  receivedFileName = expectedFileName;
                  fileSize = expectedFileSize;
                  bytesReceived = 0;
                  fileForWrite = File(
                    '$downloadDirectoryPath/$expectedFileName',
                  );
                  if (await fileForWrite!.exists()) {
                    await fileForWrite!.delete();
                  }
                  receivingMetadata = false;
                  client.write('READY_FOR_FILE_DATA');
                  if (headerBuffer.length > metadataSize) {
                    final fileData = headerBuffer.sublist(metadataSize);
                    fileForWrite!.writeAsBytesSync(
                      fileData,
                      mode: FileMode.append,
                    );
                    writtenFileBytes += fileData.length;
                    bytesReceived = writtenFileBytes;
                    setState(() {
                      progress = writtenFileBytes / expectedFileSize;
                    });
                  }
                }
              } else {
                headerBuffer.addAll(data);
              }
            } else {
              headerBuffer.addAll(data);
              if (headerBuffer.length >= metadataSize) {
                final metadataJson = utf8.decode(
                  headerBuffer.sublist(0, metadataSize),
                );
                final metadata =
                    json.decode(metadataJson) as Map<String, dynamic>;
                expectedFileName = sanitizeFileName(
                  p.basename(metadata['fileName']),
                );
                expectedFileSize = metadata['fileSize'];
                writtenFileBytes = 0;
                receivedFileName = expectedFileName;
                fileSize = expectedFileSize;
                bytesReceived = 0;
                fileForWrite = File('$downloadDirectoryPath/$expectedFileName');
                if (await fileForWrite!.exists()) {
                  await fileForWrite!.delete();
                }
                receivingMetadata = false;
                client.write('READY_FOR_FILE_DATA');
                if (headerBuffer.length > metadataSize) {
                  final fileData = headerBuffer.sublist(metadataSize);
                  fileForWrite!.writeAsBytesSync(
                    fileData,
                    mode: FileMode.append,
                  );
                  writtenFileBytes += fileData.length;
                  bytesReceived = writtenFileBytes;
                  setState(() {
                    progress = writtenFileBytes / expectedFileSize;
                  });
                }
              }
            }
          } else {
            // This is file data
            fileForWrite!.writeAsBytesSync(data, mode: FileMode.append);
            writtenFileBytes += data.length;
            bytesReceived = writtenFileBytes;
            setState(() {
              progress = writtenFileBytes / fileSize;
            });
            // File transfer complete
            if (writtenFileBytes >= fileSize) {
              receivedFiles.insert(0, {
                'name': expectedFileName,
                'size': fileSize,
                'path': fileForWrite!.path,
                'date': DateTime.now().toString(),
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text('File received: $expectedFileName'),
                    ],
                  ),
                  backgroundColor: Color(0xFF2AB673),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: EdgeInsets.all(20),
                  action: SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () {
                      _openFile(fileForWrite!.path);
                    },
                  ),
                ),
              );
              client.write('TRANSFER_COMPLETE');
              receivedFile = null;
              receivingMetadata = true;
              receivingHeaderSize = true;
              headerBuffer = [];
              setState(() {
                receivedFileName = '';
                fileSize = 0;
                bytesReceived = 0;
                progress = 0.0;
              });
            }
          }
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Error: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
        ),
      );
      setState(() {
        isReceiving = false;
        isReceivingAnimation = false;
      });
    }
  }

  void stopReceiving() {
    serverSocket?.close();
    _discoverySocket?.close();
    setState(() {
      isReceiving = false;
      isReceivingAnimation = false;
      progress = 0.0;
      receivedFileName = '';
      fileSize = 0;
      bytesReceived = 0;
      receivedFile = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Stopped receiving files'),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(20),
      ),
    );
  }

  void _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Could not open file: ${result.message}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Error opening file: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _openDownloadsFolder() async {
    try {
      if (Platform.isWindows) {
        Process.run('explorer', [downloadDirectoryPath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [downloadDirectoryPath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [downloadDirectoryPath]);
      } else {
        await Clipboard.setData(ClipboardData(text: downloadDirectoryPath));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Path copied to clipboard'),
              ],
            ),
            backgroundColor: Color(0xFF4E6AF3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Could not open folder: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _copyIpToClipboard() async {
    await Clipboard.setData(ClipboardData(text: ipAddress));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('IP address copied to clipboard'),
          ],
        ),
        backgroundColor: Color(0xFF4E6AF3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  @override
  void dispose() {
    _animationController.dispose();
    serverSocket?.close();
    _discoverySocket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Files'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status section with IP and controls
              _buildStatusSection(),

              // Current transfer if any
              if (receivedFileName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildCurrentTransferCard(),
                ),

              // Files section
              Expanded(child: _buildFilesSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            Row(
              children: [
                if (isReceivingAnimation)
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2AB673),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2AB673).withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          isReceiving ? const Color(0xFF2AB673) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  isReceiving ? 'Listening for files' : 'Not receiving',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isReceiving ? const Color(0xFF2AB673) : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Device details
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Device Name',
                    computerName,
                    Icons.smartphone_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'IP Address',
                    isLoadingIp ? 'Loading...' : ipAddress,
                    Icons.wifi_rounded,
                    onTap: isLoadingIp ? null : _copyIpToClipboard,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isReceiving ? null : startReceiving,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start Receiving'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF2AB673),
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: isReceiving ? stopReceiving : null,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2AB673)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: onTap,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.copy,
                        size: 14,
                        color: const Color(0xFF2AB673),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTransferCard() {
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
                    Icons.downloading_rounded,
                    color: Color(0xFF4E6AF3),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Current Transfer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // File details
            Row(
              children: [
                _getFileTypeIcon(receivedFileName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receivedFileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${_formatFileSize(bytesReceived)} of ${_formatFileSize(fileSize)}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]
                        : Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF4E6AF3),
                ),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 8),

            // Progress percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF4E6AF3),
                  ),
                ),
                const Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4E6AF3),
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Receiving...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF4E6AF3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Received Files',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (receivedFiles.isNotEmpty)
                TextButton.icon(
                  onPressed: _openDownloadsFolder,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text(
                    'Open Folder',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4E6AF3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),

        Expanded(child: _buildFilesList()),
      ],
    );
  }

  Widget _buildFilesList() {
    if (receivedFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/empty_folder_animation.json',
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.folder_open,
                  size: 60,
                  color: Colors.grey[300],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'No files received yet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Files you receive will appear here',
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[500]
                        : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: receivedFiles.length,
      itemBuilder: (context, index) {
        final file = receivedFiles[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _getFileTypeIcon(file['name']),
            title: Text(
              file['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${_formatFileSize(file['size'])}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  _formatDate(file['date']),
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[500]
                            : Colors.grey[600],
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              onPressed: () => _openFile(file['path']),
              tooltip: 'Open',
              iconSize: 18,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF4E6AF3).withOpacity(0.1),
                foregroundColor: const Color(0xFF4E6AF3),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getFileTypeIcon(String fileName) {
    IconData iconData;
    Color iconColor;

    if (fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg') ||
        fileName.endsWith('.png') ||
        fileName.endsWith('.gif')) {
      iconData = Icons.image_rounded;
      iconColor = Colors.blue;
    } else if (fileName.endsWith('.mp4') ||
        fileName.endsWith('.avi') ||
        fileName.endsWith('.mov')) {
      iconData = Icons.video_file_rounded;
      iconColor = Colors.red;
    } else if (fileName.endsWith('.mp3') ||
        fileName.endsWith('.wav') ||
        fileName.endsWith('.flac')) {
      iconData = Icons.audio_file_rounded;
      iconColor = Colors.purple;
    } else if (fileName.endsWith('.pdf')) {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = Colors.red;
    } else if (fileName.endsWith('.doc') ||
        fileName.endsWith('.docx') ||
        fileName.endsWith('.txt')) {
      iconData = Icons.description_rounded;
      iconColor = Colors.blue;
    } else if (fileName.endsWith('.xls') ||
        fileName.endsWith('.xlsx') ||
        fileName.endsWith('.csv')) {
      iconData = Icons.table_chart_rounded;
      iconColor = const Color(0xFF2AB673);
    } else if (fileName.endsWith('.ppt') || fileName.endsWith('.pptx')) {
      iconData = Icons.slideshow_rounded;
      iconColor = Colors.orange;
    } else if (fileName.endsWith('.zip') ||
        fileName.endsWith('.rar') ||
        fileName.endsWith('.7z')) {
      iconData = Icons.folder_zip_rounded;
      iconColor = Colors.amber;
    } else {
      iconData = Icons.insert_drive_file_rounded;
      iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }
}
