import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/production_config.dart';

class SupportService {

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Submit support ticket
  Future<void> submitSupportTicket({
    required String subject,
    required String description,
    required String category,
    String? priority,
    List<String>? attachments,
    Map<String, dynamic>? additionalData,
  }) async {
    final ticket = {
      'id': _generateTicketId(),
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority ?? 'medium',
      'attachments': attachments ?? [],
      'additional_data': additionalData ?? {},
      'device_info': await _getDeviceInfo(),
      'app_info': await _getAppInfo(),
      'user_info': await _getUserInfo(),
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'open',
    };

    await _storeSupportTicket(ticket);
    // Track support ticket submission
    print('Analytics: Support ticket submitted');

    // In a real app, this would send to a support system
    print('Support ticket submitted: ${ticket['id']}');
  }

  // Report bug
  Future<void> reportBug({
    required String description,
    required String stepsToReproduce,
    String? expectedBehavior,
    String? actualBehavior,
    String? severity,
    List<String>? screenshots,
    Map<String, dynamic>? additionalData,
  }) async {
    await submitSupportTicket(
      subject: 'Bug Report',
      description: description,
      category: 'bug',
      priority: severity ?? 'medium',
      attachments: screenshots,
      additionalData: {
        'steps_to_reproduce': stepsToReproduce,
        'expected_behavior': expectedBehavior,
        'actual_behavior': actualBehavior,
        ...?additionalData,
      },
    );
  }

  // Request feature
  Future<void> requestFeature({
    required String featureDescription,
    required String businessJustification,
    String? priority,
    Map<String, dynamic>? additionalData,
  }) async {
    await submitSupportTicket(
      subject: 'Feature Request',
      description: featureDescription,
      category: 'feature_request',
      priority: priority ?? 'low',
      additionalData: {
        'business_justification': businessJustification,
        ...?additionalData,
      },
    );
  }

