enum SupportAttachmentKind {
  image,
  pdf,
  other,
}

String supportAttachmentFileName(String url, {int fallbackIndex = 0}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return 'Attachment ${fallbackIndex + 1}';
  final segment = uri.pathSegments.isNotEmpty
      ? uri.pathSegments.last
      : 'Attachment ${fallbackIndex + 1}';
  return Uri.decodeComponent(segment);
}

SupportAttachmentKind supportAttachmentKindForUrl(String url) {
  final lower = supportAttachmentFileName(url).toLowerCase();
  if (_imageExtensions.any(lower.endsWith)) {
    return SupportAttachmentKind.image;
  }
  if (lower.endsWith('.pdf')) {
    return SupportAttachmentKind.pdf;
  }
  return SupportAttachmentKind.other;
}

const _imageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.heic',
  '.heif',
};
