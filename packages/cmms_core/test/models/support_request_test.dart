import 'package:flutter_test/flutter_test.dart';

import 'package:cmms_core/models/support_request.dart';
import 'package:cmms_core/utils/support_request_validation.dart';

void main() {
  group('SupportRequest', () {
    test('round-trips through toMap and fromMap', () {
      final original = SupportRequest.create(
        type: SupportRequestType.commissioning,
        createdBy: 'user-1',
        companyId: 'company-1',
        summary: 'New site commissioning',
        scheduledDate: DateTime.utc(2026, 6, 25, 10, 30),
        address: '123 Main St',
        country: 'Qatar',
        chargerSerialNumber: 'SN-001',
        chargerModel: 'Siemens Sicharge D',
        details: 'Need onsite support',
        attachments: const ['https://example.com/file.pdf'],
      );

      final restored = SupportRequest.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.type, SupportRequestType.commissioning);
      expect(restored.summary, 'New site commissioning');
      expect(restored.country, 'Qatar');
      expect(restored.attachments, ['https://example.com/file.pdf']);
      expect(restored.createdBy, 'user-1');
    });

    test('fromMap accepts DateTime values from Supabase conversion', () {
      final createdAt = DateTime.utc(2026, 6, 28, 23, 52, 24);
      final scheduledDate = DateTime.utc(2026, 7, 1, 9, 0);

      final request = SupportRequest.fromMap({
        'id': 'req-1',
        'type': 'commissioning',
        'status': 'submitted',
        'summary': 'Site visit',
        'createdBy': 'user-1',
        'createdAt': createdAt,
        'scheduledDate': scheduledDate,
        'attachments': const ['https://example.com/file.pdf'],
      });

      expect(request.createdAt, createdAt);
      expect(request.scheduledDate, scheduledDate);
    });

    test('round-trips staffReply', () {
      final original = SupportRequest.create(
        type: SupportRequestType.knowHow,
        createdBy: 'user-1',
        topic: 'Topic',
        question: 'Question?',
      ).copyWith(staffReply: 'Thanks for your question.');

      final restored = SupportRequest.fromMap(original.toMap());

      expect(restored.staffReply, 'Thanks for your question.');
    });
  });

  group('SupportRequestValidation', () {
    test('know how requires topic and question', () {
      expect(
        SupportRequestValidation.isKnowHowValid(
          topic: 'Firmware',
          question: 'How do I update?',
        ),
        isTrue,
      );
      expect(
        SupportRequestValidation.isKnowHowValid(
          topic: ' ',
          question: 'How do I update?',
        ),
        isFalse,
      );
    });

    test('commissioning requires all mandatory fields', () {
      expect(
        SupportRequestValidation.isCommissioningValid(
          summary: 'Commission charger',
          scheduledDate: DateTime.now(),
          address: 'Doha',
          country: 'Qatar',
          chargerSerialNumber: 'SN-1',
          chargerModel: 'Kostad',
          details: 'Details',
        ),
        isTrue,
      );
      expect(
        SupportRequestValidation.isCommissioningValid(
          summary: 'Commission charger',
          scheduledDate: null,
          address: 'Doha',
          country: 'Qatar',
          chargerSerialNumber: 'SN-1',
          chargerModel: 'Kostad',
          details: 'Details',
        ),
        isFalse,
      );
    });

    test('requiredText returns inline message', () {
      expect(
        SupportRequestValidation.requiredText('', fieldLabel: 'a topic'),
        'Please enter a topic',
      );
      expect(
        SupportRequestValidation.requiredText('Valid', fieldLabel: 'a topic'),
        isNull,
      );
    });
  });
}
