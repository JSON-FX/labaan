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

class MockWalletRepo implements WalletRepo {
  @override
  Future<LbWallet> currentWallet({int limit = 50}) => _delay(
    LbWallet(
      totalPrizeCentavos: 18400,
      totalEntryFeeCentavos: 65000,
      netCashFlowCentavos: -46600,
      pendingPrizeCentavos: 0,
      transactions: [
        LbWalletTransaction(
          id: 'wallet_prize_1',
          kind: LbWalletTransactionKind.prize,
          tournamentId: 't_qc7',
          tournamentTitle: 'QC Grind #07',
          amountCentavos: 18400,
          method: 'gcash',
          status: 'completed',
          occurredAt: LbFixtures.now.subtract(const Duration(days: 5)),
        ),
        LbWalletTransaction(
          id: 'wallet_fee_2',
          kind: LbWalletTransactionKind.entryFee,
          tournamentId: 't_allstars',
          tournamentTitle: 'All-Stars Season 3',
          amountCentavos: -50000,
          method: 'maya',
          status: 'paid',
          occurredAt: LbFixtures.now.subtract(const Duration(days: 2)),
        ),
        LbWalletTransaction(
          id: 'wallet_fee_1',
          kind: LbWalletTransactionKind.entryFee,
          tournamentId: 't_manila',
          tournamentTitle: 'Manila Clash #42',
          amountCentavos: -10000,
          method: 'gcash',
          status: 'paid',
          occurredAt: LbFixtures.now.subtract(const Duration(days: 3)),
        ),
        LbWalletTransaction(
          id: 'wallet_fee_3',
          kind: LbWalletTransactionKind.entryFee,
          tournamentId: 't_qc7',
          tournamentTitle: 'QC Grind #07',
          amountCentavos: -5000,
          method: 'card',
          status: 'paid',
          occurredAt: LbFixtures.now.subtract(const Duration(days: 10)),
        ),
      ].take(limit).toList(),
    ),
  );
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
