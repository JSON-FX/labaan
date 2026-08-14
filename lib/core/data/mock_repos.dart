import 'dart:async';
import 'dart:typed_data';

import '../domain/ranks.dart';
import '../domain/tournament_tier.dart';
import 'fixtures.dart';
import 'models.dart';
import 'repos.dart';

/// Realistic latency for reads — makes screen loading states visible in dev.
const _kReadLatency = Duration(milliseconds: 320);
const _kWriteLatency = Duration(milliseconds: 520);

Future<T> _delay<T>(T value, [Duration d = _kReadLatency]) =>
    Future.delayed(d, () => value);

class MockWalletState {
  MockWalletState()
    : transactions = [
        LbWalletTransaction(
          entryId: 'wallet_entry_tournament_reward',
          id: 'wallet_tournament_reward',
          kind: LbWalletTransactionKind.rewardGrant,
          currency: LbWalletCurrency.rewardPoint,
          amount: 18,
          occurredAt: LbFixtures.now.subtract(const Duration(seconds: 30)),
          referenceType: 'tournament_reward_grant',
          referenceId: 'reward_grant_wallet_test_cup',
        ),
        LbWalletTransaction(
          entryId: 'wallet_entry_reward_seed',
          id: 'wallet_reward_seed',
          kind: LbWalletTransactionKind.adminAdjustment,
          currency: LbWalletCurrency.rewardPoint,
          amount: 250,
          occurredAt: LbFixtures.now.subtract(const Duration(minutes: 1)),
          referenceType: 'profile',
          referenceId: LbFixtures.me.id,
        ),
        LbWalletTransaction(
          entryId: 'wallet_entry_credit_seed',
          id: 'wallet_credit_seed',
          kind: LbWalletTransactionKind.adminAdjustment,
          currency: LbWalletCurrency.entryCredit,
          amount: 1000,
          occurredAt: LbFixtures.now.subtract(const Duration(minutes: 2)),
          referenceType: 'profile',
          referenceId: LbFixtures.me.id,
        ),
      ];

  int entryCreditBalance = 1000;
  int rewardPointBalance = 268;
  final List<LbWalletTransaction> transactions;
  final Map<String, LbRegistration> registrations = {};
  final Map<String, String> entryKeys = {};
  final Map<String, String> cancellationKeys = {};
}

class MockAuthRepo implements AuthRepo {
  MockAuthRepo({LbUser? initialUser, bool signedIn = true})
    : _current = signedIn ? (initialUser ?? LbFixtures.me) : null,
      _providers = signedIn ? {'google.com'} : <String>{};

  final _controller = StreamController<LbUser?>.broadcast();
  LbUser? _current;
  final Set<String> _providers;

  /// True after any successful sign-in — so the second run through the app
  /// jumps straight to /home instead of forcing setup again. Simulates the
  /// real check the server would do against a `profiles.completed_setup`
  /// column.
  bool _setupCompletedOnce = false;

  @override
  Stream<LbUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<LbUser?> currentUser() async => _current;

  @override
  Future<LbUser> signInWithGoogle() => _signIn();

  @override
  Future<LbUser> signInWithFacebook() => _signIn();

  @override
  Future<void> requestPhoneOtp(String phoneE164) =>
      Future<void>.delayed(_kWriteLatency);

