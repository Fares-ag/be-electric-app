import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/legal_links.dart';
import '../../../utils/remote_storage_loader.dart';
import '../../../utils/support_attachment_utils.dart';
import '../../../utils/user_facing_errors.dart';
import '../../../widgets/authenticated_image.dart';

class SupportAttachmentViewerScreen extends StatelessWidget {
  const SupportAttachmentViewerScreen({
    required this.url,
    required this.title,
    super.key,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    switch (supportAttachmentKindForUrl(url)) {
      case SupportAttachmentKind.image:
        return _ImageAttachmentViewer(url: url, title: title);
      case SupportAttachmentKind.pdf:
        return _PdfAttachmentViewer(url: url, title: title);
      case SupportAttachmentKind.other:
        return _UnsupportedAttachmentViewer(url: url, title: title);
    }
  }
}

class _ImageAttachmentViewer extends StatelessWidget {
  const _ImageAttachmentViewer({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: AuthenticatedImage(
            imageUrl: url,
            fit: BoxFit.contain,
            errorWidget: const Icon(Icons.error_outline, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PdfAttachmentViewer extends StatefulWidget {
  const _PdfAttachmentViewer({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<_PdfAttachmentViewer> createState() => _PdfAttachmentViewerState();
}

class _PdfAttachmentViewerState extends State<_PdfAttachmentViewer> {
  Uint8List? _pdfBytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final bytes = await RemoteStorageLoader.loadBytes(widget.url);
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _error = null;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = e);
      debugPrint('SupportAttachmentViewerScreen: PDF load failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Could not open this PDF in the app.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: AppTheme.spacingM),
              FilledButton(
                onPressed: () => launchLegalUrl(
                  context,
                  widget.url,
                  missingMessage: 'Attachment link is not available.',
                ),
                child: const Text('Open externally'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PdfPreview(
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      allowPrinting: false,
      allowSharing: true,
      pdfFileName: widget.title,
      build: (format) async => _pdfBytes!,
    );
  }
}

class _UnsupportedAttachmentViewer extends StatelessWidget {
  const _UnsupportedAttachmentViewer({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 56,
                color: AppTheme.secondaryTextColor.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTheme.heading2.copyWith(fontSize: 16),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'This file type cannot be previewed in the app.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FilledButton.icon(
                onPressed: () async {
                  final opened = await launchLegalUrl(
                    context,
                    url,
                    missingMessage: 'Attachment link is not available.',
                  );
                  if (!opened && context.mounted) {
                    showUserErrorSnackBar(
                      context,
                      Exception('Could not open attachment'),
                      genericMessage: 'Could not open this attachment.',
                    );
                  }
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open externally'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
