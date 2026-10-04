import 'package:cmms_core/utils/work_order_cancellation_notes.dart';
import 'package:cmms_core/utils/work_order_ticket_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appendWorkOrderCancellationNote', () {
    test('returns cancellation line when notes are empty', () {
      expect(
        appendWorkOrderCancellationNote(
          existingNotes: null,
          cancellationReason: 'No longer needed',
        ),
        'Cancelled by requestor. Reason: No longer needed',
      );
    });

    test('appends cancellation line after existing notes', () {
      const existing = '''Department: N/A
Charger: Siemens
Charger ID: AST-001''';

      final result = appendWorkOrderCancellationNote(
        existingNotes: existing,
        cancellationReason: 'Duplicate request',
      );

      expect(result.startsWith(existing), isTrue);
      expect(result, contains('Cancelled by requestor. Reason: Duplicate request'));
      expect(result.split('\n\n').length, 2);
    });

    test('trims cancellation reason whitespace', () {
      expect(
        appendWorkOrderCancellationNote(
          existingNotes: 'Existing note',
          cancellationReason: '  moved location  ',
        ),
        'Existing note\n\nCancelled by requestor. Reason: moved location',
      );
    });
  });

  group('buildWorkOrderTicketNumber', () {
    test('returns WO-YYYY-NNNNN format', () {
      final ticket = buildWorkOrderTicketNumber(
        createdAt: DateTime(2026, 6, 25),
        workOrderId: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      );

      expect(RegExp(r'^WO-2026-\d{5}$').hasMatch(ticket), isTrue);
    });

    test('does not use in-memory list length', () {
      final createdAt = DateTime(2026, 6, 25, 12, 0, 0);
      final ticketA = buildWorkOrderTicketNumber(
        createdAt: createdAt,
        workOrderId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );
      final ticketB = buildWorkOrderTicketNumber(
        createdAt: createdAt,
        workOrderId: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      );

      expect(ticketA, isNot(equals(ticketB)));
    });

    test('is stable for the same inputs', () {
      final createdAt = DateTime(2026, 6, 25, 12, 0, 0);
      const workOrderId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

      expect(
        buildWorkOrderTicketNumber(
          createdAt: createdAt,
          workOrderId: workOrderId,
        ),
        buildWorkOrderTicketNumber(
          createdAt: createdAt,
          workOrderId: workOrderId,
        ),
      );
    });
  });
}
