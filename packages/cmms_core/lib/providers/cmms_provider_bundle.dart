import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'asset_provider.dart';
import 'auth_provider.dart';
import 'cmms_data_coordinator.dart';
import '../services/session_purge_service.dart';
import 'inventory_provider.dart';
import 'offline_sync_status_provider.dart';
import 'pm_inbox_provider.dart';
import 'pm_occurrence_provider.dart';
import 'support_request_provider.dart';
import 'unified_data_provider.dart';
import 'user_provider.dart';
import 'work_order_provider.dart';
import 'workflow_provider.dart';

/// Wires domain providers with correct dependency order and lifecycle.
class CmmsProviderBundle {
  CmmsProviderBundle({AuthProvider? authProvider, bool autoStart = true})
      : auth = authProvider ?? AuthProvider() {
    assets = AssetProvider();
    users = UserProvider();
    workOrders = WorkOrderProvider(users: users, assets: assets);
    inventory = InventoryProvider();
    workflows = WorkflowProvider();
    pmOccurrences = PmOccurrenceProvider();

    coordinator = CmmsDataCoordinator(
      workOrders: workOrders,
      assets: assets,
      users: users,
      inventory: inventory,
      workflows: workflows,
      pmOccurrences: pmOccurrences,
    );

    unified = UnifiedDataProvider(
      workOrders: workOrders,
      assets: assets,
      users: users,
      inventory: inventory,
      workflows: workflows,
      coordinator: coordinator,
    );

    supportRequests = SupportRequestProvider();
    pmInbox = PmInboxProvider(
      workOrders: workOrders,
      pmOccurrences: pmOccurrences,
    );
    offlineSync = OfflineSyncStatusProvider();

    SessionPurgeService.bindCoordinator(coordinator);
    SessionPurgeService.bindInventoryProvider(inventory);
    SessionPurgeService.bindWorkflowProvider(workflows);

    users.addListener(workOrders.repopulateReferences);
    assets.addListener(workOrders.repopulateReferences);
    users.addListener(_forwardUnifiedNotify);
    assets.addListener(_forwardUnifiedNotify);
    workOrders.addListener(_forwardUnifiedNotify);
    inventory.addListener(_forwardUnifiedNotify);
    workflows.addListener(_forwardUnifiedNotify);

    if (autoStart) {
      coordinator.attach();
    }
  }

  final AuthProvider auth;
  late final AssetProvider assets;
  late final UserProvider users;
  late final WorkOrderProvider workOrders;
  late final InventoryProvider inventory;
  late final WorkflowProvider workflows;
  late final CmmsDataCoordinator coordinator;
  late final UnifiedDataProvider unified;
  late final SupportRequestProvider supportRequests;
  late final PmOccurrenceProvider pmOccurrences;
  late final PmInboxProvider pmInbox;
  late final OfflineSyncStatusProvider offlineSync;

  void _forwardUnifiedNotify() {
    unified.notifyFromDomainChange();
  }

  List<SingleChildWidget> get providers => [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<AssetProvider>.value(value: assets),
        ChangeNotifierProvider<UserProvider>.value(value: users),
        ChangeNotifierProvider<WorkOrderProvider>.value(value: workOrders),
        ChangeNotifierProvider<InventoryProvider>.value(value: inventory),
        ChangeNotifierProvider<WorkflowProvider>.value(value: workflows),
        ChangeNotifierProvider<UnifiedDataProvider>.value(value: unified),
        ChangeNotifierProvider<SupportRequestProvider>.value(
          value: supportRequests,
        ),
        ChangeNotifierProvider<PmOccurrenceProvider>.value(
          value: pmOccurrences,
        ),
        ChangeNotifierProvider<PmInboxProvider>.value(
          value: pmInbox,
        ),
        ChangeNotifierProvider<OfflineSyncStatusProvider>.value(
          value: offlineSync,
        ),
      ];

  static CmmsProviderBundle forTesting({bool autoStart = false}) =>
      CmmsProviderBundle(autoStart: autoStart);

  /// Tears down domain realtime listeners and provider notifiers.
  void dispose() {
    SessionPurgeService.unbindCoordinator(coordinator);
    SessionPurgeService.unbindInventoryProvider(inventory);
    SessionPurgeService.unbindWorkflowProvider(workflows);
    offlineSync.dispose();
    coordinator.dispose();
    workOrders.dispose();
    assets.dispose();
    users.dispose();
    inventory.dispose();
    workflows.dispose();
    unified.dispose();
    supportRequests.dispose();
    pmOccurrences.dispose();
    pmInbox.dispose();
  }
}
