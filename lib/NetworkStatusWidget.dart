import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class NetworkStatusWidget extends StatefulWidget {
  final VoidCallback? onRetry;

  const NetworkStatusWidget({super.key, this.onRetry});

  /// Static helper to check if an active local network IPv4 interface exists
  static Future<bool> hasLocalNetwork() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('127.') &&
              !addr.address.startsWith('0.')) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  bool _isConnected = true;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _checkNetwork();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkNetwork();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNetwork() async {
    final connected = await NetworkStatusWidget.hasLocalNetwork();
    if (mounted && connected != _isConnected) {
      setState(() {
        _isConnected = connected;
      });
    }
  }

  void _showHotspotGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.portable_wifi_off_rounded, color: Color(0xFF4E6AF3)),
              SizedBox(width: 10),
              Text('Offline Transfer Guide'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Wi-Fi router available? You can still transfer files at maximum speeds without consuming any cellular data!',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _buildGuideStep(
                  step: '1',
                  title: 'Turn On Mobile Hotspot',
                  description:
                      'Enable Personal / Mobile Hotspot on Device A settings.',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '2',
                  title: 'Connect Device B',
                  description:
                      'Connect Device B to Device A\'s Wi-Fi Hotspot.',
                ),
                const SizedBox(height: 12),
                _buildGuideStep(
                  step: '3',
                  title: 'Open SpeedShare',
                  description:
                      'Launch SpeedShare on both devices. Device discovery will connect instantly!',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2AB673).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2AB673).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: Color(0xFF2AB673), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No mobile data is used during transfers over Hotspot.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2AB673),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E6AF3),
                foregroundColor: Colors.white,
              ),
              child: const Text('Got It'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: const Color(0xFF4E6AF3),
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade400, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No Local Network Connection',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Connect to a Wi-Fi network or turn on Mobile Hotspot to share files offline.',
            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showHotspotGuideDialog(context),
                icon: const Icon(Icons.help_outline_rounded, size: 16),
                label: const Text('Hotspot Guide'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber.shade900,
                  side: BorderSide(color: Colors.amber.shade700),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (widget.onRetry != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    _checkNetwork();
                    widget.onRetry!();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
