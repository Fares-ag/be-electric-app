import 'package:cmms_core/models/asset.dart';
import 'package:cmms_core/models/pm_occurrence.dart';
import 'package:cmms_core/models/user.dart';
import 'package:cmms_core/providers/asset_provider.dart';
import 'package:cmms_core/providers/auth_provider.dart';
import 'package:cmms_core/providers/pm_inbox_provider.dart';
import 'package:cmms_core/providers/pm_occurrence_provider.dart';
import 'package:cmms_core/providers/user_provider.dart';
import 'package:cmms_core/services/unified_data_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'fake_pm_occurrence_service.dart';
import 'fake_work_order_provider_for_inbox.dart';

class InboxStubDataService extends UnifiedDataService {
  InboxStubDataService({this.stubAssets = const []});

  final List<Asset> stubAssets;

  @override
  List<Asset> get assets => stubAssets;
}

Future<void> pumpRequestorPmWidget(
  WidgetTester tester, {
  required Widget child,
  FakePmOccurrenceService? pmService,
  List<Asset> assets = const [],
  User? user,
  bool loadCompanyData = true,
}) async {
  final auth = AuthProvider();
  if (user != null) {
    auth.setUser(user);
  }

  final dataService = InboxStubDataService(stubAssets: assets);
  final assetProvider = AssetProvider(dataService: dataService);
  final users = UserProvider(dataService: dataService);
  final workOrders = FakeWorkOrderProviderForInbox(
    users: users,
    assets: assetProvider,
    dataService: dataService,
  );
  final pmOccurrences = PmOccurrenceProvider(
    service: pmService ?? FakePmOccurrenceService(enabled: true),
  );
  final inboxProvider = PmInboxProvider(
    workOrders: workOrders,
    pmOccurrences: pmOccurrences,
    referenceDate: () => DateTime.utc(2026, 6, 25),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<UserProvider>.value(value: users),
        ChangeNotifierProvider<AssetProvider>.value(value: assetProvider),
        ChangeNotifierProvider<PmOccurrenceProvider>.value(value: pmOccurrences),
        ChangeNotifierProvider<PmInboxProvider>.value(value: inboxProvider),
      ],
      child: MaterialApp(home: child),
    ),
  );

  if (loadCompanyData && user?.companyId != null) {
    await pmOccurrences.loadCompanyOccurrences(user!.companyId);
  }
  await tester.pumpAndSettle();
}

PmOccurrence sampleAuthorizedOccurrence({
  String id = 'occ-1',
  String assetId = 'asset-1',
  String taskName = 'Quarterly inspection',
}) =>
    PmOccurrence.fromMap({
      'id': id,
      'scheduleId': 'sched-$id',
      'assetId': assetId,
      'dueDate': DateTime.utc(2026, 6, 30),
      'status': 'pending',
      'schedule': {
        'id': 'sched-$id',
        'taskName': taskName,
        'frequency': 'monthly',
        'frequencyValue': 30,
        'scheduleStartDate': DateTime.utc(2026, 1, 1),
        'scheduleEndDate': DateTime.utc(2026, 12, 31),
      },
      'asset': {
        'name': 'Charger A',
        'location': 'Bay 1',
      },
    });

Asset sampleAuthorizedAsset({String id = 'asset-1'}) => Asset(
      id: id,
      name: 'Charger A',
      location: 'Bay 1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      companyId: 'company-1',
    );

User sampleRequestorUser() => User(
      id: 'requestor-1',
      email: 'requestor@test.com',
      name: 'Requestor User',
      role: 'requestor',
      companyId: 'company-1',
      createdAt: DateTime.utc(2026, 1, 1),
    );
