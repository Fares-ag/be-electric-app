import 'asset_repository.dart';
import 'inventory_repository.dart';
import 'pm_occurrence_repository.dart';
import 'supabase/supabase_asset_repository.dart';
import 'supabase/supabase_inventory_repository.dart';
import 'supabase/supabase_pm_occurrence_repository.dart';
import 'supabase/supabase_support_request_repository.dart';
import 'supabase/supabase_user_repository.dart';
import 'supabase/supabase_work_order_repository.dart';
import 'supabase/supabase_workflow_repository.dart';
import 'support_request_repository.dart';
import 'user_repository.dart';
import 'work_order_repository.dart';
import 'workflow_repository.dart';

/// Central access point for CMMS repositories (backward-compatible singletons).
class CmmsRepositories {
  CmmsRepositories._();

  static WorkOrderRepository? _workOrders;
  static AssetRepository? _assets;
  static UserRepository? _users;
  static InventoryRepository? _inventory;
  static WorkflowRepository? _workflows;
  static SupportRequestRepository? _supportRequests;
  static PmOccurrenceRepository? _pmOccurrences;

  /// Override implementations (tests / future DI).
  static void configure({
    WorkOrderRepository? workOrders,
    AssetRepository? assets,
    UserRepository? users,
    InventoryRepository? inventory,
    WorkflowRepository? workflows,
    SupportRequestRepository? supportRequests,
    PmOccurrenceRepository? pmOccurrences,
  }) {
    if (workOrders != null) _workOrders = workOrders;
    if (assets != null) _assets = assets;
    if (users != null) _users = users;
    if (inventory != null) _inventory = inventory;
    if (workflows != null) _workflows = workflows;
    if (supportRequests != null) _supportRequests = supportRequests;
    if (pmOccurrences != null) _pmOccurrences = pmOccurrences;
  }

  static void resetForTesting() {
    _workOrders = null;
    _assets = null;
    _users = null;
    _inventory = null;
    _workflows = null;
    _supportRequests = null;
    _pmOccurrences = null;
  }

  static WorkOrderRepository get workOrders =>
      _workOrders ??= SupabaseWorkOrderRepository();

  static AssetRepository get assets =>
      _assets ??= SupabaseAssetRepository();

  static UserRepository get users => _users ??= SupabaseUserRepository();

  static InventoryRepository get inventory =>
      _inventory ??= SupabaseInventoryRepository();

  static WorkflowRepository get workflows =>
      _workflows ??= SupabaseWorkflowRepository();

  static SupportRequestRepository get supportRequests =>
      _supportRequests ??= SupabaseSupportRequestRepository();

  static PmOccurrenceRepository get pmOccurrences =>
      _pmOccurrences ??= SupabasePmOccurrenceRepository();
}

/// Alias preserved for call sites migrating off direct service access.
typedef RepositoryLocator = CmmsRepositories;
