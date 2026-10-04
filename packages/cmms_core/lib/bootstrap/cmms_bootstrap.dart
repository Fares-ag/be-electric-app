import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../config/service_locator.dart';
import '../config/locator.dart';
import '../config/supabase_config.dart';
import '../services/analytics/analytics_service.dart';
import '../services/comprehensive_cmms_service.dart';
import '../services/connectivity_service.dart';
import '../services/error_handling_service.dart';
import '../services/escalation_service.dart';
import '../services/notification_service.dart';
import '../services/parts_request_service.dart';
import '../services/purchase_order_service.dart';
import '../services/realtime_supabase_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/offline_queue_service.dart';
import '../repositories/cmms_repositories.dart';
import 'crash_reporting_setup.dart';
import '../utils/cmms_bootstrap_policy.dart';

/// Shared startup for requestor and technician app binaries.
Future<void> initializeCmms() async {
  var supabaseInitialized = false;

  configureProductionCrashReporting(
    enabled: AppConfig.isCrashReportingEnabled,
  );

  try {
    await setupServiceLocator();
    debugPrint('✅ Service Locator: Dependency injection configured');
  } catch (e, st) {
    debugPrint('❌ Service Locator error: $e');
    if (kReleaseMode) rethrow;
  }

  try {
    // Prefer GetIt when registered; same objects as `.instance` fallbacks.
    final connectivity = getIt.isRegistered<ConnectivityService>()
        ? sl<ConnectivityService>()
        : ConnectivityService.instance;
    final offlineQueue = getIt.isRegistered<OfflineQueueService>()
        ? sl<OfflineQueueService>()
        : OfflineQueueService.instance;
    await connectivity.initialize();
    await offlineQueue.initialize();
    debugPrint('✅ Offline sync: Connectivity + OfflineQueue ready');
  } catch (e, st) {
    debugPrint('❌ Offline sync initialization error: $e');
  }

  try {
    if (!AppConfig.hasValidSupabaseConfig) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY. '
        'Pass both via --dart-define for release builds.',
      );
    }
    if (shouldRethrowMissingLegalConfig(
      isReleaseMode: kReleaseMode,
      hasValidLegalConfig: AppConfig.hasValidLegalConfig,
    )) {
      throw StateError(kMissingLegalConfigBootstrapError);
    }
    await Supabase.initialize(
      url: SupabaseConfig.projectUrl,
      anonKey: SupabaseConfig.anonKey,
    );
    supabaseInitialized = true;
    debugPrint('✅ Supabase: Initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Supabase initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    if (shouldRethrowSupabaseBootstrapFailure(isReleaseMode: kReleaseMode)) {
      rethrow;
    }
  }

  if (!supabaseInitialized) {
    debugPrint(
      '⚠️ Supabase not initialized — skipping Supabase-dependent services',
    );
    _configureErrorHandlers();
    return;
  }

  // Light Supabase plumbing first so the auth listener inside
  // UnifiedDataProvider has somewhere to attach. We deliberately do NOT call
  // UnifiedDataService.initialize() / ComprehensiveCMMSService.initialize()
  // here anymore: they used to fire ~12 RLS-rejected fetches before the user
  // had a session. They now run automatically once Supabase emits signedIn.
  try {
    await sl<SupabaseAuthService>().initialize();
    await CmmsRepositories.workOrders.initialize();
    if (AppConfig.enablePmOccurrences) {
      await CmmsRepositories.pmOccurrences.initialize();
    }
    await sl<RealtimeSupabaseService>().initialize();
    debugPrint('✅ Supabase services: Initialized successfully');
  } catch (e, st) {
    debugPrint('❌ Supabase services initialization error: $e');
  }

  // Fire-and-forget the heavier domain services so they don't block first
  // frame. They each manage their own internal initialization guards.
  unawaited(_initializeDeferredServices());

  _configureErrorHandlers();
}

void _configureErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
    try {
      ErrorHandlingService.logError(details.exception, details.stack);
    } catch (e, st) {
      debugPrint('Error logging failed: $e');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack trace: $stack');
    try {
      ErrorHandlingService.logError(error, stack);
    } catch (e, st) {
      debugPrint('Error logging failed: $e');
    }
    return true;
  };
}

/// Deferred initializers that don't need to block the first frame. They are
/// safe to retry after sign-in because each underlying service is idempotent.
Future<void> _initializeDeferredServices() async {
  try {
    await sl<ComprehensiveCMMSService>().initialize();
  } catch (e, st) {
    debugPrint('❌ ComprehensiveCMMSService initialization error: $e');
  }

  try {
    await sl<NotificationService>().initialize();
    await sl<EscalationService>().initialize();
    await sl<PartsRequestService>().initialize();
    await sl<PurchaseOrderService>().initialize();
    await getIt<AnalyticsService>().initialize();
    debugPrint('✅ Additional services: Initialized successfully');
  } catch (e, st) {
    debugPrint('❌ Additional services initialization error: $e');
  }
}
