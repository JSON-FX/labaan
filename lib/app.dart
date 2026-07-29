import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/theme.dart';
import 'features/browse/browse_screen.dart';
import 'features/compete/dispute_screen.dart';
import 'features/compete/my_tournaments_screen.dart';
import 'features/compete/result_submission_screen.dart';
import 'features/home/home_feed_screen.dart';
import 'features/identity/onboarding_screen.dart';
import 'features/identity/phone_sign_in_screen.dart';
import 'features/identity/profile_screen.dart';
import 'features/identity/setup_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/registration/payment_result_screen.dart';
import 'features/registration/registration_screen.dart';
import 'features/shell/main_shell.dart';
import 'features/system/notification_prefs_screen.dart';
import 'features/system/notifications_screen.dart';
import 'features/system/account_setting_screen.dart';
import 'features/system/connected_accounts_screen.dart';
import 'features/system/legal_document_screen.dart';
import 'features/system/payout_account_screen.dart';
import 'features/system/rank_up_screen.dart';
import 'features/system/settings_screen.dart';
import 'features/team/player_search_screen.dart';
import 'features/team/team_management_screen.dart';
import 'features/tournament/bracket_view_screen.dart';
import 'features/tournament/tournament_detail_screen.dart';

class LabaanApp extends StatelessWidget {
  const LabaanApp({super.key});

  static final _router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/phone-sign-in',
        builder: (_, _) => const PhoneSignInScreen(),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegistrationScreen()),
      GoRoute(
        path: '/register/result/:status',
        builder: (_, state) {
          final raw = state.pathParameters['status'] ?? 'success';
          final status = PaymentResult.values.firstWhere(
            (s) => s.name == raw,
            orElse: () => PaymentResult.success,
          );
          return PaymentResultScreen(status: status);
        },
      ),
      GoRoute(
        path: '/submit-result',
        builder: (_, _) => const ResultSubmissionScreen(),
      ),
      GoRoute(
        path: '/dispute/:matchId',
        builder: (_, state) =>
            DisputeScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(path: '/rank-up', builder: (_, _) => const RankUpScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            builder: (_, _) => const NotificationPrefsScreen(),
          ),
          for (final field in AccountSettingField.values)
            GoRoute(
              path: field.name,
              builder: (_, _) => AccountSettingScreen(field: field),
            ),
          GoRoute(
            path: 'accounts',
            builder: (_, _) => const ConnectedAccountsScreen(),
          ),
          GoRoute(
            path: 'payout',
            builder: (_, _) => const PayoutAccountScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (_, _) =>
                const LegalDocumentScreen(document: LegalDocument.privacy),
          ),
          GoRoute(
            path: 'terms',
            builder: (_, _) =>
                const LegalDocumentScreen(document: LegalDocument.terms),
          ),
        ],
      ),
      GoRoute(
        path: '/tournament/:slug',
        builder: (_, state) =>
            TournamentDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/bracket/:tournamentId',
        builder: (_, state) => BracketViewScreen(
          tournamentId: state.pathParameters['tournamentId']!,
        ),
      ),
      GoRoute(path: '/team', builder: (_, _) => const TeamManagementScreen()),
      GoRoute(
        path: '/team/search',
        builder: (_, _) => const PlayerSearchScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeFeedScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/browse', builder: (_, _) => const BrowseScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/compete',
                builder: (_, _) => const MyTournamentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ranks',
                builder: (_, _) => const LeaderboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Labaan',
      debugShowCheckedModeBanner: false,
      theme: LbTheme.dark,
      routerConfig: _router,
    );
  }
}
