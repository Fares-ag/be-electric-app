// Duplicate Data Diagnostic - Visual summary of duplicate checks

import 'package:flutter/material.dart';
import '../config/release_safety.dart';
import '../services/unified_data_service.dart';
import '../models/user.dart';
import '../models/work_order.dart';
import '../models/pm_task.dart';
import '../models/asset.dart';
import '../config/locator.dart';

/// Diagnostic utility to analyze duplicate data
class DuplicateDataDiagnostic {
  /// Show diagnostic dialog with comprehensive analysis
  static Future<void> showDiagnosticDialog(BuildContext context) async {
    if (!ReleaseSafety.showDevTools) return;

    final service = sl<UnifiedDataService>();

    // Collect all data
    final users = service.users;
    final workOrders = service.workOrders;
    final pmTasks = service.pmTasks;
    final assets = service.assets;

    // Analyze duplicates
    final userAnalysis = _analyzeUsers(users);
    final woAnalysis = _analyzeWorkOrders(workOrders);
    final pmAnalysis = _analyzePMTasks(pmTasks);
    final assetAnalysis = _analyzeAssets(assets);

    // Show results
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Duplicate Data Diagnostic',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSection('Users', userAnalysis),
                const SizedBox(height: 16),
                _buildSection('Work Orders', woAnalysis),
                const SizedBox(height: 16),
                _buildSection('PM Tasks', pmAnalysis),
                const SizedBox(height: 16),
                _buildSection('Assets', assetAnalysis),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  static Map<String, dynamic> _analyzeUsers(List<User> users) {
    final total = users.length;
    final emails = <String, int>{};
    final fakeUsers = <String>[];

    for (final user in users) {
      emails[user.email] = (emails[user.email] ?? 0) + 1;
      if (user.name == 'Unknown User' || user.email == 'unknown@unknown.com') {
        fakeUsers.add('${user.name} (${user.email})');
      }
    }

    final duplicateEmails = emails.entries.where((e) => e.value > 1).toList();

    return {
      'total': total,
      'unique': emails.length,
      'duplicateEmails': duplicateEmails.length,
      'fakeUsers': fakeUsers.length,
      'details': {
        'Total Users': total,
        'Unique Emails': emails.length,
        'Duplicate Emails': duplicateEmails.length,
        'Fake Users (Unknown)': fakeUsers.length,
        if (duplicateEmails.isNotEmpty)
          'Duplicate Details':
              duplicateEmails.map((e) => '${e.key}: ${e.value}x').join('\n'),
        if (fakeUsers.isNotEmpty) 'Fake Users Found': fakeUsers.join('\n'),
      },
    };
  }

  static Map<String, dynamic> _analyzeWorkOrders(List<WorkOrder> workOrders) {
    final total = workOrders.length;
    final ids = <String, int>{};
    final tickets = <String, int>{};

    for (final wo in workOrders) {
      ids[wo.id] = (ids[wo.id] ?? 0) + 1;
      tickets[wo.ticketNumber] = (tickets[wo.ticketNumber] ?? 0) + 1;
    }

    final duplicateIds = ids.entries.where((e) => e.value > 1).toList();
    final duplicateTickets = tickets.entries.where((e) => e.value > 1).toList();

    return {
      'total': total,
      'unique': ids.length,
      'duplicateIds': duplicateIds.length,
      'duplicateTickets': duplicateTickets.length,
      'details': {
        'Total Work Orders': total,
        'Unique IDs': ids.length,
        'Duplicate IDs': duplicateIds.length,
        'Duplicate Tickets': duplicateTickets.length,
        if (duplicateTickets.isNotEmpty)
          'Duplicate Ticket Numbers':
              duplicateTickets.map((e) => '${e.key}: ${e.value}x').join('\n'),
      },
    };
  }

  static Map<String, dynamic> _analyzePMTasks(List<dynamic> pmTasks) {
    final total = pmTasks.length;
    final ids = <String, int>{};

    for (final pm in pmTasks) {
      ids[pm.id] = (ids[pm.id] ?? 0) + 1;
    }

    final duplicateIds = ids.entries.where((e) => e.value > 1).toList();

    return {
      'total': total,
      'unique': ids.length,
      'duplicateIds': duplicateIds.length,
      'details': {
        'Total PM Tasks': total,
        'Unique IDs': ids.length,
        'Duplicate IDs': duplicateIds.length,
        if (duplicateIds.isNotEmpty)
          'Duplicate PM Task IDs': duplicateIds
              .take(5)
              .map((e) => '${e.key}: ${e.value}x')
              .join('\n'),
      },
    };
  }

  static Map<String, dynamic> _analyzeAssets(List<Asset> assets) {
    final total = assets.length;
    final ids = <String, int>{};
    final names = <String, int>{};

    for (final asset in assets) {
      ids[asset.id] = (ids[asset.id] ?? 0) + 1;
      names[asset.name] = (names[asset.name] ?? 0) + 1;
    }

    final duplicateIds = ids.entries.where((e) => e.value > 1).toList();
    final duplicateNames = names.entries.where((e) => e.value > 1).toList();

    return {
      'total': total,
      'unique': ids.length,
      'duplicateIds': duplicateIds.length,
      'duplicateNames': duplicateNames.length,
      'details': {
        'Total Assets': total,
        'Unique IDs': ids.length,
        'Duplicate IDs': duplicateIds.length,
        'Duplicate Names': duplicateNames.length,
        if (duplicateNames.isNotEmpty)
          'Duplicate Asset Names':
              duplicateNames.map((e) => '${e.key}: ${e.value}x').join('\n'),
      },
    };
  }

  static Widget _buildSection(String title, Map<String, dynamic> data) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          ...data['details'].entries.map<Widget>((entry) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(
                    fontSize: 14,
                    color: data['duplicateIds'] > 0 ||
                            data['duplicateEmails'] > 0 ||
                            data['duplicateTickets'] > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ),),
          if (data['duplicateIds'] > 0 ||
              data['duplicateEmails'] > 0 ||
              data['duplicateTickets'] > 0)
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 4),
              child: Text(
                'DUPLICATES FOUND!',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
        ],
      );
}
