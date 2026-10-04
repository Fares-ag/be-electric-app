import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/widgets/quick_create_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpQuickCreateMenu(
    WidgetTester tester, {
    required bool canCreatePmTask,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickCreateMenuSheet(
            canCreatePmTask: canCreatePmTask,
            onCreateWorkOrder: () {},
            onCreatePmTask: () {},
            onScanQr: () {},
          ),
        ),
      ),
    );
  }

  group('QuickCreateMenuSheet (T-005)', () {
    testWidgets('technician role hides Create PM Task', (tester) async {
      final user = User(
        id: 'tech_001',
        email: 'tech@test.com',
        name: 'Technician User',
        role: 'technician',
        createdAt: DateTime(2024),
      );

      await pumpQuickCreateMenu(
        tester,
        canCreatePmTask: user.canCreatePmTasks,
      );

      expect(find.text('Quick Create'), findsOneWidget);
      expect(find.text('Create Work Order'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.text('Create PM Task'), findsNothing);
    });

    testWidgets('manager role keeps Create PM Task', (tester) async {
      final user = User(
        id: 'manager_001',
        email: 'manager@test.com',
        name: 'Manager User',
        role: 'manager',
        createdAt: DateTime(2024),
      );

      await pumpQuickCreateMenu(
        tester,
        canCreatePmTask: user.canCreatePmTasks,
      );

      expect(find.text('Create PM Task'), findsOneWidget);
      expect(find.text('Create Work Order'), findsOneWidget);
    });

    testWidgets('admin role keeps Create PM Task', (tester) async {
      final user = User(
        id: 'admin_001',
        email: 'admin@test.com',
        name: 'Admin User',
        role: 'admin',
        createdAt: DateTime(2024),
      );

      await pumpQuickCreateMenu(
        tester,
        canCreatePmTask: user.canCreatePmTasks,
      );

      expect(find.text('Create PM Task'), findsOneWidget);
    });
  });
}
