import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speedsharemob/main.dart';
import 'package:speedsharemob/DeveloperDetailsScreen.dart';
import 'package:speedsharemob/DeviceNameManager.dart';
import 'package:speedsharemob/SpeedShareAppBar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String downloadPath = '';
  bool darkMode = false;
  bool showNotifications = true;
  int port = 8080;
  String deviceName = '';
  bool loading = true;
  bool saveHistory = true;
  String localIp = '';
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: port.toString());
    _loadSettings();
    _fetchLocalIp();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.') &&
              !addr.address.startsWith('0.')) {
            if (mounted) {
              setState(() {
                localIp = addr.address;
              });
            }
            return;
          }
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        localIp = 'Not Connected';
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      loading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedDeviceName = await DeviceNameManager.getDeviceName();

      Directory? downloadsDirectory = await getDownloadsDirectory();
      String speedsharePath;
      if (downloadsDirectory != null) {
        speedsharePath = '${downloadsDirectory.path}/speedshare';
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        speedsharePath = '${appDir.path}/speedshare';
      }

      setState(() {
        deviceName = loadedDeviceName;
        darkMode = prefs.getBool('darkMode') ?? false;
        showNotifications = prefs.getBool('showNotifications') ?? true;
        port = prefs.getInt('port') ?? 8080;
        downloadPath = prefs.getString('downloadPath') ?? speedsharePath;
        saveHistory = prefs.getBool('saveHistory') ?? true;
        _portController.text = port.toString();
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _updateBoolSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
    }
  }

  Future<void> _selectDownloadFolder() async {
    try {
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        setState(() {
          downloadPath = path;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('downloadPath', path);

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download path updated: $path'),
            backgroundColor: const Color(0xFF2AB673),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error selecting folder: $e');
    }
  }

  Future<void> _resetSettings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Reset Settings'),
          ],
        ),
        content: const Text(
          'This will reset all preferences and device configurations to default values. Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await _loadSettings();

              if (!mounted || !context.mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Settings reset to defaults'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF4E6AF3),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(20),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }

  void _showEditDeviceNameDialog() {
    final controller = TextEditingController(text: deviceName);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_rounded, color: Color(0xFF4E6AF3)),
                  SizedBox(width: 10),
                  Text('Edit Device Name'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This name will be visible to other devices on your local network when sharing files.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Device Name',
                      hintText: 'Enter a name (e.g. Swift Falcon 42)',
                      prefixIcon: const Icon(Icons.devices_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.casino_rounded),
                        tooltip: 'Randomize Name',
                        onPressed: () {
                          setDialogState(() {
                            controller.text =
                                DeviceNameManager.generateRandomName();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          controller.text =
                              DeviceNameManager.generateRandomName();
                        });
                      },
                      icon: const Icon(Icons.shuffle_rounded, size: 16),
                      label: const Text('Generate Random Name'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isNotEmpty) {
                      await DeviceNameManager.setDeviceName(newName);
                      setState(() {
                        deviceName = newName;
                      });
                      if (!mounted || !context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Device name updated to "$newName"'),
                          backgroundColor: const Color(0xFF2AB673),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.all(20),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4E6AF3),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const SpeedShareAppBar(
        title: 'Settings',
        subtitle: 'Preferences & network options',
        icon: Icons.settings_rounded,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Hero Device Profile Section
                      _buildHeroDeviceCard(isDark),

                      const SizedBox(height: 16),

                      // Appearance & Preferences
                      _buildSectionCard(
                        title: 'Preferences',
                        icon: Icons.tune_rounded,
                        children: [
                          _buildSwitchSettingTile(
                            title: 'Dark Mode',
                            subtitle: 'Toggle app dark theme',
                            icon: darkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            value: darkMode,
                            onChanged: (value) async {
                              setState(() {
                                darkMode = value;
                              });
                              MyApp.updateDarkMode(value);
                              await _updateBoolSetting('darkMode', value);
                            },
                          ),
                          const Divider(height: 20),
                          _buildSwitchSettingTile(
                            title: 'Notifications',
                            subtitle:
                                'Display alerts upon completed file transfers',
                            icon: Icons.notifications_active_rounded,
                            value: showNotifications,
                            onChanged: (value) async {
                              setState(() {
                                showNotifications = value;
                              });
                              await _updateBoolSetting(
                                  'showNotifications', value);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Storage & History
                      _buildSectionCard(
                        title: 'Storage & Files',
                        icon: Icons.folder_special_rounded,
                        children: [
                          _buildDownloadPathTile(isDark),
                          const Divider(height: 20),
                          _buildSwitchSettingTile(
                            title: 'Save Transfer History',
                            subtitle:
                                'Maintain a record of received & sent files',
                            icon: Icons.history_rounded,
                            value: saveHistory,
                            onChanged: (value) async {
                              setState(() {
                                saveHistory = value;
                              });
                              await _updateBoolSetting('saveHistory', value);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Network Config
                      _buildSectionCard(
                        title: 'Network & Connectivity',
                        icon: Icons.wifi_tethering_rounded,
                        children: [
                          _buildPortSettingTile(isDark),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // About & App Info
                      _buildAboutSectionCard(isDark),

                      const SizedBox(height: 24),

                      // Reset Settings Danger Action
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _resetSettings,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset All Settings to Defaults'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDeviceCard(bool isDark) {
    final avatarLetter =
        deviceName.isNotEmpty ? deviceName.substring(0, 1).toUpperCase() : 'S';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2640), const Color(0xFF151928)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4E6AF3).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4E6AF3).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4E6AF3), Color(0xFF2AB673)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4E6AF3).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'THIS DEVICE NAME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFF4E6AF3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deviceName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: localIp != 'Not Connected'
                              ? const Color(0xFF2AB673)
                              : Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        localIp.isNotEmpty ? 'IP: $localIp' : 'Detecting IP...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showEditDeviceNameDialog,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6AF3),
                foregroundColor: Colors.white,
                elevation: 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    color: const Color(0xFF4E6AF3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: const Color(0xFF4E6AF3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: value ? const Color(0xFF4E6AF3) : Colors.grey,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF2AB673),
        ),
      ],
    );
  }

  Widget _buildDownloadPathTile(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 20,
                color: Color(0xFF4E6AF3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Where incoming files are saved',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  downloadPath.isNotEmpty
                      ? downloadPath
                      : 'Setting download location...',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _selectDownloadFolder,
                icon: const Icon(Icons.folder_shared_rounded, size: 16),
                label: const Text('Browse'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4E6AF3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortSettingTile(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.router_rounded,
                size: 20,
                color: Color(0xFF4E6AF3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Listening TCP Port',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Port for receiving raw TCP file transfers',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 120,
              child: TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Port Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) async {
                  try {
                    final parsed = int.parse(value);
                    if (parsed > 1024 && parsed < 65535) {
                      port = parsed;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('port', parsed);
                    }
                  } catch (_) {}
                },
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async {
                setState(() {
                  port = 8080;
                  _portController.text = '8080';
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('port', 8080);
              },
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text('Reset (8080)'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAboutSectionCard(bool isDark) {
    void showInfoDialog(String title, String content) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4E6AF3).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFF4E6AF3),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'About SpeedShare',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // App Brand Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4E6AF3), Color(0xFF2AB673)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4E6AF3).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'SpeedShare',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E6AF3),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2AB673).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'v1.0.3+4 • Stable Release',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2AB673),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Privacy and Terms
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          showInfoDialog(
                            'Privacy Policy',
                            'Privacy Policy\n\n'
                                'Last updated: May 19, 2025\n\n'
                                'SpeedShare values your privacy. This Privacy Policy explains how SpeedShare handles your information when you use our application to share files between devices over the local network.\n\n'
                                '1. Information Collection\n'
                                'SpeedShare does not collect, store, or transmit any personal information or files to external cloud servers. All file transfers occur directly between devices on your local network.\n\n'
                                '2. File Transfers\n'
                                'All files shared using SpeedShare remain within your local network. You are responsible for ensuring that you trust the devices you connect with.\n\n'
                                '3. Security\n'
                                'We implement standard socket encryption practices; please ensure your local Wi-Fi network is secure.',
                          );
                        },
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () {
                          showInfoDialog(
                            'Terms of Service',
                            'Terms of Service\n\n'
                                'Last updated: May 19, 2025\n\n'
                                'By using SpeedShare, you agree to these Terms of Service.\n\n'
                                '1. User Responsibility\n'
                                'You are solely responsible for the files you choose to share and receive.\n\n'
                                '2. Disclaimer\n'
                                'SpeedShare is provided "as is" without any express or implied warranties.',
                          );
                        },
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Developer details navigation tile
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2AB673).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF2AB673),
                      ),
                    ),
                    title: const Text(
                      'Developer Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Connect with the developer',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeveloperDetailsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}