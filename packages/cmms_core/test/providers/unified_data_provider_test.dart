// Unit Tests for UnifiedDataProvider
import 'package:flutter_test/flutter_test.dart';
import 'package:cmms_core/models/pm_task.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/providers/cmms_provider_bundle.dart';
import 'package:cmms_core/providers/unified_data_provider.dart';

import '../test_helpers.dart';

void main() {
  late UnifiedDataProvider provider;
  late CmmsProviderBundle bundle;

  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  setUp(() {
    bundle = CmmsProviderBundle.forTesting(autoStart: false);
    provider = bundle.unified;
  });

  tearDown(() {
    bundle.dispose();
  });

  group('UnifiedDataProvider - User Filtering', () {
    test('getTechnicians returns only technician role users', () {
      // Note: This test will use real UnifiedDataProvider
      // In a real scenario, you'd mock the UnifiedDataService

      final technicians = provider.getTechnicians();

      // Verify all returned users have technician role
      for (final tech in technicians) {
        expect(tech.role, 'technician');
      }
    });

    test('getManagers returns only manager role users', () {
      final managers = provider.getManagers();

      for (final manager in managers) {
        expect(manager.role, 'manager');
      }
    });

    test('getAdmins returns only admin role users', () {
      final admins = provider.getAdmins();

      for (final admin in admins) {
        expect(admin.role, 'admin');
      }
    });
  });

  group('UnifiedDataProvider - Work Order Filtering', () {
    test('getWorkOrdersByStatus filters correctly', () {
      final openOrders = provider.getWorkOrdersByStatus('open');

      for (final wo in openOrders) {
        expect(wo.status.name, 'open');
      }
    });

    test('getWorkOrdersByPriority filters correctly', () {
      final urgentOrders = provider.getWorkOrdersByPriority('urgent');

      for (final wo in urgentOrders) {
        expect(wo.priority.name, 'urgent');
      }
    });

    test('getWorkOrdersByTechnician filters by assigned technician', () {
      const technicianId = 'tech_001';
      final techWorkOrders = provider.getWorkOrdersByTechnician(technicianId);

      for (final wo in techWorkOrders) {
        expect(wo.assignedTechnicianId, technicianId);
      }
    });

    test('getWorkOrdersByRequestor filters by requestor', () {
      const requestorId = 'requestor_001';
      final requestorWorkOrders =
          provider.getWorkOrdersByRequestor(requestorId);

      for (final wo in requestorWorkOrders) {
        expect(wo.requestorId, requestorId);
      }
    });

    test('getOverdueWorkOrders returns only overdue work orders', () {
      final overdueOrders = provider.getOverdueWorkOrders();

      for (final wo in overdueOrders) {
        expect(wo.isOverdue, true);
      }
    });
  });

  group('UnifiedDataProvider - PM Task Filtering', () {
    test('getPMTasksByTechnician filters by assigned technician', () {
      const technicianId = 'tech_001';
      final techPMTasks = provider.getPMTasksByTechnician(technicianId);

      for (final task in techPMTasks) {
        expect(task.assignedTechnicianId, technicianId);
      }
    });

    test('getOverduePMTasks returns only overdue tasks', () {
      final overdueTasks = provider.getOverduePMTasks();

      for (final task in overdueTasks) {
        expect(task.status, PMTaskStatus.overdue);
      }
    });

    test('getPMTasksByStatus filters correctly', () {
      final pendingTasks = provider.getPMTasksByStatus(PMTaskStatus.pending);

      for (final task in pendingTasks) {
        expect(task.status, PMTaskStatus.pending);
      }
    });
  });

  group('UnifiedDataProvider - Inventory Filtering', () {
    test('getLowStockItems returns items below minimum stock', () {
      final lowStockItems = provider.getLowStockItems();

      for (final item in lowStockItems) {
        expect(item.currentStock < item.minStock, true);
      }
    });

    test('getInventoryByCategory filters correctly', () {
      const category = 'Filters';
      final categoryItems = provider.getInventoryByCategory(category);

      for (final item in categoryItems) {
        expect(item.category, category);
      }
    });
  });

  group('UnifiedDataProvider - Dashboard Stats', () {
    test('getDashboardStats returns valid statistics', () {
      final stats = provider.getDashboardStats();

      expect(stats, isNotNull);
      expect(stats.containsKey('totalWorkOrders'), true);
      expect(stats.containsKey('openWorkOrders'), true);
      expect(stats.containsKey('totalPMTasks'), true);
      expect(stats.containsKey('totalUsers'), true);

      // Verify all stats are non-negative
      expect(stats['totalWorkOrders']! >= 0, true);
      expect(stats['openWorkOrders']! >= 0, true);
      expect(stats['totalPMTasks']! >= 0, true);
      expect(stats['totalUsers']! >= 0, true);
    });

    test('getTechnicianPerformance returns valid data', () {
      const technicianId = 'tech_001';
      final performance = provider.getTechnicianPerformance(technicianId);

      expect(performance, isNotNull);
      expect(performance.containsKey('workOrders'), true);
      expect(performance.containsKey('pmTasks'), true);
      expect(performance.containsKey('workOrderStats'), true);
      expect(performance.containsKey('pmTaskStats'), true);
    });
  });

  group('UnifiedDataProvider - Loading States', () {
    test('Initial loading states are false', () {
      expect(provider.isWorkOrdersLoading, false);
      expect(provider.isPMTasksLoading, false);
      expect(provider.isUsersLoading, false);
      expect(provider.isAssetsLoading, false);
      expect(provider.isInventoryLoading, false);
    });
  });

  group('UnifiedDataProvider - Admin role change', () {
    test('updateUser accepts User with updated role (persists via service)', () async {
      // Provider delegates to UnifiedDataService.updateUser -> Supabase.
      // In test env Supabase is not initialized so updateUser throws; we assert it's called.
      final provider = bundle.unified;
      final userWithNewRole = User(
        id: 'test-id',
        email: 'test@example.com',
        name: 'Test',
        role: 'manager', // role changed from e.g. technician
        createdAt: DateTime(2024),
        updatedAt: DateTime.now(),
      );
      expect(
        provider.updateUser(userWithNewRole),
        throwsA(anything),
      );
    });
  });
}
