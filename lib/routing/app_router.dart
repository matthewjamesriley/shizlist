import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/auth/screens/country_selection_screen.dart';
import '../features/lists/screens/lists_screen.dart';
import '../features/lists/screens/list_detail_screen.dart';
import '../features/items/screens/add_item_screen.dart';
import '../features/contacts/screens/contacts_screen.dart';
import '../features/messages/screens/messages_screen.dart';
import '../features/share/screens/share_screen.dart';
import '../features/invite/screens/invite_screen.dart';
import '../features/invite/screens/accept_invite_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../widgets/app_shell.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../services/user_settings_service.dart';

/// Route paths
class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String selectCountry = '/select-country';
  static const String home = '/';
  static const String lists = '/lists';
  static const String listDetail = '/lists/:uid';
  static const String addItem = '/lists/:listId/add-item';
  static const String invite = '/invite';
  static const String acceptInvite = '/invite/:code';
  static const String contacts = '/contacts';
  static const String messages = '/messages';
  static const String share = '/share';
  static const String settings = '/settings';
  static const String profile = '/profile';
}

/// Notifier that listens to auth state changes
class AuthNotifier extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserSettingsService _userSettings = UserSettingsService();
  late final StreamSubscription<AuthState> _subscription;

  AuthNotifier() {
    _subscription = SupabaseService.authStateStream.listen((authState) async {
      // Ensure user profile exists when auth state changes (e.g., OAuth callback)
      if (authState.event == AuthChangeEvent.signedIn &&
          authState.session?.user != null) {
        await _authService.onAuthStateChanged(authState.session!.user);
        // Load user settings (including currency preference)
        await _userSettings.loadSettings();
      } else if (authState.event == AuthChangeEvent.signedOut) {
        // Clear user settings on logout
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
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();
  static final _authNotifier = AuthNotifier();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.lists,
    debugLogDiagnostics: true,
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final isAuthenticated = SupabaseService.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.signup;
      final isOnboardingRoute =
          state.matchedLocation == AppRoutes.selectCountry;
      final isAcceptInviteRoute =
          state.matchedLocation.startsWith('/invite/') &&
          state.matchedLocation != '/invite';

      // Allow accept invite route - it will handle auth check internally
      if (isAcceptInviteRoute) {
        // If not authenticated, redirect to signup with the invite code saved
        if (!isAuthenticated) {
          // Store the invite code in query params for after signup
          final code = state.pathParameters['code'];
          return '${AppRoutes.signup}?invite=$code';
        }
        return null;
      }

      // Redirect to signup if not authenticated and not on auth/onboarding route
      if (!isAuthenticated && !isAuthRoute && !isOnboardingRoute) {
        return AppRoutes.signup;
      }

      // If authenticated and on auth route (from social login callback etc.)
      // Go directly to lists - explicit navigation to selectCountry happens in signup flow
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.lists;
      }

      // Block access to onboarding route if not authenticated
      if (isOnboardingRoute && !isAuthenticated) {
        return AppRoutes.signup;
      }

      return null;
    },
    routes: [
      // Auth routes (outside shell)
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        builder: (context, state) {
          final inviteCode = state.uri.queryParameters['invite'];
          return SignupScreen(inviteCode: inviteCode);
        },
      ),
      GoRoute(
        path: AppRoutes.selectCountry,
        name: 'selectCountry',
        builder: (context, state) {
          final inviteCode = state.uri.queryParameters['invite'];
          return CountrySelectionScreen(inviteCode: inviteCode);
        },
      ),

      // Main app shell with bottom navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // My lists tab
          GoRoute(
            path: AppRoutes.lists,
            name: 'lists',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ListsScreen()),
          ),

          // Invite tab
          GoRoute(
            path: AppRoutes.invite,
            name: 'invite',
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: InviteScreen(),
                ),
          ),

          // Contacts tab
          GoRoute(
            path: AppRoutes.contacts,
            name: 'contacts',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ContactsScreen()),
          ),

          // Messages tab
          GoRoute(
            path: AppRoutes.messages,
            name: 'messages',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: MessagesScreen()),
          ),

          // Share tab
          GoRoute(
            path: AppRoutes.share,
            name: 'share',
            pageBuilder:
                (context, state) =>
                    const NoTransitionPage(child: ShareScreen()),
          ),
        ],
      ),

      // List detail (outside shell - no app header/bottom nav)
      GoRoute(
        path: '/lists/:uid',
        name: 'listDetail',
        pageBuilder: (context, state) {
          final uid = state.pathParameters['uid']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: ListDetailScreen(listUid: uid),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          );
        },
      ),

      // Add item (modal route)
      GoRoute(
        path: '/add-item/:listId',
        name: 'addItem',
        pageBuilder: (context, state) {
          final listId = int.parse(state.pathParameters['listId']!);
          return MaterialPage(
            fullscreenDialog: true,
            child: AddItemScreen(listId: listId),
          );
        },
      ),

      // Settings screen
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 200),
          );
        },
      ),

      // Accept invite deep link (outside shell - handles invite codes)
      GoRoute(
        path: '/invite/:code',
        name: 'acceptInvite',
        builder: (context, state) {
          final code = state.pathParameters['code']!;
          return AcceptInviteScreen(inviteCode: code);
        },
      ),
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
                  onPressed: () => context.go(AppRoutes.lists),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
  );
}
