// Realtime Analytics Service - subscribes to Supabase analytics/* docs
// Best practices:
// - debugPrint for logs
// - typed catches
// - timestamp normalization
// - dispose stream controllers/subscriptions
// - small, cohesive API
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

import '../models/analytics_models.dart';

class RealtimeAnalyticsService {

  SupabaseClient get _client => Supabase.instance.client;

  // Subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _kpiSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _workOrdersSummarySubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _workOrdersTrendsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _assetPerformanceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _pmComplianceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _techPerformanceSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _maintenanceCostsSubscription;

  // Controllers
  final StreamController<KPIMetrics> _kpiController =
      StreamController<KPIMetrics>.broadcast();
  final StreamController<Map<String, dynamic>> _workOrdersSummaryController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<MaintenanceDataPoint>>
      _workOrdersTrendsController =
      StreamController<List<MaintenanceDataPoint>>.broadcast();
  final StreamController<AssetPerformance> _assetPerformanceController =
      StreamController<AssetPerformance>.broadcast();
  final StreamController<Map<String, dynamic>> _pmComplianceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<TechnicianPerformance> _techPerformanceController =
      StreamController<TechnicianPerformance>.broadcast();
  final StreamController<CostAnalysis> _maintenanceCostsController =
      StreamController<CostAnalysis>.broadcast();

  // Public streams
  Stream<KPIMetrics> get kpiStream => _kpiController.stream;
  Stream<Map<String, dynamic>> get workOrdersSummaryStream =>
      _workOrdersSummaryController.stream;
  Stream<List<MaintenanceDataPoint>> get workOrdersTrendsStream =>
      _workOrdersTrendsController.stream;
  Stream<AssetPerformance> get assetPerformanceStream =>
      _assetPerformanceController.stream;
  Stream<Map<String, dynamic>> get pmComplianceStream =>
      _pmComplianceController.stream;
  Stream<TechnicianPerformance> get technicianPerformanceStream =>
      _techPerformanceController.stream;
  Stream<CostAnalysis> get maintenanceCostsStream =>
      _maintenanceCostsController.stream;

  /// Marks streams that have already failed once so we don't keep printing
  /// identical errors and re-subscribing for tables that aren't provisioned.
  final Set<String> _disabledStreams = <String>{};

  Future<void> initialize() async {
    stopListening();
    try {
      _subscribeKPIs();
      _subscribeWorkOrdersSummary();
      _subscribeWorkOrdersTrends();
      _subscribeAssetPerformance();
      _subscribePMCompliance();
      _subscribeTechnicianPerformance();
      _subscribeMaintenanceCosts();
      debugPrint('RealtimeAnalyticsService: initialized');
    } on Exception catch (e, st) {
      debugPrint('RealtimeAnalyticsService: init error: $e');
    }
  }

  /// Cancels a stream after its first error so the app doesn't log the same
  /// "table not found" / "permission denied" message indefinitely.
  void _disableStream({
    required String name,
    required Object error,
    required void Function() cancel,
  }) {
    if (_disabledStreams.add(name)) {
      debugPrint(
        'RealtimeAnalyticsService: $name stream error: $error '
        '(disabling further retries)',
      );
    }
    cancel();
  }

