import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/support_request.dart';
import 'app_theme.dart';

class SupportRequestDisplay {
  static final DateFormat _submittedFormat = DateFormat('dd MMM yyyy, HH:mm');

  static String typeLabel(SupportRequestType type) {
    return switch (type) {
      SupportRequestType.knowHow => 'Know How',
      SupportRequestType.commissioning => 'Commissioning',
    };
  }

  static String statusLabel(SupportRequestStatus status) {
    return switch (status) {
      SupportRequestStatus.submitted => 'Submitted',
      SupportRequestStatus.open => 'Open',
      SupportRequestStatus.inProgress => 'In progress',
      SupportRequestStatus.resolved => 'Resolved',
      SupportRequestStatus.closed => 'Closed',
    };
  }

  static String cardTitle(SupportRequest request) {
    if (request.type == SupportRequestType.knowHow) {
      final topic = request.topic?.trim();
      if (topic != null && topic.isNotEmpty) return topic;
    }
    final summary = request.summary?.trim();
    if (summary != null && summary.isNotEmpty) return summary;
    return typeLabel(request.type);
  }

  static String formatSubmittedDate(DateTime date) =>
      _submittedFormat.format(date.toLocal());

  static Color statusColor(SupportRequestStatus status) {
    return switch (status) {
      SupportRequestStatus.submitted => AppTheme.accentBlue,
      SupportRequestStatus.open => AppTheme.workOrderStatusOpen,
      SupportRequestStatus.inProgress => AppTheme.workOrderStatusInProgress,
      SupportRequestStatus.resolved => AppTheme.workOrderStatusCompleted,
      SupportRequestStatus.closed => AppTheme.workOrderStatusClosed,
    };
  }
}
