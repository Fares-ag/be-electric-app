import 'package:cmms_core/models/asset.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/pm_work_item.dart';
import 'package:cmms_core/utils/requestor_pm_work_item_scope.dart';
import 'package:flutter_test/flutter_test.dart';

Asset _asset(String id, {String companyId = 'company-1'}) => Asset(
      id: id,
      name: 'Charger $id',
      location: 'Bay 1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      companyId: companyId,
    );

PmWorkItem _occurrenceItem({
  required String id,
  required String assetId,
  String status = 'pending',
}) =>
    PmWorkItem.fromOccurrence(
      PmOccurrence.fromMap({
        'id': id,
        'scheduleId': 'sched-$id',
        'assetId': assetId,
        'dueDate': DateTime.utc(2026, 6, 20),
        'status': status,
        'schedule': {
          'id': 'sched-$id',
          'taskName': 'Monthly PM',
          'frequency': 'monthly',
          'frequencyValue': 30,
          'scheduleStartDate': DateTime.utc(2026, 1, 1),
          'scheduleEndDate': DateTime.utc(2026, 12, 31),
        },
        'asset': {
          'name': 'Charger $assetId',
        },
      }),
      referenceDate: DateTime.utc(2026, 6, 25),
    );

void main() {
  group('scopeRequestorPmWorkItems', () {
    test('returns only items linked to authorized assets', () {
      final inbox = [
        _occurrenceItem(id: 'occ-1', assetId: 'asset-1'),
        _occurrenceItem(id: 'occ-2', assetId: 'asset-2'),
      ];

      final scoped = scopeRequestorPmWorkItems(
        inbox,
        authorizedAssets: [_asset('asset-1')],
      );

      expect(scoped, hasLength(1));
      expect(scoped.first.id, 'occ-1');
    });

    test('drops items with missing asset ids', () {
      final legacy = PmWorkItem.fromLegacyTask(
        PMTask(
          id: 'legacy-1',
          taskName: 'Legacy PM',
          description: 'Test',
          frequency: PMTaskFrequency.monthly,
          intervalDays: 30,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final scoped = scopeRequestorPmWorkItems(
        [legacy],
        authorizedAssets: [_asset('asset-1')],
      );

      expect(scoped, isEmpty);
    });

    test('returns empty list when no authorized assets exist', () {
      final scoped = scopeRequestorPmWorkItems(
        [_occurrenceItem(id: 'occ-1', assetId: 'asset-1')],
        authorizedAssets: const [],
      );

      expect(scoped, isEmpty);
    });
  });

  group('groupRequestorPmWorkItemsByAsset', () {
    test('groups items by asset label', () {
      final grouped = groupRequestorPmWorkItemsByAsset([
        _occurrenceItem(id: 'occ-1', assetId: 'asset-1'),
        _occurrenceItem(id: 'occ-2', assetId: 'asset-2'),
      ]);

      expect(grouped.keys, hasLength(2));
      expect(grouped['Charger asset-1'], hasLength(1));
    });
  });
}
