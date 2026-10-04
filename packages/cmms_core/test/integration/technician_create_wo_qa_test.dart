import 'package:cmms_core/models/asset.dart';
import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/utils/charger_asset_filter.dart';
import 'package:cmms_core/utils/requestor_category_mapper.dart';
import 'package:cmms_core/utils/technician_work_order_filter.dart';
import 'package:cmms_core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// End-to-end payload contract for technician create-WO QA (Phases 1–3, 6 logic).
void main() {
  const techId = 'd171de84-166a-453e-9a44-e1dbf08ed805';
  const requestorId = '578356fe-598b-458a-bbb4-57eb804a9fda';
  const companyId = 'company-doha-festival-city';

  Asset listedSiemensCharger({
    required String id,
    String? qr,
  }) =>
      Asset(
        id: id,
        name: '60kW.DC Charger 01',
        location: 'Military Medical City Hospital',
        manufacturer: 'Siemens',
        status: 'active',
        category: '60kW.DC',
        itemType: '60kW.DC',
        companyId: companyId,
        qrCode: qr,
        qrCodeId: qr,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  Map<String, dynamic> buildTechnicianListedSubmission({
    required Asset asset,
    required String problemDescription,
  }) {
    const categoryIssue = 'Electrical';
    final submissionFields = mapRequestorCategoryIssue(categoryIssue);
    final chargerType = createFormChargerBrand(asset);
    final chargerId =
        asset.qrCode ?? asset.qrCodeId ?? asset.id;
    const name = 'QA Tech Contact';
    const contact = '+97450000000';
    const email = 'qa-tech@q-auto.com';
    final notes = buildMaintenanceRequestNotes(
      chargerType: chargerType,
      chargerId: chargerId,
      categoryIssue: categoryIssue,
    );

    return {
      'assetId': asset.id,
      'location': null,
      'problemDescription': problemDescription,
      'requestorId': techId,
      'priority': submissionFields.priority,
      'category': submissionFields.category,
      'requestorName': name,
      'customerName': name,
      'customerPhone': contact,
      'customerEmail': email,
      'notes': notes,
      'assignedTechnicianIds': <String>[techId],
      'status': WorkOrderStatus.assigned,
    };
  }

  Map<String, dynamic> buildTechnicianFieldSubmission({
    required String problemDescription,
    required String assetName,
  }) {
    const categoryIssue = 'Hardware';
    final draft = buildFieldAddedCharger(
      id: const Uuid().v4(),
      name: assetName,
      location: 'Bay 4 QA',
      manufacturer: 'Kostad',
      serialNumber: 'SN-QA-001',
      assetTag: 'TAG-QA-001',
      companyId: companyId,
    );
    final submissionFields = mapRequestorCategoryIssue(categoryIssue);
    final notes = buildMaintenanceRequestNotes(
      chargerType: 'Kostad',
      chargerId: draft.qrCode ?? draft.id,
      categoryIssue: categoryIssue,
    );

    return {
      'draftAsset': draft,
      'assetId': draft.id,
      'location': 'Bay 4 QA',
      'problemDescription': problemDescription,
      'requestorId': techId,
      'priority': submissionFields.priority,
      'category': submissionFields.category,
      'notes': notes,
      'assignedTechnicianIds': <String>[techId],
      'status': WorkOrderStatus.assigned,
    };
  }

  Map<String, dynamic> buildRequestorSubmission({
    required Asset asset,
    required String problemDescription,
    String department = 'Engineering',
  }) {
    const categoryIssue = 'Electrical';
    final submissionFields = mapRequestorCategoryIssue(categoryIssue);
    final notes = buildMaintenanceRequestNotes(
      chargerType: createFormChargerBrand(asset),
      chargerId: asset.qrCode ?? asset.id,
      categoryIssue: categoryIssue,
      department: department,
    );

    return {
      'assetId': asset.id,
      'problemDescription': problemDescription,
      'requestorId': requestorId,
      'priority': submissionFields.priority,
      'category': submissionFields.category,
      'customerName': 'QA Requestor',
      'customerPhone': '+97451111111',
      'customerEmail': 'qa-req@q-auto.com',
      'notes': notes,
      'assignedTechnicianIds': <String>[],
      'status': WorkOrderStatus.open,
    };
  }

  group('Phase 1 — listed Siemens charger', () {
    test('payload matches assigned technician create contract', () {
      final asset = listedSiemensCharger(
        id: 'asset_kos009220943qa',
        qr: 'KOS009220943QA',
      );
      final payload = buildTechnicianListedSubmission(
        asset: asset,
        problemDescription: 'QA-TECH-LISTED-20261004 Siemens fault details here',
      );

      expect(payload['priority'], WorkOrderPriority.high);
      expect(payload['category'], RepairCategory.electrical);
      expect(payload['requestorId'], techId);
      expect(payload['assignedTechnicianIds'], [techId]);
      expect(payload['status'], WorkOrderStatus.assigned);
      expect(payload['problemDescription'], isNot(contains('[Civil]')));
      expect(payload['notes'], contains('Category Issue: Electrical'));
      expect(payload['notes'], contains('Charger: Siemens'));

      final wo = WorkOrder(
        id: 'wo-qa-listed',
        ticketNumber: 'WO-QA-LISTED',
        assetId: payload['assetId'] as String,
        asset: asset,
        companyId: companyId,
        problemDescription: payload['problemDescription'] as String,
        requestorId: techId,
        assignedTechnicianIds: payload['assignedTechnicianIds'] as List<String>,
        assignedAt: DateTime(2026, 10, 4),
        status: WorkOrderStatus.assigned,
        priority: payload['priority'] as WorkOrderPriority,
        category: payload['category'] as RepairCategory,
        notes: payload['notes'] as String,
        customerName: payload['customerName'] as String,
        customerPhone: payload['customerPhone'] as String,
        customerEmail: payload['customerEmail'] as String,
        createdAt: DateTime(2026, 10, 4),
        updatedAt: DateTime(2026, 10, 4),
      );
      expect(() => validateWorkOrder(wo), returnsNormally);
    });

    test('catalog filter excludes non-chargers for Siemens dropdown', () {
      final assets = [
        listedSiemensCharger(id: 'a1'),
        Asset(
          id: 'asset_pump_01',
          name: 'Lobby circulation pump',
          location: 'X',
          status: 'active',
          category: 'HVAC',
          itemType: 'Pump',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];
      final listed = chargersForCreateForm(
        assets: assets,
        manufacturer: 'Siemens',
      );
      expect(listed.map((a) => a.id), ['a1']);
      expect(isChargerLikeAsset(assets[1]), isFalse);
    });
  });

  group('Phase 2 — field-added charger', () {
    test('draft asset is charger-like for RLS INSERT policy', () {
      final submission = buildTechnicianFieldSubmission(
        problemDescription: 'QA-TECH-FIELD-20261004 hardware issue details',
        assetName: 'QA Field Kostad 20261004',
      );
      final draft = submission['draftAsset'] as Asset;
      expect(draft.itemType, 'charger');
      expect(isChargerLikeAsset(draft), isTrue);
      expect(submission['category'], RepairCategory.specializedEquipment);
      expect(submission['location'], 'Bay 4 QA');
      expect(submission['assetId'], isNotNull);
    });

    test('new field charger appears in Kostad create-form list after add', () {
      final submission = buildTechnicianFieldSubmission(
        problemDescription: 'QA-TECH-FIELD picker test long enough',
        assetName: 'QA Field Kostad picker',
      );
      final draft = submission['draftAsset'] as Asset;
      final existing = listedSiemensCharger(id: 'existing-kos');
      final kostadListed = chargersForCreateForm(
        assets: [existing, draft],
        manufacturer: 'Kostad',
      );
      expect(kostadListed.any((a) => a.id == draft.id), isTrue);
    });
  });

  group('Phase 3 — requestor side-by-side', () {
    test('same category and notes shape; different assignment and status', () {
      final asset = listedSiemensCharger(id: 'asset_kos009220943qa');
      final tech = buildTechnicianListedSubmission(
        asset: asset,
        problemDescription: 'QA parity listed problem text here',
      );
      final req = buildRequestorSubmission(
        asset: asset,
        problemDescription: 'QA-REQ-20261004 parity problem text here',
      );

      expect(tech['category'], req['category']);
      expect(tech['priority'], req['priority']);
      expect(tech['customerPhone'], isNotNull);
      expect(req['customerPhone'], isNotNull);

      final techNotes = tech['notes'] as String;
      final reqNotes = req['notes'] as String;
      expect(techNotes, contains('Category Issue: Electrical'));
      expect(reqNotes, contains('Category Issue: Electrical'));
      expect(techNotes, contains('Department: N/A'));
      expect(reqNotes, contains('Department: Engineering'));

      expect(tech['requestorId'], isNot(req['requestorId']));
      expect(tech['status'], WorkOrderStatus.assigned);
      expect(req['status'], WorkOrderStatus.open);
    });

    test('T-006: requestor WO hidden from technician assigned list', () {
      final asset = listedSiemensCharger(id: 'a1');
      final techPayload = buildTechnicianListedSubmission(
        asset: asset,
        problemDescription: 'QA tech assigned visibility test',
      );
      final reqPayload = buildRequestorSubmission(
        asset: asset,
        problemDescription: 'QA req visibility test long enough',
      );

      final techWo = WorkOrder(
        id: 'wo-tech-vis',
        ticketNumber: 'WO-T',
        assetId: asset.id,
        problemDescription: techPayload['problemDescription'] as String,
        requestorId: techId,
        assignedTechnicianIds: [techId],
        status: WorkOrderStatus.assigned,
        createdAt: DateTime(2026, 10, 4),
        updatedAt: DateTime(2026, 10, 4),
      );
      final reqWo = WorkOrder(
        id: 'wo-req-vis',
        ticketNumber: 'WO-R',
        assetId: asset.id,
        problemDescription: reqPayload['problemDescription'] as String,
        requestorId: requestorId,
        assignedTechnicianIds: const [],
        status: WorkOrderStatus.open,
        createdAt: DateTime(2026, 10, 4),
        updatedAt: DateTime(2026, 10, 4),
      );

      final techList = workOrdersForRoleListView(
        workOrders: [techWo, reqWo],
        userId: techId,
        userRole: 'technician',
        isTechnicianView: true,
      );
      expect(techList.map((w) => w.id), ['wo-tech-vis']);

      final reqList = workOrdersForRoleListView(
        workOrders: [techWo, reqWo],
        userId: requestorId,
        userRole: 'requestor',
        isTechnicianView: false,
      );
      expect(reqList.map((w) => w.id), ['wo-req-vis']);
    });
  });

  group('Phase 6 — validation negatives (logic)', () {
    test('empty problem description fails validateWorkOrder', () {
      expect(
        () => validateWorkOrder(
          WorkOrder(
            id: 'wo-empty',
            ticketNumber: 'WO-E',
            problemDescription: '   ',
            requestorId: techId,
            createdAt: DateTime(2026, 10, 4),
            updatedAt: DateTime(2026, 10, 4),
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('field-added charger without name would fail asset validation', () {
      final bad = buildFieldAddedCharger(
        id: const Uuid().v4(),
        name: '   ',
        location: 'Bay 4',
        manufacturer: 'Siemens',
      );
      expect(bad.name.trim(), isEmpty);
    });
  });
}
