/// Heuristic for errors that should fall back to the offline sync queue.
bool isLikelyNetworkError(Object error) {
  final s = error.toString().toLowerCase();
  return s.contains('socket') ||
      s.contains('network') ||
      s.contains('failed host lookup') ||
      s.contains('connection refused') ||
      s.contains('connection reset') ||
      s.contains('connection closed') ||
      s.contains('timed out') ||
      s.contains('timeout') ||
      s.contains('clientexception') ||
      s.contains('handshake') ||
      s.contains('unreachable') ||
      s.contains('offline');
}

/// True when [path] looks like a local filesystem path (not a remote URL).
bool isLocalFilePath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final p = path.trim().toLowerCase();
  if (p.startsWith('http://') || p.startsWith('https://')) return false;
  if (p.startsWith('data:')) return false;
  return true;
}

/// Collect local photo paths from a work order completion / problem photo fields.
List<String> collectLocalPhotoPaths({
  List<String>? completionPhotoPaths,
  String? completionPhotoPath,
  List<String>? photoPaths,
  String? photoPath,
}) {
  final out = <String>[];
  void add(String? p) {
    if (isLocalFilePath(p) && !out.contains(p)) out.add(p!);
  }

  if (completionPhotoPaths != null) {
    for (final p in completionPhotoPaths) {
      add(p);
    }
  }
  add(completionPhotoPath);
  if (photoPaths != null) {
    for (final p in photoPaths) {
      add(p);
    }
  }
  add(photoPath);
  return out;
}
