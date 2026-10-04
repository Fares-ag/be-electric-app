import 'package:cmms_core/models/asset.dart';
import 'package:cmms_core/models/work_order.dart';
import 'package:cmms_core/utils/charger_asset_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Asset _charger({
  required String name,
  String? manufacturer,
  String? vendor,
}) {
  final now = DateTime(2024, 6, 1);
  return Asset(
    id: 'asset-1',
    name: name,
    location: 'C, FF',
    status: 'active',
    itemType: 'charger',
    category: 'charger',
    manufacturer: manufacturer,
    vendor: vendor,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('deriveChargerManufacturerFromName', () {
    test('KOS prefix maps to Kostad', () {
      expect(
        deriveChargerManufacturerFromName('KOS002220713QA'),
        'Kostad',
      );
      expect(deriveChargerManufacturerFromName('kos123'), 'Kostad');
    });

    test('non-KOS names map to Siemens', () {
      expect(
        deriveChargerManufacturerFromName('Siemens Charger #001'),
        'Siemens',
      );
      expect(deriveChargerManufacturerFromName('KEC00067'), 'Siemens');
    });

    test('empty name defaults to Siemens', () {
      expect(deriveChargerManufacturerFromName(''), 'Siemens');
      expect(deriveChargerManufacturerFromName('   '), 'Siemens');
    });
  });

  group('resolveChargerManufacturer', () {
    test('prefers DB manufacturer over KOS name prefix', () {
      final asset = _charger(
        name: 'KOS002220713QA',
        manufacturer: 'Siemens',
      );
      expect(resolveChargerManufacturer(asset), 'Siemens');
    });

    test('uses Kostad from DB when set', () {
      final asset = _charger(
        name: 'Siemens Charger #001',
        manufacturer: 'Kostad',
      );
      expect(resolveChargerManufacturer(asset), 'Kostad');
    });

    test('falls back to KOS name rule when DB manufacturer is empty', () {
      final asset = _charger(name: 'KOS002220713QA');
      expect(resolveChargerManufacturer(asset), 'Kostad');
    });

    test('falls back to vendor when not charger-like', () {
      final now = DateTime(2024, 6, 1);
      final asset = Asset(
        id: 'hvac-1',
        name: 'AHU-12',
        location: 'Roof',
        status: 'active',
        itemType: 'hvac',
        vendor: 'Carrier',
        createdAt: now,
        updatedAt: now,
      );
      expect(resolveChargerManufacturer(asset), 'Carrier');
    });
  });

  group('matchesChargerBrand', () {
    test('matches Siemens from DB when KOS name would imply Kostad', () {
      final asset = _charger(
        name: 'KOS002220713QA',
        manufacturer: 'Siemens',
      );
      expect(matchesChargerBrand(asset, 'Siemens'), isTrue);
      expect(matchesChargerBrand(asset, 'Kostad'), isFalse);
    });

    test('matches Kostad from DB when set', () {
      final asset = _charger(
        name: 'Siemens Charger #001',
        manufacturer: 'Kostad',
      );
      expect(matchesChargerBrand(asset, 'Kostad'), isTrue);
      expect(matchesChargerBrand(asset, 'Siemens'), isFalse);
    });

    test('uses name rule when DB manufacturer is empty', () {
      final asset = _charger(name: 'EV-001');
      expect(matchesChargerBrand(asset, 'Siemens'), isTrue);
      expect(matchesChargerBrand(asset, 'Kostad'), isFalse);
    });
  });

  group('resolveWorkOrderChargerManufacturer', () {
    test('derives from hydrated asset name', () {
      final wo = WorkOrder(
        id: 'wo-1',
        ticketNumber: 'WO-1',
        problemDescription: 'Fault',
        requestorId: 'user-1',
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
        asset: _charger(name: 'KOS001', manufacturer: 'Siemens'),
      );
      expect(resolveWorkOrderChargerManufacturer(wo), 'Siemens');
    });

    test('returns null when asset is not hydrated', () {
      final wo = WorkOrder(
        id: 'wo-2',
        ticketNumber: 'WO-2',
        problemDescription: 'Fault',
        requestorId: 'user-1',
        createdAt: DateTime(2024, 6, 1),
        updatedAt: DateTime(2024, 6, 1),
        assetId: 'asset-1',
      );
      expect(resolveWorkOrderChargerManufacturer(wo), isNull);
    });
  });

  group('chargersForCreateForm', () {
    final now = DateTime(2024, 6, 1);
    Asset charger({
      required String id,
      required String name,
      required String manufacturer,
      required String companyId,
    }) =>
        Asset(
          id: id,
          name: name,
          location: 'C, FF',
          status: 'active',
          itemType: 'charger',
          category: 'charger',
          manufacturer: manufacturer,
          companyId: companyId,
          createdAt: now,
          updatedAt: now,
        );

    final siemens = charger(
      id: 's1',
      name: 'Sicharge 1',
      manufacturer: 'Siemens',
      companyId: 'co-1',
    );
    final kostad = charger(
      id: 'k1',
      name: 'KOS001',
      manufacturer: 'Kostad',
      companyId: 'co-1',
    );
    final otherCompany = charger(
      id: 's2',
      name: 'Sicharge 2',
      manufacturer: 'Siemens',
      companyId: 'co-2',
    );
    final hvac = Asset(
      id: 'hvac-1',
      name: 'AHU-12',
      location: 'Roof',
      status: 'active',
      itemType: 'hvac',
      companyId: 'co-1',
      createdAt: now,
      updatedAt: now,
    );

    test('technician catalog is chargers of the selected brand only', () {
      final result = chargersForCreateForm(
        assets: [siemens, kostad, otherCompany, hvac],
        manufacturer: 'Siemens',
      );

      expect(result.map((a) => a.id), ['s1', 's2']);
    });

    test('requestor catalog stays company-scoped', () {
      final result = chargersForCreateForm(
        assets: [siemens, kostad, otherCompany, hvac],
        manufacturer: 'Siemens',
        companyId: 'co-1',
        restrictToCompany: true,
      );

      expect(result.map((a) => a.id), ['s1']);
    });

    test('excludes non-charger assets', () {
      final result = chargersForCreateForm(
        assets: [hvac],
        manufacturer: 'Siemens',
      );
      expect(result, isEmpty);
    });
  });

  group('buildFieldAddedCharger', () {
    test('builds a charger-like asset technicians can attach a work order to', () {
      final now = DateTime(2026, 10, 4);
      final asset = buildFieldAddedCharger(
        id: 'field-1',
        name: 'Site charger A',
        location: 'Mall P2',
        manufacturer: 'Siemens',
        serialNumber: 'SN-99',
        assetTag: '2026_00011',
        companyId: 'co-1',
        now: now,
      );

      expect(isChargerLikeAsset(asset), isTrue);
      expect(matchesChargerBrand(asset, 'Siemens'), isTrue);
      expect(asset.itemType, 'charger');
      expect(asset.category, 'charger');
      expect(asset.serialNumber, 'SN-99');
      expect(asset.qrCode, '2026_00011');
      expect(asset.companyId, 'co-1');
      expect(asset.status, 'active');
    });
  });

  group('isChargerLikeAsset', () {
    test('KOS-prefixed name is charger-like', () {
      final now = DateTime(2024, 6, 1);
      final asset = Asset(
        id: 'x',
        name: 'KOS999',
        location: 'A',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );
      expect(isChargerLikeAsset(asset), isTrue);
    });
  });
}
