import 'package:cmms_core/models/asset.dart';
import 'package:cmms_core/models/user.dart';

/// Shared fixtures for requestor auth/submit integration tests.
class RequestorIntegrationFixtures {
  static User linkedRequestor({
    String id = 'requestor_int_001',
    String companyId = 'company_int_001',
  }) =>
      User(
        id: id,
        email: 'requestor.integration@test.com',
        name: 'Integration Requestor',
        role: 'requestor',
        companyId: companyId,
        createdAt: DateTime(2024, 1, 1),
      );

  static User requestorWithoutCompany() => User(
        id: 'requestor_no_co_001',
        email: 'orphan.integration@test.com',
        name: 'Orphan Requestor',
        role: 'requestor',
        createdAt: DateTime(2024, 1, 1),
      );

  static User technicianAccount() => User(
        id: 'tech_int_001',
        email: 'tech.integration@test.com',
        name: 'Integration Technician',
        role: 'technician',
        companyId: 'company_int_001',
        createdAt: DateTime(2024, 1, 1),
      );

  static Asset registeredCharger({
    String id = 'charger_int_001',
    String companyId = 'company_int_001',
  }) =>
      Asset(
        id: id,
        name: 'Integration Test Charger',
        category: 'EV Charger',
        location: 'Bay 1',
        status: 'operational',
        manufacturer: 'Siemens',
        companyId: companyId,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

  static Asset placeholderCharger() => Asset(
        id: 'siemens',
        name: 'Placeholder Siemens',
        category: 'EV Charger',
        location: '',
        status: 'unknown',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
}
