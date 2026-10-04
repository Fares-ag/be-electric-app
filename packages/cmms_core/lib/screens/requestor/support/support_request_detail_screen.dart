import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/support_request.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/requestor_home_navigation.dart';
import '../../../utils/responsive_layout.dart';
import '../../../utils/support_attachment_launcher.dart';
import '../../../utils/support_attachment_utils.dart';
import '../../../utils/support_request_display.dart';
import '../../../widgets/custom_app_bar.dart';
import '../../../widgets/requestor_more_menu.dart';
import '../../../widgets/support/support_request_status_badge.dart';

class SupportRequestDetailScreen extends StatelessWidget {
  const SupportRequestDetailScreen({
    required this.request,
    super.key,
  });

  final SupportRequest request;

  static final _scheduledDateFormat = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.getResponsivePadding(context);
    final maxWidth = ResponsiveLayout.getMaxContentWidth(context);
    final staffReply = request.staffReply?.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: CustomAppBar(
        title: SupportRequestDisplay.typeLabel(request.type),
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
          child: SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                SupportRequestDisplay.cardTitle(request),
                                style: AppTheme.heading2.copyWith(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            SupportRequestStatusBadge(status: request.status),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Submitted ${SupportRequestDisplay.formatSubmittedDate(request.createdAt)}',
                          style: AppTheme.bodyText.copyWith(
                            color: AppTheme.secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                if (request.type == SupportRequestType.knowHow) ...[
                  _DetailSection(
                    title: 'Topic',
                    value: request.topic,
                  ),
                  _DetailSection(
                    title: 'Question',
                    value: request.question,
                    multiline: true,
                  ),
                  if (_hasText(request.chargerModel))
                    _DetailSection(
                      title: 'Charger model',
                      value: request.chargerModel,
                    ),
                ] else ...[
                  _DetailSection(
                    title: 'Summary',
                    value: request.summary,
                  ),
                  if (request.scheduledDate != null)
                    _DetailSection(
                      title: 'Scheduled date',
                      value: _scheduledDateFormat.format(
                        request.scheduledDate!.toLocal(),
                      ),
                    ),
                  _DetailSection(
                    title: 'Charging station address',
                    value: request.address,
                    multiline: true,
                  ),
                  _DetailSection(
                    title: 'Country',
                    value: request.country,
                  ),
                  _DetailSection(
                    title: 'Charger serial number',
                    value: request.chargerSerialNumber,
                  ),
                  _DetailSection(
                    title: 'Charger model',
                    value: request.chargerModel,
                  ),
                  _DetailSection(
                    title: 'Details',
                    value: request.details,
                    multiline: true,
                  ),
                ],
                if (staffReply != null && staffReply.isNotEmpty)
                  _DetailSection(
                    title: 'Response from Be Electric',
                    value: staffReply,
                    multiline: true,
                    highlight: true,
                  ),
                _AttachmentsSection(
                  attachments: request.attachments,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.value,
    this.multiline = false,
    this.highlight = false,
  });

  final String title;
  final String? value;
  final bool multiline;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Card(
        color: highlight ? AppTheme.accentGreen.withValues(alpha: 0.06) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                text,
                style: AppTheme.bodyText.copyWith(
                  fontSize: 14,
                  height: multiline ? 1.45 : 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.attachments});

  final List<String> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppTheme.spacingM),
          child: Text('No attachments'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ATTACHMENTS',
              style: AppTheme.smallText.copyWith(
                color: AppTheme.secondaryTextColor,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ...attachments.asMap().entries.map((entry) {
              final index = entry.key;
              final url = entry.value;
              final name = supportAttachmentFileName(url, fallbackIndex: index);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attach_file),
                title: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.visibility_outlined, size: 20),
                onTap: () => openSupportAttachment(context, url, index: index),
              );
            }),
          ],
        ),
      ),
    );
  }
}
