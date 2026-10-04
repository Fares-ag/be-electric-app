import '../utils/deterministic_id_generator.dart';

class User {
  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.department,
    this.lastLoginAt,
    this.workEmail,
    this.companyId,
    this.isActive = true,
    this.updatedAt,
  });

  /// Create a new user with deterministic ID based on email
  factory User.create({
    required String email,
    required String name,
    required String role,
    String? department,
    String? workEmail,
    String? companyId,
    bool isActive = true,
  }) {
    final id = DeterministicIdGenerator.generateUserId(email);
    return User(
      id: id,
      email: email.toLowerCase().trim(),
      name: name.trim(),
      role: role,
      department: department,
      createdAt: DateTime.now(),
      workEmail: workEmail,
      companyId: companyId,
      isActive: isActive,
      updatedAt: DateTime.now(),
    );
  }

  factory User.fromMap(Map<String, dynamic> data) {
    final email = data['email'] ?? '';
    return User(
      id: data['id'] ?? DeterministicIdGenerator.generateUserId(email),
      email: email,
      name: data['name'] ?? '',
      role: data['role'] ?? 'requestor',
      department: data['department'],
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      lastLoginAt: _parseDate(data['lastLoginAt']),
      workEmail: data['workEmail'],
      companyId: _stringOrNull(data['companyId']) ??
          _stringOrNull(data['company_id']),
      isActive: _parseBoolFromDynamic(data['isActive']) ?? true,
      updatedAt: _parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Helper method to parse DateTime from Supabase (ISO8601 string) or DateTime
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Safely parse boolean from dynamic value
  /// Handles: bool, int (0/1), null
  static bool? _parseBoolFromDynamic(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1; // 0 → false, 1 → true
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  final String id;
  final String email;
  final String name;
  final String role; // 'requestor', 'technician', 'manager', or 'admin'
  final String? department;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String? workEmail;
  final String? companyId; // Company/tenant association
  final bool isActive; // Required for requestors
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'department': department,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'workEmail': workEmail,
        'companyId': companyId,
        'isActive': isActive,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? department,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? workEmail,
    String? companyId,
    bool? isActive,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        name: name ?? this.name,
        role: role ?? this.role,
        department: department ?? this.department,
        createdAt: createdAt ?? this.createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        workEmail: workEmail ?? this.workEmail,
        companyId: companyId ?? this.companyId,
        isActive: isActive ?? this.isActive,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isManager => role == 'manager';
  bool get isTechnician => role == 'technician';
  bool get isRequestor => role == 'requestor';
  bool get isAdmin => role == 'admin';
  bool get isAdminOrManager => role == 'admin' || role == 'manager';

  /// Aligns with `pm_tasks` INSERT RLS (admin/manager only).
  bool get canCreatePmTasks => isAdminOrManager;

  /// Convert User to Firestore map
  Map<String, dynamic> toFirestoreMap() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'department': department,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'workEmail': workEmail,
        'isActive': isActive,
        'updatedAt': updatedAt?.toIso8601String(),
      };
}
