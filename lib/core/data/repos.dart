import '../domain/ranks.dart';
import '../domain/tournament_tier.dart';
import 'models.dart';

/// Abstract repository contracts. Screens depend on these, not on Supabase.
///
/// Wiring order: screens → Riverpod providers → these interfaces →
/// MockRepository (now) or SupabaseRepository (when backend ships). Swapping
/// the impl is one provider override — no screen changes.

/// Sign-in, sign-out, session, first-run identity setup (username / region /
/// games picker).
abstract class AuthRepo {
  Stream<LbUser?> authStateChanges();
  Future<LbUser?> currentUser();
  Future<LbUser> signInWithGoogle();
  Future<LbUser> signInWithFacebook();
  Future<void> requestPhoneOtp(String phoneE164);
  Future<LbUser> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  });
  Future<Set<String>> linkedProviders();
  Future<void> linkGoogle();
  Future<void> requestPhoneLink(String phoneE164);
  Future<void> verifyPhoneLink({
    required String phoneE164,
    required String token,
  });
  Future<void> requestEmailChange(String email);
  Future<void> completeFirstRunSetup({
    required String username,
    required String region,
    required List<String> games,
  });
  Future<void> signOut();
}

/// Everything the home feed, browse, and tournament detail need.
abstract class TournamentsRepo {
  /// Home feed — personalized live/urgent/newly-opened. First page only.
  Future<LbHomeFeed> homeFeed({required String userId});

  /// Browse marketplace — cursor-paginated (spec §9.3). Pass the previous
  /// page's [cursor] to fetch the next.
  Future<LbTournamentPage> browse({
    String? cursor,
    String? gameFilter,
    TournamentTier? tierFilter,
    String? organizerId,
    String? searchQuery,
    int limit = 20,
  });

  Future<LbTournament> byId(String tournamentId);

  Stream<LbTournament> watch(String tournamentId);
}

class LbHomeFeed {
  const LbHomeFeed({
    required this.liveMatchReady,
    required this.featured,
    required this.trending,
  });
  final LbTournament? liveMatchReady;
  final List<LbTournament> featured;
  final List<LbTournament> trending;
}

class LbTournamentPage {
  const LbTournamentPage({required this.items, this.nextCursor});
  final List<LbTournament> items;
  final String? nextCursor;
}

/// The player's own registrations, grouped by state for the Compete tab.
abstract class MyTournamentsRepo {
  Future<LbMyTournaments> forUser(String userId);
  Stream<LbMyTournaments> watchForUser(String userId);
}

class LbMyTournaments {
  const LbMyTournaments({
    required this.live,
    required this.upcoming,
    required this.completed,
  });
  final List<LbLiveEntry> live;
  final List<LbUpcomingEntry> upcoming;
  final List<LbCompletedTournament> completed;
}

class LbLiveEntry {
  const LbLiveEntry({
    required this.tournament,
    required this.matchReady,
    required this.currentBracketNode,
  });
  final LbTournament tournament;
  final bool matchReady;
  final String currentBracketNode;
}

class LbUpcomingEntry {
  const LbUpcomingEntry({required this.tournament, required this.locksIn});
  final LbTournament tournament;
  final Duration locksIn;
}

/// Bracket view — real-time stream. Impl MUST unsubscribe on cancel (spec
/// §9.3 critical decision).
abstract class BracketRepo {
  Stream<LbBracket> watch(String tournamentId);
}

class LbBracket {
  const LbBracket({
    required this.tournamentId,
    required this.upper,
    required this.lower,
    required this.grandFinal,
  });
  final String tournamentId;
  final List<LbMatch> upper;
  final List<LbMatch> lower;
  final LbMatch? grandFinal;
}

/// Registration + payment.
abstract class RegistrationRepo {
  Future<LbRegistration> register({
    required String tournamentId,
    required String userId,
    String? teamId,
    required PayMethod method,
    required String captchaToken,
  });

  Stream<RegistrationPaymentStatus> watchPayment(String registrationId);
}

/// Result submission (score + screenshot).
abstract class ResultsRepo {
  Future<String> requestScreenshotUploadUrl({
    required String matchId,
    required int contentLengthBytes,
  });

  Future<void> submit({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String screenshotUrl,
  });

  Future<void> openDispute({required String matchId, required String reason});
}

/// Profile: rank badge, achievement badges, W/L stats, tournament history.
abstract class ProfileRepo {
  Future<LbPlayerProfile> byUsername(String username);
  Future<LbPlayerProfile> byId(String userId);
  Future<void> updateAvatar(String userId, String assetUri);
  Future<void> updateIdentity({
    required String userId,
    required String username,
    required String region,
    required List<String> games,
  });
}

abstract class SettingsRepo {
  Future<LbNotificationPreferences> notificationPreferences(String userId);
  Future<void> saveNotificationPreferences(
    String userId,
    LbNotificationPreferences preferences,
  );
  Future<LbPayoutAccount?> payoutAccount(String userId);
  Future<void> savePayoutAccount(String userId, LbPayoutAccount account);
  Future<void> deletePayoutAccount(String userId);
}

/// Team management — create, invite, roster, leave.
abstract class TeamsRepo {
  Future<LbTeam> byId(String teamId);
  Future<List<LbTeam>> forUser(String userId);
  Future<LbTeam> createTeam({
    required String name,
    required String tag,
    required String captainUserId,
  });
  Future<void> invite({required String teamId, required String userId});
  Future<void> acceptInvite(String inviteId);
  Future<void> declineInvite(String inviteId);
  Future<void> leaveTeam({required String teamId, required String userId});
}

/// Player search — the recruiter's tool. Filter by game + minimum rank.
abstract class PlayersRepo {
  Future<LbPlayerSearchPage> search({
    String? game,
    Rank? minRank,
    String? region,
    bool freeAgentsOnly = false,
    String? cursor,
    int limit = 20,
  });
}

class LbPlayerSearchPage {
  const LbPlayerSearchPage({required this.items, this.nextCursor});
  final List<LbPlayerSearchResult> items;
  final String? nextCursor;
}

class LbPlayerSearchResult {
  const LbPlayerSearchResult({
    required this.user,
    required this.rank,
    required this.games,
    required this.isFreeAgent,
  });
  final LbUser user;
  final LbUserRank rank;
  final List<String> games;
  final bool isFreeAgent;
}

/// Season-based leaderboard (Redis-cached; Flutter reads the cached view).
abstract class LeaderboardRepo {
  Future<List<LbLeaderboardPlayer>> topPlayers({String? game, int limit = 20});
  Future<List<LbLeaderboardTeam>> topTeams({String? game, int limit = 20});
  Future<int?> playerPosition({required String userId, String? game});
}

class LbLeaderboardPlayer {
  const LbLeaderboardPlayer({
    required this.position,
    required this.user,
    required this.rank,
  });
  final int position;
  final LbUser user;
  final LbUserRank rank;
}

class LbLeaderboardTeam {
  const LbLeaderboardTeam({
    required this.position,
    required this.team,
    required this.wins,
  });
  final int position;
  final LbTeam team;
  final int wins;
}

/// Notifications feed + inline actions (accept/decline team invite, etc.).
abstract class NotificationsRepo {
  Stream<List<LbNotification>> watchForUser(String userId);
  Future<void> markAllRead(String userId);
  Future<void> markRead(String notificationId);
  Future<void> respondToTeamInvite({
    required String notificationId,
    required bool accept,
  });
}
