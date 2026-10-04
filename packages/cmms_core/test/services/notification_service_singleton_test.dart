import 'package:cmms_core/config/locator.dart';
import 'package:cmms_core/services/enhanced_notification_service.dart'
    as enhanced;
import 'package:cmms_core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(() async {
    await ensureServiceLocatorForTests();
  });

  tearDownAll(() async {
    await tearDownServiceLocatorForTests();
  });

  tearDown(() {
    sl<NotificationService>().resetForTesting();
    sl<enhanced.EnhancedNotificationService>().resetForTesting();
  });

  group('NotificationService singleton', () {
    test('initialize runs once and shares one notifications stream', () async {
      final service = sl<NotificationService>();
      final otherRef = sl<NotificationService>();

      expect(identical(service, otherRef), isTrue);

      await service.initialize();
      await service.initialize();

      await service.createNotification(
        title: 'Parts request',
        message: 'Awaiting approval',
        type: NotificationType.systemAlert,
        priority: NotificationPriority.medium,
      );

      expect(service.unreadCount, 1);
      expect(otherRef.unreadCount, 1);
      expect(service.notificationsStream, otherRef.notificationsStream);
    });

    test('writers and stream listeners observe the same in-memory list', () async {
      final service = sl<NotificationService>();
      await service.initialize();

      final seen = <List<Notification>>[];
      final sub = service.notificationsStream.listen(seen.add);

      await service.createNotification(
        title: 'Badge test',
        message: 'Should appear in stream',
        type: NotificationType.workOrderAssigned,
        priority: NotificationPriority.high,
        userId: 'tech-1',
      );

      await Future<void>.delayed(Duration.zero);

      expect(service.notifications.length, 1);
      expect(seen, isNotEmpty);
      expect(seen.last.first.title, 'Badge test');
      expect(service.getUnreadNotificationsForUser('tech-1').length, 1);

      await sub.cancel();
    });
  });

  group('EnhancedNotificationService singleton', () {
    test('initialize runs once and does not duplicate cleanup timers', () async {
      final service = sl<enhanced.EnhancedNotificationService>();

      await service.initialize();
      await service.initialize();
      await service.initialize();

      await service.createNotification(
        title: 'Workflow approval',
        message: 'Needs review',
        type: enhanced.NotificationType.workflowApproval,
      );

      expect(service.totalCount, 1);
      expect(sl<enhanced.EnhancedNotificationService>().totalCount, 1);
    });
  });
}
