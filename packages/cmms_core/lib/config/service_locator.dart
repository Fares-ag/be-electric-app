// Service Locator Configuration
//
// Centralized dependency injection setup using GetIt.
//
// Services are registered as lazy singletons in dependency order so circular
// references resolve at first use (not at construction time).

import 'package:get_it/get_it.dart';

import '../repositories/asset_repository.dart';
import '../repositories/cmms_repositories.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/pm_occurrence_repository.dart';
import '../repositories/supabase/supabase_asset_repository.dart';
import '../repositories/supabase/supabase_inventory_repository.dart';
import '../repositories/supabase/supabase_pm_occurrence_repository.dart';
import '../repositories/supabase/supabase_support_request_repository.dart';
import '../repositories/supabase/supabase_user_repository.dart';
import '../repositories/supabase/supabase_work_order_repository.dart';
import '../repositories/supabase/supabase_workflow_repository.dart';
import '../repositories/support_request_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/work_order_repository.dart';
import '../repositories/workflow_repository.dart';
import '../services/activity_log_service.dart';
import '../services/advanced_reporting_service.dart';
import '../services/analytics/analytics_calculator.dart';
import '../services/analytics/analytics_monitor.dart';
import '../services/analytics/analytics_service.dart';
import '../services/asset_change_detection_service.dart';
import '../services/asset_database_service.dart';
import '../services/asset_integration_service.dart';
import '../services/audit_logging_service.dart';
import '../services/comprehensive_cmms_service.dart';
import '../services/connectivity_service.dart';
import '../services/data_quality_monitor.dart';
import '../services/enhanced_inventory_service.dart';
import '../services/enhanced_notification_service.dart';
import '../services/escalation_service.dart';
import '../services/hyper_speed_asset_service.dart';
import '../services/hyper_speed_cache.dart';
import '../services/hybrid_dam_service.dart';
import '../services/logger_service.dart';
import '../services/notification_service.dart';
import '../services/orphan_cleanup_service.dart';
import '../services/parts_request_service.dart';
import '../services/performance_service.dart';
import '../services/pm_occurrence_service.dart';
import '../services/purchase_order_service.dart';
import '../services/realtime_analytics_service.dart';
import '../services/realtime_supabase_service.dart';
import '../services/service_account_auth.dart';
import '../services/simplified_reporting_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_database_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/support_request_service.dart';
import '../services/support_service.dart';
import '../services/offline_queue_service.dart';
import '../services/unified_data_service.dart';
import '../services/universal_hyper_speed_cache.dart';
import '../services/user_auth_service.dart';
import '../services/workflow_automation_service.dart';
import '../services/workflow_permission_service.dart';
import '../services/workflow_routing_service.dart';

final getIt = GetIt.instance;

