import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ranks.dart';
import 'firebase_auth_repo.dart';
import 'mock_repos.dart';
import 'models.dart';
import 'repos.dart';
import 'supabase_client.dart';
import 'supabase_repos.dart';

/// Repository singletons use the hosted backend for normal app runs.
/// Automated tests and explicit `USE_MOCK_BACKEND=true` runs use fixtures.

class BackendModeController extends Notifier<bool> {
  @override
  bool build() => Lb.useSupabase;

  void useMocks() => state = false;
}

final backendEnabledProvider = NotifierProvider<BackendModeController, bool>(
  BackendModeController.new,
);

final authRepoProvider = Provider<AuthRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? FirebaseAuthRepo(Lb.client)
      : MockAuthRepo(),
);

final tournamentsRepoProvider = Provider<TournamentsRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseTournamentsRepo(Lb.client)
      : MockTournamentsRepo(),
);

final myTournamentsRepoProvider = Provider<MyTournamentsRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseMyTournamentsRepo(Lb.client)
      : MockMyTournamentsRepo(),
);

final bracketRepoProvider = Provider<BracketRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseBracketRepo(Lb.client)
      : MockBracketRepo(),
);

final registrationRepoProvider = Provider<RegistrationRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseRegistrationRepo(Lb.client)
      : MockRegistrationRepo(),
);

final resultsRepoProvider = Provider<ResultsRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseResultsRepo(Lb.client)
      : MockResultsRepo(),
);

final profileRepoProvider = Provider<ProfileRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseProfileRepo(Lb.client)
      : MockProfileRepo(),
);

final settingsRepoProvider = Provider<SettingsRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseSettingsRepo(Lb.client)
      : MockSettingsRepo(),
);

final teamsRepoProvider = Provider<TeamsRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseTeamsRepo(Lb.client)
      : MockTeamsRepo(),
);

final playersRepoProvider = Provider<PlayersRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabasePlayersRepo(Lb.client)
      : MockPlayersRepo(),
);

final leaderboardRepoProvider = Provider<LeaderboardRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseLeaderboardRepo(Lb.client)
      : MockLeaderboardRepo(),
);

final notificationsRepoProvider = Provider<NotificationsRepo>(
  (ref) => ref.watch(backendEnabledProvider)
      ? SupabaseNotificationsRepo(Lb.client)
      : MockNotificationsRepo(),
);

// ── Session ────────────────────────────────────────────────────────────────

/// Currently signed-in user. Reactive; screens can watch to react to sign-in
/// and sign-out.
final currentUserProvider = StreamProvider<LbUser?>((ref) {
  final repo = ref.watch(authRepoProvider);
  return repo.authStateChanges();
});

final linkedProvidersProvider = FutureProvider.autoDispose<Set<String>>((ref) {
  return ref.watch(authRepoProvider).linkedProviders();
});

// ── Screen-scoped data providers ───────────────────────────────────────────

final homeFeedProvider = FutureProvider.autoDispose<LbHomeFeed>((ref) async {
  final repo = ref.watch(tournamentsRepoProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) throw StateError('Authentication required');
  return repo.homeFeed(userId: user.id);
});

final homeFeedForUserProvider = FutureProvider.autoDispose
    .family<LbHomeFeed, String>((ref, userId) {
      return ref.watch(tournamentsRepoProvider).homeFeed(userId: userId);
    });

final myTournamentsProvider = FutureProvider.autoDispose
    .family<LbMyTournaments, String>((ref, userId) {
      return ref.watch(myTournamentsRepoProvider).forUser(userId);
    });

final tournamentByIdProvider = FutureProvider.autoDispose
    .family<LbTournament, String>((ref, id) {
      return ref.watch(tournamentsRepoProvider).byId(id);
    });

final bracketProvider = StreamProvider.autoDispose.family<LbBracket, String>((
  ref,
  tournamentId,
) {
  // autoDispose ensures unsubscribe on nav — matches spec §9.3 requirement
  // that Realtime subs are strictly per-tournament and released on nav.
  return ref.watch(bracketRepoProvider).watch(tournamentId);
});

final browsePageProvider = FutureProvider.autoDispose
    .family<LbTournamentPage, BrowseQuery>((ref, query) {
      return ref
          .watch(tournamentsRepoProvider)
          .browse(
            gameFilter: query.game,
            tierFilter: query.tier,
            searchQuery: query.search,
          );
    });

class BrowseQuery {
  const BrowseQuery({this.game, this.tier, this.search});
  final String? game;
  final dynamic tier; // TournamentTier — kept dynamic to avoid coupling here
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is BrowseQuery &&
      other.game == game &&
      other.tier == tier &&
      other.search == search;

  @override
  int get hashCode => Object.hash(game, tier, search);
}

final profileByIdProvider = FutureProvider.autoDispose
    .family<LbPlayerProfile, String>((ref, id) {
      return ref.watch(profileRepoProvider).byId(id);
    });

final notificationPreferencesProvider = FutureProvider.autoDispose
    .family<LbNotificationPreferences, String>((ref, userId) {
      return ref.watch(settingsRepoProvider).notificationPreferences(userId);
    });

final payoutAccountProvider = FutureProvider.autoDispose
    .family<LbPayoutAccount?, String>((ref, userId) {
      return ref.watch(settingsRepoProvider).payoutAccount(userId);
    });

final teamByIdProvider = FutureProvider.autoDispose.family<LbTeam, String>((
  ref,
  id,
) {
  return ref.watch(teamsRepoProvider).byId(id);
});

final teamsForUserProvider = FutureProvider.autoDispose
    .family<List<LbTeam>, String>((ref, userId) {
      return ref.watch(teamsRepoProvider).forUser(userId);
    });

final teamMembersProvider = FutureProvider.autoDispose
    .family<List<LbPlayerProfile>, String>((ref, teamId) async {
      final team = await ref.watch(teamsRepoProvider).byId(teamId);
      final repo = ref.watch(profileRepoProvider);
      return Future.wait([for (final id in team.memberIds) repo.byId(id)]);
    });

final playerSearchProvider = FutureProvider.autoDispose
    .family<LbPlayerSearchPage, PlayerSearchQuery>((ref, query) {
      return ref
          .watch(playersRepoProvider)
          .search(
            game: query.game,
            minRank: query.minRank,
            freeAgentsOnly: query.freeAgentsOnly,
          );
    });

class PlayerSearchQuery {
  const PlayerSearchQuery({
    this.game,
    this.minRank,
    this.freeAgentsOnly = false,
  });
  final String? game;
  final Rank? minRank;
  final bool freeAgentsOnly;

  @override
  bool operator ==(Object other) =>
      other is PlayerSearchQuery &&
      other.game == game &&
      other.minRank == minRank &&
      other.freeAgentsOnly == freeAgentsOnly;

  @override
  int get hashCode => Object.hash(game, minRank, freeAgentsOnly);
}

final topPlayersProvider = FutureProvider.autoDispose
    .family<List<LbLeaderboardPlayer>, String?>((ref, game) {
      return ref.watch(leaderboardRepoProvider).topPlayers(game: game);
    });

final topTeamsProvider = FutureProvider.autoDispose
    .family<List<LbLeaderboardTeam>, String?>((ref, game) {
      return ref.watch(leaderboardRepoProvider).topTeams(game: game);
    });

final notificationsProvider = StreamProvider.autoDispose
    .family<List<LbNotification>, String>((ref, userId) {
      return ref.watch(notificationsRepoProvider).watchForUser(userId);
    });
