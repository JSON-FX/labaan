import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/badges.dart';
import '../domain/ranks.dart';
import '../domain/roles.dart';
import '../domain/tournament_status.dart';
import '../domain/tournament_tier.dart';
import 'models.dart';
import 'repos.dart';
import 'supabase_client.dart';

/// Supabase adapters for the schema owned by the sibling
/// `labaan-backend` project. Reads use PostgREST, live data uses Realtime,
/// and privileged writes use the backend's Edge Functions.

extension _EnumSnakeExt on Enum {
  String get snake => name.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (m) => '_${m.group(0)!.toLowerCase()}',
  );
}

T _enumFromSnake<T extends Enum>(List<T> values, String value) {
  return values.firstWhere(
    (e) => e.snake == value || e.name == value,
    orElse: () => throw StateError('Unknown enum value "$value" for $T'),
  );
}

int _centavosToPhp(Object? value) => ((value as num? ?? 0) / 100).round();

TournamentTier _tierFromName(Object? value) {
  final name = value?.toString().toLowerCase();
  return TournamentTier.values.firstWhere(
    (tier) => tier.name == name || tier.displayName.toLowerCase() == name,
    orElse: () => throw StateError('Unknown tournament tier "$value"'),
  );
}

Rank _rankFromRowValue(Map<String, dynamic> row) {
  final level = (row['current_rank'] as num?)?.toInt();
  if (level != null && level >= 1 && level <= Rank.values.length) {
    return Rank.values[level - 1];
  }
  final name = row['rank_name']?.toString().toLowerCase();
  return Rank.values.firstWhere(
    (rank) => rank.name == name,
    orElse: () => Rank.recruit,
  );
}

UserRole _roleFromClaim(Object? value) => switch (value?.toString()) {
  'super_admin' => UserRole.superAdmin,
  'organizer' => UserRole.tournamentOrganizer,
  'moderator' => UserRole.moderator,
  'spectator' => UserRole.spectator,
  _ => UserRole.player,
};

Map<String, dynamic> _map(Object? value) =>
    (value as Map).cast<String, dynamic>();

