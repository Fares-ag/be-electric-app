import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/countries.dart';
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

class CommissioningSupportScreen extends StatefulWidget {
  const CommissioningSupportScreen({super.key});

  @override
  State<CommissioningSupportScreen> createState() =>
      _CommissioningSupportScreenState();
}

class _CommissioningSupportScreenState
    extends State<CommissioningSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _addressController = TextEditingController();
  final _serialController = TextEditingController();
  final _modelController = TextEditingController();
  final _detailsController = TextEditingController();
  final _dateFormat = DateFormat('dd MMM yyyy, HH:mm');

  String? _selectedCountry;
  DateTime? _scheduledDate;
  String? _dateError;
  List<PendingSupportAttachment> _attachments = [];

  @override
  void dispose() {
    _summaryController.dispose();
    _addressController.dispose();
    _serialController.dispose();
    _modelController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDate ?? now),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    if (_scheduledDate == null) {
      setState(
        () => _dateError = SupportRequestValidation.requiredDate(null),
      );
    }

    if (!_formKey.currentState!.validate() || _scheduledDate == null) {
      return;
    }

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
      await provider.submitCommissioningRequest(
        createdBy: user.id,
        companyId: user.companyId,
        summary: _summaryController.text,
        scheduledDate: _scheduledDate!,
        address: _addressController.text,
        country: _selectedCountry!,
        chargerSerialNumber: _serialController.text,
        chargerModel: _modelController.text,
        details: _detailsController.text,
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
          contextLabel: 'CommissioningSupportScreen: submit',
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
                    ? 'Uploading documents (${(progress * 100).round()}%)...'
                    : 'Uploading documents...';

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
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final isSubmitting =
        context.watch<SupportRequestProvider>().isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: 'Commissioning',
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
            autovalidateMode: AutovalidateMode.disabled,
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SupportFormField(
                    label: 'SUMMARY',
                    controller: _summaryController,
                    hintText: 'Short summary of the commissioning request',
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'a summary',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DATE',
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 13 : 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 10 : AppTheme.spacingS),
                      InkWell(
                        onTap: isSubmitting ? null : _pickDateTime,
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 8 : AppTheme.radiusS,
                        ),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            errorText: _dateError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 8 : AppTheme.radiusS,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 8 : AppTheme.radiusS,
                              ),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                              ),
                            ),
                            suffixIcon:
                                const Icon(Icons.calendar_today_outlined),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 20 : 16,
                              vertical: isDesktop ? 16 : 12,
                            ),
                          ),
                          child: Text(
                            _scheduledDate == null
                                ? 'Select date and time'
                                : _dateFormat.format(_scheduledDate!),
                            style: TextStyle(
                              color: _scheduledDate == null
                                  ? Colors.grey[400]
                                  : Colors.black,
                              fontSize: isDesktop ? 15 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportFormField(
                    label: 'CHARGING STATION ADDRESS',
                    controller: _addressController,
                    hintText: 'Street, city, postal code',
                    maxLines: 2,
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'the charging station address',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportCountryDropdown(
                    label: 'COUNTRY',
                    value: _selectedCountry,
                    countries: Countries.all,
                    onChanged: (value) {
                      if (isSubmitting) return;
                      setState(() => _selectedCountry = value);
                    },
                    validator: (value) =>
                        SupportRequestValidation.requiredSelection(
                      value,
                      fieldLabel: 'a country',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportFormField(
                    label: 'CHARGER SERIAL NUMBER',
                    controller: _serialController,
                    hintText: 'Serial number on the charger',
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'the charger serial number',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportFormField(
                    label: 'CHARGER MODEL',
                    controller: _modelController,
                    hintText: 'Charger model name',
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'the charger model',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportFormField(
                    label: 'DETAILS',
                    controller: _detailsController,
                    hintText: 'Additional commissioning details',
                    maxLines: 5,
                    validator: (value) => SupportRequestValidation.requiredText(
                      value,
                      fieldLabel: 'commissioning details',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  SupportAttachmentPicker(
                    sectionLabel: 'DOCUMENTS',
                    attachments: _attachments,
                    onAttachmentsChanged: (attachments) {
                      setState(() => _attachments = attachments);
                    },
                    helperText:
                        'Attach site photos, PDFs, Word, Excel, or other documents.',
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