/// Register all app services. Call once at startup before resolving dependencies.
Future<void> setupServiceLocator() async {
  // Layer 0 — infrastructure (no app-service dependencies)
  getIt.registerLazySingleton<LoggerService>(LoggerService.new);
  getIt.registerLazySingleton<SupabaseAuthService>(SupabaseAuthService.new);
  getIt.registerLazySingleton<SupabaseDatabaseService>(
    SupabaseDatabaseService.new,
  );
  getIt.registerLazySingleton<SupabaseStorageService>(
    SupabaseStorageService.new,
  );
  getIt.registerLazySingleton<UserAuthService>(UserAuthService.new);
  getIt.registerLazySingleton<RealtimeAnalyticsService>(
    RealtimeAnalyticsService.new,
  );
  getIt.registerLazySingleton<ActivityLogService>(ActivityLogService.new);
  // Same singleton for GetIt and `.instance` (HEAD-compatible offline access).
  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService.instance,
  );
  getIt.registerLazySingleton<OfflineQueueService>(
    () => OfflineQueueService.instance,
  );
  getIt.registerLazySingleton<HybridDamService>(HybridDamService.new);
  getIt.registerLazySingleton<SupportService>(SupportService.new);
  getIt.registerLazySingleton<SupportRequestService>(
    SupportRequestService.new,
  );
  getIt.registerLazySingleton<PerformanceService>(PerformanceService.new);
  getIt.registerLazySingleton<NotificationService>(NotificationService.new);
  getIt.registerLazySingleton<ServiceAccountAuth>(ServiceAccountAuth.new);
  getIt.registerLazySingleton<AssetDatabaseService>(AssetDatabaseService.new);
  getIt.registerLazySingleton<AssetIntegrationService>(
    AssetIntegrationService.new,
  );
  getIt.registerLazySingleton<AssetChangeDetectionService>(
    AssetChangeDetectionService.new,
  );
  getIt.registerLazySingleton<HyperSpeedCache>(HyperSpeedCache.new);
  getIt.registerLazySingleton<HyperSpeedAssetService>(
    HyperSpeedAssetService.new,
  );
  getIt.registerLazySingleton<UniversalHyperSpeedCache>(
    UniversalHyperSpeedCache.new,
  );

  // Layer 1 — depends on database / auth
  getIt.registerLazySingleton<RealtimeSupabaseService>(
    RealtimeSupabaseService.new,
  );
  getIt.registerLazySingleton<AuditLoggingService>(AuditLoggingService.new);
  getIt.registerLazySingleton<EnhancedNotificationService>(
    EnhancedNotificationService.new,
  );

  // Layer 2 — domain data & feature services
  getIt.registerLazySingleton<UnifiedDataService>(UnifiedDataService.new);
  getIt.registerLazySingleton<EnhancedInventoryService>(
    EnhancedInventoryService.new,
  );
  getIt.registerLazySingleton<EscalationService>(EscalationService.new);
  getIt.registerLazySingleton<PartsRequestService>(PartsRequestService.new);
  getIt.registerLazySingleton<PmOccurrenceService>(PmOccurrenceService.new);
  getIt.registerLazySingleton<PurchaseOrderService>(PurchaseOrderService.new);
  getIt.registerLazySingleton<OrphanCleanupService>(OrphanCleanupService.new);
  getIt.registerLazySingleton<DataQualityMonitor>(DataQualityMonitor.new);
  getIt.registerLazySingleton<WorkflowPermissionService>(
    WorkflowPermissionService.new,
  );
  getIt.registerLazySingleton<WorkflowRoutingService>(
    WorkflowRoutingService.new,
  );
  getIt.registerLazySingleton<WorkflowAutomationService>(
    WorkflowAutomationService.new,
  );
  getIt.registerLazySingleton<SimplifiedReportingService>(
    SimplifiedReportingService.new,
  );
  getIt.registerLazySingleton<AdvancedReportingService>(
    AdvancedReportingService.new,
  );

  // Layer 3 — orchestrators
  getIt.registerLazySingleton<ComprehensiveCMMSService>(
    ComprehensiveCMMSService.new,
  );

  // Repositories
  getIt.registerLazySingleton<WorkOrderRepository>(
    SupabaseWorkOrderRepository.new,
  );
  getIt.registerLazySingleton<AssetRepository>(
    SupabaseAssetRepository.new,
  );
  getIt.registerLazySingleton<UserRepository>(
    SupabaseUserRepository.new,
  );
  getIt.registerLazySingleton<InventoryRepository>(
    SupabaseInventoryRepository.new,
  );
  getIt.registerLazySingleton<WorkflowRepository>(
    SupabaseWorkflowRepository.new,
  );
  getIt.registerLazySingleton<SupportRequestRepository>(
    SupabaseSupportRequestRepository.new,
  );
  getIt.registerLazySingleton<PmOccurrenceRepository>(
    SupabasePmOccurrenceRepository.new,
  );

  CmmsRepositories.configure(
    workOrders: getIt<WorkOrderRepository>(),
    assets: getIt<AssetRepository>(),
    users: getIt<UserRepository>(),
    inventory: getIt<InventoryRepository>(),
    workflows: getIt<WorkflowRepository>(),
    supportRequests: getIt<SupportRequestRepository>(),
    pmOccurrences: getIt<PmOccurrenceRepository>(),
  );

  // Analytics
  getIt.registerLazySingleton<AnalyticsCalculator>(AnalyticsCalculator.new);
  getIt.registerLazySingleton<AnalyticsService>(AnalyticsService.new);
  getIt.registerLazySingleton<AnalyticsMonitor>(AnalyticsMonitor.new);
}

/// Unregister all services. Use in tests before registering mocks.
Future<void> resetServiceLocator() async {
  await getIt.reset();
  CmmsRepositories.resetForTesting();
}

bool isServiceRegistered<T extends Object>() => getIt.isRegistered<T>();
