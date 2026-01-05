import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/home_screen.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../services/user_settings_service.dart';

/// Route paths
class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/';
  
  // Add your custom routes here:
  // static const String profile = '/profile';
  // static const String settings = '/settings';
}

/// Notifier that listens to auth state changes
class AuthNotifier extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserSettingsService _userSettings = UserSettingsService();
  late final StreamSubscription<AuthState> _subscription;

  AuthNotifier() {
    _subscription = SupabaseService.authStateStream.listen((authState) async {
      if (authState.event == AuthChangeEvent.signedIn &&
          authState.session?.user != null) {
        await _authService.onAuthStateChanged(authState.session!.user);
        await _userSettings.loadSettings();
      } else if (authState.event == AuthChangeEvent.signedOut) {
        _userSettings.clear();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// App router configuration
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _authNotifier = AuthNotifier();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final isAuthenticated = SupabaseService.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;

      // Redirect to signup if not authenticated and not on auth route
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.signup;
      }

      // If authenticated and on auth route, go home
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),

      // Main app routes
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // ============================================
      // TODO: Add your custom routes here
      // ============================================
      // GoRoute(
      //   path: AppRoutes.profile,
      //   name: 'profile',
      //   builder: (context, state) => const ProfileScreen(),
      // ),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.matchedLocation,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
  );
}




