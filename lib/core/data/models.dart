import 'package:flutter/foundation.dart';

import '../domain/badges.dart';
import '../domain/ranks.dart';
import '../domain/roles.dart';
import '../domain/tournament_status.dart';
import '../domain/tournament_tier.dart';

/// Data models mirroring spec §10 "Core Data Model". Hand-written immutable
/// classes — no code-gen required for MVP. When we're ready to serialize
/// against Supabase, we add `fromJson` factories here.
///
/// Every field name matches the spec's column name where practical.

@immutable
class LbUser {
  const LbUser({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.region,
    this.avatarUrl,
    required this.createdAt,
    this.isBanned = false,
    this.role = UserRole.player,
    this.games = const [],
    this.hasCompletedSetup = true,
  });

  final String id;
  final String username;
  final String email;
  final String? phone;
  final String? region;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isBanned;
  final UserRole role;
  final List<String> games;

  /// False until the player completes the post-OAuth identity setup
  /// (username / region / games picker). Onboarding routes them to /setup
  /// when this is false.
  final bool hasCompletedSetup;

  LbUser copyWith({
    String? username,
    String? email,
    String? phone,
    String? region,
    List<String>? games,
    bool? hasCompletedSetup,
  }) => LbUser(
    id: id,
    username: username ?? this.username,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    region: region ?? this.region,
    avatarUrl: avatarUrl,
    createdAt: createdAt,
    isBanned: isBanned,
    role: role,
    games: games ?? this.games,
    hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
  );
}

@immutable
class LbUserRank {
  const LbUserRank({
    required this.userId,
    required this.totalWins,
    required this.rank,
    required this.rankUpdatedAt,
  });

  final String userId;
  final int totalWins;
  final Rank rank;
  final DateTime rankUpdatedAt;

  int get winsToNext => rank.winsToNext(totalWins);
  double get progressWithinRank => rank.progressWithin(totalWins);
}

@immutable
class LbUserBadge {
  const LbUserBadge({
    required this.userId,
    required this.badge,
    required this.earnedAt,
  });

  final String userId;
  final AchievementBadge badge;
  final DateTime earnedAt;
}

