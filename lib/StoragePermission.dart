import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissionScreen extends StatefulWidget {
  @override
  _StoragePermissionScreenState createState() => _StoragePermissionScreenState();
}

class _StoragePermissionScreenState extends State<StoragePermissionScreen> {
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Storage Permission Required'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 20),
            Text(
              'Storage Access Required',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'SpeedShare needs permission to access files for sharing. '
              'Without this permission, you cannot send or receive files.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isRequesting ? null : _requestStoragePermission,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: _isRequesting
                  ? CircularProgressIndicator()
                  : Text('Grant Permission', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 15),
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestStoragePermission() async {
    setState(() {
      _isRequesting = true;
    });

    try {
      PermissionStatus status = await Permission.storage.request();
      
      if (!mounted) return;

      if (status.isGranted) {
        Navigator.pop(context, true);
      } else {
        // Request manage external storage on newer Android
        await openAppSettings();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }
}