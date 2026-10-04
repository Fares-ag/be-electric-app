import 'package:flutter/material.dart';

import '../../models/support_request.dart';
import '../../utils/app_theme.dart';
import '../../utils/support_request_display.dart';
import 'support_request_status_badge.dart';

class SupportRequestListCard extends StatelessWidget {
  const SupportRequestListCard({
    required this.request,
    required this.onTap,
    super.key,
  });

  final SupportRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = SupportRequestDisplay.cardTitle(request);
    final chargerModel = request.chargerModel?.trim();
    final attachmentCount = request.attachments.length;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      SupportRequestDisplay.typeLabel(request.type),
                      style: AppTheme.smallText.copyWith(
                        color: AppTheme.secondaryTextColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  SupportRequestStatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                title,
                style: AppTheme.heading2.copyWith(fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                SupportRequestDisplay.formatSubmittedDate(request.createdAt),
                style: AppTheme.bodyText.copyWith(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
              if (chargerModel != null && chargerModel.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Charger model: $chargerModel',
                  style: AppTheme.bodyText.copyWith(
                    color: AppTheme.secondaryTextColor,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppTheme.spacingS),
              Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 16,
                    color: AppTheme.secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    attachmentCount == 1
                        ? '1 attachment'
                        : '$attachmentCount attachments',
                    style: AppTheme.bodyText.copyWith(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.secondaryTextColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
