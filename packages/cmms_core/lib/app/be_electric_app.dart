import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'cmms_app_mode_scope.dart';
import '../config/cmms_app_mode.dart';
import '../providers/cmms_provider_bundle.dart';
import '../screens/analytics/consolidated_analytics_dashboard.dart';
import '../screens/auth/login_screen.dart';
import '../screens/requestor/create_maintenance_request_screen.dart';
import '../screens/requestor/requestor_splash_screen.dart';
import '../utils/app_theme.dart';
import '../theme/design_tokens.dart';
import '../widgets/role_based_navigation.dart';

class BeElectricApp extends StatefulWidget {
  const BeElectricApp({super.key, required this.appMode});

  final CmmsAppMode appMode;

  @override
  State<BeElectricApp> createState() => _BeElectricAppState();
}

class _BeElectricAppState extends State<BeElectricApp> {
  late final CmmsProviderBundle _providerBundle;

  @override
  void initState() {
    super.initState();
    _providerBundle = CmmsProviderBundle();
  }

  @override
  void dispose() {
    _providerBundle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.appMode) {
      CmmsAppMode.requestor => 'Be Electric — Requestor',
      CmmsAppMode.technician => 'Be Electric — Technician',
    };

    return MultiProvider(
      providers: _providerBundle.providers,
      child: CmmsAppModeScope(
        appMode: widget.appMode,
        child: MaterialApp(
          title: title,
          theme: AppTheme.lightTheme,
          builder: (context, child) => DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: DesignTokens.fontFamily),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
          routes: {
            '/create_maintenance_request': (context) {
              final args = ModalRoute.of(context)!.settings.arguments!
                  as Map<String, dynamic>;
              return CreateMaintenanceRequestScreen(
                asset: args['asset'],
                qrCode: args['qrCode'],
              );
            },
            '/analytics_dashboard': (context) =>
                const ConsolidatedAnalyticsDashboard(),
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showSplash = true;
  bool _splashCompleted = false;
  bool _listenerAdded = false;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_listenerAdded) {
      try {
        _authProvider = Provider.of<AuthProvider>(context, listen: false);
        _authProvider?.addListener(_onAuthChanged);
        _listenerAdded = true;
        debugPrint('🔧 AuthWrapper: Listener added to AuthProvider');
      } catch (e, st) {
        debugPrint('⚠️ AuthWrapper: Error adding listener: $e');
      }
    }
  }

  void _onAuthChanged() {
    if (mounted) {
      debugPrint(
        '🔔 AuthWrapper: Auth state changed listener triggered - forcing rebuild',
      );
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (_listenerAdded && _authProvider != null) {
      try {
        _authProvider!.removeListener(_onAuthChanged);
        debugPrint('🔧 AuthWrapper: Listener removed from AuthProvider');
      } catch (e, st) {
        debugPrint('⚠️ AuthWrapper: Error removing listener: $e');
      }
    }
    super.dispose();
  }

  void _startSplashSequence() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSplash = false;
          _splashCompleted = true;
        });
        _checkAuthStatus();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuthStatus();
    } catch (e, st) {
      debugPrint('Error checking auth status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return const RequestorSplashScreen();
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint(
          '🔄 AuthWrapper REBUILD: isAuthenticated=${authProvider.isAuthenticated}, '
          'isRestoringSession=${authProvider.isRestoringSession}, '
          'isLoading=${authProvider.isLoading}, '
          'currentUser=${authProvider.currentUser?.name}, '
          'splashCompleted=$_splashCompleted',
        );

        if (!_splashCompleted || authProvider.isRestoringSession) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated && authProvider.currentUser != null) {
          debugPrint(
            '✅ AuthWrapper: Navigating to RoleBasedNavigation for user: ${authProvider.currentUser!.name}',
          );
          return RoleBasedNavigation(
            key: ValueKey(authProvider.currentUser!.id),
            appMode: CmmsAppModeScope.of(context),
          );
        }

        debugPrint('⚠️ AuthWrapper: Showing LoginScreen');
        return const LoginScreen();
      },
    );
  }
}
