// Tests for user model extensions
import 'package:flutter_test/flutter_test.dart';
import 'package:cmms_core/models/user.dart';

void main() {
  group('User Model Tests', () {
    test('Create user with required fields', () {
      final user = User(
        id: 'test_001',
        email: 'test@example.com',
        name: 'Test User',
        role: 'technician',
        createdAt: DateTime(2024),
      );

      expect(user.id, 'test_001');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.role, 'technician');
      expect(user.isActive, true); // Default value
    });

    test('Create user with all fields', () {
      final createdAt = DateTime(2024);
      final lastLoginAt = DateTime(2024, 1, 2);

      final user = User(
        id: 'test_002',
        email: 'admin@example.com',
        name: 'Admin User',
        role: 'admin',
        department: 'IT',
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
        workEmail: 'work@example.com',
      );

      expect(user.id, 'test_002');
      expect(user.email, 'admin@example.com');
      expect(user.name, 'Admin User');
      expect(user.role, 'admin');
      expect(user.department, 'IT');
      expect(user.createdAt, createdAt);
      expect(user.lastLoginAt, lastLoginAt);
      expect(user.workEmail, 'work@example.com');
      expect(user.isActive, true);
    });

    test('User toMap serialization', () {
      final user = User(
        id: 'test_003',
        email: 'test@example.com',
        name: 'Test User',
        role: 'manager',
        department: 'Operations',
        createdAt: DateTime(2024),
        isActive: false,
      );

      final map = user.toMap();

      expect(map['id'], 'test_003');
      expect(map['email'], 'test@example.com');
      expect(map['name'], 'Test User');
      expect(map['role'], 'manager');
      expect(map['department'], 'Operations');
      expect(map['isActive'], false);
    });

    test('User fromMap deserialization', () {
      final map = {
        'id': 'test_004',
        'email': 'user@example.com',
        'name': 'User Name',
        'role': 'requestor',
        'department': 'Facilities',
        'created_at': '2024-01-01T00:00:00.000',
        'is_active': 1,
      };

      final user = User.fromMap(map);

      expect(user.id, 'test_004');
      expect(user.email, 'user@example.com');
      expect(user.name, 'User Name');
      expect(user.role, 'requestor');
      expect(user.department, 'Facilities');
      expect(user.isActive, true);
    });

    test('User toFirestoreMap serialization', () {
      final user = User(
        id: 'test_005',
        email: 'firebase@example.com',
        name: 'Firebase User',
        role: 'admin',
        createdAt: DateTime(2024),
      );

      final map = user.toFirestoreMap();

      expect(map['id'], 'test_005');
      expect(map['email'], 'firebase@example.com');
      expect(map['name'], 'Firebase User');
      expect(map['role'], 'admin');
      expect(map['isActive'], true); // Firestore uses bool directly
    });

    test('User fromFirestoreMap deserialization with bool', () {
      final map = {
        'id': 'test_006',
        'email': 'fb@example.com',
        'name': 'FB User',
        'role': 'technician',
        'createdAt': DateTime(2024).toIso8601String(),
        'isActive': true, // Boolean
      };

      final user = User.fromMap(map);

      expect(user.id, 'test_006');
      expect(user.email, 'fb@example.com');
      expect(user.isActive, true);
    });

    test('User fromFirestoreMap deserialization with int (legacy)', () {
      final map = {
        'id': 'test_007',
        'email': 'legacy@example.com',
        'name': 'Legacy User',
        'role': 'manager',
        'createdAt': DateTime(2024).toIso8601String(),
        'isActive': 1, // Integer (legacy format)
      };

      final user = User.fromMap(map);

      expect(user.id, 'test_007');
      expect(user.isActive, true); // Correctly converted from int
    });

    test('Inactive user with isActive = 0', () {
      final map = {
        'id': 'test_008',
        'email': 'inactive@example.com',
        'name': 'Inactive User',
        'role': 'technician',
        'createdAt': '2024-01-01T00:00:00.000',
        'isActive': 0,
      };

      final user = User.fromMap(map);

      expect(user.isActive, false);
    });

    test('User with missing optional fields', () {
      final map = {
        'id': 'test_009',
        'email': 'minimal@example.com',
        'name': 'Minimal User',
        'role': 'requestor',
        'created_at': '2024-01-01T00:00:00.000',
      };

      final user = User.fromMap(map);

      expect(user.id, 'test_009');
      expect(user.department, null);
      expect(user.lastLoginAt, null);
      expect(user.workEmail, null);
      expect(user.isActive, true); // Default value
    });

    test('canCreatePmTasks matches pm_tasks INSERT RLS roles', () {
      expect(
        User(
          id: 't',
          email: 't@test.com',
          name: 'Tech',
          role: 'technician',
          createdAt: DateTime(2024),
        ).canCreatePmTasks,
        isFalse,
      );
      expect(
        User(
          id: 'r',
          email: 'r@test.com',
          name: 'Req',
          role: 'requestor',
          createdAt: DateTime(2024),
        ).canCreatePmTasks,
        isFalse,
      );
      expect(
        User(
          id: 'm',
          email: 'm@test.com',
          name: 'Mgr',
          role: 'manager',
          createdAt: DateTime(2024),
        ).canCreatePmTasks,
        isTrue,
      );
      expect(
        User(
          id: 'a',
          email: 'a@test.com',
          name: 'Adm',
          role: 'admin',
          createdAt: DateTime(2024),
        ).canCreatePmTasks,
        isTrue,
      );
    });

    test('Admin role change: updated user has new role and same id', () {
      // Simulates building the "updated" user when admin changes role in UI
      const originalId = 'e7fd2cfe-3928-4a3f-81cf-437a7178be6c';
      const newRole = 'manager';
      final original = User(
        id: originalId,
        email: 'jeffiong@q-auto.com',
        name: 'Joseph',
        role: 'technician',
        createdAt: DateTime(2024),
      );
      final updated = User(
        id: original.id,
        email: original.email,
        name: original.name,
        role: newRole,
        department: original.department,
        createdAt: original.createdAt,
        lastLoginAt: original.lastLoginAt,
        workEmail: original.workEmail,
        isActive: original.isActive,
        updatedAt: DateTime.now(),
      );
      expect(updated.id, originalId);
      expect(updated.role, newRole);
      expect(updated.email, original.email);
    });
  });
}
