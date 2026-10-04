import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/support_request_provider.dart';
import '../../../services/support_request_service.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/requestor_home_navigation.dart';
import '../../../utils/responsive_layout.dart';
import '../../../utils/support_request_validation.dart';
import '../../../utils/user_facing_errors.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/requestor_more_menu.dart';
import '../../../widgets/support/support_attachment_picker.dart';
import '../../../widgets/support/support_form_field.dart';

class KnowHowSupportScreen extends StatefulWidget {
  const KnowHowSupportScreen({super.key});

  @override
  State<KnowHowSupportScreen> createState() => _KnowHowSupportScreenState();
}

class _KnowHowSupportScreenState extends State<KnowHowSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  final _questionController = TextEditingController();
  final _chargerModelController = TextEditingController();
  List<PendingSupportAttachment> _attachments = [];

  @override
  void dispose() {
    _topicController.dispose();
    _questionController.dispose();
    _chargerModelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) {
      showUserErrorSnackBar(
        context,
        Exception('Not logged in'),
        genericMessage: 'Please sign in to submit a support request.',
      );
      return;
    }

    final provider = Provider.of<SupportRequestProvider>(
      context,
      listen: false,
    );
    if (provider.isSubmitting) return;

    _showLoadingDialog(provider);

    try {
      await provider.submitKnowHowRequest(
        createdBy: user.id,
        companyId: user.companyId,
        topic: _topicController.text,
        question: _questionController.text,
        chargerModel: _chargerModelController.text,
        attachments: _attachments,
      );

      if (mounted) {
        Navigator.of(context).pop(); // loading dialog
        Navigator.of(context).pop(true);
      }
    } catch (e, st) {
      if (mounted) {
        Navigator.of(context).pop(); // loading dialog
        showUserErrorSnackBar(
          context,
          e,
          genericMessage:
              'Could not submit your support request. Please try again.',
          stackTrace: st,
          contextLabel: 'KnowHowSupportScreen: submit',
        );
      }
    }
  }

  void _showLoadingDialog(SupportRequestProvider provider) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: provider,
          builder: (context, _) {
            final progress = provider.uploadProgress;
            final message = _attachments.isEmpty
                ? 'Submitting request...'
                : progress > 0
                    ? 'Uploading attachments (${(progress * 100).round()}%)...'
                    : 'Uploading attachments...';

            return AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Expanded(child: Text(message)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);
    final isSubmitting =
        context.watch<SupportRequestProvider>().isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'Know How',
        usePageTitle: true,
        showMenu: false,
        showBackButton: true,
        onMoreTap: () {
          showRequestorMoreMenu(
            context,
            primaryLabel: 'Home',
            primaryIcon: Icons.home_outlined,
            onPrimaryNav: () => navigateToRequestorMain(context),
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SupportFormField(
                    label: 'TOPIC',
                    controller: _topicController,
                    hintText: 'Brief subject for your question',
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'a topic',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportFormField(
                    label: 'QUESTION',
                    controller: _questionController,
                    hintText: 'Describe your question or issue',
                    maxLines: 5,
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'your question',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportFormField(
                    label: 'CHARGER MODEL (optional)',
                    controller: _chargerModelController,
                    hintText: 'e.g. Siemens Sicharge D',
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportAttachmentPicker(
                    attachments: _attachments,
                    onAttachmentsChanged: (attachments) {
                      setState(() => _attachments = attachments);
                    },
                    helperText:
                        'Add images, PDFs, or documents to help us assist you.',
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isSubmitting ? null : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