  /// Triggers Supabase Functions to recalculate a metric document if stale/missing.
  Future<void> triggerRecalculation({
    required String docName,
    int? periodDays,
  }) async {
    try {
      await _client.from('analytics').upsert({
        'id': docName,
        'triggerCalculation': true,
        if (periodDays != null) 'periodDays': periodDays,
        'requestedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('RealtimeAnalyticsService: trigger set for $docName');
    } on Exception catch (e, st) {
      debugPrint('RealtimeAnalyticsService: trigger error: $e');
    }
  }

  void _subscribeKPIs() {
    _kpiSubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'kpi_metrics').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          _normalizeIsoTimestamps(data, keys: const ['calculatedAt', 'from', 'to']);
          final metrics = KPIMetrics.fromJson(data);
          _kpiController.add(metrics);
          debugPrint('RealtimeAnalyticsService: KPI metrics updated');
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: KPI parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'KPI',
          error: error,
          cancel: () {
            _kpiSubscription?.cancel();
            _kpiSubscription = null;
          },
        );
      },
    );
  }

  void _subscribeWorkOrdersSummary() {
    _workOrdersSummarySubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'work_orders_summary').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          _normalizeIsoTimestamps(data, keys: const ['calculatedAt', 'from', 'to']);
          _workOrdersSummaryController.add(data);
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: WO summary parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'WO summary',
          error: error,
          cancel: () {
            _workOrdersSummarySubscription?.cancel();
            _workOrdersSummarySubscription = null;
          },
        );
      },
    );
  }

  void _subscribeWorkOrdersTrends() {
    _workOrdersTrendsSubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'work_orders_trends').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          final raw = (data['points'] as List?) ?? <dynamic>[];
          final points = raw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .map((m) {
                if (m['date'] is String) {
                  // Already ISO8601 string from Supabase
                  return m;
                }
                return m;
              })
              .map(MaintenanceDataPoint.fromJson)
              .toList();
          _workOrdersTrendsController.add(points);
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: WO trend parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'WO trends',
          error: error,
          cancel: () {
            _workOrdersTrendsSubscription?.cancel();
            _workOrdersTrendsSubscription = null;
          },
        );
      },
    );
  }

  void _subscribeAssetPerformance() {
    _assetPerformanceSubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'asset_performance').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          _normalizeIsoTimestamps(data, keys: const ['calculatedAt', 'from', 'to']);
          final ap = AssetPerformance.fromJson(data);
          _assetPerformanceController.add(ap);
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: Asset performance parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'Asset performance',
          error: error,
          cancel: () {
            _assetPerformanceSubscription?.cancel();
            _assetPerformanceSubscription = null;
          },
        );
      },
    );
  }

  void _subscribePMCompliance() {
    _pmComplianceSubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'pm_compliance').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          _normalizeIsoTimestamps(data, keys: const ['calculatedAt', 'from', 'to']);
          _pmComplianceController.add(data);
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: PM compliance parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'PM compliance',
          error: error,
          cancel: () {
            _pmComplianceSubscription?.cancel();
            _pmComplianceSubscription = null;
          },
        );
      },
    );
  }

  void _subscribeTechnicianPerformance() {
    _techPerformanceSubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'technician_performance').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          _normalizeIsoTimestamps(data, keys: const ['calculatedAt', 'from', 'to']);
          final perf = TechnicianPerformance.fromJson(data);
          _techPerformanceController.add(perf);
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: Tech performance parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'Tech performance',
          error: error,
          cancel: () {
            _techPerformanceSubscription?.cancel();
            _techPerformanceSubscription = null;
          },
        );
      },
    );
  }

  void _subscribeMaintenanceCosts() {
    _maintenanceCostsSubscription = _client
        .from('analytics')
        .stream(primaryKey: ['id'])
        .map((snapshot) {
          return snapshot.where((doc) => doc['id'] == 'maintenance_costs').toList();
        })
        .listen(
      (snapshot) {
        if (snapshot.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(snapshot.first);
          _normalizeIsoTimestamps(data, keys: const ['calculatedAt', 'from', 'to']);
          final costs = CostAnalysis.fromJson(data);
          _maintenanceCostsController.add(costs);
        } on Exception catch (e, st) {
          debugPrint('RealtimeAnalyticsService: Costs parse error: $e');
        }
      },
      onError: (error) {
        _disableStream(
          name: 'Maintenance costs',
          error: error,
          cancel: () {
            _maintenanceCostsSubscription?.cancel();
            _maintenanceCostsSubscription = null;
          },
        );
      },
    );
  }

  void _normalizeIsoTimestamps(
    Map<String, dynamic> data, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) {
        // Already ISO8601 string from Supabase
        try {
          DateTime.parse(value);
          // Valid ISO8601 string, keep as is
        } catch (e, st) {
          // Not a valid date string, skip
        }
      }
    }
  }

  /// Cancels Supabase stream subscriptions without closing broadcast controllers.
  /// Safe to call when leaving a screen that uses [instance].
  void stopListening() {
    _kpiSubscription?.cancel();
    _workOrdersSummarySubscription?.cancel();
    _workOrdersTrendsSubscription?.cancel();
    _assetPerformanceSubscription?.cancel();
    _pmComplianceSubscription?.cancel();
    _techPerformanceSubscription?.cancel();
    _maintenanceCostsSubscription?.cancel();

    _kpiSubscription = null;
    _workOrdersSummarySubscription = null;
    _workOrdersTrendsSubscription = null;
    _assetPerformanceSubscription = null;
    _pmComplianceSubscription = null;
    _techPerformanceSubscription = null;
    _maintenanceCostsSubscription = null;
  }

  /// Tears down the app-wide singleton. Do not call from widget [dispose].
  void dispose() {
    stopListening();

    if (!_kpiController.isClosed) {
      _kpiController.close();
    }
    if (!_workOrdersSummaryController.isClosed) {
      _workOrdersSummaryController.close();
    }
    if (!_workOrdersTrendsController.isClosed) {
      _workOrdersTrendsController.close();
    }
    if (!_assetPerformanceController.isClosed) {
      _assetPerformanceController.close();
    }
    if (!_pmComplianceController.isClosed) {
      _pmComplianceController.close();
    }
    if (!_techPerformanceController.isClosed) {
      _techPerformanceController.close();
    }
    if (!_maintenanceCostsController.isClosed) {
      _maintenanceCostsController.close();
    }
  }
}
