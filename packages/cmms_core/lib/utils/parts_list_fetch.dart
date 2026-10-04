import 'dart:convert';

import '../models/parts_request.dart';

/// Result of falling back to SharedPreferences after a cloud list failure.
class PartsListFallback {
  const PartsListFallback({
    required this.requests,
    required this.fromCache,
    required this.errorMessage,
  });

  final List<PartsRequest> requests;
  final bool fromCache;
  final String errorMessage;
}

/// Parse prefs JSON and build a non-silent fallback for BE-QA-OFF-003.
PartsListFallback resolvePartsListFallback({
  required Object error,
  required List<String> prefsJson,
}) {
  final requests = <PartsRequest>[];
  for (final json in prefsJson) {
    try {
      requests.add(PartsRequest.fromMap(jsonDecode(json) as Map<String, dynamic>));
    } catch (_) {
      // Skip corrupt rows.
    }
  }
  return PartsListFallback(
    requests: requests,
    fromCache: true,
    errorMessage:
        'Showing cached parts requests. Cloud refresh failed: $error',
  );
}