@immutable
class LbTeam {
  const LbTeam({
    required this.id,
    required this.name,
    required this.tag,
    this.logoUrl,
    required this.captainUserId,
    required this.memberIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String tag;
  final String? logoUrl;
  final String captainUserId;
  final List<String> memberIds;
  final DateTime createdAt;

  int get memberCount => memberIds.length;
}

@immutable
class LbTournament {
  const LbTournament({
    required this.id,
    required this.title,
    required this.game,
    required this.format,
    required this.tier,
    required this.maxTeams,
    this.registeredTeams = 0,
    required this.entryFeePhp,
    required this.commissionRate,
    required this.prizePoolPhp,
    required this.status,
    required this.organizerId,
    this.moderatorIds = const [],
    this.spectatorIds = const [],
    this.gabPermitNumber,
    required this.startsAt,
    this.locksAt,
    required this.createdAt,
    this.economyMode = TournamentEconomy.legacyCash,
    this.entryCreditCost,
    this.rewardCompetitorBasis,
    this.rewardPointsPerCompetitor,
    this.rewardPoolCap,
    this.rewardFirstPlaceBps,
    this.rewardSecondPlaceBps,
    this.rewardThirdPlaceBps,
    this.rewardCompetitorCount,
    this.finalRewardPool,
    this.rewardPoolLockedAt,
    this.minimumTeams,
    this.belowMinimumAction,
    this.registrationCloseOutcome,
    this.registrationCloseCompetitorCount,
    this.registrationClosedAt,
  });

  final String id;
  final String title;
  final String game;
  final BracketFormat format;
  final TournamentTier tier;
  final int maxTeams;
  final int registeredTeams;
  final int entryFeePhp;
  final double commissionRate;
  final int prizePoolPhp;
  final TournamentStatus status;
  final String organizerId;
  final List<String> moderatorIds;
  final List<String> spectatorIds;
  final String? gabPermitNumber;
  final DateTime startsAt;
  final DateTime? locksAt;
  final DateTime createdAt;
  final TournamentEconomy economyMode;
  final int? entryCreditCost;
  final RewardCompetitorBasis? rewardCompetitorBasis;
  final int? rewardPointsPerCompetitor;
  final int? rewardPoolCap;
  final int? rewardFirstPlaceBps;
  final int? rewardSecondPlaceBps;
  final int? rewardThirdPlaceBps;
  final int? rewardCompetitorCount;
  final int? finalRewardPool;
  final DateTime? rewardPoolLockedAt;
  final int? minimumTeams;
  final BelowMinimumAction? belowMinimumAction;
  final RegistrationCloseOutcome? registrationCloseOutcome;
  final int? registrationCloseCompetitorCount;
  final DateTime? registrationClosedAt;

  bool get isLive => status == TournamentStatus.live;
  bool get isOpen =>
      status == TournamentStatus.open || status == TournamentStatus.fillingUp;
  bool get usesWallet => economyMode == TournamentEconomy.walletV2;
  bool get hasRewardRule =>
      rewardCompetitorBasis != null && rewardPointsPerCompetitor != null;
  bool get rewardPoolIsLocked => rewardPoolLockedAt != null;
  bool get hasMinimumCloseRule =>
      minimumTeams != null && belowMinimumAction != null;
  int get slotsRemaining => maxTeams - registeredTeams;

  /// Countdown to lock — null if lock time isn't scheduled or has passed.
  Duration? countdownToLock(DateTime now) {
    if (locksAt == null) return null;
    final d = locksAt!.difference(now);
    return d.isNegative ? null : d;
  }
}

enum RegistrationPaymentStatus { pending, paid, refunded, failed }

enum TournamentEconomy { legacyCash, walletV2 }

enum RewardCompetitorBasis { registration, team }

enum BelowMinimumAction { postpone, cancel }

enum RegistrationCloseOutcome { started, postponed, cancelled }

@immutable
class LbRegistration {
  const LbRegistration({
    required this.id,
    required this.tournamentId,
    required this.userId,
    this.teamId,
    required this.paymentStatus,
    this.paidAt,
    required this.amountPhp,
    required this.commissionCollectedPhp,
    this.paymongoRef,
    this.economyMode = TournamentEconomy.legacyCash,
    this.entryCreditAmount,
    this.cancelledAt,
  });

  final String id;
  final String tournamentId;
  final String userId;
  final String? teamId;
  final RegistrationPaymentStatus paymentStatus;
  final DateTime? paidAt;
  final int amountPhp;
  final int commissionCollectedPhp;
  final String? paymongoRef;
  final TournamentEconomy economyMode;
  final int? entryCreditAmount;
  final DateTime? cancelledAt;
}

@immutable
class CreditRegistrationResult {
  const CreditRegistrationResult({
    required this.registration,
    required this.entryCreditBalance,
    required this.entryCreditCost,
    this.walletTransactionId,
    required this.existing,
  });

  final LbRegistration registration;
  final int entryCreditBalance;
  final int entryCreditCost;
  final String? walletTransactionId;
  final bool existing;
}

class LbRegistrationFailure implements Exception {
  const LbRegistrationFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

@immutable
class RegistrationCheckout {
  const RegistrationCheckout({required this.registration, this.checkoutUrl});

  final LbRegistration registration;

  /// Present for real PayMongo Checkout sessions and absent for the
  /// deterministic development adapter or an already-paid registration.
  final Uri? checkoutUrl;
}

@immutable
class LbMatch {
  const LbMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    this.position = 1,
    required this.bracketSide,
    required this.teamAId,
    required this.teamBId,
    this.winnerId,
    this.scoreA = 0,
    this.scoreB = 0,
    this.status = LbMatchStatus.pending,
    this.submittedByUserId,
    this.submittedTeamId,
    this.verifiedByModeratorId,
    this.screenshotUrl,
    this.verifiedAt,
  });

  final String id;
  final String tournamentId;
  final int round;
  final int position;
  final BracketSide bracketSide;
  final String teamAId;
  final String teamBId;
  final String? winnerId;
  final int scoreA;
  final int scoreB;
  final LbMatchStatus status;
  final String? submittedByUserId;
  final String? submittedTeamId;
  final String? verifiedByModeratorId;
  final String? screenshotUrl;
  final DateTime? verifiedAt;

  bool get isVerified => verifiedAt != null;
  bool get isPending => winnerId == null;
}

enum BracketSide { upper, lower, grandFinal }

enum LbMatchStatus {
  pending,
  ready,
  awaitingResult,
  awaitingVerification,
  disputed,
  completed,
}

enum PayMethod { gcash, maya, card }

enum PaymentStatus { pending, succeeded, failed, refunded }

@immutable
class LbPayment {
  const LbPayment({
    required this.id,
    required this.userId,
    required this.tournamentId,
    required this.amountPhp,
    required this.commissionPhp,
    required this.netPrizePhp,
    required this.method,
    required this.status,
    required this.paymongoRef,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String tournamentId;
  final int amountPhp;
  final int commissionPhp;
  final int netPrizePhp;
  final PayMethod method;
  final PaymentStatus status;
  final String paymongoRef;
  final String idempotencyKey;
  final DateTime createdAt;
}

@immutable
class LbDisbursement {
  const LbDisbursement({
    required this.id,
    required this.tournamentId,
    required this.winningTeamId,
    required this.amountPhp,
    required this.method,
    required this.status,
    this.attempts = 0,
    this.processedAt,
  });

  final String id;
  final String tournamentId;
  final String winningTeamId;
  final int amountPhp;
  final PayMethod method;
  final PaymentStatus status;
  final int attempts;
  final DateTime? processedAt;
}

@immutable
class LbModeratorQueueItem {
  const LbModeratorQueueItem({
    required this.id,
    required this.moderatorId,
    required this.tournamentId,
    required this.action,
    required this.createdAt,
    this.deadlineAt,
    this.resolvedAt,
    this.escalatedTo,
  });

  final String id;
  final String moderatorId;
  final String tournamentId;
  final ModeratorAction action;
  final DateTime createdAt;
  final DateTime? deadlineAt;
  final DateTime? resolvedAt;
  final String? escalatedTo;

  bool get isResolved => resolvedAt != null;
  Duration? remaining(DateTime now) => deadlineAt?.difference(now);
}

/// Notification categories from the spec's push list.
enum NotifKind {
  matchReady,
  startingSoon,
  rankUp,
  badgeEarned,
  teamInvite,
  resultVerified,
  disputeOpened,
  payoutReceived,
}

@immutable
class LbNotificationPreferences {
  const LbNotificationPreferences({required this.push, required this.email});

  factory LbNotificationPreferences.defaults() => LbNotificationPreferences(
    push: {for (final kind in NotifKind.values) kind: true},
    email: {
      for (final kind in NotifKind.values)
        kind: const {
          NotifKind.rankUp,
          NotifKind.disputeOpened,
          NotifKind.payoutReceived,
        }.contains(kind),
    },
  );

  final Map<NotifKind, bool> push;
  final Map<NotifKind, bool> email;

  LbNotificationPreferences copyWith({
    Map<NotifKind, bool>? push,
    Map<NotifKind, bool>? email,
  }) => LbNotificationPreferences(
    push: push ?? this.push,
    email: email ?? this.email,
  );
}

@immutable
class LbPayoutAccount {
  const LbPayoutAccount({
    required this.provider,
    required this.accountName,
    required this.mobileNumber,
  });

  final String provider;
  final String accountName;
  final String mobileNumber;

  String get maskedNumber => mobileNumber.length < 4
      ? mobileNumber
      : '••${mobileNumber.substring(mobileNumber.length - 4)}';
}

enum LbAccountDeletionStatus {
  pending,
  underReview,
  processing,
  cancelled,
  completed,
}

@immutable
class LbAccountDeletionRequest {
  const LbAccountDeletionRequest({
    required this.id,
    required this.userId,
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
    this.cancelledAt,
    this.completedAt,
    this.retentionUntil,
    this.reviewReason,
  });

  final String id;
  final String userId;
  final LbAccountDeletionStatus status;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final DateTime? retentionUntil;
  final String? reviewReason;

  bool get canCancel =>
      status == LbAccountDeletionStatus.pending ||
      status == LbAccountDeletionStatus.underReview;
}

enum LbWalletCurrency { entryCredit, rewardPoint }

enum LbWalletTransactionKind {
  topup,
  entryFee,
  entryRefund,
  providerReversal,
  rewardAllocation,
  rewardGrant,
  shopPurchase,
  shopRefund,
  adminAdjustment,
}

@immutable
class LbWalletBalance {
  const LbWalletBalance({
    required this.currency,
    required this.displayName,
    required this.symbol,
    required this.balance,
  });

  final LbWalletCurrency currency;
  final String displayName;
  final String symbol;
  final int balance;
}

@immutable
class LbWalletCursor {
  const LbWalletCursor({required this.createdAt, required this.entryId});

  final DateTime createdAt;
  final String entryId;
}

@immutable
class LbWalletTransaction {
  const LbWalletTransaction({
    required this.entryId,
    required this.id,
    required this.kind,
    required this.currency,
    required this.amount,
    required this.occurredAt,
    this.referenceType,
    this.referenceId,
  });

  final String entryId;
  final String id;
  final LbWalletTransactionKind kind;
  final LbWalletCurrency currency;

  /// Signed wallet-unit movement from the player's perspective.
  final int amount;
  final DateTime occurredAt;
  final String? referenceType;
  final String? referenceId;

  bool get isIncoming => amount > 0;
}

@immutable
class LbWallet {
  const LbWallet({
    required this.version,
    required this.balances,
    required this.transactions,
    this.nextCursor,
  });

  final int version;
  final List<LbWalletBalance> balances;
  final List<LbWalletTransaction> transactions;
  final LbWalletCursor? nextCursor;

  LbWalletBalance balanceFor(LbWalletCurrency currency) => balances.firstWhere(
    (balance) => balance.currency == currency,
    orElse: () => LbWalletBalance(
      currency: currency,
      displayName: currency == LbWalletCurrency.entryCredit
          ? 'Credits'
          : 'Victory Points',
      symbol: currency == LbWalletCurrency.entryCredit ? 'CR' : 'VP',
      balance: 0,
    ),
  );
}

@immutable
class LbNotification {
  const LbNotification({
    required this.id,
    required this.userId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.deepLink,
    this.payload = const {},
  });

  final String id;
  final String userId;
  final NotifKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? deepLink;
  final Map<String, Object?> payload;

  bool get isRead => readAt != null;
}

/// Fee config lives in the `fee_config` table so Super-Admin changes take
/// effect on the next tournament without redeploy (spec §6.3).
@immutable
class LbFeeConfig {
  const LbFeeConfig({
    required this.id,
    required this.tierName,
    required this.entryFeePhp,
    required this.commissionRate,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.supersededAt,
  });

  final String id;
  final String tierName;
  final int entryFeePhp;
  final double commissionRate;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? supersededAt;
}

/// Rank config likewise Super-Admin editable — new thresholds apply on the
/// next background rank-recalculation job.
@immutable
class LbRankConfig {
  const LbRankConfig({
    required this.id,
    required this.rankLevel,
    required this.rankName,
    required this.minWins,
    required this.badgeColor,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.supersededAt,
  });

  final String id;
  final int rankLevel;
  final String rankName;
  final int minWins;
  final String badgeColor;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? supersededAt;
}

@immutable
class LbAuditLogEntry {
  const LbAuditLogEntry({
    required this.id,
    required this.actorId,
    required this.actorRole,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.oldValue,
    this.newValue,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final UserRole actorRole;
  final String action;
  final String entityType;
  final String entityId;
  final Map<String, Object?>? oldValue;
  final Map<String, Object?>? newValue;
  final DateTime createdAt;
}

/// Composed view — one player's full public profile. What team recruiters
/// see. Assembled from User + UserRank + UserBadge + recent matches.
@immutable
class LbPlayerProfile {
  const LbPlayerProfile({
    required this.user,
    required this.rank,
    required this.badges,
    required this.gamesPlayed,
    required this.totalMatches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalPayoutPhp,
    required this.teamIds,
    required this.recentTournaments,
  });

  final LbUser user;
  final LbUserRank rank;
  final List<AchievementBadge> badges;
  final List<String> gamesPlayed;
  final int totalMatches;
  final int totalWins;
  final int totalLosses;
  final int totalPayoutPhp;
  final List<String> teamIds;
  final List<LbCompletedTournament> recentTournaments;

  double get winRate => totalMatches == 0 ? 0.0 : totalWins / totalMatches;
}

@immutable
class LbCompletedTournament {
  const LbCompletedTournament({
    required this.tournament,
    required this.finalPlace,
    required this.payoutPhp,
  });

  final LbTournament tournament;
  final int finalPlace;
  final int payoutPhp;

  bool get wasWin => finalPlace == 1;
}