  @override
  Future<LbUser> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  }) => _signIn();

  @override
  Future<Set<String>> linkedProviders() async => Set.unmodifiable(_providers);

  @override
  Future<void> linkGoogle() async {
    await Future<void>.delayed(_kWriteLatency);
    _providers.add('google.com');
  }

  @override
  Future<void> requestPhoneLink(String phoneE164) =>
      Future<void>.delayed(_kWriteLatency);

  @override
  Future<void> verifyPhoneLink({
    required String phoneE164,
    required String token,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    _providers.add('phone');
    _current = _current?.copyWith(phone: phoneE164);
    _controller.add(_current);
  }

  @override
  Future<void> requestEmailChange(String email) async {
    await Future<void>.delayed(_kWriteLatency);
  }

  Future<LbUser> _signIn() async {
    await Future<void>.delayed(_kWriteLatency);
    _current = _setupCompletedOnce
        ? LbFixtures.me
        : LbFixtures.me.copyWith(
            username: '',
            region: null,
            games: const [],
            hasCompletedSetup: false,
          );
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<void> completeFirstRunSetup({
    required String username,
    required String region,
    required List<String> games,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    _setupCompletedOnce = true;
    if (_current != null) {
      _current = _current!.copyWith(
        username: username,
        region: region,
        games: games,
        hasCompletedSetup: true,
      );
      _controller.add(_current);
    }
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}

class MockTournamentsRepo implements TournamentsRepo {
  @override
  Future<LbHomeFeed> homeFeed({required String userId}) => _delay(
    LbHomeFeed(
      liveMatchReady: LbFixtures.liveManilaClash,
      featured: [
        LbFixtures.manilaAscentS3,
        LbFixtures.sundayNight,
        LbFixtures.caviteOpen,
      ],
      trending: [LbFixtures.qcGrind08, LbFixtures.caviteOpen],
    ),
  );

  @override
  Future<LbTournamentPage> browse({
    String? cursor,
    String? gameFilter,
    TournamentTier? tierFilter,
    String? organizerId,
    String? searchQuery,
    int limit = 20,
  }) async {
    var items = LbFixtures.allTournaments
        .where((t) => t.isOpen || t.isLive)
        .toList();
    if (gameFilter != null && gameFilter != 'All games') {
      items = items.where((t) => t.game == gameFilter).toList();
    }
    if (tierFilter != null) {
      items = items.where((t) => t.tier == tierFilter).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((t) => t.title.toLowerCase().contains(q)).toList();
    }
    return _delay(LbTournamentPage(items: items));
  }

  @override
  Future<LbTournament> byId(String tournamentId) =>
      _delay(LbFixtures.allTournaments.firstWhere((t) => t.id == tournamentId));

  @override
  Stream<LbTournament> watch(String tournamentId) async* {
    yield await byId(tournamentId);
  }
}

class MockMyTournamentsRepo implements MyTournamentsRepo {
  @override
  Future<LbMyTournaments> forUser(String userId) => _delay(_snapshot());

  @override
  Stream<LbMyTournaments> watchForUser(String userId) async* {
    yield await forUser(userId);
  }

  LbMyTournaments _snapshot() => LbMyTournaments(
    live: [
      LbLiveEntry(
        tournament: LbFixtures.liveManilaClash,
        matchReady: true,
        currentBracketNode: 'UPPER · R2',
        currentMatchId: 'm_u3',
        matchAction: LbMatchAction.verifyResult,
      ),
    ],
    upcoming: [
      LbUpcomingEntry(
        tournament: LbFixtures.caviteOpen,
        locksIn: const Duration(hours: 2, minutes: 14, seconds: 36),
      ),
      LbUpcomingEntry(
        tournament: LbFixtures.sundayNight,
        locksIn: const Duration(days: 1, hours: 6),
      ),
    ],
    completed: [
      LbCompletedTournament(
        tournament: LbFixtures.qcGrind07Completed,
        finalPlace: 1,
        payoutPhp: 5250,
      ),
      LbCompletedTournament(
        tournament: LbFixtures.ascentS2Completed,
        finalPlace: 4,
        payoutPhp: 1200,
      ),
    ],
  );
}

class MockBracketRepo implements BracketRepo {
  @override
  Stream<LbBracket> watch(String tournamentId) async* {
    // Simple two-round bracket for the live Manila Clash.
    yield LbBracket(
      tournamentId: tournamentId,
      upper: [
        LbMatch(
          id: 'm_u1',
          tournamentId: tournamentId,
          round: 1,
          bracketSide: BracketSide.upper,
          teamAId: LbFixtures.teamMnl.id,
          teamBId: LbFixtures.teamCebuKings.id,
          winnerId: LbFixtures.teamMnl.id,
          scoreA: 2,
          scoreB: 0,
          verifiedAt: LbFixtures.now.subtract(const Duration(hours: 1)),
        ),
        LbMatch(
          id: 'm_u2',
          tournamentId: tournamentId,
          round: 1,
          bracketSide: BracketSide.upper,
          teamAId: LbFixtures.teamDavaoGg.id,
          teamBId: 't_ilo',
          winnerId: LbFixtures.teamDavaoGg.id,
          scoreA: 2,
          scoreB: 1,
          verifiedAt: LbFixtures.now.subtract(const Duration(minutes: 30)),
        ),
        LbMatch(
          id: 'm_u3',
          tournamentId: tournamentId,
          round: 2,
          bracketSide: BracketSide.upper,
          teamAId: LbFixtures.teamMnl.id,
          teamBId: LbFixtures.teamDavaoGg.id,
          scoreA: 1,
          scoreB: 0,
        ),
      ],
      lower: [
        LbMatch(
          id: 'm_l1',
          tournamentId: tournamentId,
          round: 1,
          bracketSide: BracketSide.lower,
          teamAId: LbFixtures.teamCebuKings.id,
          teamBId: 't_ilo',
        ),
      ],
      grandFinal: null,
      teams: {
        LbFixtures.teamMnl.id: LbFixtures.teamMnl,
        LbFixtures.teamCebuKings.id: LbFixtures.teamCebuKings,
        LbFixtures.teamDavaoGg.id: LbFixtures.teamDavaoGg,
      },
    );
  }
}

class MockRegistrationRepo implements RegistrationRepo {
  MockRegistrationRepo([MockWalletState? walletState])
    : _walletState = walletState ?? MockWalletState();

  final MockWalletState _walletState;

  @override
  Future<CreditRegistrationResult> enterWithCredits({
    required String tournamentId,
    required String userId,
    String? teamId,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final tournament = LbFixtures.allTournaments.firstWhere(
      (item) => item.id == tournamentId,
    );
    final cost = tournament.entryCreditCost;
    if (!tournament.usesWallet || cost == null) {
      throw const LbRegistrationFailure(
        'wallet_registration_unavailable',
        'This tournament still uses legacy registration.',
      );
    }
    final registrationId = 'credit_reg_${tournament.id}_$userId';
    final current = _walletState.registrations[registrationId];
    if (current?.paymentStatus == RegistrationPaymentStatus.paid) {
      if (_walletState.entryKeys[registrationId] != idempotencyKey) {
        throw const LbRegistrationFailure(
          'already_registered',
          'You are already registered for this tournament.',
        );
      }
      return CreditRegistrationResult(
        registration: current!,
        entryCreditBalance: _walletState.entryCreditBalance,
        entryCreditCost: cost,
        walletTransactionId: 'credit_entry_$registrationId',
        existing: true,
      );
    }
    if (_walletState.entryCreditBalance < cost) {
      throw const LbRegistrationFailure(
        'insufficient_wallet_balance',
        'You do not have enough Credits to enter this tournament.',
      );
    }

    _walletState.entryCreditBalance -= cost;
    final registration = LbRegistration(
      id: registrationId,
      tournamentId: tournamentId,
      userId: userId,
      teamId: teamId,
      paymentStatus: RegistrationPaymentStatus.paid,
      paidAt: LbFixtures.now,
      amountPhp: 0,
      commissionCollectedPhp: 0,
      economyMode: TournamentEconomy.walletV2,
      entryCreditAmount: cost,
    );
    _walletState.registrations[registrationId] = registration;
    _walletState.entryKeys[registrationId] = idempotencyKey;
    final transactionId = 'credit_entry_$registrationId';
    _walletState.transactions.insert(
      0,
      LbWalletTransaction(
        entryId: 'entry_$transactionId',
        id: transactionId,
        kind: LbWalletTransactionKind.entryFee,
        currency: LbWalletCurrency.entryCredit,
        amount: -cost,
        occurredAt: LbFixtures.now,
        referenceType: 'registration',
        referenceId: registrationId,
      ),
    );
    return CreditRegistrationResult(
      registration: registration,
      entryCreditBalance: _walletState.entryCreditBalance,
      entryCreditCost: cost,
      walletTransactionId: transactionId,
      existing: false,
    );
  }

  @override
  Future<CreditRegistrationResult> cancelCreditRegistration({
    required String registrationId,
    required String userId,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final current = _walletState.registrations[registrationId];
    if (current == null || current.userId != userId) {
      throw const LbRegistrationFailure(
        'registration_not_found',
        'Registration not found.',
      );
    }
    final credits = current.entryCreditAmount ?? 0;
    if (current.paymentStatus == RegistrationPaymentStatus.refunded) {
      return CreditRegistrationResult(
        registration: current,
        entryCreditBalance: _walletState.entryCreditBalance,
        entryCreditCost: credits,
        walletTransactionId: 'credit_refund_$registrationId',
        existing: true,
      );
    }
    _walletState.entryCreditBalance += credits;
    final registration = LbRegistration(
      id: current.id,
      tournamentId: current.tournamentId,
      userId: current.userId,
      teamId: current.teamId,
      paymentStatus: RegistrationPaymentStatus.refunded,
      paidAt: current.paidAt,
      amountPhp: 0,
      commissionCollectedPhp: 0,
      economyMode: TournamentEconomy.walletV2,
      entryCreditAmount: credits,
      cancelledAt: LbFixtures.now,
    );
    _walletState.registrations[registrationId] = registration;
    _walletState.cancellationKeys[registrationId] = idempotencyKey;
    final transactionId = 'credit_refund_$registrationId';
    _walletState.transactions.insert(
      0,
      LbWalletTransaction(
        entryId: 'entry_$transactionId',
        id: transactionId,
        kind: LbWalletTransactionKind.entryRefund,
        currency: LbWalletCurrency.entryCredit,
        amount: credits,
        occurredAt: LbFixtures.now,
        referenceType: 'registration',
        referenceId: registrationId,
      ),
    );
    return CreditRegistrationResult(
      registration: registration,
      entryCreditBalance: _walletState.entryCreditBalance,
      entryCreditCost: credits,
      walletTransactionId: transactionId,
      existing: false,
    );
  }

  @override
  Future<RegistrationCheckout> register({
    required String tournamentId,
    required String userId,
    String? teamId,
    required PayMethod method,
    required String captchaToken,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final t = LbFixtures.allTournaments.firstWhere((t) => t.id == tournamentId);
    final commission = (t.entryFeePhp * t.commissionRate).round();
    final status = switch (method) {
      PayMethod.gcash => RegistrationPaymentStatus.paid,
      PayMethod.maya => RegistrationPaymentStatus.pending,
      PayMethod.card => RegistrationPaymentStatus.failed,
    };
    return RegistrationCheckout(
      registration: LbRegistration(
        id: 'reg_${DateTime.fromMillisecondsSinceEpoch(0).microsecond}',
        tournamentId: tournamentId,
        userId: userId,
        teamId: teamId,
        paymentStatus: status,
        paidAt: status == RegistrationPaymentStatus.paid
            ? LbFixtures.now
            : null,
        amountPhp: t.entryFeePhp,
        commissionCollectedPhp: commission,
        paymongoRef: 'paymongo_mock_${method.name}',
      ),
    );
  }

  @override
  Stream<RegistrationPaymentStatus> watchPayment(String registrationId) async* {
    yield RegistrationPaymentStatus.pending;
    await Future<void>.delayed(const Duration(seconds: 1));
    yield RegistrationPaymentStatus.paid;
  }
}

class MockResultsRepo implements ResultsRepo {
  @override
  Future<LbMatch> byId(String matchId) => _delay(
    LbMatch(
      id: matchId,
      tournamentId: LbFixtures.liveManilaClash.id,
      round: 2,
      bracketSide: BracketSide.upper,
      teamAId: LbFixtures.teamMnl.id,
      teamBId: LbFixtures.teamDavaoGg.id,
      scoreA: 2,
      scoreB: 1,
      status: LbMatchStatus.awaitingVerification,
      submittedByUserId: 'u_sage',
      submittedTeamId: LbFixtures.teamDavaoGg.id,
      screenshotUrl: 'u_sage/$matchId/proof.jpg',
    ),
  );

  @override
  Future<String> uploadScreenshot({
    required String userId,
    required String matchId,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    return '$userId/$matchId/proof.$extension';
  }

  @override
  Future<void> submit({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String screenshotPath,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
  }

  @override
  Future<String?> screenshotPreviewUrl(String screenshotPath) async {
    await Future<void>.delayed(_kReadLatency);
    return null;
  }

  @override
  Future<void> verify({required String matchId}) async {
    await Future<void>.delayed(_kWriteLatency);
  }

  @override
  Future<void> openDispute({
    required String matchId,
    required String reason,
    required String detail,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
  }
}

class MockProfileRepo implements ProfileRepo {
  MockProfileRepo({Map<String, LbPlayerProfile> profiles = const {}})
    : _profiles = profiles;

  final Map<String, LbPlayerProfile> _profiles;
  Uint8List? lastAvatarBytes;
  String? lastAvatarContentType;

  @override
  Future<LbPlayerProfile> byId(String userId) => _delay(_profileFor(userId));

  @override
  Future<LbPlayerProfile> byUsername(String username) {
    final u = LbFixtures.allUsers.firstWhere((u) => u.username == username);
    return byId(u.id);
  }

  LbPlayerProfile _profileFor(String userId) {
    final supplied = _profiles[userId];
    if (supplied != null) return supplied;
    final u = LbFixtures.allUsers.firstWhere((u) => u.id == userId);
    final rank = LbFixtures.ranks[userId]!;
    return LbPlayerProfile(
      user: u,
      rank: rank,
      badges: userId == LbFixtures.me.id ? LbFixtures.myBadges : const [],
      gamesPlayed: const ['MLBB', 'VALORANT'],
      totalMatches: 182,
      totalWins: rank.totalWins,
      totalLosses: 182 - rank.totalWins,
      totalPayoutPhp: 18400,
      totalRewardPoints: userId == LbFixtures.me.id ? 268 : 0,
      teamIds: userId == LbFixtures.me.id ? [LbFixtures.teamMnl.id] : const [],
      recentTournaments: [
        LbCompletedTournament(
          tournament: LbFixtures.qcGrind07Completed,
          finalPlace: 1,
          payoutPhp: 5250,
        ),
        LbCompletedTournament(
          tournament: LbFixtures.ascentS2Completed,
          finalPlace: 4,
          payoutPhp: 1200,
        ),
      ],
    );
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    lastAvatarBytes = bytes;
    lastAvatarContentType = contentType;
    final avatarUrl = 'https://example.test/avatars/$userId/avatar';
    final existing = _profileFor(userId);
    _profiles[userId] = LbPlayerProfile(
      user: LbUser(
        id: existing.user.id,
        username: existing.user.username,
        email: existing.user.email,
        phone: existing.user.phone,
        region: existing.user.region,
        avatarUrl: avatarUrl,
        createdAt: existing.user.createdAt,
        isBanned: existing.user.isBanned,
        role: existing.user.role,
        games: existing.user.games,
        hasCompletedSetup: existing.user.hasCompletedSetup,
      ),
      rank: existing.rank,
      badges: existing.badges,
      gamesPlayed: existing.gamesPlayed,
      totalMatches: existing.totalMatches,
      totalWins: existing.totalWins,
      totalLosses: existing.totalLosses,
      totalPayoutPhp: existing.totalPayoutPhp,
      totalRewardPoints: existing.totalRewardPoints,
      teamIds: existing.teamIds,
      recentTournaments: existing.recentTournaments,
    );
    return avatarUrl;
  }

  @override
  Future<void> updateIdentity({
    required String userId,
    required String username,
    required String region,
    required List<String> games,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
  }
}

class MockSettingsRepo implements SettingsRepo {
  LbNotificationPreferences _preferences = LbNotificationPreferences.defaults();
  LbPayoutAccount? _payoutAccount;
  LbAccountDeletionRequest? _deletionRequest;

  @override
  Future<LbNotificationPreferences> notificationPreferences(String userId) =>
      _delay(_preferences);

  @override
  Future<void> saveNotificationPreferences(
    String userId,
    LbNotificationPreferences preferences,
  ) async {
    await Future<void>.delayed(_kWriteLatency);
    _preferences = preferences;
  }

  @override
  Future<LbPayoutAccount?> payoutAccount(String userId) =>
      _delay(_payoutAccount);

  @override
  Future<void> savePayoutAccount(String userId, LbPayoutAccount account) async {
    await Future<void>.delayed(_kWriteLatency);
    _payoutAccount = account;
  }

  @override
  Future<void> deletePayoutAccount(String userId) async {
    await Future<void>.delayed(_kWriteLatency);
    _payoutAccount = null;
  }

  @override
  Future<LbAccountDeletionRequest?> accountDeletionRequest(String userId) =>
      _delay(_deletionRequest);

  @override
  Future<LbAccountDeletionRequest> requestAccountDeletion() async {
    await Future<void>.delayed(_kWriteLatency);
    final now = LbFixtures.now;
    return _deletionRequest = LbAccountDeletionRequest(
      id: 'deletion_request_1',
      userId: LbFixtures.me.id,
      status: LbAccountDeletionStatus.pending,
      requestedAt: now,
      scheduledFor: now.add(const Duration(days: 30)),
    );
  }

  @override
  Future<LbAccountDeletionRequest> cancelAccountDeletion() async {
    await Future<void>.delayed(_kWriteLatency);
    final current = _deletionRequest!;
    return _deletionRequest = LbAccountDeletionRequest(
      id: current.id,
      userId: current.userId,
      status: LbAccountDeletionStatus.cancelled,
      requestedAt: current.requestedAt,
      scheduledFor: current.scheduledFor,
      cancelledAt: LbFixtures.now,
    );
  }
}

class MockEconomyFeatureFlagsRepo implements EconomyFeatureFlagsRepo {
  @override
  Future<LbEconomyFeatures> forPlatform({
    required String environment,
    required LbClientPlatform platform,
  }) async {
    final direct = platform != LbClientPlatform.ios;
    return LbEconomyFeatures({
      LbEconomyFeature.walletRegistration: true,
      LbEconomyFeature.creditTopup: direct,
      LbEconomyFeature.organizerSponsorship: platform == LbClientPlatform.web,
      LbEconomyFeature.shop: direct,
    }, const {});
  }
}

class MockAdminEconomyRepo implements AdminEconomyRepo {
  @override
  Future<LbAdminEconomyDashboard> dashboard() async =>
      const LbAdminEconomyDashboard(
        summary: {
          'outstanding_credits': 12500,
          'awarded_victory_points': 4200,
          'redeemed_victory_points': 900,
          'unfulfilled_expected_cost_centavos': 0,
        },
        actionCounts: {'topups': 0, 'sponsors': 0, 'rewards': 0, 'shop': 0},
        actionItems: [],
        riskCases: [],
      );

  @override
  Future<void> adjustWallet({
    required String targetUserId,
    required LbWalletCurrency currency,
    required bool grant,
    required int amount,
    required String reason,
    required String idempotencyKey,
  }) async {}

  @override
  Future<void> allocateRewardFunding({
    required String tournamentId,
    required bool brandSponsored,
    required String fundingReference,
    String? attributionName,
    required int amount,
    required int sourceCap,
    required String reason,
  }) async {}

  @override
  Future<Map<String, int>> runShopFulfillment({int limit = 25}) async => const {
    'claimed': 0,
    'fulfilled': 0,
    'retried': 0,
    'review': 0,
  };

  @override
  Future<void> resolveRiskCase({
    required String caseId,
    required bool dismissed,
    required String reason,
  }) async {}
}

class MockWalletRepo implements WalletRepo {
  MockWalletRepo([MockWalletState? state])
    : _state = state ?? MockWalletState();

  final MockWalletState _state;

  @override
  Future<LbWallet> currentWallet({int limit = 50, LbWalletCursor? before}) =>
      _delay(
        LbWallet(
          version: 2,
          balances: [
            LbWalletBalance(
              currency: LbWalletCurrency.entryCredit,
              displayName: 'Credits',
              symbol: 'CR',
              balance: _state.entryCreditBalance,
            ),
            LbWalletBalance(
              currency: LbWalletCurrency.rewardPoint,
              displayName: 'Victory Points',
              symbol: 'VP',
              balance: _state.rewardPointBalance,
            ),
          ],
          transactions: _state.transactions.take(limit).toList(),
          nextCursor: null,
        ),
      );

  @override
  Future<List<LbCreditPack>> activeCreditPacks({
    required CreditPackProvider provider,
    required CreditPackPlatform platform,
  }) => _delay([
    for (final pack in _developmentCreditPacks)
      if (pack.provider == provider && pack.platform == platform) pack,
  ]);

  @override
  Future<LbTopupCheckout> createPaymongoTopup({
    required LbCreditPack pack,
    required PayMethod method,
    required CreditPackPlatform platform,
    required String idempotencyKey,
    required Uri successUrl,
    required Uri cancelUrl,
  }) => _delay(
    LbTopupCheckout(
      orderId: 'mock-topup-${pack.packCode}',
      checkoutUrl: Uri.parse('https://checkout.paymongo.com/mock-topup'),
      creditAmount: pack.creditAmount,
      priceCentavos: pack.priceCentavos,
    ),
    _kWriteLatency,
  );
}

final _developmentCreditPacks = [
  for (final platform in [
    CreditPackPlatform.web,
    CreditPackPlatform.androidDirect,
  ]) ...[
    LbCreditPack(
      id: 'mock_credit_50_${platform.name}',
      packCode: 'dev_credit_50',
      revision: 1,
      provider: CreditPackProvider.paymongo,
      platform: platform,
      creditAmount: 50,
      priceCentavos: 5000,
      currencyCode: 'PHP',
      maxPurchasesPerDay: 10,
      sortOrder: 10,
    ),
    LbCreditPack(
      id: 'mock_credit_100_${platform.name}',
      packCode: 'dev_credit_100',
      revision: 1,
      provider: CreditPackProvider.paymongo,
      platform: platform,
      creditAmount: 100,
      priceCentavos: 10000,
      currencyCode: 'PHP',
      maxPurchasesPerDay: 10,
      sortOrder: 20,
    ),
    LbCreditPack(
      id: 'mock_credit_250_${platform.name}',
      packCode: 'dev_credit_250',
      revision: 1,
      provider: CreditPackProvider.paymongo,
      platform: platform,
      creditAmount: 250,
      priceCentavos: 25000,
      currencyCode: 'PHP',
      maxPurchasesPerDay: 10,
      sortOrder: 30,
    ),
  ],
];

class MockHostSponsorRepo implements HostSponsorRepo {
  static const _packages = [
    LbSponsorPackage(
      id: 'sponsor_starter_v1',
      packageCode: 'starter_boost',
      displayName: 'Starter boost',
      description: 'Add 100 Victory Points to one tournament.',
      rewardPointAmount: 100,
      priceCentavos: 14900,
      perTournamentPurchaseLimit: 5,
      tournamentSponsorCap: 1000,
    ),
    LbSponsorPackage(
      id: 'sponsor_featured_v1',
      packageCode: 'featured_boost',
      displayName: 'Featured boost',
      description: 'Add 300 Victory Points to one tournament.',
      rewardPointAmount: 300,
      priceCentavos: 39900,
      perTournamentPurchaseLimit: 3,
      tournamentSponsorCap: 1000,
    ),
  ];

  @override
  Future<String> createTournamentDraft(LbWalletTournamentDraft draft) =>
      _delay('mock-wallet-tournament');

  @override
  Future<LbHostSponsorPortal> portalForOrganizer(String organizerId) => _delay(
    LbHostSponsorPortal(
      tournaments: [LbFixtures.caviteOpen],
      packages: _packages,
    ),
  );

  @override
  Future<LbSponsorCheckout> createCheckout({
    required String tournamentId,
    required LbSponsorPackage package,
    required PayMethod method,
    required bool showAttribution,
    required String idempotencyKey,
    required Uri successUrl,
    required Uri cancelUrl,
  }) => _delay(
    LbSponsorCheckout(
      orderId: 'mock-sponsor-order',
      checkoutUrl: Uri.parse('https://checkout.paymongo.com/mock-sponsor'),
      rewardPointAmount: package.rewardPointAmount,
      priceCentavos: package.priceCentavos,
    ),
  );
}

class MockShopRepo implements ShopRepo {
  MockShopRepo(this._walletState);

  final MockWalletState _walletState;
  final List<LbShopOrder> _orders = [];

  static const products = [
    LbShopProduct(
      id: 'shop_neon_frame_v1',
      productCode: 'neon_contender_frame',
      revision: 1,
      displayName: 'Neon Contender frame',
      description: 'A permanent neon frame for your player profile.',
      category: 'profile_cosmetic',
      fulfillmentType: 'internal_entitlement',
      priceRewardPoints: 120,
      platformVisibility: {ShopPlatform.web, ShopPlatform.androidDirect},
      perUserLimit: 1,
    ),
    LbShopProduct(
      id: 'shop_founder_badge_v1',
      productCode: 'founding_challenger_badge',
      revision: 1,
      displayName: 'Founding Challenger badge',
      description: 'A permanent badge for early competitive players.',
      category: 'profile_cosmetic',
      fulfillmentType: 'internal_entitlement',
      priceRewardPoints: 250,
      platformVisibility: {ShopPlatform.web, ShopPlatform.androidDirect},
      perUserLimit: 1,
    ),
  ];

  @override
  Future<List<LbShopProduct>> catalog(ShopPlatform platform) => _delay([
    for (final product in products)
      if (product.platformVisibility.contains(platform)) product,
  ]);

  @override
  Future<List<LbShopOrder>> orders() => _delay(List.unmodifiable(_orders));

  @override
  Future<LbShopPurchaseResult> purchase({
    required LbShopProduct product,
    required ShopPlatform platform,
    required int quantity,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    if (_walletState.rewardPointBalance <
        product.priceRewardPoints * quantity) {
      throw StateError('insufficient_reward_points');
    }
    _walletState.rewardPointBalance -= product.priceRewardPoints * quantity;
    final order = LbShopOrder(
      id: 'shop_order_${_orders.length + 1}',
      status: ShopOrderStatus.fulfillmentPending,
      totalRewardPoints: product.priceRewardPoints * quantity,
      productName: product.displayName,
      quantity: quantity,
      customerStatus: 'Preparing your item',
      createdAt: LbFixtures.now,
    );
    _orders.insert(0, order);
    return LbShopPurchaseResult(
      order: order,
      rewardPointBalance: _walletState.rewardPointBalance,
      existing: false,
    );
  }

  @override
  Future<LbShopPurchaseResult> cancel({
    required String orderId,
    required String reason,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final index = _orders.indexWhere((order) => order.id == orderId);
    final previous = _orders[index];
    _walletState.rewardPointBalance += previous.totalRewardPoints;
    final refunded = LbShopOrder(
      id: previous.id,
      status: ShopOrderStatus.refunded,
      totalRewardPoints: previous.totalRewardPoints,
      productName: previous.productName,
      quantity: previous.quantity,
      customerStatus: 'Cancelled and refunded',
      createdAt: previous.createdAt,
      refundedAt: LbFixtures.now,
    );
    _orders[index] = refunded;
    return LbShopPurchaseResult(
      order: refunded,
      rewardPointBalance: _walletState.rewardPointBalance,
      existing: false,
    );
  }
}

class MockTeamsRepo implements TeamsRepo {
  MockTeamsRepo()
    : _teams = {for (final team in LbFixtures.allTeams) team.id: team};

  final Map<String, LbTeam> _teams;

  @override
  Future<LbTeam> byId(String teamId) =>
      _delay(_teams.values.firstWhere((t) => t.id == teamId));

  @override
  Future<List<LbTeam>> forUser(String userId) =>
      _delay(_teams.values.where((t) => t.memberIds.contains(userId)).toList());

  @override
  Future<LbTeam> createTeam({
    required String name,
    required String tag,
    required String captainUserId,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    return LbTeam(
      id: 't_new',
      name: name,
      tag: tag,
      captainUserId: captainUserId,
      memberIds: [captainUserId],
      createdAt: LbFixtures.now,
    );
  }

  @override
  Future<void> invite({required String teamId, required String userId}) =>
      Future<void>.delayed(_kWriteLatency);

  @override
  Future<void> inviteByUsername({
    required String teamId,
    required String username,
  }) => Future<void>.delayed(_kWriteLatency);

  @override
  Future<void> updateTeam({
    required String teamId,
    required String name,
    required String tag,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final team = _teams[teamId]!;
    _teams[teamId] = _copyTeam(
      team,
      name: name.trim(),
      tag: tag.trim().toUpperCase(),
    );
  }

  @override
  Future<void> removeMember({
    required String teamId,
    required String userId,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final team = _teams[teamId]!;
    _teams[teamId] = _copyTeam(
      team,
      memberIds: team.memberIds.where((id) => id != userId).toList(),
    );
  }

  @override
  Future<void> transferCaptain({
    required String teamId,
    required String userId,
  }) async {
    await Future<void>.delayed(_kWriteLatency);
    final team = _teams[teamId]!;
    _teams[teamId] = _copyTeam(team, captainUserId: userId);
  }

  @override
  Future<void> acceptInvite(String inviteId) =>
      Future<void>.delayed(_kWriteLatency);

  @override
  Future<void> declineInvite(String inviteId) =>
      Future<void>.delayed(_kWriteLatency);

  @override
  Future<void> leaveTeam({
    required String teamId,
    required String userId,
  }) async {
    await removeMember(teamId: teamId, userId: userId);
  }

  LbTeam _copyTeam(
    LbTeam team, {
    String? name,
    String? tag,
    String? captainUserId,
    List<String>? memberIds,
  }) => LbTeam(
    id: team.id,
    name: name ?? team.name,
    tag: tag ?? team.tag,
    logoUrl: team.logoUrl,
    captainUserId: captainUserId ?? team.captainUserId,
    memberIds: memberIds ?? team.memberIds,
    createdAt: team.createdAt,
  );
}

class MockPlayersRepo implements PlayersRepo {
  @override
  Future<LbPlayerSearchPage> search({
    String? game,
    String? username,
    Rank? minRank,
    String? region,
    bool freeAgentsOnly = false,
    String? cursor,
    int limit = 20,
  }) async {
    var items = LbFixtures.freeAgents;
    final usernameTerm = username?.trim().toLowerCase().replaceFirst('@', '');
    if (usernameTerm != null && usernameTerm.isNotEmpty) {
      items = items
          .where((p) => p.user.username.toLowerCase().contains(usernameTerm))
          .toList();
    }
    if (freeAgentsOnly) {
      items = items.where((p) => p.isFreeAgent).toList();
    }
    if (minRank != null) {
      items = items.where((p) => p.rank.rank.level >= minRank.level).toList();
    }
    if (game != null && game != 'All games') {
      items = items.where((p) => p.games.contains(game)).toList();
    }
    return _delay(LbPlayerSearchPage(items: items));
  }
}

class MockLeaderboardRepo implements LeaderboardRepo {
  @override
  Future<List<LbLeaderboardPlayer>> topPlayers({
    String? game,
    int limit = 20,
  }) async {
    final entries = LbFixtures.ranks.entries.toList()
      ..sort((a, b) => b.value.totalWins.compareTo(a.value.totalWins));
    return _delay([
      for (var i = 0; i < entries.length && i < limit; i++)
        LbLeaderboardPlayer(
          position: i + 1,
          user: LbFixtures.allUsers.firstWhere((u) => u.id == entries[i].key),
          rank: entries[i].value,
        ),
    ]);
  }

  @override
  Future<List<LbLeaderboardTeam>> topTeams({
    String? game,
    int limit = 20,
  }) async {
    // Static leaderboard values for MVP mock.
    return _delay(const [
      // NB: these use LbTeam already; reads deterministic values below.
    ]).then(
      (_) => [
        LbLeaderboardTeam(position: 1, team: LbFixtures.teamMnl, wins: 42),
        LbLeaderboardTeam(
          position: 2,
          team: LbFixtures.teamCebuKings,
          wins: 38,
        ),
        LbLeaderboardTeam(position: 3, team: LbFixtures.teamDavaoGg, wins: 31),
      ],
    );
  }

  @override
  Future<int?> playerPosition({required String userId, String? game}) async {
    final players = await topPlayers(game: game, limit: 1000);
    final p = players.firstWhere(
      (p) => p.user.id == userId,
      orElse: () => players.first,
    );
    return p.position;
  }
}

class MockNotificationsRepo implements NotificationsRepo {
  final _controller = StreamController<List<LbNotification>>.broadcast(
    sync: true,
  );
  late List<LbNotification> _items = List.of(LbFixtures.myNotifications);

  MockNotificationsRepo() {
    _controller.onListen = () => _controller.add(_items);
  }

  @override
  Stream<List<LbNotification>> watchForUser(String userId) =>
      _controller.stream;

  @override
  Future<void> markAllRead(String userId) async {
    _items = [
      for (final n in _items)
        n.isRead
            ? n
            : LbNotification(
                id: n.id,
                userId: n.userId,
                kind: n.kind,
                title: n.title,
                body: n.body,
                createdAt: n.createdAt,
                readAt: LbFixtures.now,
                deepLink: n.deepLink,
                payload: n.payload,
              ),
    ];
    _controller.add(_items);
  }

  @override
  Future<void> markRead(String notificationId) async {}

  @override
  Future<void> respondToTeamInvite({
    required String invitationId,
    required bool accept,
  }) async {
    final status = accept ? 'accepted' : 'declined';
    _items = [
      for (final n in _items)
        if (n.payload['invitation_id'] == invitationId)
          LbNotification(
            id: n.id,
            userId: n.userId,
            kind: n.kind,
            title: n.title,
            body: n.body,
            createdAt: n.createdAt,
            readAt: LbFixtures.now,
            deepLink: n.deepLink,
            payload: {...n.payload, 'invitation_status': status},
          )
        else
          n,
    ];
    _controller.add(_items);
  }
}
