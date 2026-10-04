import 'dart:convert';

import 'package:cmms_core/models/parts_request.dart';
import 'package:cmms_core/utils/parts_list_fetch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolvePartsListFallback', () {
    test('marks fromCache and keeps parseable rows', () {
      final now = DateTime.utc(2026, 7, 20);
      final request = PartsRequest(
        id: 'pr-1',
        workOrderId: 'wo-1',
        technicianId: 'tech-1',
        inventoryItemId: 'inv-1',
        quantity: 2,
        reason: 'need',
        priority: PartsRequestPriority.medium,
        status: PartsRequestStatus.pending,
        requestedAt: now,
        updatedAt: now,
      );

      final fallback = resolvePartsListFallback(
        error: Exception('SocketException: offline'),
        prefsJson: [
          jsonEncode(request.toMap()),
          '{not-json',
        ],
      );

      expect(fallback.fromCache, isTrue);
      expect(fallback.requests, hasLength(1));
      expect(fallback.requests.first.id, 'pr-1');
      expect(fallback.errorMessage, contains('Cloud refresh failed'));
      expect(fallback.errorMessage, contains('SocketException'));
    });

    test('empty prefs still signals cache fallback', () {
      final fallback = resolvePartsListFallback(
        error: 'timeout',
        prefsJson: const [],
      );
      expect(fallback.fromCache, isTrue);
      expect(fallback.requests, isEmpty);
    });
  });
}
