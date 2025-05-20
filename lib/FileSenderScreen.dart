import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speedsharemob/PermissionManager.dart';

class FileSenderScreen extends StatefulWidget {
  @override
  _FileSenderScreenState createState() => _FileSenderScreenState();
}

class _FileSenderScreenState extends State<FileSenderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSending = false;
  double _progress = 0.0;
  int _totalFileSize = 0;
  int _totalBytesSent = 0;
  int _currentFileIndex = 0;
  bool _filesSelected = false;
  List<FileToSend> _selectedFiles = [];
  bool _transferComplete = false;

  bool isScanning = false;
  bool isConnecting = false;
  Socket? socket;
  Timer? _scanTimer;
  String? _receiverName;

  List<ReceiverDevice> availableReceivers = [];
  int _selectedReceiverIndex = -1;
  bool _isDiscovering = false;
  Timer? _discoveryTimer;
  RawDatagramSocket? _discoverySocket;

  int _currentStep = 1;
  String _searchQuery = '';
  List<ReceiverDevice> _filteredReceivers = [];

  final String _userLogin = Platform.localHostname;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _controller.forward();
    _checkPermissionsAndStart();

    _discoveryTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) startScanning();
    });

    _filteredReceivers = availableReceivers;
  }
  Future<void> _checkPermissionsAndStart() async {
  bool hasPermissions = await PermissionManager().requestAppPermissions();
  
  if (hasPermissions) {
    // In FileSenderScreen
    startScanning();
    
    // OR in ReceiveScreen
    // startReceiving();
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
  

  void startScanning() {
    if (!mounted) return;
    setState(() {
      isScanning = true;
    });
    discoverWithUDP();
    _scanTimer = Timer(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          isScanning = false;
        });
      }
    });
  }

  void discoverWithUDP() async {
    try {
      setState(() {
        _isDiscovering = true;
        availableReceivers.clear();
        _filteredReceivers = [];
      });

      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      _discoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            if (message.startsWith('SPEEDSHARE_RESPONSE:')) {
              final parts = message.split(':');
              if (parts.length >= 3) {
                final deviceName = parts[1];
                final ipAddress = datagram.address.address;
                if (mounted) {
                  setState(() {
                    if (!availableReceivers.any(
                      (device) => device.ip == ipAddress,
                    )) {
                      final newDevice = ReceiverDevice(
                        name: deviceName,
                        ip: ipAddress,
                      );
                      availableReceivers.add(newDevice);
                      _filteredReceivers = _filterReceivers();
                    }
                  });
                }
              }
            }
          }
        }
      });

      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        if (interface.name.contains('lo')) continue;
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final subnet = parts.sublist(0, 3).join('.');
              final message = utf8.encode('SPEEDSHARE_DISCOVERY');
              try {
                final gatewayAddress = InternetAddress('$subnet.1');
                _discoverySocket!.send(message, gatewayAddress, 8081);
                final ownAddress = InternetAddress(addr.address);
                _discoverySocket!.send(message, ownAddress, 8081);
                for (int i = 2; i < 10; i++) {
                  _discoverySocket!.send(
                    message,
                    InternetAddress('$subnet.$i'),
                    8081,
                  );
                }
                _discoverySocket!.send(
                  message,
                  InternetAddress('$subnet.255'),
                  8081,
                );
              } catch (e) {
                print('Failed to send discovery packet: $e');
              }
            }
          }
        }
      }
      Timer(Duration(seconds: 2), () {
        if (mounted) {
          if (availableReceivers.isEmpty) {
            checkDirectTCPConnections();
          } else {
            setState(() {
              _isDiscovering = false;
              isScanning = false;
              _filteredReceivers = _filterReceivers();
            });
          }
        }
      });
    } catch (e) {
      print('UDP discovery error: $e');
      if (mounted) checkDirectTCPConnections();
    }
  }

  void checkDirectTCPConnections() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        if (interface.name.contains('lo')) continue;
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final prefix = parts.sublist(0, 3).join('.');
              for (int i = 1; i <= 10; i++) {
                await checkReceiver('$prefix.$i');
              }
              await checkReceiver('$prefix.100');
              await checkReceiver('$prefix.101');
              await checkReceiver('$prefix.102');
              await checkReceiver('$prefix.255');
            }
          }
        }
      }
    } catch (e) {
      print('TCP discovery error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
          isScanning = false;
          _filteredReceivers = _filterReceivers();
        });
      }
    }
  }

  Future<void> checkReceiver(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        8080,
        timeout: Duration(milliseconds: 500),
      ).catchError((e) => null);

      if (socket == null) return;

      final completer = Completer<String?>();

      Timer(Duration(seconds: 1), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      socket.listen((data) {
        final message = String.fromCharCodes(data);
        if (message.startsWith('DEVICE_NAME:')) {
          final deviceName = message.replaceFirst('DEVICE_NAME:', '');
          if (!completer.isCompleted) {
            completer.complete(deviceName);
          }
        }
      });

      final deviceName = await completer.future;
      socket.destroy();

      if (deviceName != null && deviceName.isNotEmpty && mounted) {
        setState(() {
          if (!availableReceivers.any((device) => device.ip == ip)) {
            availableReceivers.add(ReceiverDevice(name: deviceName, ip: ip));
            _filteredReceivers = _filterReceivers();
          }
        });
      }
    } catch (e) {}
  }

  void connectToReceiver(String ip, [String? name]) async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Please select at least one file'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
        ),
      );
      return;
    }
    setState(() {
      isConnecting = true;
      _currentStep = 3;
    });
    try {
      socket = await Socket.connect(ip, 8080, timeout: Duration(seconds: 5));

      String deviceName = name ?? '';
      if (deviceName.isEmpty) {
        final completer = Completer<String>();
        socket!.listen(
          (data) {
            String message = String.fromCharCodes(data);
            if (message.startsWith('DEVICE_NAME:')) {
              deviceName = message.replaceFirst('DEVICE_NAME:', '');
              if (!completer.isCompleted) {
                completer.complete(deviceName);
              }
            }
          },
          onDone: () {
            if (!completer.isCompleted) {
              completer.complete('Unknown Device');
            }
          },
          onError: (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          },
        );
        try {
          deviceName = await completer.future.timeout(Duration(seconds: 1));
        } catch (e) {
          deviceName = 'Unknown Device';
        }
      }

      if (mounted) {
        setState(() {
          isConnecting = false;
          _receiverName = deviceName;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Connected to $deviceName'),
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

      // We will listen for READY_FOR_FILE_DATA and TRANSFER_COMPLETE
      socket!.listen(
        (data) {
          final message = utf8.decode(data);
          if (message == 'READY_FOR_FILE_DATA') {
            // Start sending data for the current file
            _sendCurrentFileData();
          } else if (message == 'TRANSFER_COMPLETE') {
            _handleFileTransferComplete();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isSending = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Connection error: ${error.toString().substring(0, min(error.toString().length, 50))}',
                  ),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(20),
            ),
          );
        },
        onDone: () {
          if (_isSending && _progress < 1.0 && mounted) {
            setState(() {
              _isSending = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Connection closed unexpectedly'),
                  ],
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(20),
              ),
            );
          }
        },
      );

      // Start the file transfer handshake for the first file
      _startFileTransfer();
    } catch (e) {
      if (mounted) {
        setState(() {
          isConnecting = false;
          _currentStep = 2;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Failed to connect: ${e.toString().substring(0, min(e.toString().length, 50))}',
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => connectToReceiver(ip, name),
          ),
        ),
      );
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      dialogTitle: 'Select files to send',
    );
    if (result != null && result.files.isNotEmpty) {
      List<FileToSend> files = [];
      int totalSize = 0;
      for (var file in result.files) {
        if (file.path != null) {
          File fileData = File(file.path!);
          String fileName =
              file.path!.split(Platform.isWindows ? '\\' : '/').last;
          int fileSize = fileData.lengthSync();
          String fileType =
              lookupMimeType(file.path!) ?? 'application/octet-stream';
          files.add(
            FileToSend(
              file: fileData,
              name: fileName,
              size: fileSize,
              type: fileType,
              progress: 0.0,
              bytesSent: 0,
              status: 'Pending',
            ),
          );
          totalSize += fileSize;
        }
      }
      _prepareFiles(files, totalSize);
      _controller.reset();
      _controller.forward();
      setState(() {
        _currentStep = 2;
      });
    }
  }

  void _prepareFiles(List<FileToSend> files, int totalSize) {
    setState(() {
      _selectedFiles = files;
      _totalFileSize = totalSize;
      _totalBytesSent = 0;
      _filesSelected = true;
      _transferComplete = false;
      _currentFileIndex = 0;
    });
  }

  void _removeFile(int index) {
    setState(() {
      _totalFileSize -= _selectedFiles[index].size;
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) {
        _filesSelected = false;
        _totalFileSize = 0;
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _startFileTransfer() {
    if (_selectedFiles.isEmpty || _currentFileIndex >= _selectedFiles.length) {
      return;
    }
    setState(() {
      _isSending = true;
      _selectedFiles[_currentFileIndex].progress = 0.0;
      _selectedFiles[_currentFileIndex].bytesSent = 0;
      _selectedFiles[_currentFileIndex].status = 'Sending';
    });
    // Start the handshake: send metadata, then wait for READY_FOR_FILE_DATA
    _sendCurrentFileMetadata();
  }

  void _sendCurrentFileMetadata() async {
    if (socket == null || _currentFileIndex >= _selectedFiles.length) return;
    final currentFile = _selectedFiles[_currentFileIndex];
    try {
      final metadata = {
        'fileName': currentFile.name,
        'fileSize': currentFile.size,
        'fileType': currentFile.type,
        'sender': _userLogin,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'totalFiles': _selectedFiles.length,
        'fileIndex': _currentFileIndex,
      };
      final metadataStr = json.encode(metadata);
      final metadataBytes = utf8.encode(metadataStr);

      final metadataSize = Uint8List(4);
      ByteData.view(metadataSize.buffer).setInt32(0, metadataBytes.length);
      socket!.add(metadataSize);
      socket!.add(metadataBytes);
      await socket!.flush();
      // Do not send file data here! Wait for READY_FOR_FILE_DATA from receiver
      // The socket's listener (set up in connectToReceiver) will call _sendCurrentFileData
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedFiles[_currentFileIndex].status = 'Failed';
          _isSending = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Error sending metadata: ${e.toString().substring(0, min(e.toString().length, 50))}',
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _sendCurrentFileMetadata,
          ),
        ),
      );
    }
  }

  void _sendCurrentFileData() async {
    if (socket == null || _currentFileIndex >= _selectedFiles.length) return;
    final currentFile = _selectedFiles[_currentFileIndex];
    try {
      final fileBytes = await currentFile.file.readAsBytes();
      final int bufferSize =
          currentFile.size > 100 * 1024 * 1024 ? 32 * 1024 : 4 * 1024;
      int bytesSent = 0;
      int lastProgressUpdate = 0;
      final int updateThreshold = (currentFile.size / 100).round();

      for (int i = 0; i < fileBytes.length; i += bufferSize) {
        if (socket == null) {
          throw Exception("Connection lost");
        }
        int end =
            (i + bufferSize < fileBytes.length)
                ? i + bufferSize
                : fileBytes.length;
        List<int> chunk = fileBytes.sublist(i, end);

        socket!.add(chunk);
        bytesSent += chunk.length;
        _totalBytesSent += chunk.length;

        if (bytesSent - lastProgressUpdate > updateThreshold && mounted) {
          setState(() {
            _selectedFiles[_currentFileIndex].progress =
                bytesSent / fileBytes.length;
            _selectedFiles[_currentFileIndex].bytesSent = bytesSent;
            _progress = _totalBytesSent / _totalFileSize;
          });
          lastProgressUpdate = bytesSent;
        }
        if (i % (bufferSize * 10) == 0) {
          await Future.delayed(Duration(milliseconds: 1));
        }
      }

      if (mounted) {
        setState(() {
          _selectedFiles[_currentFileIndex].progress = 1.0;
          _selectedFiles[_currentFileIndex].bytesSent = currentFile.size;
          _progress = _totalBytesSent / _totalFileSize;
        });
      }

      Timer(Duration(seconds: 15), () {
        if (_isSending &&
            _selectedFiles[_currentFileIndex].progress >= 0.99 &&
            mounted) {
          _handleFileTransferComplete();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedFiles[_currentFileIndex].status = 'Failed';
          _isSending = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Error sending file: ${e.toString().substring(0, min(e.toString().length, 50))}',
              ),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(20),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _sendCurrentFileData,
          ),
        ),
      );
    }
  }

  void _handleFileTransferComplete() {
    if (!mounted) return;
    setState(() {
      _selectedFiles[_currentFileIndex].status = 'Completed';
      _currentFileIndex++;
      if (_currentFileIndex >= _selectedFiles.length) {
        _isSending = false;
        _transferComplete = true;
        _progress = 1.0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('All files sent successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF2AB673),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(20),
            action: SnackBarAction(
              label: 'Send More',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                  _filesSelected = false;
                  _selectedFiles = [];
                  _transferComplete = false;
                  _totalFileSize = 0;
                  _totalBytesSent = 0;
                });
              },
            ),
          ),
        );
      } else {
        // For next file: send metadata, wait for READY_FOR_FILE_DATA, then send data
        _sendCurrentFileMetadata();
      }
    });
  }

  List<ReceiverDevice> _filterReceivers() {
    if (_searchQuery.isEmpty) {
      return availableReceivers;
    }
    return availableReceivers
        .where(
          (device) =>
              device.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              device.ip.contains(_searchQuery),
        )
        .toList();
  }

  IconData _getFileIconData(String fileType) {
    if (fileType.startsWith('image/')) {
      return Icons.image_rounded;
    } else if (fileType.startsWith('video/')) {
      return Icons.video_file_rounded;
    } else if (fileType.startsWith('audio/')) {
      return Icons.audio_file_rounded;
    } else if (fileType.contains('pdf')) {
      return Icons.picture_as_pdf_rounded;
    } else if (fileType.contains('word') || fileType.contains('document')) {
      return Icons.description_rounded;
    } else if (fileType.contains('excel') || fileType.contains('sheet')) {
      return Icons.table_chart_rounded;
    } else if (fileType.contains('presentation') ||
        fileType.contains('powerpoint')) {
      return Icons.slideshow_rounded;
    } else if (fileType.contains('zip') || fileType.contains('compressed')) {
      return Icons.folder_zip_rounded;
    } else {
      return Icons.insert_drive_file_rounded;
    }
  }

  Color _getFileIconColor(String fileType) {
    if (fileType.startsWith('image/')) {
      return Color(0xFF3498db);
    } else if (fileType.startsWith('video/')) {
      return Color(0xFFe74c3c);
    } else if (fileType.startsWith('audio/')) {
      return Color(0xFF9b59b6);
    } else if (fileType.contains('pdf')) {
      return Color(0xFFe74c3c);
    } else if (fileType.contains('word') || fileType.contains('document')) {
      return Color(0xFF3498db);
    } else if (fileType.contains('excel') || fileType.contains('sheet')) {
      return Color(0xFF2ecc71);
    } else if (fileType.contains('presentation') ||
        fileType.contains('powerpoint')) {
      return Color(0xFFe67e22);
    } else if (fileType.contains('zip') || fileType.contains('compressed')) {
      return Color(0xFFf39c12);
    } else {
      return Color(0xFF95a5a6);
    }
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanTimer?.cancel();
    _discoveryTimer?.cancel();
    _discoverySocket?.close();
    socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 50,
              child: Row(
                children: [
                  _buildStepItem(1, 'Select Files', _currentStep >= 1),
                  _buildStepConnector(_currentStep >= 2),
                  _buildStepItem(2, 'Select Receiver', _currentStep >= 2),
                  _buildStepConnector(_currentStep >= 3),
                  _buildStepItem(3, 'Transfer', _currentStep >= 3),
                ],
              ),
            ),

            // Main content area
            Expanded(child: _buildCurrentStepContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int step, String label, bool isActive) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF4E6AF3) : Colors.grey[300],
              shape: BoxShape.circle,
              boxShadow:
                  isActive
                      ? [
                        BoxShadow(
                          color: const Color(0xFF4E6AF3).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                      : null,
            ),
            child: Center(
              child:
                  isActive && step < _currentStep
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                        '$step',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFF4E6AF3) : Colors.grey[500],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      color: isActive ? const Color(0xFF4E6AF3) : Colors.grey[300],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildSelectFileStep();
      case 2:
        return _buildSelectReceiverStep();
      case 3:
        return _buildTransferStep();
      default:
        return _buildSelectFileStep();
    }
  }

  Widget _buildSelectFileStep() {
    return _filesSelected ? _buildSelectedFilesInfo() : _buildFileSelectArea();
  }

  Widget _buildFileSelectArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/upload_animation.json',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF4E6AF3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 40,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Select Files to Send',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Choose files to share with other devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Browse Files'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF4E6AF3),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              shadowColor: const Color(0xFF4E6AF3).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Multiple files supported',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFilesInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Files (${_selectedFiles.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Total Size: ${_formatFileSize(_totalFileSize)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add More', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4E6AF3),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // List of selected files
          Expanded(
            child: ListView.builder(
              itemCount: _selectedFiles.length,
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getFileIconColor(file.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getFileIconData(file.type),
                        size: 20,
                        color: _getFileIconColor(file.type),
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
                    subtitle: Text(
                      _formatFileSize(file.size),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeFile(index),
                      tooltip: 'Remove file',
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep = 2; // Move to receiver selection
                });
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF4E6AF3),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectReceiverStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected files summary
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E6AF3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  size: 20,
                  color: Color(0xFF4E6AF3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedFiles.length} File${_selectedFiles.length > 1 ? 's' : ''} Selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Total: ${_formatFileSize(_totalFileSize)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Change'),
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

          const SizedBox(height: 16),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[500], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filteredReceivers = _filterReceivers();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search receivers...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[500]),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _filteredReceivers = _filterReceivers();
                      });
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Status text
          Row(
            children: [
              isScanning
                  ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                  : Icon(
                    Icons.wifi_rounded,
                    size: 14,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                  ),
              const SizedBox(width: 8),
              Text(
                isScanning
                    ? 'Scanning for devices...'
                    : 'Available devices on your network',
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

          const SizedBox(height: 12),

          // Receiver list
          Expanded(
            child:
                _filteredReceivers.isEmpty
                    ? _buildEmptyReceiverState()
                    : ListView.builder(
                      itemCount: _filteredReceivers.length,
                      itemBuilder: (context, index) {
                        final receiver = _filteredReceivers[index];
                        final isSelected = _selectedReceiverIndex == index;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color:
                              isSelected
                                  ? const Color(0xFF4E6AF3).withOpacity(0.05)
                                  : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? const Color(0xFF4E6AF3)
                                      : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedReceiverIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? const Color(
                                                0xFF4E6AF3,
                                              ).withOpacity(0.2)
                                              : Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[800]
                                              : Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.check : Icons.computer,
                                      color:
                                          isSelected
                                              ? const Color(0xFF4E6AF3)
                                              : Colors.grey[600],
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          receiver.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isSelected
                                                    ? const Color(0xFF4E6AF3)
                                                    : null,
                                          ),
                                        ),
                                        Text(
                                          receiver.ip,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          const SizedBox(height: 16),

          // Bottom navigation
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentStep = 1;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4E6AF3),
                    side: const BorderSide(color: Color(0xFF4E6AF3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed:
                      (_filesSelected &&
                              _selectedReceiverIndex >= 0 &&
                              _selectedReceiverIndex <
                                  _filteredReceivers.length)
                          ? () => connectToReceiver(
                            _filteredReceivers[_selectedReceiverIndex].ip,
                            _filteredReceivers[_selectedReceiverIndex].name,
                          )
                          : null,
                  icon:
                      isConnecting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.send),
                  label: Text(
                    isConnecting ? 'Connecting...' : 'Send Files',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF4E6AF3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReceiverState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/searchss.json',
            height: 120,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.search_off_rounded,
                size: 60,
                color: Colors.grey[300],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'No receivers found',
            style: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[300]
                      : Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Make sure other devices are on the same network and have receiving enabled',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: isScanning ? null : startScanning,
            icon:
                isScanning
                    ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF4E6AF3),
                      ),
                    )
                    : const Icon(Icons.refresh_rounded),
            label: Text(isScanning ? 'Scanning...' : 'Scan Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4E6AF3),
              side: const BorderSide(color: Color(0xFF4E6AF3), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with receiver info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E6AF3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.computer_rounded,
                  size: 20,
                  color: Color(0xFF4E6AF3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sending to: ${_receiverName ?? "Device"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'From: ${_userLogin}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 32),

          // Overall progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overall Progress',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          _transferComplete
                              ? const Color(0xFF2AB673)
                              : const Color(0xFF4E6AF3),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _transferComplete
                        ? const Color(0xFF2AB673)
                        : const Color(0xFF4E6AF3),
                  ),
                  minHeight: 8,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Sending file ${_currentFileIndex + 1} of ${_selectedFiles.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // List of files with their progress
          Expanded(
            child: ListView.builder(
              itemCount: _selectedFiles.length,
              itemBuilder: (context, index) {
                final file = _selectedFiles[index];
                final isCurrentFile = index == _currentFileIndex;

                // Determine status color
                Color statusColor;
                if (file.status == 'Completed') {
                  statusColor = const Color(0xFF2AB673);
                } else if (file.status == 'Failed') {
                  statusColor = Colors.red;
                } else if (file.status == 'Sending') {
                  statusColor = const Color(0xFF4E6AF3);
                } else {
                  statusColor = Colors.grey;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color:
                      isCurrentFile
                          ? const Color(0xFF4E6AF3).withOpacity(0.05)
                          : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getFileIconColor(
                                  file.type,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFileIconData(file.type),
                                size: 18,
                                color: _getFileIconColor(file.type),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_formatFileSize(file.bytesSent)} of ${_formatFileSize(file.size)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCurrentFile && file.status == 'Sending')
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              statusColor,
                                            ),
                                      ),
                                    )
                                  else if (file.status == 'Completed')
                                    Icon(
                                      Icons.check_circle,
                                      size: 10,
                                      color: statusColor,
                                    )
                                  else if (file.status == 'Failed')
                                    Icon(
                                      Icons.error,
                                      size: 10,
                                      color: statusColor,
                                    )
                                  else
                                    Icon(
                                      Icons.schedule,
                                      size: 10,
                                      color: statusColor,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    file.status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (isCurrentFile || file.progress > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: file.progress,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Bottom navigation
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _transferComplete || !_isSending
                          ? () {
                            setState(() {
                              _currentStep = 2;
                            });
                          }
                          : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4E6AF3),
                    side: const BorderSide(color: Color(0xFF4E6AF3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed:
                      _transferComplete
                          ? () {
                            setState(() {
                              _currentStep = 1;
                              _filesSelected = false;
                              _selectedFiles = [];
                              _transferComplete = false;
                              _totalFileSize = 0;
                              _totalBytesSent = 0;
                              _currentFileIndex = 0;
                            });
                          }
                          : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Send More Files',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF2AB673),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ReceiverDevice {
  final String name;
  final String ip;

  ReceiverDevice({required this.name, required this.ip});
}

class FileToSend {
  final File file;
  final String name;
  final int size;
  final String type;
  double progress;
  int bytesSent;
  String status;

  FileToSend({
    required this.file,
    required this.name,
    required this.size,
    required this.type,
    required this.progress,
    required this.bytesSent,
    required this.status,
  });
}
