import 'package:flutter/material.dart';

import '../screens/requestor/support/support_attachment_viewer_screen.dart';
import 'support_attachment_utils.dart';

/// Opens a support request attachment in an in-app viewer when possible.
Future<void> openSupportAttachment(
  BuildContext context,
  String url, {
  int index = 0,
}) {
  final title = supportAttachmentFileName(url, fallbackIndex: index);
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => SupportAttachmentViewerScreen(
        url: url,
        title: title,
      ),
    ),
  );
}
