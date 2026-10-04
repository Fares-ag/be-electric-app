import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asset.dart';
import '../providers/auth_provider.dart';
import '../screens/assets/asset_detail_screen.dart';
import '../screens/pm_tasks/create_pm_task_screen.dart';
import '../screens/work_orders/create_work_request_screen.dart';
import '../repositories/cmms_repositories.dart';
import '../services/hybrid_dam_service.dart';
import '../config/locator.dart';
import '../utils/user_facing_errors.dart';

class MobileQRScannerWidget extends StatefulWidget {
  const MobileQRScannerWidget({
    super.key,
    this.isRequestorMode = false,
    this.onQRCodeScanned,
    this.returnResolvedAsset = false,
  });
  final bool isRequestorMode;
  final Function(String)? onQRCodeScanned;

  /// When true, pop with the resolved [Asset] instead of opening a new create screen.
  final bool returnResolvedAsset;

  @override
  State<MobileQRScannerWidget> createState() => _MobileQRScannerWidgetState();
}

class _MobileQRScannerWidgetState extends State<MobileQRScannerWidget> {
  // Mobile scanner controller - only used on mobile platforms
  // ignore: unused_field
  dynamic controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    // Mobile scanner not available on web
  }

  @override
  Widget build(BuildContext context) {
    // Web fallback - show manual entry dialog
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('QR Code Scanner'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'QR Scanner not available on web',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please use manual entry'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showManualEntryDialog(context),
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter QR Code Manually'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }

    // For mobile platforms, show manual entry since mobile_scanner is disabled
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'QR Scanner not available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Please use manual entry'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showManualEntryDialog(context),
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter QR Code Manually'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile scanner detection - not used on web
  // void _onDetect(BarcodeCapture capture) {
  //   final barcodes = capture.barcodes;
  //   for (final barcode in barcodes) {
  //     if (barcode.rawValue != null) {
  //       _processQRCode(barcode.rawValue!);
  //       break;
  //     }
  //   }
  // }

  /// Extract itemId from QR code content
  /// Supports various QR code formats that contain itemId numbers
  String? _extractItemIdFromQRCode(String qrCode) {
    // Remove any whitespace
    final cleanCode = qrCode.trim();

    // Pattern 1: Asset format (e.g., "2025_00001", "2024_12345")
    if (RegExp(r'^\d{4}_\d{5}$').hasMatch(cleanCode)) {
      return cleanCode;
    }

    // Pattern 2: Pure numeric itemId (e.g., "12345", "67890")
    if (RegExp(r'^\d+$').hasMatch(cleanCode)) {
      return cleanCode;
    }

    // Pattern 2: JSON format with itemId field
    try {
      final jsonData = jsonDecode(cleanCode);
      if (jsonData is Map<String, dynamic>) {
        // Check for various possible itemId field names
        final itemIdFields = [
          'itemId',
          'item_id',
          'id',
          'assetId',
          'asset_id',
          'qrCode',
          'qr_code',
        ];
        for (final field in itemIdFields) {
          if (jsonData.containsKey(field)) {
            final value = jsonData[field];
            if (value is String &&
                (RegExp(r'^\d{4}_\d{5}$').hasMatch(value) ||
                    RegExp(r'^\d+$').hasMatch(value))) {
              return value;
            } else if (value is int) {
              return value.toString();
            }
          }
        }
      }
    } catch (e, st) {
      // Not JSON, continue with other patterns
    }

    // Pattern 3: URL format with itemId parameter
    if (cleanCode.contains('itemId=') ||
        cleanCode.contains('item_id=') ||
        cleanCode.contains('id=')) {
      final uri = Uri.tryParse(cleanCode);
      if (uri != null) {
        final itemId = uri.queryParameters['itemId'] ??
            uri.queryParameters['item_id'] ??
            uri.queryParameters['id'];
        if (itemId != null &&
            (RegExp(r'^\d{4}_\d{5}$').hasMatch(itemId) ||
                RegExp(r'^\d+$').hasMatch(itemId))) {
          return itemId;
        }
      }
    }

    // Pattern 4: Text format with itemId (e.g., "Asset ID: 2025_00001", "Item: 12345")
    final textPatterns = [
      RegExp(r'item[_\s]*id[:\s]*(\d{4}_\d{5})', caseSensitive: false),
      RegExp(r'asset[_\s]*id[:\s]*(\d{4}_\d{5})', caseSensitive: false),
      RegExp(r'qr[_\s]*code[:\s]*(\d{4}_\d{5})', caseSensitive: false),
      RegExp(r'id[:\s]*(\d{4}_\d{5})', caseSensitive: false),
      RegExp(r'item[_\s]*id[:\s]*(\d+)', caseSensitive: false),
      RegExp(r'asset[_\s]*id[:\s]*(\d+)', caseSensitive: false),
      RegExp(r'qr[_\s]*code[:\s]*(\d+)', caseSensitive: false),
      RegExp(r'id[:\s]*(\d+)', caseSensitive: false),
    ];

    for (final pattern in textPatterns) {
      final match = pattern.firstMatch(cleanCode);
      if (match != null && match.groupCount > 0) {
        return match.group(1);
      }
    }

    // Pattern 5: Extract asset format (YYYY_NNNNN) from anywhere in the text
    final assetFormatMatch = RegExp(r'\d{4}_\d{5}').firstMatch(cleanCode);
    if (assetFormatMatch != null) {
      return assetFormatMatch.group(0);
    }

    // Pattern 6: Extract any sequence of digits from the QR code (fallback)
    final digitMatch = RegExp(r'\d+').firstMatch(cleanCode);
    if (digitMatch != null) {
      return digitMatch.group(0);
    }

    return null; // No valid itemId found
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _processQRCode(String qrCode) async {
    try {
      // Stop scanning to prevent multiple scans
      controller?.stop();

      // If callback is provided, use it (for asset selection screen)
      if (widget.onQRCodeScanned != null) {
        widget.onQRCodeScanned!(qrCode);
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      debugPrint('ðŸ” Processing QR Code: $qrCode');

      // Extract itemId from QR code
      final itemId = _extractItemIdFromQRCode(qrCode);
      if (itemId == null) {
        // Close loading dialog
        if (mounted) {
          Navigator.pop(context);
        }
        _showErrorDialog(
          'Invalid QR Code',
          'QR code does not contain a valid itemId number.\n\nScanned: $qrCode\n\nPlease scan a QR code that contains an itemId.',
        );
        // Resume scanning - disabled for web
        // controller?.start();
        return;
      }

      debugPrint('ðŸ” Extracted itemId: $itemId');

      // Use Hybrid DAM Service for asset lookup
      Asset? asset;
      try {
        debugPrint('ðŸš€ Looking up asset using Hybrid DAM Service...');
        final hybridService = sl<HybridDamService>();
        await hybridService.initialize();
        asset = await hybridService.getAssetByQRCode(itemId);
        debugPrint('ðŸš€ Hybrid DAM Service found asset: ${asset != null}');
        debugPrint('ðŸš€ Connection method: ${hybridService.connectionMethod}');
      } catch (e, st) {
        debugPrint('âŒ Hybrid DAM Service error: $e');
      }

      // Fallback to local database if Hybrid DAM Service fails
      if (asset == null) {
        try {
          debugPrint('ðŸ“± Fallback to local database...');
          asset = await CmmsRepositories.assets.getAssetByQRCode(itemId);
          debugPrint('ðŸ“± Local database found asset: ${asset != null}');
        } catch (e, st) {
          debugPrint('âŒ Local database error: $e');
        }
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      debugPrint('âœ… Final asset found: ${asset != null}');

      if (asset != null && mounted) {
        if (widget.returnResolvedAsset) {
          Navigator.pop(context, asset);
          return;
        }
        // Offer next actions: Create Work Order or PM Task for this asset
        await _showPostScanActionSheet(context, asset);
      } else if (mounted) {
        _showErrorDialog(
          'Asset not found',
          'No asset found with itemId: $itemId\n\nChecked:\nâ€¢ Local CMMS database\nâ€¢ Persistent storage\nâ€¢ External Asset Management System\n\nPlease ensure the asset is registered in the Asset Management System.',
        );
        // Resume scanning - disabled for web
        // controller?.start();
      }
    } catch (e, st) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        _showErrorDialog(
          'Error',
          userFacingErrorMessage(
            e,
            genericMessage: 'Could not process QR code. Please try again.',
            stackTrace: st,
            contextLabel: 'MobileQrScanner: process QR',
          ),
        );
        // Resume scanning - disabled for web
        // controller?.start();
      }
    }
  }


  Future<void> _showPostScanActionSheet(
      BuildContext context, Asset asset,) async {
    final canCreatePmTask =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.canCreatePmTasks ??
            false;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.build),
              title: const Text('Create Work Order'),
              subtitle: Text('For asset: ${asset.name}'),
              onTap: () {
                Navigator.pop(ctx, 'work_order');
              },
            ),
            if (canCreatePmTask)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Create PM Task'),
                subtitle: Text('For asset: ${asset.name}'),
                onTap: () {
                  Navigator.pop(ctx, 'pm_task');
                },
              ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Asset Details'),
              subtitle: Text(
                  '${asset.name}${asset.location.isNotEmpty ? " - ${asset.location}" : ""}',),
              onTap: () {
                Navigator.pop(ctx, 'view_details');
              },
            ),
          ],
        ),
      ),
    );

    if (mounted && result != null) {
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.pop();

      switch (result) {
        case 'work_order':
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => CreateWorkRequestScreen(initialAsset: asset),
            ),
          );
          break;
        case 'pm_task':
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => CreatePMTaskScreen(initialAsset: asset),
            ),
          );
          break;
        case 'view_details':
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => AssetDetailScreen(asset: asset),
            ),
          );
          break;
      }
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showManualEntryDialog(BuildContext context) {
    final qrCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter QR Code Manually'),
        content: TextField(
          controller: qrCodeController,
          decoration: const InputDecoration(
            labelText: 'QR Code',
            hintText: 'Enter the QR code here...',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (qrCodeController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _processQRCode(qrCodeController.text.trim());
              }
            },
            child: const Text('Find Asset'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // controller?.dispose(); // Mobile scanner not available
    super.dispose();
  }
}

// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
    this.cutOutBottomOffset = 0,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..fillType = PathFillType.evenOdd
    ..addPath(getOuterPath(rect), Offset.zero);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) => Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + borderRadius)
      ..quadraticBezierTo(
        rect.left,
        rect.top,
        rect.left + borderRadius,
        rect.top,
      )
      ..lineTo(rect.right, rect.top);

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderOffset;
    final cutOutHeight =
        cutOutSize < height ? cutOutSize : height - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - cutOutWidth / 2 + borderOffset,
      rect.top + height / 2 - cutOutHeight / 2 + borderOffset,
      cutOutWidth - borderOffset * 2,
      cutOutHeight - borderOffset * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw border
    final path = Path()
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.top + borderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
        cutOutRect.left - borderOffset,
        cutOutRect.top - borderOffset,
        cutOutRect.left + borderRadius,
        cutOutRect.top - borderOffset,
      )
      ..lineTo(cutOutRect.left + borderLength, cutOutRect.top - borderOffset)
      ..moveTo(cutOutRect.right + borderOffset, cutOutRect.top + borderLength)
      ..lineTo(cutOutRect.right + borderOffset, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
        cutOutRect.right + borderOffset,
        cutOutRect.top - borderOffset,
        cutOutRect.right - borderRadius,
        cutOutRect.top - borderOffset,
      )
      ..lineTo(cutOutRect.right - borderLength, cutOutRect.top - borderOffset)
      ..moveTo(cutOutRect.left - borderOffset, cutOutRect.bottom - borderLength)
      ..lineTo(cutOutRect.left - borderOffset, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
        cutOutRect.left - borderOffset,
        cutOutRect.bottom + borderOffset,
        cutOutRect.left + borderRadius,
        cutOutRect.bottom + borderOffset,
      )
      ..lineTo(cutOutRect.left + borderLength, cutOutRect.bottom + borderOffset)
      ..moveTo(
        cutOutRect.right + borderOffset,
        cutOutRect.bottom - borderLength,
      )
      ..lineTo(
        cutOutRect.right + borderOffset,
        cutOutRect.bottom - borderRadius,
      )
      ..quadraticBezierTo(
        cutOutRect.right + borderOffset,
        cutOutRect.bottom + borderOffset,
        cutOutRect.right - borderRadius,
        cutOutRect.bottom + borderOffset,
      )
      ..lineTo(
        cutOutRect.right - borderLength,
        cutOutRect.bottom + borderOffset,
      );

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => QrScannerOverlayShape(
        borderColor: borderColor,
        borderWidth: borderWidth,
        overlayColor: overlayColor,
      );
}
