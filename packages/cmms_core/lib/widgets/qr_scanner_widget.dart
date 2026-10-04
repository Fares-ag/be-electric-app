import 'package:flutter/material.dart';

import '../screens/assets/asset_detail_screen.dart';
import '../repositories/cmms_repositories.dart';
import '../utils/user_facing_errors.dart';

class QRScannerWidget extends StatefulWidget {
  const QRScannerWidget({super.key});

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final TextEditingController _qrCodeController = TextEditingController();

  @override
  void dispose() {
    _qrCodeController.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String qrCode) async {
    try {
      // Look for asset by QR code
      final asset = await CmmsRepositories.assets.getAssetByQRCode(qrCode);

      if (asset != null && mounted) {
        // Navigate to asset details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetDetailScreen(asset: asset),
          ),
        );
      } else if (mounted) {
        _showErrorDialog(
          'Asset not found',
          'No asset found with QR code: $qrCode',
        );
      }
    } catch (e, st) {
      if (mounted) {
        _showErrorDialog(
          'Error',
          userFacingErrorMessage(
            e,
            genericMessage: 'Could not process QR code. Please try again.',
            stackTrace: st,
            contextLabel: 'QRScannerWidget: process QR',
          ),
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Enter QR Code'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'QR Code Scanner',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter the QR code manually or use a QR code scanner app to get the code.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _qrCodeController,
                decoration: const InputDecoration(
                  labelText: 'QR Code',
                  hintText: 'Enter the QR code here...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _processQRCode(value.trim());
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_qrCodeController.text.trim().isNotEmpty) {
                      _processQRCode(_qrCodeController.text.trim());
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a QR code'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Find Asset'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sample QR Codes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('ASSET_2025_00001'),
                      Text('ASSET_2025_00002'),
                      SizedBox(height: 8),
                      Text(
                        'Note: In a real app, these would be actual QR codes that can be scanned with a camera.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
