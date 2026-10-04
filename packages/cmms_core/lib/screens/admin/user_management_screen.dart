import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/company.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/unified_data_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../services/user_auth_service.dart';
import '../../utils/app_theme.dart';
import '../auth/login_screen.dart';
import '../../utils/user_facing_errors.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  // No more local state! We'll use Consumer to get real-time data

  Future<void> _createTechnician() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateUserScreen(userRole: 'technician'),
      ),
    );
    // No need to refresh - Consumer rebuilds automatically!
  }

  Future<void> _createRequestor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateUserScreen(userRole: 'requestor'),
      ),
    );
    // No need to refresh - Consumer rebuilds automatically!
  }

  // Removed _forceDatabaseInit - no longer needed with real-time Supabase sync!

  @override
  Widget build(BuildContext context) {
    // Mobile responsive check
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Use Consumer to automatically rebuild when users arrive from Supabase!
    return Consumer<UnifiedDataProvider>(
      builder: (context, unifiedProvider, child) {
        final users = unifiedProvider.users;
        print(
          '🔍 User Management: Rendering ${users.length} users (real-time)',
        );

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'User Management (${users.length} users)',
              style: TextStyle(fontSize: isMobile ? 16 : 20),
            ),
            backgroundColor: AppTheme.surfaceColor,
            foregroundColor: AppTheme.darkTextColor,
            elevation: AppTheme.elevationS,
          ),
          body: users.isEmpty && unifiedProvider.isUsersLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a technician or requestor account to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Action Buttons - Responsive layout
                    Padding(
                      padding: EdgeInsets.all(
                        isMobile ? AppTheme.spacingM : AppTheme.spacingL,
                      ),
                      child: Column(
                        children: [
                          if (isMobile)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _createTechnician,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Create Technician'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.spacingM,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingM),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _createRequestor,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Create Requestor'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.spacingM,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _createTechnician,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Create Technician'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.spacingM,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spacingM),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _createRequestor,
                                    icon: const Icon(Icons.person_add),
                                    label: const Text('Create Requestor'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppTheme.spacingM,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          // No refresh button needed - real-time sync!
                        ],
                      ),
                    ),

                    // Users List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingL,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _buildUserCard(user);
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildUserCard(User user) {
    Color roleColor;
    IconData roleIcon;

    switch (user.role.toLowerCase()) {
      case 'admin':
        roleColor = AppTheme.accentRed;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'manager':
        roleColor = AppTheme.accentOrange;
        roleIcon = Icons.manage_accounts;
        break;
      case 'technician':
        roleColor = AppTheme.accentBlue;
        roleIcon = Icons.build;
        break;
      case 'requestor':
        roleColor = AppTheme.accentGreen;
        roleIcon = Icons.person;
        break;
      default:
        roleColor = AppTheme.secondaryTextColor;
        roleIcon = Icons.person;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: roleColor.withOpacity(0.2),
                child: Icon(roleIcon, color: roleColor),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: AppTheme.heading2.copyWith(
                        color: AppTheme.darkTextColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      user.email,
                      style: AppTheme.smallText.copyWith(
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                    if (user.workEmail != null) ...[
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        'Work: ${user.workEmail}',
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    // Check if user can be deleted
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final currentUser = authProvider.currentUser;
                    
                    // Only admins can delete admins/managers
                    if ((user.role == 'admin' || user.role == 'manager') &&
                        currentUser?.role != 'admin') {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Only administrators can delete ${user.role}s',
                            ),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                      return;
                    }
                    
                    // Can't delete yourself
                    if (currentUser?.id == user.id) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'You cannot delete your own account',
                            ),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                      return;
                    }
                    
                    final confirmed = await _showDeleteConfirmation(user);
                    if (confirmed ?? false) {
                      await _deleteUser(user);
                    }
                  } else if (value == 'reset_password') {
                    await _sendPasswordReset(user);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reset_password',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, color: AppTheme.accentBlue),
                        SizedBox(width: AppTheme.spacingS),
                        Text('Send Password Reset'),
                      ],
                    ),
                  ),
                  // Show delete option for all users (validation happens on click)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.accentRed),
                        SizedBox(width: AppTheme.spacingS),
                        Text('Delete User'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              // Current role badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingS,
                  vertical: AppTheme.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: AppTheme.smallText.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              // Role selector
              DropdownButton<String>(
                value: user.role,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 'requestor',
                    child: Text('Requestor'),
                  ),
                  DropdownMenuItem(
                    value: 'technician',
                    child: Text('Technician'),
                  ),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Administrator'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null || value == user.role) return;
                  await _updateUserRole(user, value);
                },
              ),
              const Spacer(),
              // Active toggle
              Row(
                children: [
                  Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: AppTheme.smallText.copyWith(
                      color: user.isActive
                          ? AppTheme.accentGreen
                          : AppTheme.secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Switch(
                    value: user.isActive,
                    onChanged: (v) async => _toggleUserActive(user, v),
                    activeThumbColor: AppTheme.accentGreen,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateUserRole(User user, String newRole) async {
    try {
      final updated = User(
        id: user.id,
        email: user.email,
        name: user.name,
        role: newRole,
        department: user.department,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        workEmail: user.workEmail,
        isActive: user.isActive,
        updatedAt: DateTime.now(),
      );

      // CRITICAL: Save to both local database AND Supabase!
      // Update user in Supabase via UnifiedDataProvider (already called below)
      await Provider.of<UnifiedDataProvider>(context, listen: false)
          .updateUser(updated);

      debugPrint('✅ User role updated: ${user.name} → $newRole');

      // Real-time sync will auto-update the UI!
      try {
        await Provider.of<UnifiedDataProvider>(context, listen: false)
            .refreshAll();
      } catch (_) {}

      // If the updated user is the currently logged-in user, refresh session and re-route
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser?.id == updated.id) {
        // Force logout and re-login to ensure clean session
        await authProvider.logout();

        // Show message about re-login requirement
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Your role has been changed to $newRole. Please log in again.',
              ),
              backgroundColor: AppTheme.accentOrange,
              duration: const Duration(seconds: 5),
            ),
          );

          // Navigate to login screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated role for ${user.name} to $newRole'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update role. Please try again.',
          stackTrace: st,
          contextLabel: 'UserManagement: update role',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _toggleUserActive(User user, bool isActive) async {
    try {
      final updated = User(
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        department: user.department,
        createdAt: user.createdAt,
        lastLoginAt: user.lastLoginAt,
        workEmail: user.workEmail,
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      // Update user in Supabase via UnifiedDataProvider
      await Provider.of<UnifiedDataProvider>(context, listen: false)
          .updateUser(updated);

      debugPrint('✅ User active status updated: ${user.name} → $isActive');
      // Real-time sync will auto-update the UI!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? 'Reactivated ${user.name}'
                  : 'Deactivated ${user.name}',
            ),
            backgroundColor:
                isActive ? AppTheme.accentGreen : AppTheme.accentOrange,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not update status. Please try again.',
          stackTrace: st,
          contextLabel: 'UserManagement: update status',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<void> _sendPasswordReset(User user) async {
    try {
      await UserAuthService().sendPasswordResetEmail(user.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${user.email}'),
            backgroundColor: AppTheme.accentBlue,
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not send reset email. Please try again.',
          stackTrace: st,
          contextLabel: 'UserManagement: reset email',
          backgroundColor: AppTheme.accentRed,
        );
      }
    }
  }

  Future<bool?> _showDeleteConfirmation(User user) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete User'),
          content: Text('Are you sure you want to delete ${user.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accentRed),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

  Future<void> _deleteUser(User user) async {
    try {
      // Get current user for validation
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Deleting ${user.name}...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Use UnifiedDataProvider to delete (handles both local and Supabase)
      final unifiedProvider = Provider.of<UnifiedDataProvider>(context, listen: false);
      await unifiedProvider.deleteUser(
        user.id,
        currentUserRole: currentUser?.role,
        currentUserId: currentUser?.id,
      );
      
      // Success - user is deleted from local database (and Supabase if connected)
      // Real-time sync will auto-update the UI!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.name} deleted successfully'),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: ${e.toString()}'),
            backgroundColor: AppTheme.accentRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({required this.userRole, super.key});
  final String userRole;

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedCompanyId;
  List<Company> _companies = [];
  bool _loadingCompanies = false;

  @override
  void initState() {
    super.initState();
    if (widget.userRole == 'requestor') {
      _loadCompanies();
    }
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    try {
      final companies = await CmmsRepositories.users.getAllCompanies();
      if (mounted) {
        setState(() {
          _companies = companies;
          _loadingCompanies = false;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _loadingCompanies = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _workEmailController.dispose();
    _departmentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // First, create the authentication account
      final authResult = await _createAuthAccount();
      if (authResult == null) {
        throw Exception('Failed to create authentication account');
      }

      // Use Auth UUID so public.users.id matches auth.users.id (required for triggers/RLS)
      final authUid = authResult['uid']?.toString();
      final user = User(
        id: authUid?.isNotEmpty == true ? authUid! : '',
        email: widget.userRole == 'requestor'
            ? _workEmailController.text.trim()
            : _emailController.text.trim(),
        name: _nameController.text.trim(),
        role: widget.userRole,
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        workEmail: widget.userRole == 'requestor'
            ? _workEmailController.text.trim()
            : null,
        companyId: widget.userRole == 'requestor' ? _selectedCompanyId : null,
        createdAt: DateTime.now(),
      );

      print(
        '🔍 User Creation: Creating user ${user.name} with role ${user.role}',
      );
      
      // Create user in Supabase via UnifiedDataProvider
      final unifiedProvider = Provider.of<UnifiedDataProvider>(context, listen: false);
      await unifiedProvider.createUser(user);
      print('✅ User Creation: User ${user.name} created successfully in Supabase');

      if (mounted) {
        // Show credentials dialog
        await _showCredentialsDialog(authResult);
        Navigator.pop(context, true);
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not create user account. Please try again.',
          stackTrace: st,
          contextLabel: 'UserManagement: create account',
          backgroundColor: AppTheme.accentRed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _createAuthAccount() async {
    final email = widget.userRole == 'requestor'
        ? _workEmailController.text.trim()
        : _emailController.text.trim();
    
    try {
      final authService = UserAuthService();

      return await authService.createUserAccount(
        email: email,
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: widget.userRole,
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        workEmail: widget.userRole == 'requestor'
            ? _workEmailController.text.trim()
            : null,
      );
    } catch (e, st) {
      // Check if error is "email already in use"
      if (e.toString().contains('An account already exists for this email') ||
          e.toString().contains('email-already-in-use')) {
        // Check if user exists in Supabase
        final existingUser = await CmmsRepositories.users.getUserByEmail(email);
        
        if (existingUser != null) {
          // User exists in both Auth and Supabase - this is a real duplicate
          throw Exception('User with this email already exists in the system');
        }
        
        // Auth account already exists in Supabase Auth but no app profile was found.
        // We cannot safely retrieve the Auth UID client-side without the service role key.
        // Throw a clear error so the admin knows the correct recovery path.
        throw Exception(
          'An Auth account already exists for  but no app profile was found. '
          'To recover: run sync_one_auth_user_to_public.sql in the Supabase SQL Editor '
          'to sync the existing Auth account, then assign them a company and role in this screen.',
        );
      }
      
      print('Auth account creation error: $e');
      rethrow;
    }
  }

  Future<void> _showCredentialsDialog(Map<String, dynamic> authResult) async =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.accentGreen),
              SizedBox(width: AppTheme.spacingS),
              Text('Account Created Successfully'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.userRole.capitalize()} account has been created with the following credentials:',
                  style: AppTheme.bodyText,
                ),
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border:
                        Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCredentialRow('Email', authResult['email']),
                      _buildCredentialRow('Password', _passwordController.text),
                      _buildCredentialRow('Role', authResult['role']),
                      _buildCredentialRow('User ID', authResult['uid']),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingM),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: AppTheme.accentOrange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning,
                        color: AppTheme.accentOrange,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          'Please save these credentials securely. The user will need them to log in.',
                          style: AppTheme.smallText.copyWith(
                            color: AppTheme.darkTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Copy credentials to clipboard
                // You would implement clipboard functionality here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Credentials copied to clipboard'),
                    backgroundColor: AppTheme.accentGreen,
                  ),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Copy Credentials'),
            ),
          ],
        ),
      );

  Widget _buildCredentialRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                '$label:',
                style: AppTheme.smallText.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkTextColor,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTheme.smallText.copyWith(
                  color: AppTheme.primaryColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text('Create ${widget.userRole.capitalize()}'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.darkTextColor,
          elevation: AppTheme.elevationS,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the full name';
                    }
                    return null;
                  },
                ),
                if (widget.userRole != 'requestor') ...[
                  const SizedBox(height: AppTheme.spacingL),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the email address';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppTheme.spacingL),
                TextFormField(
                  controller: _departmentController,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                  ),
                ),
                // Company selection (for requestors)
                if (widget.userRole == 'requestor') ...[
                  const SizedBox(height: AppTheme.spacingL),
                  _loadingCompanies
                      ? const CircularProgressIndicator()
                      : DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Company',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusS)),
                            ),
                          ),
                          value: _selectedCompanyId,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No Company'),
                            ),
                            ..._companies
                                .where((c) => c.isActive)
                                .map((company) => DropdownMenuItem<String>(
                                      value: company.id,
                                      child: Text(company.name),
                                    )),
                          ],
                          onChanged: (value) => setState(() => _selectedCompanyId = value),
                        ),
                ],
                const SizedBox(height: AppTheme.spacingL),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spacingL),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm the password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (widget.userRole == 'requestor') ...[
                  const SizedBox(height: AppTheme.spacingL),
                  TextFormField(
                    controller: _workEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Work Email *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the work email address';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid work email address';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppTheme.spacingL),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: AppTheme.accentBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppTheme.accentBlue,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            'Account Creation',
                            style: AppTheme.bodyText.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Text(
                        'This will create a login account for the ${widget.userRole} with the provided credentials. They will be able to log in to the system using their email and password.',
                        style: AppTheme.smallText.copyWith(
                          color: AppTheme.darkTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createUser,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(
                    _isLoading
                        ? 'Creating...'
                        : 'Create ${widget.userRole.capitalize()}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.userRole == 'technician'
                        ? AppTheme.accentBlue
                        : AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingM,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}