  // Get support tickets
  Future<List<Map<String, dynamic>>> getSupportTickets({
    String? status,
    String? category,
    int? limit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final ticketsJson = prefs.getStringList('support_tickets') ?? [];

    var tickets = ticketsJson
        .map((ticket) => jsonDecode(ticket) as Map<String, dynamic>)
        .toList();

    // Filter by status
    if (status != null) {
      tickets = tickets.where((ticket) => ticket['status'] == status).toList();
    }

    // Filter by category
    if (category != null) {
      tickets =
          tickets.where((ticket) => ticket['category'] == category).toList();
    }

    // Sort by timestamp (newest first)
    tickets.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    // Apply limit
    if (limit != null && tickets.length > limit) {
      tickets = tickets.take(limit).toList();
    }

    return tickets;
  }

  // Update support ticket status
  Future<void> updateSupportTicketStatus(String ticketId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final ticketsJson = prefs.getStringList('support_tickets') ?? [];

    final tickets = ticketsJson
        .map((ticket) => jsonDecode(ticket) as Map<String, dynamic>)
        .toList();

    final ticketIndex =
        tickets.indexWhere((ticket) => ticket['id'] == ticketId);
    if (ticketIndex != -1) {
      tickets[ticketIndex]['status'] = status;
      tickets[ticketIndex]['updated_at'] = DateTime.now().toIso8601String();

      final updatedTicketsJson = tickets.map(jsonEncode).toList();
      await prefs.setStringList('support_tickets', updatedTicketsJson);

      // Track support ticket update
      print('Analytics: Support ticket updated');
    }
  }

  // Get FAQ data
  Future<List<Map<String, dynamic>>> getFAQ() async => [
        {
          'id': 'faq_001',
          'question': 'How do I login to the app?',
          'answer':
              "Use your company email and password provided by IT. If you don't have credentials, contact your IT department.",
          'category': 'authentication',
        },
        {
          'id': 'faq_002',
          'question': 'How do I scan a QR code?',
          'answer':
              'Tap the QR code icon in asset search, point your camera at the QR code, and wait for it to be recognized automatically.',
          'category': 'features',
        },
        {
          'id': 'faq_003',
          'question': 'What if the app is offline?',
          'answer':
              "The app works offline. You can create work orders and complete tasks. Data will sync automatically when you're back online.",
          'category': 'offline',
        },
        {
          'id': 'faq_004',
          'question': 'How do I add photos to work orders?',
          'answer':
              'Tap the camera icon in the work order form, take a photo or select from gallery, and it will be attached automatically.',
          'category': 'features',
        },
        {
          'id': 'faq_005',
          'question': 'How do I complete a work order?',
          'answer':
              'Open the work order, fill in the completion details, add your signature, and tap "Close Ticket".',
          'category': 'work_orders',
        },
        {
          'id': 'faq_006',
          'question': "What if I can't find an asset?",
          'answer':
              'Try searching by name or serial number. If still not found, contact your manager or IT support.',
          'category': 'assets',
        },
        {
          'id': 'faq_007',
          'question': 'How do I change my password?',
          'answer':
              'Go to Profile settings, tap "Change Password", enter your current and new password, then save.',
          'category': 'account',
        },
        {
          'id': 'faq_008',
          'question': 'Why am I not receiving notifications?',
          'answer':
              'Check your device notification settings for the app. Make sure notifications are enabled and not blocked.',
          'category': 'notifications',
        },
      ];

  // Get help articles
  Future<List<Map<String, dynamic>>> getHelpArticles() async => [
        {
          'id': 'help_001',
          'title': 'Getting Started Guide',
          'content': 'Complete guide to using the CMMS mobile app...',
          'category': 'getting_started',
          'tags': ['beginner', 'setup', 'first_time'],
        },
        {
          'id': 'help_002',
          'title': 'Work Order Management',
          'content': 'How to create, assign, and complete work orders...',
          'category': 'work_orders',
          'tags': ['work_orders', 'maintenance', 'tasks'],
        },
        {
          'id': 'help_003',
          'title': 'Preventive Maintenance',
          'content': 'Managing PM tasks and schedules...',
          'category': 'pm_tasks',
          'tags': ['preventive', 'maintenance', 'scheduling'],
        },
        {
          'id': 'help_004',
          'title': 'Asset Management',
          'content': 'Finding and managing assets...',
          'category': 'assets',
          'tags': ['assets', 'qr_codes', 'search'],
        },
        {
          'id': 'help_005',
          'title': 'Offline Mode',
          'content': 'Working without internet connection...',
          'category': 'offline',
          'tags': ['offline', 'sync', 'connectivity'],
        },
      ];

  // Get system status
  Future<Map<String, dynamic>> getSystemStatus() async => {
        'app_version': ProductionConfig.appVersion,
        'api_status': await _checkApiStatus(),
        'sync_status': await _checkSyncStatus(),
        'last_sync': await _getLastSyncTime(),
        'offline_mode': await _isOfflineMode(),
        'device_info': await _getDeviceInfo(),
        'timestamp': DateTime.now().toIso8601String(),
      };

  // Send feedback
  Future<void> sendFeedback({
    required String feedback,
    required String type,
    int? rating,
    Map<String, dynamic>? additionalData,
  }) async {
    await submitSupportTicket(
      subject: 'User Feedback',
      description: feedback,
      category: 'feedback',
      priority: 'low',
      additionalData: {
        'feedback_type': type,
        'rating': rating,
        ...?additionalData,
      },
    );
  }

  // Get contact information
  Map<String, String> getContactInfo() => {
        'support_email': ProductionConfig.supportEmail,
        'support_phone': ProductionConfig.supportPhone,
        'support_website': ProductionConfig.supportWebsite,
        'emergency_contact': '+1-555-EMERGENCY',
      };

  // Private helper methods
  String _generateTicketId() =>
      'ticket_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';

  Future<void> _storeSupportTicket(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final tickets = prefs.getStringList('support_tickets') ?? [];

    tickets.add(jsonEncode(ticket));

    // Keep only last 100 tickets
    if (tickets.length > 100) {
      tickets.removeRange(0, tickets.length - 100);
    }

    await prefs.setStringList('support_tickets', tickets);
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'version': iosInfo.systemVersion,
          'identifier': iosInfo.identifierForVendor,
        };
      }
    } catch (e) {
      // Handle error
    }

    return {'platform': 'unknown'};
  }

  Future<Map<String, dynamic>> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'app_name': packageInfo.appName,
        'package_name': packageInfo.packageName,
        'version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
      };
    } catch (e) {
      return {
        'app_name': ProductionConfig.appName,
        'version': ProductionConfig.appVersion,
        'build_number': ProductionConfig.appBuildNumber,
      };
    }
  }

  Future<Map<String, dynamic>> _getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': prefs.getString('current_user_id'),
      'user_email': prefs.getString('current_user_email'),
      'user_role': prefs.getString('current_user_role'),
      'last_login': prefs.getString('last_login_time'),
    };
  }

  Future<String> _checkApiStatus() async {
    // This would check the actual API status
    return 'online';
  }

  Future<String> _checkSyncStatus() async {
    // This would check the sync status
    return 'up_to_date';
  }

  Future<String?> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_time');
  }

  Future<bool> _isOfflineMode() async {
    // This would check connectivity
    return false;
  }
}
