import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/theme.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/browse/browse_screen.dart';
import 'features/compete/dispute_screen.dart';
import 'features/compete/my_tournaments_screen.dart';
import 'features/compete/result_submission_screen.dart';
import 'features/compete/result_verification_screen.dart';
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
import 'features/system/account_deletion_screen.dart';
import 'features/system/connected_accounts_screen.dart';
import 'features/system/legal_document_screen.dart';
import 'features/system/host_tournament_screen.dart';
import 'features/system/payout_account_screen.dart';
import 'features/system/rank_up_screen.dart';
import 'features/system/settings_screen.dart';
import 'features/system/support_screen.dart';
import 'features/system/wallet_screen.dart';
import 'features/team/player_search_screen.dart';
import 'features/team/team_management_screen.dart';
import 'features/tournament/bracket_view_screen.dart';
import 'features/tournament/tournament_detail_screen.dart';

class LabaanApp extends StatelessWidget {
  const LabaanApp({super.key, this.router});

  final GoRouter? router;

  static final _router = createRouter();

  static void openPushLocation(String location) => _router.go(location);

  /// Creates the app router.
  ///
  /// [initialLocation] is injectable for route regression tests and platform
  /// callbacks. iOS OAuth callbacks can reopen the app at `/`, so that
  /// location must remain a valid entry point even though ordinary cold
  /// launches start at `/onboarding`.
  static GoRouter createRouter({String initialLocation = '/onboarding'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/onboarding'),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/phone-sign-in',
          builder: (_, _) => const PhoneSignInScreen(),
        ),
        GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
        GoRoute(
          path: '/register',
          builder: (_, _) => const RegistrationScreen(),
        ),
        GoRoute(
          path: '/register/:tournamentId',
          builder: (_, state) => RegistrationScreen(
            tournamentId: state.pathParameters['tournamentId']!,
          ),
        ),
        GoRoute(
          path: '/register/result/:status',
          builder: (_, state) {
            final raw = state.pathParameters['status'] ?? 'success';
            final status = PaymentResult.values.firstWhere(
              (s) => s.name == raw,
              orElse: () => PaymentResult.success,
            );
            return PaymentResultScreen(
              status: status,
              tournamentId: state.uri.queryParameters['tournamentId'],
              tournamentTitle:
                  state.uri.queryParameters['tournament'] ??
                  'Tournament registration',
              amount: state.uri.queryParameters['amount'] ?? '—',
              reference: state.uri.queryParameters['reference'],
              registrationId: state.uri.queryParameters['registrationId'],
              usesCredits: state.uri.queryParameters['wallet'] == 'true',
            );
          },
        ),
        GoRoute(
          path: '/submit-result/:matchId',
          builder: (_, state) =>
              ResultSubmissionScreen(matchId: state.pathParameters['matchId']!),
        ),
        GoRoute(
          path: '/verify-result/:matchId',
          builder: (_, state) => ResultVerificationScreen(
            matchId: state.pathParameters['matchId']!,
          ),
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
          path: '/wallet',
          builder: (_, state) => WalletScreen(
            topupResult: state.uri.queryParameters['topupResult'],
          ),
        ),
        GoRoute(path: '/host', builder: (_, _) => const HostTournamentScreen()),
        GoRoute(
          path: '/support',
          builder: (_, state) =>
              SupportScreen(topic: state.uri.queryParameters['topic']),
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
              path: 'delete-account',
              builder: (_, _) => const AccountDeletionScreen(),
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
        GoRoute(
          path: '/team',
          builder: (_, state) =>
              TeamManagementScreen(teamId: state.uri.queryParameters['teamId']),
        ),
        GoRoute(
          path: '/team/search',
          builder: (_, state) => PlayerSearchScreen(
            teamId: state.uri.queryParameters['teamId'] ?? 't_mnl',
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => MainShell(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const HomeFeedScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/browse',
                  builder: (_, _) => const BrowseScreen(),
                ),
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
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Labaan',
      debugShowCheckedModeBanner: false,
      theme: LbTheme.dark,
      scaffoldMessengerKey: PushNotificationService.scaffoldMessengerKey,
      routerConfig: router ?? _router,
    );
  }
}
