import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/support_request_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';

class SupportAttachmentPicker extends StatefulWidget {
  const SupportAttachmentPicker({
    required this.attachments,
    required this.onAttachmentsChanged,
    super.key,
    this.sectionLabel = 'ATTACHMENTS',
    this.helperText,
    this.allowDocuments = true,
  });

  final List<PendingSupportAttachment> attachments;
  final ValueChanged<List<PendingSupportAttachment>> onAttachmentsChanged;
  final String sectionLabel;
  final String? helperText;
  final bool allowDocuments;

  @override
  State<SupportAttachmentPicker> createState() =>
      _SupportAttachmentPickerState();
}

class _SupportAttachmentPickerState extends State<SupportAttachmentPicker> {
  final ImagePicker _picker = ImagePicker();
  final Map<String, Uint8List> _previewBytes = {};

  @override
  void didUpdateWidget(covariant SupportAttachmentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentNames =
        widget.attachments.map((attachment) => attachment.displayName).toSet();
    _previewBytes.removeWhere((key, _) => !currentNames.contains(key));
  }

  Future<void> _capturePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;
    await _addImageAttachment(photo);
  }

  Future<void> _pickPhotosFromGallery() async {
    final photos = await _picker.pickMultiImage(imageQuality: 85);
    for (final photo in photos) {
      await _addImageAttachment(photo);
    }
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'txt',
        'csv',
        'png',
        'jpg',
        'jpeg',
        'heic',
      ],
      withData: true,
    );

    if (result == null) return;

    final updated = List<PendingSupportAttachment>.from(widget.attachments);
    for (final file in result.files) {
      final xFile = _platformFileToXFile(file);
      if (xFile == null) continue;
      updated.add(
        PendingSupportAttachment(
          file: xFile,
          displayName: file.name,
          isImage: _isImageFileName(file.name),
        ),
      );
      if (_isImageFileName(file.name)) {
        final bytes = await xFile.readAsBytes();
        if (mounted) {
          setState(() => _previewBytes[file.name] = bytes);
        }
      }
    }
    widget.onAttachmentsChanged(updated);
  }

  Future<void> _addImageAttachment(XFile photo) async {
    final bytes = await photo.readAsBytes();
    final displayName = photo.name.isNotEmpty
        ? photo.name
        : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final updated = List<PendingSupportAttachment>.from(widget.attachments)
      ..add(
        PendingSupportAttachment(
          file: photo,
          displayName: displayName,
          isImage: true,
        ),
      );

    if (mounted) {
      setState(() => _previewBytes[displayName] = bytes);
      widget.onAttachmentsChanged(updated);
    }
  }

  void _removeAttachment(int index) {
    final attachment = widget.attachments[index];
    final updated = List<PendingSupportAttachment>.from(widget.attachments)
      ..removeAt(index);
    _previewBytes.remove(attachment.displayName);
    widget.onAttachmentsChanged(updated);
  }

  XFile? _platformFileToXFile(PlatformFile file) {
    if (file.path != null && file.path!.isNotEmpty) {
      return XFile(file.path!, name: file.name);
    }
    if (file.bytes != null) {
      return XFile.fromData(
        file.bytes!,
        name: file.name,
        mimeType: file.extension,
      );
    }
    return null;
  }

  bool _isImageFileName(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.webp');
  }

  IconData _iconForAttachment(PendingSupportAttachment attachment) {
    if (attachment.isImage) return Icons.image_outlined;
    final lower = attachment.displayName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description_outlined;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.sectionLabel,
          style: AppTheme.smallText.copyWith(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 13 : 12,
            letterSpacing: 0.5,
          ),
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: AppTheme.smallText.copyWith(
              color: AppTheme.secondaryTextColor,
              fontSize: isDesktop ? 12 : 11,
            ),
          ),
        ],
        SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
        if (widget.attachments.isNotEmpty) ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.attachments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final attachment = widget.attachments[index];
              final preview = _previewBytes[attachment.displayName];

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(isDesktop ? 8 : AppTheme.radiusS),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListTile(
                  leading: preview != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            preview,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(_iconForAttachment(attachment)),
                  title: Text(
                    attachment.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.accentRed),
                    onPressed: () => _removeAttachment(index),
                    tooltip: 'Remove',
                  ),
                ),
              );
            },
          ),
          SizedBox(height: isDesktop ? 16 : AppTheme.spacingM),
        ],
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: [
            _actionButton(
              context,
              icon: Icons.camera_alt,
              label: 'Camera',
              onPressed: _capturePhoto,
            ),
            _actionButton(
              context,
              icon: Icons.photo_library,
              label: 'Gallery',
              onPressed: _pickPhotosFromGallery,
            ),
            if (widget.allowDocuments)
              _actionButton(
                context,
                icon: Icons.attach_file,
                label: 'Documents',
                onPressed: _pickDocuments,
              ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isDesktop ? 20 : 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 16 : 12,
          vertical: isDesktop ? 14 : AppTheme.spacingS,
        ),
        side: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }
}
