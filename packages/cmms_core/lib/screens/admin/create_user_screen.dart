import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart' as app_user;
import '../../providers/unified_data_provider.dart';
import '../../repositories/cmms_repositories.dart';
import '../../services/user_auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../utils/data_integrity_guard.dart';
import '../../utils/user_facing_errors.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({
    required this.userRole,
    super.key,
  });

  final String userRole;

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final name = _nameController.text.trim();
      final password = _passwordController.text;
      final department = _departmentController.text.trim();

      // Validate user data
      final validation = DataIntegrityGuard.validateUserData(
        email: email,
        name: name,
        role: widget.userRole,
      );

      if (!validation['isValid']) {
        final errors = validation['errors'] as List<String>;
        throw Exception(errors.join('\n'));
      }

      // Check for duplicate email
      final isUnique = await DataIntegrityGuard.isEmailUnique(email);
      if (!isUnique) {
        throw Exception('Email already exists in the system!');
      }

      // Create authentication account
      final authService = UserAuthService();
      Map<String, dynamic>? authResult;

      try {
        authResult = await authService.createUserAccount(
          email: email,
          password: password,
          name: name,
          role: widget.userRole,
          department: department.isEmpty ? null : department,
        );
      } catch (e, st) {
        // Check if error is "email already in use"
        if (e.toString().contains('An account already exists for this email') ||
            e.toString().contains('email-already-in-use')) {
          // Check if user exists in Supabase
          final existingUser =
              await CmmsRepositories.users.getUserByEmail(email);

          if (existingUser != null) {
            // User exists in both Auth and Supabase - this is a real duplicate
            throw Exception(
                'User with this email already exists in the system');
          }

          // Auth account exists but Supabase document doesn't - create the Supabase document
          print(
              '⚠️ Auth account exists for $email but Supabase document is missing. Creating Supabase document...');

          // Return a placeholder - the Supabase document will be created with readable ID
          authResult = {
            'uid': '', // Will be empty since we can't get it without password
            'email': email,
            'name': name,
            'role': widget.userRole,
            'isEmailVerified': false,
          };
        } else {
          rethrow;
        }
      }

      if (authResult == null) {
        throw Exception('Failed to create authentication account');
      }

      // Use Auth UUID when available so public.users.id matches auth.users.id
      final authUid = authResult['uid']?.toString();
      final user = app_user.User(
        id: authUid?.isNotEmpty == true ? authUid! : '',
        email: email,
        name: name,
        role: widget.userRole,
        department: department.isEmpty ? null : department,
        createdAt: DateTime.now(),
      );

      final unifiedProvider =
          Provider.of<UnifiedDataProvider>(context, listen: false);
      await unifiedProvider.createUser(user);

      if (mounted) {
        // Show success dialog
        await _showSuccessDialog(email, password);

        // Go back to user management
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      if (mounted) {
        showUserErrorSnackBar(
          context,
          e,
          genericMessage: 'Could not create user. Please try again.',
          stackTrace: st,
          contextLabel: 'CreateUser: create',
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSuccessDialog(String email, String password) async =>
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 32),
              SizedBox(width: AppTheme.spacingM),
              Text('User Created!'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_capitalize(widget.userRole)} account created successfully!',
                  style: AppTheme.bodyText.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen
                        .withValues(alpha: 0.1), // Be Electric brand green
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                      color: AppTheme.accentGreen
                          .withValues(alpha: 0.3), // Be Electric brand green
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Login Credentials:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      _buildCredentialRow('Email', email),
                      _buildCredentialRow('Password', password),
                      _buildCredentialRow('Role', _capitalize(widget.userRole)),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.accentOrange),
                      SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: Text(
                          'Please save these credentials. The user will need them to login.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  Widget _buildCredentialRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('Create ${_capitalize(widget.userRole)}'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.darkTextColor,
        elevation: AppTheme.elevationS,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ResponsiveContainer(
            maxWidth: ResponsiveLayout.getFormMaxWidth(context),
            padding: ResponsiveLayout.getResponsivePadding(context),
            centerContent: ResponsiveLayout.isDesktop(context) ||
                ResponsiveLayout.isTablet(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingL),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getRoleIcon(),
                              color: _getRoleColor(),
                              size: 32,
                            ),
                            const SizedBox(width: AppTheme.spacingM),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New ${_capitalize(widget.userRole)} Account',
                                    style: AppTheme.heading1.copyWith(
                                      color: AppTheme.darkTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacingXS),
                                  Text(
                                    'Fill in the details below to create a new user account',
                                    style: AppTheme.smallText.copyWith(
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingL),

                  // Form Fields
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      if (value.trim().toLowerCase() == 'unknown') {
                        return 'Cannot use "unknown" as name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppTheme.spacingM),

                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!DataIntegrityGuard.isValidEmail(value)) {
                        return 'Please enter a valid email';
                      }
                      if (value.toLowerCase().contains('unknown')) {
                        return 'Cannot use "unknown" in email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppTheme.spacingM),

                  _buildTextField(
                    controller: _departmentController,
                    label: 'Department (Optional)',
                    icon: Icons.business,
                    required: false,
                  ),

                  const SizedBox(height: AppTheme.spacingM),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
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

                  const SizedBox(height: AppTheme.spacingM),

                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
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

                  const SizedBox(height: AppTheme.spacingXL),

                  // Submit Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
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
                            ? 'Creating User...'
                            : 'Create ${_capitalize(widget.userRole)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getRoleColor(),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    bool required = true,
  }) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          prefixIcon: Icon(icon,
              color: AppTheme.accentGreen), // Be Electric brand green
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: BorderSide(
              color: AppTheme.secondaryTextColor.withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            borderSide: const BorderSide(
              color: AppTheme.accentGreen, // Be Electric brand green
              width: 2,
            ),
          ),
          filled: true,
          fillColor: AppTheme.surfaceColor,
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        textInputAction: TextInputAction.next,
      );

  IconData _getRoleIcon() {
    switch (widget.userRole.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'technician':
        return Icons.build_circle;
      case 'requestor':
        return Icons.person;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor() {
    switch (widget.userRole.toLowerCase()) {
      case 'admin':
        return AppTheme.accentRed;
      case 'manager':
        return AppTheme.accentOrange;
      case 'technician':
        return AppTheme.accentBlue;
      case 'requestor':
        return AppTheme.accentGreen;
      default:
        return AppTheme.accentBlue;
    }
  }
}
