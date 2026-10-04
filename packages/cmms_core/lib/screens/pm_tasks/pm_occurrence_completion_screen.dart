import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/pm_occurrence.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pm_occurrence_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/user_facing_errors.dart';

/// Technician completion flow for Option A PM occurrences (notes + photo only).
class PmOccurrenceCompletionScreen extends StatefulWidget {
  const PmOccurrenceCompletionScreen({
    required this.occurrence,
    super.key,
  });

  final PmOccurrence occurrence;

  @override
  State<PmOccurrenceCompletionScreen> createState() =>
      _PmOccurrenceCompletionScreenState();
}

class _PmOccurrenceCompletionScreenState
    extends State<PmOccurrenceCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _completionPhoto;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickCompletionPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() {
      _completionPhoto = pickedFile;
    });
  }

  Future<void> _submitCompletion() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to complete preventive maintenance.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final pmOccurrences =
        Provider.of<PmOccurrenceProvider>(context, listen: false);
    if (!pmOccurrences.isEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduled PM completion is not available yet.'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await pmOccurrences.completeOccurrence(
        occurrenceId: widget.occurrence.id,
        completedById: currentUser.id,
        completionNotes: _notesController.text.trim(),
        completionPhoto: _completionPhoto,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preventive maintenance completed'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } on Exception catch (error, stackTrace) {
      if (!mounted) return;
      showUserErrorSnackBar(
        context,
        error,
        genericMessage: 'Could not complete preventive maintenance. Please try again.',
        stackTrace: stackTrace,
        contextLabel: 'PmOccurrenceCompletion: submit',
        backgroundColor: AppTheme.errorColor,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PmOccurrenceProvider>(
      builder: (context, pmOccurrences, _) {
        if (!pmOccurrences.isEnabled) {
          return Scaffold(
            appBar: AppBar(title: const Text('Complete Scheduled PM')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingM),
                child: Text(
                  'Scheduled PM completion is not available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return _buildForm(context, pmOccurrences);
      },
    );
  }

  Widget _buildForm(BuildContext context, PmOccurrenceProvider pmOccurrences) {
    final title = widget.occurrence.taskName.isNotEmpty
        ? widget.occurrence.taskName
        : 'Preventive maintenance';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Scheduled PM'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          children: [
            Text(
              title,
              style: AppTheme.heading2.copyWith(color: AppTheme.darkTextColor),
            ),
            if (widget.occurrence.assetName?.isNotEmpty ?? false) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(
                widget.occurrence.assetName!,
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingL),
            TextFormField(
              key: const Key('pm_occurrence_completion_notes'),
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Completion notes',
                hintText: 'Describe work performed',
                border: OutlineInputBorder(),
              ),
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Completion photo',
              style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.spacingS),
            if (_completionPhoto != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                child: kIsWeb
                    ? Image.network(
                        _completionPhoto!.path,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_completionPhoto!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: AppTheme.spacingS),
            ],
            OutlinedButton.icon(
              key: const Key('pm_occurrence_completion_add_photo'),
              onPressed: _isSubmitting ? null : _pickCompletionPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _completionPhoto == null ? 'Add photo' : 'Replace photo',
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('pm_occurrence_completion_submit'),
                onPressed: _isSubmitting ? null : _submitCompletion,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit completion'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
