import 'dart:typed_data';

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
    this.currentMatchId,
    this.matchAction = LbMatchAction.none,
  });
  final LbTournament tournament;
  final bool matchReady;
  final String currentBracketNode;
  final String? currentMatchId;
  final LbMatchAction matchAction;
}

enum LbMatchAction { none, submitResult, verifyResult, awaitingVerification }

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
    this.teams = const {},
  });
  final String tournamentId;
  final List<LbMatch> upper;
  final List<LbMatch> lower;
  final LbMatch? grandFinal;
  final Map<String, LbTeam> teams;
}

/// Registration + payment.
abstract class RegistrationRepo {
  Future<CreditRegistrationResult> enterWithCredits({
    required String tournamentId,
    required String userId,
    String? teamId,
    required String idempotencyKey,
  });

  Future<CreditRegistrationResult> cancelCreditRegistration({
    required String registrationId,
    required String userId,
    required String idempotencyKey,
  });

  /// Legacy PayMongo path retained only for legacy-cash tournaments.
  Future<RegistrationCheckout> register({
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
  Future<LbMatch> byId(String matchId);

  Future<String> uploadScreenshot({
    required String userId,
    required String matchId,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  });

  Future<void> submit({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String screenshotPath,
  });

  Future<String?> screenshotPreviewUrl(String screenshotPath);

  Future<void> verify({required String matchId});

  Future<void> openDispute({
    required String matchId,
    required String reason,
    required String detail,
  });
}

/// Profile: rank badge, achievement badges, W/L stats, tournament history.
abstract class ProfileRepo {
  Future<LbPlayerProfile> byUsername(String username);
  Future<LbPlayerProfile> byId(String userId);
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  });
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
  Future<LbAccountDeletionRequest?> accountDeletionRequest(String userId);
  Future<LbAccountDeletionRequest> requestAccountDeletion();
  Future<LbAccountDeletionRequest> cancelAccountDeletion();
}

/// Player-owned, non-cashable wallet balances and append-only activity.
abstract class WalletRepo {
  Future<LbWallet> currentWallet({int limit = 50, LbWalletCursor? before});

  Future<List<LbCreditPack>> activeCreditPacks({
    required CreditPackProvider provider,
    required CreditPackPlatform platform,
  });

  Future<LbTopupCheckout> createPaymongoTopup({
    required LbCreditPack pack,
    required PayMethod method,
    required CreditPackPlatform platform,
    required String idempotencyKey,
    required Uri successUrl,
    required Uri cancelUrl,
  });
}

abstract class EconomyFeatureFlagsRepo {
  Future<LbEconomyFeatures> forPlatform({
    required String environment,
    required LbClientPlatform platform,
  });
}

abstract class AdminEconomyRepo {
  Future<LbAdminEconomyDashboard> dashboard();
  Future<void> resolveRiskCase({
    required String caseId,
    required bool dismissed,
    required String reason,
  });
  Future<void> adjustWallet({
    required String targetUserId,
    required LbWalletCurrency currency,
    required bool grant,
    required int amount,
    required String reason,
    required String idempotencyKey,
  });

  Future<void> allocateRewardFunding({
    required String tournamentId,
    required bool brandSponsored,
    required String fundingReference,
    String? attributionName,
    required int amount,
    required int sourceCap,
    required String reason,
  });

  Future<Map<String, int>> runShopFulfillment({int limit = 25});
}

/// Web-only organizer sponsorship catalog and PayMongo checkout commands.
abstract class HostSponsorRepo {
  Future<LbHostSponsorPortal> portalForOrganizer(String organizerId);

  Future<String> createTournamentDraft(LbWalletTournamentDraft draft);

  Future<void> publishTournament({
    required String tournamentId,
    required DateTime registrationLocksAt,
    required DateTime startsAt,
  });

  Future<LbSponsorCheckout> createCheckout({
    required String tournamentId,
    required LbSponsorPackage package,
    required PayMethod method,
    required bool showAttribution,
    required String idempotencyKey,
    required Uri successUrl,
    required Uri cancelUrl,
  });
}

class LbWalletTournamentDraft {
  const LbWalletTournamentDraft({
    required this.title,
    required this.game,
    required this.format,
    required this.entryCreditCost,
    required this.maxTeams,
    required this.minimumTeams,
    required this.belowMinimumAction,
    required this.rewardPointsPerCompetitor,
    required this.rewardPoolCap,
    this.firstPlaceBps = 7000,
    this.secondPlaceBps = 3000,
    this.thirdPlaceBps = 0,
  });

  final String title;
  final String game;
  final String format;
  final int entryCreditCost;
  final int maxTeams;
  final int minimumTeams;
  final String belowMinimumAction;
  final int rewardPointsPerCompetitor;
  final int rewardPoolCap;
  final int firstPlaceBps;
  final int secondPlaceBps;
  final int thirdPlaceBps;
}

abstract class ShopRepo {
  Future<List<LbShopProduct>> catalog(ShopPlatform platform);
  Future<List<LbShopOrder>> orders();

  Future<LbShopPurchaseResult> purchase({
    required LbShopProduct product,
    required ShopPlatform platform,
    required int quantity,
    required String idempotencyKey,
  });

  Future<LbShopPurchaseResult> cancel({
    required String orderId,
    required String reason,
    required String idempotencyKey,
  });
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
  Future<void> inviteByUsername({
    required String teamId,
    required String username,
  });
  Future<void> updateTeam({
    required String teamId,
    required String name,
    required String tag,
  });
  Future<void> removeMember({required String teamId, required String userId});
  Future<void> transferCaptain({
    required String teamId,
    required String userId,
  });
  Future<void> acceptInvite(String inviteId);
  Future<void> declineInvite(String inviteId);
  Future<void> leaveTeam({required String teamId, required String userId});
}

/// Player search — the recruiter's tool. Filter by game + minimum rank.
abstract class PlayersRepo {
  Future<LbPlayerSearchPage> search({
    String? game,
    String? username,
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
    required String invitationId,
    required bool accept,
  });
}
