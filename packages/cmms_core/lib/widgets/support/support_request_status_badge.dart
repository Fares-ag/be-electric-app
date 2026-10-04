import 'package:flutter/material.dart';

import '../../models/support_request.dart';
import '../../utils/app_theme.dart';
import '../../utils/support_request_display.dart';

class SupportRequestStatusBadge extends StatelessWidget {
  const SupportRequestStatusBadge({
    required this.status,
    super.key,
  });

  final SupportRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = SupportRequestDisplay.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        SupportRequestDisplay.statusLabel(status),
        style: AppTheme.smallText.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
