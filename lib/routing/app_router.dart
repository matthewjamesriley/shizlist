import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/lists/screens/lists_screen.dart';
import '../features/lists/screens/list_detail_screen.dart';
import '../features/items/screens/add_item_screen.dart';
import '../features/contacts/screens/contacts_screen.dart';
import '../features/messages/screens/messages_screen.dart';
import '../features/share/screens/share_screen.dart';
import '../widgets/app_shell.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

/// Route paths
class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String home = '/';
  static const String lists = '/lists';
  static const String listDetail = '/lists/:uid';
  static const String addItem = '/lists/:listId/add-item';
  static const String invite = '/invite';
  static const String contacts = '/contacts';
  static const String messages = '/messages';
  static const String share = '/share';
  static const String settings = '/settings';
  static const String profile = '/profile';
}

/// Notifier that listens to auth state changes
class AuthNotifier extends ChangeNotifier {
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _subscription;

  AuthNotifier() {
    _subscription = SupabaseService.authStateStream.listen((authState) async {
      // Ensure user profile exists when auth state changes (e.g., OAuth callback)
      if (authState.event == AuthChangeEvent.signedIn && authState.session?.user != null) {
        await _authService.onAuthStateChanged(authState.session!.user);
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

      // Redirect to signup if not authenticated and not on auth route
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.signup;
      }

      // Redirect to home if authenticated and on auth route
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.lists;
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
        builder: (context, state) => const SignupScreen(),
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
            routes: [
              GoRoute(
                path: ':uid',
                name: 'listDetail',
                builder: (context, state) {
                  final uid = state.pathParameters['uid']!;
                  return ListDetailScreen(listUid: uid);
                },
              ),
            ],
          ),

          // Invite tab
          GoRoute(
            path: AppRoutes.invite,
            name: 'invite',
            pageBuilder:
                (context, state) => const NoTransitionPage(
                  child: ShareScreen(), // Reusing share for invite
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