LbUser _userFromProfile(
  Map<String, dynamic> row, {
  User? authUser,
  UserRole role = UserRole.player,
}) {
  return LbUser(
    id: row['id'] as String,
    username: row['username'] as String,
    email: authUser?.email ?? '',
    phone: authUser?.phone,
    region: row['region'] as String?,
    avatarUrl: row['avatar_url'] as String?,
    role: role,
    games: ((row['games'] as List?) ?? const []).cast<String>(),
    hasCompletedSetup: (row['has_completed_setup'] as bool?) ?? false,
    isBanned: (row['is_banned'] as bool?) ?? false,
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

LbUserRank _rankFromRow(Map<String, dynamic> row) => LbUserRank(
  userId: row['user_id'] as String,
  totalWins: (row['total_wins'] as num?)?.toInt() ?? 0,
  rank: _rankFromRowValue(row),
  rankUpdatedAt: DateTime.parse(row['rank_updated_at'] as String),
);

LbTeam _teamFromRow(Map<String, dynamic> row, {List<String>? memberIds}) {
  return LbTeam(
    id: row['id'] as String,
    name: row['name'] as String,
    tag: row['tag'] as String? ?? '',
    logoUrl: row['logo_url'] as String?,
    captainUserId: row['captain_user_id'] as String,
    memberIds: memberIds ?? const [],
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

int _registrationCount(Map<String, dynamic> row) {
  final stored = row['registered_teams'];
  if (stored is num) return stored.toInt();
  final registrations = row['registrations'];
  if (registrations is! List || registrations.isEmpty) return 0;
  return (_map(registrations.first)['count'] as num?)?.toInt() ?? 0;
}

List<String> _relatedUserIds(Map<String, dynamic> row, String key) {
  final values = row[key];
  if (values is! List) return const [];
  return [
    for (final item in values)
      if (_map(item)['user_id'] case final String id) id,
  ];
}

LbTournament _tournamentFromRow(Map<String, dynamic> row) {
  final createdAt = DateTime.parse(row['created_at'] as String);
  return LbTournament(
    id: row['id'] as String,
    title: row['title'] as String,
    game: row['game'] as String,
    format: _enumFromSnake(BracketFormat.values, row['format'] as String),
    tier: _tierFromName(row['tier_name']),
    maxTeams: (row['max_teams'] as num).toInt(),
    registeredTeams: _registrationCount(row),
    entryFeePhp: _centavosToPhp(row['entry_fee']),
    commissionRate: (row['commission_rate'] as num).toDouble(),
    prizePoolPhp: _centavosToPhp(row['prize_pool']),
    status: _enumFromSnake(TournamentStatus.values, row['status'] as String),
    organizerId: row['organizer_id'] as String,
    moderatorIds: _relatedUserIds(row, 'tournament_moderators'),
    spectatorIds: _relatedUserIds(row, 'tournament_spectators'),
    gabPermitNumber: row['gab_permit_number'] as String?,
    startsAt: row['starts_at'] == null
        ? createdAt
        : DateTime.parse(row['starts_at'] as String),
    locksAt: row['registration_locks_at'] == null
        ? null
        : DateTime.parse(row['registration_locks_at'] as String),
    createdAt: createdAt,
  );
}

LbMatch _matchFromRow(Map<String, dynamic> row, {BracketSide? side}) {
  return LbMatch(
    id: row['id'] as String,
    tournamentId: row['tournament_id'] as String,
    round: (row['round'] as num).toInt(),
    bracketSide:
        side ??
        (row['bracket_side'] == null
            ? BracketSide.upper
            : _enumFromSnake(
                BracketSide.values,
                row['bracket_side'] as String,
              )),
    teamAId: row['team_a_id'] as String? ?? '',
    teamBId: row['team_b_id'] as String? ?? '',
    winnerId: row['winner_id'] as String?,
    scoreA: (row['score_a'] as num?)?.toInt() ?? 0,
    scoreB: (row['score_b'] as num?)?.toInt() ?? 0,
    screenshotUrl: row['screenshot_url'] as String?,
    verifiedByModeratorId: row['verified_by'] as String?,
    verifiedAt: row['verified_at'] == null
        ? null
        : DateTime.parse(row['verified_at'] as String),
  );
}

NotifKind _notificationKind(Object? value) {
  final raw = value?.toString() ?? '';
  return NotifKind.values.firstWhere(
    (kind) => kind.snake == raw || kind.name == raw,
    orElse: () => NotifKind.startingSoon,
  );
}

LbNotification _notificationFromRow(Map<String, dynamic> row) {
  final data = ((row['data'] as Map?) ?? const {}).cast<String, Object?>();
  return LbNotification(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    kind: _notificationKind(row['type']),
    title: row['title'] as String,
    body: row['body'] as String? ?? '',
    deepLink: data['deep_link'] as String?,
    payload: data,
    readAt: row['read_at'] == null
        ? null
        : DateTime.parse(row['read_at'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

LbRegistration _registrationFromRow(Map<String, dynamic> row) {
  return LbRegistration(
    id: row['id'] as String,
    tournamentId: row['tournament_id'] as String,
    userId: row['user_id'] as String,
    teamId: row['team_id'] as String?,
    paymentStatus: _enumFromSnake(
      RegistrationPaymentStatus.values,
      row['payment_status'] as String,
    ),
    paidAt: row['paid_at'] == null
        ? null
        : DateTime.parse(row['paid_at'] as String),
    amountPhp: _centavosToPhp(row['amount']),
    commissionCollectedPhp: _centavosToPhp(row['commission_collected']),
    paymongoRef: row['paymongo_ref'] as String?,
  );
}

Map<String, dynamic> _functionData(FunctionResponse response) {
  if (response.status < 200 || response.status >= 300) {
    throw StateError('Backend function failed (${response.status})');
  }
  final body = response.data;
  if (body is Map && body['data'] is Map) return _map(body['data']);
  if (body is Map) return body.cast<String, dynamic>();
  throw StateError('Backend function returned an invalid response');
}

class SupabaseAuthRepo implements AuthRepo {
  SupabaseAuthRepo(this._client);
  final SupabaseClient _client;

  @override
  Stream<LbUser?> authStateChanges() async* {
    final initial = await currentUser();
    yield initial;
    await for (final event in _client.auth.onAuthStateChange) {
      final user = event.session?.user;
      yield user == null ? null : await _loadProfile(user);
    }
  }

  Future<LbUser?> _loadProfile(User authUser) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();
    if (row == null) return null;
    return _userFromProfile(
      row,
      authUser: authUser,
      role: _roleFromClaim(authUser.appMetadata['user_role']),
    );
  }

  @override
  Future<LbUser?> currentUser() async {
    final user = _client.auth.currentUser;
    return user == null ? null : _loadProfile(user);
  }

  Future<LbUser> _signInWithOAuth(OAuthProvider provider) async {
    final authEvent = _client.auth.onAuthStateChange.firstWhere(
      (event) => event.session?.user != null,
    );
    final opened = await _client.auth.signInWithOAuth(
      provider,
      redirectTo: Lb.oauthRedirectUrl,
    );
    if (!opened) throw AuthException('Could not open the sign-in page');
    final event = await authEvent.timeout(const Duration(minutes: 3));
    final user = event.session!.user;
    final profile = await _loadProfile(user);
    if (profile == null) throw AuthException('Profile was not created');
    return profile;
  }

  @override
  Future<LbUser> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  @override
  Future<LbUser> signInWithFacebook() =>
      _signInWithOAuth(OAuthProvider.facebook);

  @override
  Future<LbUser> signInWithPhone(String phoneE164) async {
    await requestPhoneOtp(phoneE164);
    throw UnimplementedError(
      'OTP requested. Complete sign-in on the phone verification screen.',
    );
  }

  @override
  Future<LbUser> signInForTesting() async {
    final response = await _client.auth.signInWithPassword(
      email: 'tonton@seed.labaan.test',
      password: 'Labaan-Test-Only-2026!',
    );
    final user = response.user;
    if (user == null) throw AuthException('Development sign-in failed');
    final profile = await _loadProfile(user);
    if (profile == null) throw AuthException('Seed profile was not found');
    return profile;
  }

  @override
  Future<void> requestPhoneOtp(String phoneE164) =>
      _client.auth.signInWithOtp(phone: phoneE164);

  @override
  Future<LbUser> verifyPhoneOtp({
    required String phoneE164,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: phoneE164,
      token: token,
      type: OtpType.sms,
    );
    final user = response.user;
    if (user == null) throw AuthException('OTP verification failed');
    final profile = await _loadProfile(user);
    if (profile == null) throw AuthException('Profile was not created');
    return profile;
  }

  @override
  Future<void> completeFirstRunSetup({
    required String username,
    required String region,
    required List<String> games,
  }) async {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw AuthException('Not signed in');
    await _client
        .from('profiles')
        .update({
          'username': username,
          'region': region,
          'games': games,
          'has_completed_setup': true,
        })
        .eq('id', id);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

const _tournamentSelect =
    '*, tournament_moderators(user_id), '
    'tournament_spectators(user_id)';

class SupabaseTournamentsRepo implements TournamentsRepo {
  SupabaseTournamentsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbHomeFeed> homeFeed({required String userId}) async {
    final responses = await Future.wait([
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .eq('status', 'live')
          .limit(1),
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .inFilter('status', ['open', 'filling_up'])
          .order('registration_locks_at', nullsFirst: false)
          .limit(3),
      _client
          .from('tournaments')
          .select(_tournamentSelect)
          .inFilter('status', ['open', 'filling_up'])
          .order('created_at', ascending: false)
          .limit(3),
    ]);
    final live = responses[0];
    return LbHomeFeed(
      liveMatchReady: live.isEmpty ? null : _tournamentFromRow(live.first),
      featured: [for (final row in responses[1]) _tournamentFromRow(row)],
      trending: [for (final row in responses[2]) _tournamentFromRow(row)],
    );
  }

  @override
  Future<LbTournamentPage> browse({
    String? cursor,
    String? gameFilter,
    TournamentTier? tierFilter,
    String? organizerId,
    String? searchQuery,
    int limit = 20,
  }) async {
    dynamic query = _client
        .from('tournaments')
        .select(_tournamentSelect)
        .inFilter('status', ['open', 'filling_up', 'live']);
    if (gameFilter != null && gameFilter != 'All games') {
      query = query.eq('game', gameFilter);
    }
    if (tierFilter != null) {
      query = query.eq('tier_name', tierFilter.displayName);
    }
    if (organizerId != null) {
      query = query.eq('organizer_id', organizerId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }
    if (cursor != null) {
      final parts = cursor.split('|');
      if (parts.length == 2) {
        query = query.or(
          'created_at.lt.${parts[0]},'
          'and(created_at.eq.${parts[0]},id.lt.${parts[1]})',
        );
      }
    }
    final List<dynamic> rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return LbTournamentPage(
      items: [for (final row in rows) _tournamentFromRow(row)],
      nextCursor: rows.length == limit
          ? '${rows.last['created_at']}|${rows.last['id']}'
          : null,
    );
  }

  @override
  Future<LbTournament> byId(String tournamentId) async {
    final row = await _client
        .from('tournaments')
        .select(_tournamentSelect)
        .eq('id', tournamentId)
        .single();
    return _tournamentFromRow(row);
  }

  @override
  Stream<LbTournament> watch(String tournamentId) {
    return _client
        .from('tournaments')
        .stream(primaryKey: ['id'])
        .eq('id', tournamentId)
        .where((rows) => rows.isNotEmpty)
        .map((rows) => _tournamentFromRow(rows.first));
  }
}

class SupabaseMyTournamentsRepo implements MyTournamentsRepo {
  SupabaseMyTournamentsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbMyTournaments> forUser(String userId) async {
    final rows = await _client
        .from('registrations')
        .select('*, tournaments!inner($_tournamentSelect)')
        .eq('user_id', userId)
        .eq('payment_status', 'paid');
    final now = DateTime.now();
    final live = <LbLiveEntry>[];
    final upcoming = <LbUpcomingEntry>[];
    final completed = <LbCompletedTournament>[];
    for (final row in rows) {
      final tournament = _tournamentFromRow(_map(row['tournaments']));
      switch (tournament.status) {
        case TournamentStatus.live:
          live.add(
            LbLiveEntry(
              tournament: tournament,
              matchReady: true,
              currentBracketNode: 'CURRENT MATCH',
            ),
          );
        case TournamentStatus.open:
        case TournamentStatus.fillingUp:
        case TournamentStatus.locked:
          upcoming.add(
            LbUpcomingEntry(
              tournament: tournament,
              locksIn: tournament.locksAt?.difference(now) ?? Duration.zero,
            ),
          );
        case TournamentStatus.completed:
          completed.add(
            LbCompletedTournament(
              tournament: tournament,
              finalPlace: 0,
              payoutPhp: 0,
            ),
          );
        case TournamentStatus.draft:
        case TournamentStatus.cancelled:
          break;
      }
    }
    return LbMyTournaments(
      live: live,
      upcoming: upcoming,
      completed: completed,
    );
  }

  @override
  Stream<LbMyTournaments> watchForUser(String userId) async* {
    yield await forUser(userId);
    await for (final _
        in _client
            .from('registrations')
            .stream(primaryKey: ['id'])
            .eq('user_id', userId)) {
      yield await forUser(userId);
    }
  }
}

class SupabaseBracketRepo implements BracketRepo {
  SupabaseBracketRepo(this._client);
  final SupabaseClient _client;

  @override
  Stream<LbBracket> watch(String tournamentId) {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .map((rows) {
          final nullable = rows
              .where((row) => row['bracket_side'] == null)
              .toList();
          Map<String, dynamic>? finalRow;
          if (nullable.isNotEmpty) {
            nullable.sort((a, b) {
              final round = (b['round'] as num).compareTo(a['round'] as num);
              if (round != 0) return round;
              return (b['position'] as num).compareTo(a['position'] as num);
            });
            finalRow = nullable.first;
          }
          final matches = [
            for (final row in rows)
              _matchFromRow(
                row,
                side: identical(row, finalRow) ? BracketSide.grandFinal : null,
              ),
          ];
          return LbBracket(
            tournamentId: tournamentId,
            upper: [
              for (final match in matches)
                if (match.bracketSide == BracketSide.upper) match,
            ]..sort((a, b) => a.round.compareTo(b.round)),
            lower: [
              for (final match in matches)
                if (match.bracketSide == BracketSide.lower) match,
            ]..sort((a, b) => a.round.compareTo(b.round)),
            grandFinal: matches
                .where((match) => match.bracketSide == BracketSide.grandFinal)
                .firstOrNull,
          );
        });
  }
}

class SupabaseRegistrationRepo implements RegistrationRepo {
  SupabaseRegistrationRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbRegistration> register({
    required String tournamentId,
    required String userId,
    String? teamId,
    required PayMethod method,
    required String captchaToken,
  }) async {
    final response = await _client.functions.invoke(
      'registration-reserve',
      body: {
        'tournamentId': tournamentId,
        'teamId': ?teamId,
        'idempotencyKey':
            '$userId:$tournamentId:${DateTime.now().microsecondsSinceEpoch}',
      },
    );
    return _registrationFromRow(_functionData(response));
  }

  @override
  Stream<RegistrationPaymentStatus> watchPayment(String registrationId) {
    return _client
        .from('registrations')
        .stream(primaryKey: ['id'])
        .eq('id', registrationId)
        .where((rows) => rows.isNotEmpty)
        .map(
          (rows) => _enumFromSnake(
            RegistrationPaymentStatus.values,
            rows.first['payment_status'] as String,
          ),
        );
  }
}

class SupabaseResultsRepo implements ResultsRepo {
  SupabaseResultsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<String> requestScreenshotUploadUrl({
    required String matchId,
    required int contentLengthBytes,
  }) async {
    final signed = await _client.storage
        .from('match-screenshots')
        .createSignedUploadUrl(
          '${_client.auth.currentUser?.id ?? 'unknown'}/$matchId.jpg',
        );
    return signed.signedUrl;
  }

  @override
  Future<void> submit({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required String screenshotUrl,
  }) async {
    final response = await _client.functions.invoke(
      'match-submit-result',
      body: {
        'matchId': matchId,
        'scoreA': scoreA,
        'scoreB': scoreB,
        'screenshotUrl': screenshotUrl,
      },
    );
    _functionData(response);
  }

  @override
  Future<void> openDispute({
    required String matchId,
    required String reason,
  }) async {
    final response = await _client.functions.invoke(
      'match-dispute',
      body: {'matchId': matchId, 'reason': reason},
    );
    _functionData(response);
  }
}

class SupabaseProfileRepo implements ProfileRepo {
  SupabaseProfileRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbPlayerProfile> byId(String userId) async {
    final responses = await Future.wait<dynamic>([
      _client.from('profiles').select().eq('id', userId).single(),
      _client.from('user_rank').select().eq('user_id', userId).maybeSingle(),
      _client.from('user_badges').select().eq('user_id', userId),
      _client.from('team_members').select('team_id').eq('user_id', userId),
    ]);
    final profile = responses[0] as Map<String, dynamic>;
    final rankRow = responses[1] as Map<String, dynamic>?;
    final badges = responses[2] as List<dynamic>;
    final memberships = responses[3] as List<dynamic>;
    final authUser = _client.auth.currentUser?.id == userId
        ? _client.auth.currentUser
        : null;
    final rank = rankRow == null
        ? LbUserRank(
            userId: userId,
            totalWins: 0,
            rank: Rank.recruit,
            rankUpdatedAt: DateTime.now(),
          )
        : _rankFromRow(rankRow);
    final losses = (rankRow?['total_losses'] as num?)?.toInt() ?? 0;
    return LbPlayerProfile(
      user: _userFromProfile(profile, authUser: authUser),
      rank: rank,
      badges: [
        for (final row in badges)
          _enumFromSnake(AchievementBadge.values, row['badge_key'] as String),
      ],
      gamesPlayed: ((profile['games'] as List?) ?? const []).cast<String>(),
      totalMatches: rank.totalWins + losses,
      totalWins: rank.totalWins,
      totalLosses: losses,
      totalPayoutPhp: 0,
      teamIds: [for (final row in memberships) row['team_id'] as String],
      recentTournaments: const [],
    );
  }

  @override
  Future<LbPlayerProfile> byUsername(String username) async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();
    return byId(row['id'] as String);
  }

  @override
  Future<void> updateAvatar(String userId, String assetUri) => _client
      .from('profiles')
      .update({'avatar_url': assetUri})
      .eq('id', userId);

  @override
  Future<void> updateRegion(String userId, String region) =>
      _client.from('profiles').update({'region': region}).eq('id', userId);
}

class SupabaseTeamsRepo implements TeamsRepo {
  SupabaseTeamsRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbTeam> byId(String teamId) async {
    final responses = await Future.wait<dynamic>([
      _client.from('teams').select().eq('id', teamId).single(),
      _client.from('team_members').select('user_id').eq('team_id', teamId),
    ]);
    return _teamFromRow(
      responses[0] as Map<String, dynamic>,
      memberIds: [
        for (final row in responses[1] as List<dynamic>)
          row['user_id'] as String,
      ],
    );
  }

  @override
  Future<List<LbTeam>> forUser(String userId) async {
    final rows = await _client
        .from('team_members')
        .select('teams(*)')
        .eq('user_id', userId);
    return [
      for (final row in rows)
        if (row['teams'] != null) _teamFromRow(_map(row['teams'])),
    ];
  }

  @override
  Future<LbTeam> createTeam({
    required String name,
    required String tag,
    required String captainUserId,
  }) async {
    final row = await _client
        .from('teams')
        .insert({'name': name, 'tag': tag, 'captain_user_id': captainUserId})
        .select()
        .single();
    await _client.from('team_members').insert({
      'team_id': row['id'],
      'user_id': captainUserId,
      'role': 'captain',
    });
    return _teamFromRow(row, memberIds: [captainUserId]);
  }

  @override
  Future<void> invite({required String teamId, required String userId}) {
    throw UnsupportedError(
      'The backend does not define a team invitation command yet.',
    );
  }

  @override
  Future<void> acceptInvite(String inviteId) {
    throw UnsupportedError(
      'The backend does not define a team invitation command yet.',
    );
  }

  @override
  Future<void> declineInvite(String inviteId) {
    throw UnsupportedError(
      'The backend does not define a team invitation command yet.',
    );
  }

  @override
  Future<void> leaveTeam({required String teamId, required String userId}) =>
      _client
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId);
}

class SupabasePlayersRepo implements PlayersRepo {
  SupabasePlayersRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<LbPlayerSearchPage> search({
    String? game,
    Rank? minRank,
    String? region,
    bool freeAgentsOnly = false,
    String? cursor,
    int limit = 20,
  }) async {
    dynamic query = _client.from('profiles').select('*, user_rank(*)');
    if (game != null && game != 'All games') {
      query = query.contains('games', [game]);
    }
    if (region != null) query = query.eq('region', region);
    if (cursor != null) query = query.lt('id', cursor);
    final List<dynamic> rows = await query
        .order('id', ascending: false)
        .limit(limit);
    final ids = [for (final row in rows) row['id'] as String];
    final memberIds = <String>{};
    if (ids.isNotEmpty) {
      final memberships = await _client
          .from('team_members')
          .select('user_id')
          .inFilter('user_id', ids);
      memberIds.addAll([
        for (final row in memberships) row['user_id'] as String,
      ]);
    }
    final items = <LbPlayerSearchResult>[];
    for (final row in rows) {
      final user = _userFromProfile(row);
      final nested = row['user_rank'];
      final rankRow = nested is List
          ? (nested.isEmpty ? null : _map(nested.first))
          : (nested == null ? null : _map(nested));
      final rank = rankRow == null
          ? LbUserRank(
              userId: user.id,
              totalWins: 0,
              rank: Rank.recruit,
              rankUpdatedAt: DateTime.now(),
            )
          : _rankFromRow(rankRow);
      final isFreeAgent = !memberIds.contains(user.id);
      if (minRank != null && rank.rank.level < minRank.level) continue;
      if (freeAgentsOnly && !isFreeAgent) continue;
      items.add(
        LbPlayerSearchResult(
          user: user,
          rank: rank,
          games: user.games,
          isFreeAgent: isFreeAgent,
        ),
      );
    }
    return LbPlayerSearchPage(
      items: items,
      nextCursor: rows.length == limit ? rows.last['id'] as String : null,
    );
  }
}

class SupabaseLeaderboardRepo implements LeaderboardRepo {
  SupabaseLeaderboardRepo(this._client);
  final SupabaseClient _client;

  @override
  Future<List<LbLeaderboardPlayer>> topPlayers({
    String? game,
    int limit = 20,
  }) async {
    dynamic query = _client.from('user_rank').select('*, profiles!inner(*)');
    if (game != null && game != 'All games') {
      query = query.contains('profiles.games', [game]);
    }
    final List<dynamic> rows = await query
        .order('total_wins', ascending: false)
        .limit(limit);
    return [
      for (var index = 0; index < rows.length; index++)
        LbLeaderboardPlayer(
          position: index + 1,
          user: _userFromProfile(_map(rows[index]['profiles'])),
          rank: _rankFromRow(rows[index]),
        ),
    ];
  }

  @override
  Future<List<LbLeaderboardTeam>> topTeams({
    String? game,
    int limit = 20,
  }) async {
    dynamic query = _client
        .from('matches')
        .select('winner_id, tournaments!inner(game)')
        .eq('status', 'completed')
        .not('winner_id', 'is', null);
    if (game != null && game != 'All games') {
      query = query.eq('tournaments.game', game);
    }
    final List<dynamic> winners = await query;
    final wins = <String, int>{};
    for (final row in winners) {
      final id = row['winner_id'] as String;
      wins[id] = (wins[id] ?? 0) + 1;
    }
    final orderedIds = wins.keys.toList()
      ..sort((a, b) => wins[b]!.compareTo(wins[a]!));
    final selectedIds = orderedIds.take(limit).toList();
    if (selectedIds.isEmpty) return const [];
    final teams = await _client
        .from('teams')
        .select()
        .inFilter('id', selectedIds);
    final byId = {
      for (final row in teams) row['id'] as String: _teamFromRow(row),
    };
    return [
      for (var index = 0; index < selectedIds.length; index++)
        if (byId[selectedIds[index]] case final LbTeam team)
          LbLeaderboardTeam(
            position: index + 1,
            team: team,
            wins: wins[selectedIds[index]]!,
          ),
    ];
  }

  @override
  Future<int?> playerPosition({required String userId, String? game}) async {
    final players = await topPlayers(game: game, limit: 1000);
    for (final player in players) {
      if (player.user.id == userId) return player.position;
    }
    return null;
  }
}

class SupabaseNotificationsRepo implements NotificationsRepo {
  SupabaseNotificationsRepo(this._client);
  final SupabaseClient _client;

  @override
  Stream<List<LbNotification>> watchForUser(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => [for (final row in rows) _notificationFromRow(row)]);
  }

  @override
  Future<void> markAllRead(String userId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('user_id', userId)
      .filter('read_at', 'is', null);

  @override
  Future<void> markRead(String notificationId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('id', notificationId);

  @override
  Future<void> respondToTeamInvite({
    required String notificationId,
    required bool accept,
  }) {
    throw UnsupportedError(
      'The backend does not define a team invitation command yet.',
    );
  }
}
